import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Dịch vụ quản lý và lưu trữ hóa đơn, chứng từ:
/// - Lưu trữ vĩnh viễn trên máy (Documents/receipts - không bị xóa khi dọn cache)
/// - Đồng bộ đám mây (Firebase Storage với Fallback Base64 qua Firestore)
/// - Hiển thị đa nguồn thông minh (File -> Base64 -> HTTPS URL)
/// - Trình phóng to toàn màn hình cảm ứng đa điểm (InteractiveViewer)
class ReceiptStorageService {
  static final ReceiptStorageService _instance = ReceiptStorageService._internal();
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
  Future<String> saveReceiptPermanently(File tempFile, String transactionId) async {
    try {
      final dir = await _receiptsDirectory;
      final ext = tempFile.path.contains('.') ? tempFile.path.split('.').last.toLowerCase() : 'jpg';
      final fileName = 'receipt_${transactionId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final targetPath = '${dir.path}/$fileName';

      final permanentFile = await tempFile.copy(targetPath);
      debugPrint('ReceiptStorage: Đã lưu hóa đơn vĩnh viễn tại: ${permanentFile.path}');
      return permanentFile.path;
    } catch (e) {
      debugPrint('ReceiptStorage: Lỗi sao chép ảnh sang thư mục vĩnh viễn: $e');
      return tempFile.path; // Fallback đường dẫn tạm thời nếu lỗi I/O
    }
  }

  /// Upload ảnh hóa đơn: Thử Firebase Storage trước -> Fallback Base64 an toàn nếu lỗi billing/mạng
  Future<({String photoUrl, String photoStoragePath, String photoLocalPath})> processAndUploadReceipt({
    required String uid,
    required String transactionId,
    required File pickedFile,
  }) async {
    // 1. Luôn lưu vĩnh viễn vào bộ nhớ máy (SQLite-first)
    final permanentLocalPath = await saveReceiptPermanently(pickedFile, transactionId);
    final fileToUpload = File(permanentLocalPath);

    final ext = fileToUpload.path.contains('.') ? fileToUpload.path.split('.').last.toLowerCase() : 'jpg';
    final fileName = '$transactionId.$ext';
    final storagePath = 'transaction_images/$uid/$transactionId/$fileName';

    try {
      // 2. Thử upload lên Firebase Storage
      final ref = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      );
      final task = await ref.putFile(fileToUpload, metadata);
      final downloadUrl = await task.ref.getDownloadURL();

      debugPrint('ReceiptStorage: Tải lên Firebase Storage thành công: $downloadUrl');
      return (
        photoUrl: downloadUrl,
        photoStoragePath: storagePath,
        photoLocalPath: permanentLocalPath,
      );
    } catch (storageError) {
      debugPrint('ReceiptStorage: Firebase Storage upload không thành công ($storageError). Kích hoạt Base64 Fallback...');

      // 3. Fallback: Mã hóa Base64 Data URI lưu trực tiếp lên Firestore
      try {
        final bytes = await fileToUpload.readAsBytes();
        final base64String = base64Encode(bytes);
        final dataUri = 'data:image/jpeg;base64,$base64String';

        debugPrint('ReceiptStorage: Đã tạo Base64 fallback (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
        return (
          photoUrl: dataUri,
          photoStoragePath: '',
          photoLocalPath: permanentLocalPath,
        );
      } catch (fallbackError) {
        debugPrint('ReceiptStorage: Base64 fallback error: $fallbackError');
        return (
          photoUrl: '',
          photoStoragePath: '',
          photoLocalPath: permanentLocalPath,
        );
      }
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
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
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
              child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF438883)),
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
      child: const Icon(Icons.receipt_long_rounded, size: 36, color: Colors.grey),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 18),
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
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
