import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../services/sync_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/language_service.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/mono_dialog.dart';
import '../../utils/page_transitions.dart';
import '../../utils/currency_format_utils.dart';
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
  bool _isCreatingBackup = false;
  bool _isLoadingBackups = false;
  String? _restoringBackupId;
  int _pendingCount = 0;
  List<CloudBackupSummary> _backups = const [];

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
    _loadCloudBackups();
  }

  Future<void> _loadPendingCount() async {
    final count = await _syncService.getPendingSyncCount();
    if (mounted) {
      setState(() => _pendingCount = count);
    }
  }

  Future<void> _loadCloudBackups() async {
    if (_isLoadingBackups) return;
    setState(() => _isLoadingBackups = true);
    try {
      final list = await _syncService.listCloudBackups();
      if (mounted) {
        setState(() => _backups = list);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingBackups = false);
      }
    }
  }

  /// Đồng bộ 2 chiều thực sự: đẩy thay đổi cục bộ lên Firebase & kéo dữ liệu mới nhất từ Firebase về máy
  Future<void> _triggerManualSync() async {
    if (_isManualSyncing ||
        _isCreatingBackup ||
        _restoringBackupId != null ||
        _syncService.isSyncing) {
      return;
    }

    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() => _isManualSyncing = true);
    try {
      final report = await _syncService.forceFullResync();
      await _loadPendingCount();
      await _loadCloudBackups();

      if (mounted) {
        if (report.isSuccess) {
          final downloadedWallets = report.downloadSuccess['wallets'] ?? 0;
          final downloadedTxs = report.downloadSuccess['transactions'] ?? 0;
          TopToast.show(
            context,
            isVi
                ? 'Đồng bộ 2 chiều thành công ($downloadedWallets ví, $downloadedTxs giao dịch)!'
                : '2-way sync completed ($downloadedWallets wallets, $downloadedTxs transactions)!',
          );
        } else if (!_connectivity.isOnline ||
            report.uploadError == 'Device is offline.') {
          TopToast.show(
            context,
            isVi
                ? 'Không có kết nối mạng. Dữ liệu đã lưu ở SQLite.'
                : 'No internet connection. Data saved to SQLite.',
            isError: true,
          );
        } else {
          TopToast.show(
            context,
            isVi
                ? 'Đồng bộ chưa hoàn tất: ${report.uploadError ?? report.downloadErrors.values.first}'
                : 'Sync incomplete: ${report.uploadError ?? report.downloadErrors.values.first}',
            isError: true,
          );
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

  /// Tạo bản sao lưu mới từ trạng thái hiện tại trên máy lên Firebase
  Future<void> _triggerCreateBackup() async {
    if (_isManualSyncing ||
        _isCreatingBackup ||
        _restoringBackupId != null ||
        _syncService.isSyncing) {
      return;
    }

    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() => _isCreatingBackup = true);
    try {
      final success = await _syncService.createCloudBackupSnapshot(
        label: isVi ? 'Sao lưu thủ công' : 'Manual Backup',
      );
      await _loadPendingCount();
      await _loadCloudBackups();

      if (mounted) {
        if (success) {
          TopToast.show(
            context,
            isVi
                ? 'Đã tạo bản sao lưu mới trên Firebase thành công!'
                : 'New cloud backup created on Firebase!',
          );
        } else {
          TopToast.show(
            context,
            isVi
                ? 'Không thể tạo bản sao lưu. Vui lòng kiểm tra kết nối mạng.'
                : 'Could not create backup. Please check your internet connection.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        TopToast.show(
          context,
          isVi ? 'Lỗi tạo sao lưu: $e' : 'Backup error: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingBackup = false);
      }
    }
  }

  /// Khôi phục dữ liệu từ một bản sao lưu đã chọn trong danh sách
  Future<void> _confirmAndRestoreBackup(CloudBackupSummary backup) async {
    if (_isManualSyncing || _isCreatingBackup || _restoringBackupId != null) {
      return;
    }
    final isVi = LanguageScope.of(context).isVietnamese;
    final timeStr = DateFormat('HH:mm - dd/MM/yyyy').format(backup.backedUpAt);
    final walletSummary = backup.wallets
        .map((w) => '• ${w.name}: ${CurrencyUtils.formatCurrency(w.balance)}')
        .join('\n');

    final confirmed = await MonoDialog.confirm(
      context,
      title: isVi ? 'Khôi phục bản sao lưu?' : 'Restore Cloud Backup?',
      message: isVi
          ? 'Khôi phục bản sao lưu lúc $timeStr?\n\n'
                'Tổng số dư: ${CurrencyUtils.formatCurrency(backup.totalBalance)}\n'
                '$walletSummary\n\n'
                'Số dư các ví trên máy và Firebase sẽ được cập nhật khớp theo bản sao lưu này.'
          : 'Restore backup from $timeStr?\n\n'
                'Total balance: ${CurrencyUtils.formatCurrency(backup.totalBalance)}\n'
                '$walletSummary\n\n'
                'Your wallets on this device and Firebase will be updated to match this backup.',
      cancelText: isVi ? 'Hủy' : 'Cancel',
      confirmText: isVi ? 'Khôi phục ngay' : 'Restore Now',
      icon: Icons.restore_rounded,
    );

    if (confirmed != true || !mounted) return;

    setState(() => _restoringBackupId = backup.id);
    try {
      final ok = await _syncService.restoreCloudBackupById(backup.id);
      await _loadPendingCount();
      await _loadCloudBackups();

      if (mounted) {
        if (ok) {
          TopToast.show(
            context,
            isVi
                ? 'Đã khôi phục thành công! Tổng số dư: ${CurrencyUtils.formatCurrency(backup.totalBalance)}'
                : 'Restored successfully! Total balance: ${CurrencyUtils.formatCurrency(backup.totalBalance)}',
          );
        } else {
          TopToast.show(
            context,
            isVi
                ? 'Khôi phục thất bại. Vui lòng kiểm tra kết nối mạng và thử lại.'
                : 'Restore failed. Please check your connection and try again.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        TopToast.show(
          context,
          isVi ? 'Lỗi khôi phục: $e' : 'Restore error: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _restoringBackupId = null);
      }
    }
  }

  Future<void> _confirmAndDeleteBackup(CloudBackupSummary backup) async {
    if (backup.isLatestDoc || _restoringBackupId != null) return;
    final isVi = LanguageScope.of(context).isVietnamese;
    final timeStr = DateFormat('HH:mm - dd/MM/yyyy').format(backup.backedUpAt);

    final confirmed = await MonoDialog.confirm(
      context,
      title: isVi ? 'Xóa bản sao lưu?' : 'Delete Backup?',
      message: isVi
          ? 'Xóa bản sao lưu lúc $timeStr khỏi Firebase? Dữ liệu hiện tại trên máy không bị ảnh hưởng.'
          : 'Delete backup from $timeStr on Firebase? Your current data will not be affected.',
      cancelText: isVi ? 'Hủy' : 'Cancel',
      confirmText: isVi ? 'Xóa' : 'Delete',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (confirmed != true || !mounted) return;
    final ok = await _syncService.deleteCloudBackup(backup.id);
    if (ok) {
      await _loadCloudBackups();
      if (mounted) {
        TopToast.show(
          context,
          isVi ? 'Đã xóa bản sao lưu.' : 'Backup deleted.',
        );
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
        isVi
            ? 'Đã dọn sạch bộ nhớ đệm ứng dụng!'
            : 'App cache cleared successfully!',
      );
    }
  }

  String _formatLastSyncTime(DateTime? time, bool isVi) {
    if (time == null) {
      return isVi ? 'Chưa đồng bộ phiên này' : 'Not synced this session';
    }
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return isVi ? 'Vừa xong' : 'Just now';
    if (diff.inMinutes < 60) {
      return isVi
          ? '${diff.inMinutes} phút trước'
          : '${diff.inMinutes} mins ago';
    }
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
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    isVi ? 'Dữ liệu và riêng tư' : 'Data & Privacy',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HERO: CLOUD SYNC CARD
                      _buildSyncHeroCard(
                        isDark,
                        isOnline,
                        isSyncing,
                        lastSyncTime,
                        isVi,
                      ),
                      const SizedBox(height: 24),

                      // Section 0: BẢN SAO LƯU & KHÔI PHỤC ĐÁM MÂY
                      _buildCloudBackupsSection(isDark, isVi),
                      const SizedBox(height: 24),

                      // Section 1: QUẢN LÝ DỮ LIỆU
                      _buildSectionTitle(
                        isVi ? 'QUẢN LÝ DỮ LIỆU' : 'DATA MANAGEMENT',
                      ),
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
                              PageTransitions.slideRight(
                                const DataUsageScreen(),
                              ),
                            ),
                          ),
                          _buildDivider(isDark),
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.cleaning_services_rounded,
                            title: isVi
                                ? 'Dọn dẹp bộ nhớ đệm (Cache)'
                                : 'Clear App Cache',
                            subtitle: isVi
                                ? 'Giải phóng dung lượng hình ảnh tạm'
                                : 'Free up temporary image storage',
                            onTap: _clearCache,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section 2: CHÍNH SÁCH BẢO VỆ RIÊNG TƯ
                      _buildSectionTitle(
                        isVi ? 'CHÍNH SÁCH & BẢO MẬT' : 'POLICIES & PRIVACY',
                      ),
                      _buildCardContainer(
                        isDark: isDark,
                        children: [
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.privacy_tip_outlined,
                            title: isVi
                                ? 'Chính sách bảo mật'
                                : 'Privacy Policy',
                            subtitle: isVi
                                ? 'Tìm hiểu cách chúng tôi bảo vệ thông tin của bạn'
                                : 'Learn how we protect your information',
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideRight(
                                const PrivacyPolicyScreen(),
                              ),
                            ),
                          ),
                          _buildDivider(isDark),
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.lock_person_outlined,
                            title: isVi
                                ? 'Quyền sở hữu dữ liệu'
                                : 'Data Ownership',
                            subtitle: isVi
                                ? 'Dữ liệu tài chính chỉ thuộc về bạn và luôn được mã hóa'
                                : 'Your financial records belong exclusively to you and are always encrypted',
                            badge: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.brandColor.withValues(
                                  alpha: 0.12,
                                ),
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
                      _buildSectionTitle(
                        isVi ? 'VÙNG NGUY HIỂM' : 'DANGER ZONE',
                      ),
                      _buildCardContainer(
                        isDark: isDark,
                        children: [
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideRight(
                                const DeleteConfirmationScreen(),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: context.expense.withValues(
                                        alpha: isDark ? 0.2 : 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.delete_forever_rounded,
                                      color: context.expense,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isVi
                                              ? 'Xóa tài khoản vĩnh viễn'
                                              : 'Delete Account Permanently',
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
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color:
                                                context.colors.onSurfaceVariant,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: context.colors.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
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
                  color:
                      (isOnline
                              ? context.brandColor
                              : context.colors.onSurfaceVariant)
                          .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: isOnline
                      ? context.brandColor
                      : context.colors.onSurfaceVariant,
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
                              ? (isVi
                                    ? 'Đang kết nối Firestore'
                                    : 'Connected to Firestore')
                              : (isVi
                                    ? 'Chế độ ngoại tuyến (SQLite)'
                                    : 'Offline Mode (SQLite)'),
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
              color: isDark
                  ? context.surfaceElevatedColor
                  : const Color(0xFFF9FAFB),
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
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.onSurfaceVariant,
                      ),
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
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _pendingCount == 0
                          ? (isVi ? 'Đã đồng bộ 100%' : '100% Synced')
                          : (isVi
                                ? '$_pendingCount mục chờ đẩy'
                                : '$_pendingCount items pending'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _pendingCount == 0
                            ? context.income
                            : context.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Button 1: "Đồng bộ ngay bây giờ" (2 chiều: đẩy & tải mới nhất)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed:
                  (isSyncing || _isCreatingBackup || _restoringBackupId != null)
                  ? null
                  : _triggerManualSync,
              child: isSyncing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isVi ? 'Đang đồng bộ dữ liệu...' : 'Syncing data...',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Action Button 2: "Tạo bản sao lưu mới"
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.brandColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                side: BorderSide(color: context.brandColor.withValues(alpha: 0.55)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed:
                  (isSyncing || _isCreatingBackup || _restoringBackupId != null)
                  ? null
                  : _triggerCreateBackup,
              child: _isCreatingBackup
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: context.brandColor,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isVi ? 'Đang tạo bản sao lưu...' : 'Creating backup...',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_outlined, size: 19),
                        const SizedBox(width: 8),
                        Text(
                          isVi ? 'Tạo bản sao lưu mới' : 'Create New Backup',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudBackupsSection(bool isDark, bool isVi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(
              isVi ? 'BẢN SAO LƯU & KHÔI PHỤC' : 'CLOUD BACKUPS & RESTORE',
            ),
            InkWell(
              onTap: _isLoadingBackups ? null : _loadCloudBackups,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 6, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 15,
                      color: context.brandColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVi ? 'Tải lại' : 'Refresh',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.brandColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        _buildCardContainer(
          isDark: isDark,
          children: [
            if (_isLoadingBackups && _backups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: context.brandColor,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isVi
                            ? 'Đang tải danh sách bản sao lưu...'
                            : 'Loading cloud backups...',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_backups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_queue_rounded,
                      color: context.colors.onSurfaceVariant,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isVi
                            ? 'Chưa có bản sao lưu nào trên Firebase. Nhấn "Tạo bản sao lưu mới" để lưu trạng thái hiện tại.'
                            : 'No cloud backups yet. Tap "Create New Backup" to save your current data.',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (int i = 0; i < _backups.length; i++) ...[
                _buildBackupItemTile(_backups[i], i == 0, isDark, isVi),
                if (i < _backups.length - 1) _buildDivider(isDark),
              ],
          ],
        ),
      ],
    );
  }

  Widget _buildBackupItemTile(
    CloudBackupSummary backup,
    bool isNewest,
    bool isDark,
    bool isVi,
  ) {
    final isRestoringThis = _restoringBackupId == backup.id;
    final timeStr = DateFormat('HH:mm • dd/MM/yyyy').format(backup.backedUpAt);
    final titleText = backup.displayTitle(isVi: isVi);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.brandColor.withValues(
                    alpha: isDark ? 0.2 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.backup_rounded,
                  color: context.brandColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            titleText,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: context.colors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isNewest) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.income.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isVi ? 'Mới nhất' : 'Latest',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: context.income,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$timeStr  •  ${backup.walletCount} ${isVi ? 'ví' : 'wallets'}  •  ${backup.transactionCount} ${isVi ? 'giao dịch' : 'txs'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${isVi ? 'Tổng số dư' : 'Total'}: ${CurrencyUtils.formatCurrency(backup.totalBalance)}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.brandColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (!backup.isLatestDoc)
                IconButton(
                  tooltip: isVi ? 'Xóa bản sao lưu' : 'Delete backup',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: context.colors.onSurfaceVariant,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: _restoringBackupId != null
                      ? null
                      : () => _confirmAndDeleteBackup(backup),
                ),
            ],
          ),
          if (backup.wallets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: backup.wallets.map((w) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? context.surfaceElevatedColor
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${w.name}: ${CurrencyUtils.formatCurrency(w.balance)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandColor.withValues(alpha: 0.12),
                foregroundColor: context.brandColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                minimumSize: const Size(double.infinity, 42),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed:
                  (_isManualSyncing ||
                      _isCreatingBackup ||
                      _restoringBackupId != null)
                  ? null
                  : () => _confirmAndRestoreBackup(backup),
              icon: isRestoringThis
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: context.brandColor,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.restore_rounded, size: 17),
              label: Text(
                isRestoringThis
                    ? (isVi ? 'Đang khôi phục...' : 'Restoring...')
                    : (isVi ? 'Khôi phục bản này' : 'Restore This Backup'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
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

  Widget _buildCardContainer({
    required bool isDark,
    required List<Widget> children,
  }) {
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
                color: context.brandColor.withValues(
                  alpha: isDark ? 0.2 : 0.12,
                ),
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
            if (badge != null) ...[const SizedBox(width: 8), badge],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
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
