import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/sync_service.dart';
import '../../services/language_service.dart';
import '../../services/transaction_balance_service.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../widgets/top_toast.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../utils/category_utils.dart';
import '../../utils/page_transitions.dart';
import '../../services/receipt_storage_service.dart';
import 'edit_transaction_screen.dart';
import 'transaction_photo_detail_screen.dart';
import '../../utils/currency_format_utils.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late TransactionModel _transaction;
  WalletModel? _wallet;
  bool _isLoadingWallet = true;
  StreamSubscription? _txSubscription;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _loadWalletInfo();
    _refreshTransaction();

    _txSubscription = TransactionRepository().getTransactionsStream().listen((list) {
      if (!mounted) return;
      final match = list.where((t) => t.id == _transaction.id).firstOrNull;
      if (match != null && (match.syncStatus != _transaction.syncStatus || match.amount != _transaction.amount)) {
        setState(() {
          _transaction = match;
        });
      }
    });
  }

  @override
  void dispose() {
    _txSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadWalletInfo() async {
    if (_transaction.walletId.isNotEmpty) {
      final w = await WalletRepository().getWalletById(_transaction.walletId);
      if (mounted) {
        setState(() {
          _wallet = w;
          _isLoadingWallet = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _wallet = null;
          _isLoadingWallet = false;
        });
      }
    }
  }

  bool _isManualSyncing = false;

  Future<void> _triggerManualSync() async {
    if (_isManualSyncing) return;
    setState(() => _isManualSyncing = true);
    try {
      // Đồng bộ trực tiếp giao dịch này lên Firestore
      await SyncService().syncSingleTransaction(_transaction.id);
      final recheck = await TransactionRepository().getTransactionById(_transaction.id);
      if (recheck != null && mounted) {
        setState(() {
          _transaction = recheck;
        });
      }
      if (mounted) {
        TopToast.show(context, 'Đã đồng bộ giao dịch lên Firebase thành công!');
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        TopToast.show(context, 'Đồng bộ thất bại: $errorMsg', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isManualSyncing = false);
      }
    }
  }

  Future<void> _refreshTransaction() async {
    final updated = await TransactionRepository().getTransactionById(_transaction.id);
    if (updated != null && mounted) {
      setState(() {
        _transaction = updated;
      });
      _loadWalletInfo();

      // Nếu đang online nhưng SQLite ghi nhận chưa synced, chạy sync nền để đẩy lên cloud
      if (updated.syncStatus != 'synced') {
        SyncService().syncNow().then((_) async {
          final recheck = await TransactionRepository().getTransactionById(_transaction.id);
          if (recheck != null && mounted) {
            setState(() {
              _transaction = recheck;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final isIncome = _transaction.isIncome;
    final category = _transaction.category;
    final description = _transaction.description;
    final date = '${_transaction.date.day.toString().padLeft(2, '0')}/${_transaction.date.month.toString().padLeft(2, '0')}/${_transaction.date.year}';
    final time = _transaction.time;
    final amount = '${isIncome ? "+" : "-"} ${CurrencyUtils.formatCurrency(_transaction.amount)}'; 
    final icon = _transaction.icon;

    // Tự động chọn màu tùy theo trạng thái Thu / Chi
    final Color statusColor = isIncome
        ? const Color(0xFF24A869) // Xanh lá
        : const Color(0xFFE17E5B); // Cam đất
    final String statusText = isIncome ? 'Khoản Thu' : 'Khoản Chi';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. CUSTOM APP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Chi tiết giao dịch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    offset: const Offset(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final result = await Navigator.push(
                          context, 
                          PageTransitions.slideRight(EditTransactionScreen(transaction: _transaction)),
                        );
                        if (result == true) {
                          await _refreshTransaction();
                        }
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Xác nhận xóa'),
                            content: Text(
                              _transaction.isTransfer
                                  ? 'Đây là giao dịch chuyển tiền giữa các ví. Xóa giao dịch này sẽ tự động hoàn lại tiền cho cả 2 ví liên quan.'
                                  : 'Bạn có chắc chắn muốn xóa giao dịch này không?',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            // Xóa giao dịch và hoàn lại số dư ví trong 1 transaction nguyên tử
                            await TransactionBalanceService().deleteTransactionAtomic(_transaction);

                            // 3. Đồng bộ lên Firestore nếu có mạng
                            try {
                              SyncService().syncNow();
                            } catch (_) {}

                            if (context.mounted) {
                              TopToast.show(context, 'Đã xóa giao dịch thành công!');
                              Navigator.pop(context, true);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              TopToast.show(context, 'Lỗi khi xóa giao dịch: $e', isError: true);
                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (!_transaction.isTransfer)
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: const [
                              Icon(Icons.edit_outlined, color: Color(0xFF438883), size: 20),
                              SizedBox(width: 10),
                              Text('Chỉnh sửa'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            SizedBox(width: 10),
                            Text('Xóa giao dịch', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. KHUNG NỘI DUNG BO GÓC TRÊN
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: 32,
                    bottom: 40,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    children: [
                      // ICON GIAO DỊCH CHÍNH GIỮA
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: CategoryUtils.getLightBgColor(category, isDark),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: CategoryUtils.getVibrantColor(category), size: 36),
                      ),
                      const SizedBox(height: 14),

                      // VIÊN THUỐC TRẠNG THÁI (Thu nhập / Chi phí)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // SỐ TIỀN TO BỰ
                      Text(
                        amount,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // KHỐI THÔNG TIN VÍ TIỀN (THEO YÊU CẦU NGƯỜI DÙNG)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF222C2A) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Color(_wallet?.colorValue ?? 0xFF438883).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _wallet?.icon ?? Icons.account_balance_wallet_rounded,
                                color: Color(_wallet?.colorValue ?? 0xFF438883),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isIncome ? 'Tiền nhận vào ví' : 'Tiền lấy từ ví',
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _wallet != null
                                        ? _wallet!.name
                                        : (_transaction.walletId.isNotEmpty
                                            ? (_isLoadingWallet ? 'Đang tải thông tin ví...' : 'Ví đã xóa / chưa rõ')
                                            : 'Chưa gắn ví'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (_wallet != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _wallet!.typeDisplayName,
                                      style: TextStyle(
                                        color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // TIÊU ĐỀ CHI TIẾT GIAO DỊCH
                      Row(
                        children: [
                          Text(
                            'Chi tiết thông tin',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // CÁC DÒNG THÔNG TIN CHI TIẾT
                      _buildDetailRow('Danh mục', category),
                      _buildDetailRow('Nội dung', description.isEmpty ? 'Không có nội dung' : description),
                      _buildDetailRow('Thời gian', time.isEmpty ? '--:--' : time),
                      _buildDetailRow('Ngày', date),
                      _buildDetailRow(
                        'Phân loại nguồn', 
                        _transaction.isTransfer
                            ? 'Chuyển tiền giữa các ví'
                            : (_transaction.source == 'fund' ? 'Quỹ chi tiêu nhóm' : 'Chi tiêu cá nhân'),
                        valueColor: _transaction.isTransfer
                            ? const Color(0xFF0284C7)
                            : (_transaction.source == 'fund' ? const Color(0xFF438883) : null),
                      ),
                      // TRẠNG THÁI ĐỒNG BỘ TƯƠNG TÁC (CHẠM ĐỂ ĐỒNG BỘ NGAY)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr('sync_status'),
                              style: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: _isManualSyncing ? null : _triggerManualSync,
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: (_transaction.syncStatus == 'synced'
                                              ? const Color(0xFF24A869)
                                              : const Color(0xFFF59E0B))
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: (_transaction.syncStatus == 'synced'
                                                ? const Color(0xFF24A869)
                                                : const Color(0xFFF59E0B))
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_isManualSyncing) ...[
                                            const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF438883)),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Đang đồng bộ...',
                                              style: TextStyle(
                                                color: Color(0xFF438883),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ] else ...[
                                            Icon(
                                              _transaction.syncStatus == 'synced'
                                                  ? Icons.cloud_done_rounded
                                                  : Icons.sync_rounded,
                                              size: 16,
                                              color: _transaction.syncStatus == 'synced'
                                                  ? const Color(0xFF24A869)
                                                  : const Color(0xFFF59E0B),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _transaction.syncStatus == 'synced'
                                                  ? context.tr('synced_cloud')
                                                  : 'Chưa đồng bộ (Chạm để đồng bộ)',
                                              style: TextStyle(
                                                color: _transaction.syncStatus == 'synced'
                                                    ? const Color(0xFF24A869)
                                                    : const Color(0xFFF59E0B),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ẢNH HÓA ĐƠN / CHỨNG TỪ
                      () {
                        final hasLocalPhoto = _transaction.photoLocalPath.isNotEmpty &&
                            File(_transaction.photoLocalPath).existsSync();
                        final hasRemotePhoto = _transaction.photoUrl.isNotEmpty;
                        final hasAnyPhoto = _transaction.hasPhoto && (hasLocalPhoto || hasRemotePhoto);

                        if (!hasAnyPhoto) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Divider(color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFEEEEEE), thickness: 1),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Ảnh hóa đơn / Chứng từ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF438883).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_in_rounded, size: 14, color: Color(0xFF438883)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Chạm để xem',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF438883)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                PageTransitions.slideRight(
                                  TransactionPhotoDetailScreen(transaction: _transaction),
                                ),
                              ),
                              child: Hero(
                                tag: 'tx_photo_${_transaction.id}',
                                child: Container(
                                  width: double.infinity,
                                  constraints: const BoxConstraints(maxHeight: 280, minHeight: 160),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0D1615) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: ReceiptStorageService.buildReceiptImage(
                                      photoLocalPath: _transaction.photoLocalPath,
                                      photoUrl: _transaction.photoUrl,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }(),

                      const SizedBox(height: 20),
                      Divider(color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFEEEEEE), thickness: 1),
                      const SizedBox(height: 16),

                      // TỔNG CỘNG
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tổng cộng',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            amount,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HÀM TẠO TỪNG DÒNG CHI TIẾT ---
  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: valueColor ?? (isDark ? Colors.white : const Color(0xFF1F2937)),
                    fontSize: 15,
                    fontWeight: valueColor != null
                        ? FontWeight.w600
                        : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}