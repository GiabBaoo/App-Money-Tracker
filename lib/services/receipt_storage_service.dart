import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../data/local/database_helper.dart';
import '../data/local/sync_queue_writer.dart';
import '../data/repositories/transaction_repository.dart';
import 'connectivity_service.dart';
import 'sync_trigger.dart';

/// Dịch vụ quản lý và lưu trữ hóa đơn, chứng từ:
/// - Lưu trữ vĩnh viễn trên máy (Documents/receipts - không bị xóa khi dọn cache)
/// - Đồng bộ đám mây (Firebase Storage với Fallback Base64 qua Firestore)
/// - Hiển thị đa nguồn thông minh (File -> Base64 -> HTTPS URL)
/// - Trình phóng to toàn màn hình cảm ứng đa điểm (InteractiveViewer)
class ReceiptStorageService {
  static final ReceiptStorageService _instance =
      ReceiptStorageService._internal();
  factory ReceiptStorageService() => _instance;
  ReceiptStorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Lấy hoặc tạo thư mục lưu trữ hóa đơn vĩnh viễn
  Future<Directory> get _receiptsDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/receipts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Sao chép file từ cache (ImagePicker) sang thư mục vĩnh viễn của ứng dụng
  Future<String> saveReceiptPermanently(
    File tempFile,
    String transactionId,
  ) async {
    try {
      final dir = await _receiptsDirectory;
      final ext = tempFile.path.contains('.')
          ? tempFile.path.split('.').last.toLowerCase()
          : 'jpg';
      final fileName =
          'receipt_${transactionId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final targetPath = '${dir.path}/$fileName';

      final permanentFile = await tempFile.copy(targetPath);
      debugPrint(
        'ReceiptStorage: Đã lưu hóa đơn vĩnh viễn tại: ${permanentFile.path}',
      );
      return permanentFile.path;
    } catch (e) {
      debugPrint('ReceiptStorage: Lỗi sao chép ảnh sang thư mục vĩnh viễn: $e');
      return tempFile.path; // Fallback đường dẫn tạm thời nếu lỗi I/O
    }
  }

  static const int _maxBase64Bytes = 200 * 1024; // Giới hạn Base64 fallback <= 200 KB

  /// Upload ảnh hóa đơn lên Firebase Storage (có timeout 20s) và giới hạn Base64 fallback <= 200 KB.
  Future<({String photoUrl, String photoStoragePath, String photoLocalPath})>
  processAndUploadReceipt({
    required String uid,
    required String transactionId,
    required File pickedFile,
  }) async {
    // 1. Luôn lưu vĩnh viễn vào bộ nhớ máy (SQLite-first)
    final permanentLocalPath = await saveReceiptPermanently(
      pickedFile,
      transactionId,
    );
    return uploadSavedReceipt(
      uid: uid,
      transactionId: transactionId,
      permanentLocalPath: permanentLocalPath,
    );
  }

  /// Upload file đã lưu local lên Firebase Storage (timeout 20s).
  /// Nếu lỗi/offline: chỉ fallback Base64 khi file <= 200 KB, ngược lại giữ local path.
  Future<({String photoUrl, String photoStoragePath, String photoLocalPath})>
  uploadSavedReceipt({
    required String uid,
    required String transactionId,
    required String permanentLocalPath,
  }) async {
    final fileToUpload = File(permanentLocalPath);
    if (!await fileToUpload.exists()) {
      return (
        photoUrl: '',
        photoStoragePath: '',
        photoLocalPath: permanentLocalPath,
      );
    }

    final ext = fileToUpload.path.contains('.')
        ? fileToUpload.path.split('.').last.toLowerCase()
        : 'jpg';
    final fileName = '$transactionId.$ext';
    final storagePath = 'transaction_images/$uid/$transactionId/$fileName';

    if (ConnectivityService().isOnline) {
      try {
        final ref = _storage.ref().child(storagePath);
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        );
        final task = await ref
            .putFile(fileToUpload, metadata)
            .timeout(const Duration(seconds: 20));
        final downloadUrl = await task.ref
            .getDownloadURL()
            .timeout(const Duration(seconds: 10));

        debugPrint(
          'ReceiptStorage: Tải lên Firebase Storage thành công: $downloadUrl',
        );
        return (
          photoUrl: downloadUrl,
          photoStoragePath: storagePath,
          photoLocalPath: permanentLocalPath,
        );
      } catch (storageError) {
        debugPrint(
          'ReceiptStorage: Firebase Storage upload không thành công ($storageError)',
        );
      }
    }

    // Fallback Base64 chỉ khi dung lượng <= 200 KB để không làm phình Firestore doc
    try {
      final bytes = await fileToUpload.readAsBytes();
      if (bytes.length <= _maxBase64Bytes) {
        final base64String = base64Encode(bytes);
        final dataUri = 'data:image/jpeg;base64,$base64String';
        return (
          photoUrl: dataUri,
          photoStoragePath: '',
          photoLocalPath: permanentLocalPath,
        );
      }
    } catch (fallbackError) {
      debugPrint('ReceiptStorage: Base64 fallback error: $fallbackError');
    }

