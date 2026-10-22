import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../services/sync_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/language_service.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/mono_dialog.dart';
import '../../utils/page_transitions.dart';
import 'data_usage_screen.dart';
import 'delete_confirmation_screen.dart';
import 'privacy_policy_screen.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final _syncService = SyncService();
  final _connectivity = ConnectivityService();
  bool _isManualSyncing = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final count = await _syncService.getPendingSyncCount();
    if (mounted) {
      setState(() => _pendingCount = count);
    }
  }

  Future<void> _triggerManualSync() async {
    if (_isManualSyncing || _syncService.isSyncing) return;

    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() => _isManualSyncing = true);
    try {
      final success = await _syncService.syncAll();
      await _loadPendingCount();

      if (mounted) {
        if (success) {
          TopToast.show(
            context,
            isVi ? 'Đồng bộ dữ liệu lên Firebase thành công!' : 'Firebase cloud sync successful!',
          );
        } else {
          if (!_connectivity.isOnline) {
            TopToast.show(
              context,
              isVi ? 'Không có kết nối mạng. Dữ liệu đã lưu ở SQLite.' : 'No internet connection. Data saved to SQLite.',
              isError: true,
            );
          } else {
            TopToast.show(
              context,
              isVi ? 'Đồng bộ hoàn tất (đã cập nhật phiên bản mới nhất).' : 'Sync completed (latest version updated).',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        TopToast.show(
          context,
          isVi ? 'Lỗi đồng bộ: $e' : 'Sync error: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isManualSyncing = false);
      }
    }
  }

  void _clearCache() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    final confirmed = await MonoDialog.confirm(
      context,
      title: isVi ? 'Xóa bộ nhớ đệm (Cache)' : 'Clear App Cache',
      message: isVi
          ? 'Thao tác này sẽ dọn dẹp các tệp hình ảnh tạm thời và bộ nhớ đệm hiển thị để giải phóng dung lượng. Dữ liệu thu chi của bạn hoàn toàn không bị ảnh hưởng.'
          : 'This will clean up temporary image files and cache to free up storage. Your transaction records will not be affected.',
      cancelText: isVi ? 'Hủy' : 'Cancel',
      confirmText: isVi ? 'Dọn dẹp ngay' : 'Clear Now',
      icon: Icons.cleaning_services_rounded,
    );

    if (confirmed == true && mounted) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      TopToast.show(
        context,
        isVi ? 'Đã dọn sạch bộ nhớ đệm ứng dụng!' : 'App cache cleared successfully!',
      );
    }
  }

  void _clearOldTransactions() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    final confirmed = await MonoDialog.confirm(
      context,
      title: isVi ? 'Dọn dẹp dữ liệu thu/chi cũ' : 'Purge Old Transactions',
      message: isVi
          ? 'Hệ thống sẽ xóa toàn bộ các giao dịch thu/chi từ tháng 8 trở về trước đó trên máy và đồng bộ lên đám mây. Dữ liệu từ tháng 9 trở đi vẫn được giữ an toàn.'
          : 'The system will purge transactions from August and earlier both locally and in cloud sync. Data from September onwards will remain safe.',
      cancelText: isVi ? 'Hủy' : 'Cancel',
      confirmText: isVi ? 'Xóa dữ liệu cũ' : 'Delete Old Data',
      isDestructive: true,
      icon: Icons.auto_delete_rounded,
    );

    if (confirmed == true && mounted) {
      final count = await TransactionRepository().purgeHistoryBeforeSeptember2026();
      await _loadPendingCount();
      if (mounted) {
        TopToast.show(
          context,
          count > 0
              ? (isVi
                  ? 'Đã xóa thành công $count giao dịch từ tháng 8 trở về trước!'
                  : 'Successfully deleted $count transactions from August and earlier!')
              : (isVi
                  ? 'Không còn giao dịch nào từ tháng 8 trở về trước.'
                  : 'No transactions found from August or earlier.'),
        );
      }
    }
  }

  String _formatLastSyncTime(DateTime? time, bool isVi) {
    if (time == null) return isVi ? 'Chưa đồng bộ phiên này' : 'Not synced this session';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return isVi ? 'Vừa xong' : 'Just now';
    if (diff.inMinutes < 60) return isVi ? '${diff.inMinutes} phút trước' : '${diff.inMinutes} mins ago';
    return DateFormat('HH:mm - dd/MM/yyyy').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = context.isDark;
    final isOnline = _connectivity.isOnline;
    final isSyncing = _isManualSyncing || _syncService.isSyncing;
    final lastSyncTime = _syncService.lastSyncTime;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : context.brandColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    isVi ? 'Dữ liệu và riêng tư' : 'Data & Privacy',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Main Content Area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HERO: CLOUD SYNC CARD
                      _buildSyncHeroCard(isDark, isOnline, isSyncing, lastSyncTime, isVi),
                      const SizedBox(height: 24),

                      // Section 1: QUẢN LÝ DỮ LIỆU
                      _buildSectionTitle(isVi ? 'QUẢN LÝ DỮ LIỆU' : 'DATA MANAGEMENT'),
                      _buildCardContainer(
                        isDark: isDark,
                        children: [
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.data_usage_rounded,
                            title: isVi ? 'Sử dụng dữ liệu' : 'Data Usage',
                            subtitle: isVi
                                ? 'Kiểm soát mức tiêu thụ dữ liệu mạng và bộ nhớ'
                                : 'Control network data and storage usage',
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideRight(const DataUsageScreen()),
                            ),
                          ),
                          _buildDivider(isDark),
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.cleaning_services_rounded,
                            title: isVi ? 'Dọn dẹp bộ nhớ đệm (Cache)' : 'Clear App Cache',
                            subtitle: isVi ? 'Giải phóng dung lượng hình ảnh tạm' : 'Free up temporary image storage',
                            onTap: _clearCache,
                          ),
                          _buildDivider(isDark),
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.auto_delete_outlined,
                            title: isVi ? 'Dọn dẹp dữ liệu thu/chi cũ' : 'Purge Old Transactions',
                            subtitle: isVi
                                ? 'Xóa toàn bộ giao dịch từ tháng 8 trở về trước'
                                : 'Delete all transactions from August and earlier',
                            onTap: _clearOldTransactions,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section 2: CHÍNH SÁCH BẢO VỆ RIÊNG TƯ
                      _buildSectionTitle(isVi ? 'CHÍNH SÁCH & BẢO MẬT' : 'POLICIES & PRIVACY'),
                      _buildCardContainer(
                        isDark: isDark,
                        children: [
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.privacy_tip_outlined,
                            title: isVi ? 'Chính sách bảo mật' : 'Privacy Policy',
                            subtitle: isVi
                                ? 'Tìm hiểu cách chúng tôi bảo vệ thông tin của bạn'
                                : 'Learn how we protect your information',
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideRight(const PrivacyPolicyScreen()),
                            ),
                          ),
                          _buildDivider(isDark),
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.lock_person_outlined,
                            title: isVi ? 'Quyền sở hữu dữ liệu' : 'Data Ownership',
                            subtitle: isVi
                                ? 'Dữ liệu tài chính chỉ thuộc về bạn và luôn được mã hóa'
                                : 'Your financial records belong exclusively to you and are always encrypted',
                            badge: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.brandColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isVi ? 'An toàn' : 'Secured',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.brandColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section 3: VÙNG NGUY HIỂM (Danger Zone)
                      _buildSectionTitle(isVi ? 'VÙNG NGUY HIỂM' : 'DANGER ZONE'),
                      _buildCardContainer(
                        isDark: isDark,
                        children: [
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideRight(const DeleteConfirmationScreen()),
                            ),
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: context.expense.withValues(alpha: isDark ? 0.2 : 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.delete_forever_rounded, color: context.expense, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isVi ? 'Xóa tài khoản vĩnh viễn' : 'Delete Account Permanently',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: context.expense,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          isVi
                                              ? 'Xóa tài khoản và toàn bộ dữ liệu trên đám mây'
                                              : 'Permanently remove your account and all cloud data',
                                          style: TextStyle(fontSize: 12.5, color: context.colors.onSurfaceVariant, height: 1.25),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.colors.onSurfaceVariant.withValues(alpha: 0.5)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
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

  Widget _buildSyncHeroCard(
    bool isDark,
    bool isOnline,
    bool isSyncing,
    DateTime? lastSyncTime,
    bool isVi,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isOnline ? context.brandColor : context.colors.onSurfaceVariant)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: isOnline ? context.brandColor : context.colors.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'Đồng bộ đám mây Firebase' : 'Firebase Cloud Sync',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? context.income : context.warning,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline
                              ? (isVi ? 'Đang kết nối Firestore' : 'Connected to Firestore')
                              : (isVi ? 'Chế độ ngoại tuyến (SQLite)' : 'Offline Mode (SQLite)'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? context.surfaceElevatedColor : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'Đồng bộ gần nhất' : 'Last Synced',
                      style: TextStyle(fontSize: 11, color: context.colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatLastSyncTime(lastSyncTime, isVi),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isVi ? 'Hàng chờ đồng bộ' : 'Pending Queue',
                      style: TextStyle(fontSize: 11, color: context.colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _pendingCount == 0
                          ? (isVi ? 'Đã đồng bộ 100%' : '100% Synced')
                          : (isVi ? '$_pendingCount mục chờ đẩy' : '$_pendingCount items pending'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _pendingCount == 0 ? context.income : context.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Button: "Đồng bộ ngay bây giờ"
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: isSyncing ? null : _triggerManualSync,
              child: isSyncing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isVi ? 'Đang đồng bộ dữ liệu...' : 'Syncing data...',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sync_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isVi ? 'Đồng bộ ngay bây giờ' : 'Sync Now',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: context.colors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCardContainer({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingRow({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? badge,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.brandColor.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: context.brandColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.colors.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              badge,
            ],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.colors.onSurfaceVariant.withValues(alpha: 0.5)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 62,
      endIndent: 16,
      color: context.dividerColor,
    );
  }
}