    return (
      photoUrl: '',
      photoStoragePath: '',
      photoLocalPath: permanentLocalPath,
    );
  }

  /// Chạy upload ảnh nền sau khi giao dịch đã lưu local, xong thì cập nhật photoUrl vào SQLite + sync_queue.
  Future<void> uploadReceiptInBackgroundAndUpdateTx({
    required String uid,
    required String transactionId,
    required String permanentLocalPath,
  }) async {
    try {
      final res = await uploadSavedReceipt(
        uid: uid,
        transactionId: transactionId,
        permanentLocalPath: permanentLocalPath,
      );
      if (res.photoUrl.isEmpty) return;

      final db = await DatabaseHelper().database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.transaction((txn) async {
        final existing = await txn.query(
          'transactions',
          where: 'id = ? AND uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
          whereArgs: [transactionId, uid],
          limit: 1,
        );
        if (existing.isEmpty) return;

        await txn.update(
          'transactions',
          {
            'photoUrl': res.photoUrl,
            'photoStoragePath': res.photoStoragePath,
            'hasPhoto': 1,
            'updatedAt': nowMs,
            'syncStatus': 'pending',
          },
          where: 'id = ? AND uid = ?',
          whereArgs: [transactionId, uid],
        );
        await SyncQueueWriter.enqueue(
          txn,
          ownerUid: uid,
          table: 'transactions',
          recordId: transactionId,
          action: 'UPDATE',
          data: {
            'uid': uid,
            'photoUrl': res.photoUrl,
            'photoStoragePath': res.photoStoragePath,
            'hasPhoto': true,
            'updatedAt': nowMs,
          },
        );
      });
      TransactionRepository().notifyTransactionsChanged();
      SyncTrigger.requestSync();
    } catch (e) {
      debugPrint('ReceiptStorage: Background upload error: $e');
    }
  }

  /// Widget hiển thị ảnh hóa đơn thông minh hỗ trợ 3 nguồn dữ liệu: Local File -> Base64 -> Network URL
  static Widget buildReceiptImage({
    required String photoLocalPath,
    required String photoUrl,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
  }) {
    // 1. Kiểm tra file cục bộ trên máy
    if (photoLocalPath.isNotEmpty) {
      final file = File(photoLocalPath);
      if (file.existsSync()) {
        final int? resolvedCacheWidth = (width != null && width.isFinite)
            ? (width * 2.5).round()
            : (height != null && height.isFinite ? null : 800);
        final int? resolvedCacheHeight = (height != null && height.isFinite)
            ? (height * 2.5).round()
            : null;
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: resolvedCacheWidth,
          cacheHeight: resolvedCacheHeight,
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackImage(photoUrl, fit, width, height, placeholder),
        );
      }
    }

    // 2. Nếu không có file máy, dùng photoUrl
    return _buildFallbackImage(photoUrl, fit, width, height, placeholder);
  }

  static Widget _buildFallbackImage(
    String photoUrl,
    BoxFit fit,
    double? width,
    double? height,
    Widget? placeholder,
  ) {
    if (photoUrl.isEmpty) {
      return placeholder ?? _defaultPlaceholder(width, height);
    }

    // 2a. Base64 Data URI
    if (photoUrl.startsWith('data:image/')) {
      try {
        final base64Data = photoUrl.split(',').last;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              placeholder ?? _defaultPlaceholder(width, height),
        );
      } catch (_) {
        return placeholder ?? _defaultPlaceholder(width, height);
      }
    }

    // 2b. Network URL
    return Image.network(
      photoUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.grey.withValues(alpha: 0.1),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Color(0xFF438883),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          placeholder ?? _defaultPlaceholder(width, height),
    );
  }

  static Widget _defaultPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: const Icon(
        Icons.receipt_long_rounded,
        size: 36,
        color: Colors.grey,
      ),
    );
  }

  /// Mở trình xem hóa đơn toàn màn hình với tính năng phóng to / thu nhỏ cảm ứng đa điểm (Pinch-to-zoom)
  static void showFullScreenViewer(
    BuildContext context, {
    required String photoLocalPath,
    required String photoUrl,
    String title = 'Chi tiết hóa đơn',
  }) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                // Khu vực zoom ảnh đa điểm
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    clipBehavior: Clip.none,
                    child: buildReceiptImage(
                      photoLocalPath: photoLocalPath,
                      photoUrl: photoUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),

                // Thanh công cụ trên cùng
                Positioned(
                  top: 10,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.zoom_in_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                          side: const BorderSide(color: Colors.white24),
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Gợi ý cử chỉ ở góc dưới
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text(
                        'Dùng 2 ngón tay để phóng to hoặc kéo di chuyển',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
