import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../services/connectivity_service.dart';
import '../../services/language_service.dart';
import '../../services/sync_service.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/mono_dialog.dart';
import '../../widgets/top_toast.dart';
import 'data_usage_screen.dart';
import 'delete_confirmation_screen.dart';
import 'privacy_policy_screen.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  static const int _initialVisibleBackups = 3;

  final _syncService = SyncService();
  final _connectivity = ConnectivityService();

  bool _isCreatingBackup = false;
  bool _isLoadingBackups = false;
  bool _showAllBackups = false;
  String? _restoringBackupId;
  int _pendingCount = 0;
  List<CloudBackupSummary> _backups = const [];

  bool get _isBusy =>
      _isCreatingBackup || _restoringBackupId != null || _syncService.isSyncing;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadPendingCount(),
      _loadCloudBackups(),
    ]);
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

  /// Tạo bản sao lưu mới từ trạng thái hiện tại trên máy lên Firebase
  Future<void> _triggerCreateBackup() async {
    if (_isBusy) return;

    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() => _isCreatingBackup = true);
    try {
      final success = await _syncService.createCloudBackupSnapshot(
        label: isVi ? 'Sao lưu thủ công' : 'Manual Backup',
      );
      await _refreshAll();

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
    if (_isCreatingBackup || _restoringBackupId != null) return;

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
      await _refreshAll();

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

  Future<void> _clearCache() async {
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
      return isVi ? 'Chưa đồng bộ' : 'Not yet';
    }
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return isVi ? 'Vừa xong' : 'Just now';
    if (diff.inMinutes < 60) {
      return isVi
          ? '${diff.inMinutes} phút trước'
          : '${diff.inMinutes} mins ago';
    }
    if (diff.inHours < 24) {
      return DateFormat('HH:mm').format(time);
    }
    return DateFormat('dd/MM HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = context.isDark;
    final isOnline = _connectivity.isOnline;
    final lastSyncTime = _syncService.lastSyncTime;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : context.brandColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      isVi ? 'Dữ liệu và riêng tư' : 'Data & Privacy',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Main Content Sheet
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: RefreshIndicator(
                    color: context.brandColor,
                    onRefresh: _refreshAll,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        22,
                        20,
                        bottomPadding + 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Trạng thái đồng bộ tự động (không có nút Đồng bộ ngay)
                          _buildAutoSyncStatusCard(
                            isDark: isDark,
                            isOnline: isOnline,
                            lastSyncTime: lastSyncTime,
                            isVi: isVi,
                          ),
                          const SizedBox(height: 24),

                          // 2. Sao lưu & Khôi phục đám mây
                          _buildCloudBackupsSection(isDark, isVi),
                          const SizedBox(height: 24),

                          // 3. Dữ liệu & Bộ nhớ
                          _buildSectionTitle(
                            isVi ? 'DỮ LIỆU & BỘ NHỚ' : 'DATA & STORAGE',
                          ),
                          _buildCardContainer(
                            isDark: isDark,
                            children: [
                              _buildSettingRow(
                                isDark: isDark,
                                icon: Icons.data_usage_rounded,
                                title: isVi ? 'Sử dụng dữ liệu' : 'Data Usage',
                                subtitle: isVi
                                    ? 'Kiểm soát mức tiêu thụ mạng và dung lượng'
                                    : 'Monitor network and local storage usage',
                                onTap: () => Navigator.push(
                                  context,
                                  PageTransitions.slideRight(
                                    const DataUsageScreen(),
                                  ),
                                ),
                              ),
                              _buildDivider(),
                              _buildSettingRow(
                                isDark: isDark,
                                icon: Icons.cleaning_services_rounded,
                                title: isVi
                                    ? 'Dọn dẹp bộ nhớ đệm'
                                    : 'Clear App Cache',
                                subtitle: isVi
                                    ? 'Xóa ảnh tạm để giải phóng dung lượng máy'
                                    : 'Remove temporary image cache safely',
                                onTap: _clearCache,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 4. Quyền riêng tư & Bảo mật
                          _buildSectionTitle(
                            isVi
                                ? 'QUYỀN RIÊNG TƯ & BẢO MẬT'
                                : 'PRIVACY & SECURITY',
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
                                    ? 'Cách chúng tôi thu thập và bảo vệ dữ liệu'
                                    : 'How we collect and protect your data',
                                onTap: () => Navigator.push(
                                  context,
                                  PageTransitions.slideRight(
                                    const PrivacyPolicyScreen(),
                                  ),
                                ),
                              ),
                              _buildDivider(),
                              _buildSettingRow(
                                isDark: isDark,
                                icon: Icons.verified_user_outlined,
                                title: isVi
                                    ? 'Quyền sở hữu dữ liệu'
                                    : 'Data Ownership',
                                subtitle: isVi
                                    ? 'Dữ liệu tài chính được mã hóa và thuộc toàn quyền của bạn'
                                    : 'Encrypted financial records owned exclusively by you',
                                badge: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.income.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isVi ? 'Đã mã hóa' : 'Encrypted',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: context.income,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // 5. Vùng nguy hiểm (tách biệt rõ ràng, chống chạm nhầm)
                          _buildSectionTitle(
                            isVi ? 'VÙNG NGUY HIỂM' : 'DANGER ZONE',
                            color: context.expense,
                          ),
                          _buildDangerZoneCard(isDark: isDark, isVi: isVi),
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
    );
  }

  /// Card trạng thái đồng bộ tự động (gọn, dễ quét, không có nút Đồng bộ ngay)
  Widget _buildAutoSyncStatusCard({
    required bool isDark,
    required bool isOnline,
    required DateTime? lastSyncTime,
    required bool isVi,
  }) {
    final statusColor = isOnline ? context.income : context.warning;
    final isSyncingNow = _syncService.isSyncing;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
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
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isOnline
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
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
                      isVi
                          ? 'Đồng bộ đám mây tự động'
                          : 'Automatic Cloud Sync',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isSyncingNow
                                ? (isVi
                                      ? 'Đang tự động đồng bộ...'
                                      : 'Auto-syncing in background...')
                                : isOnline
                                ? (isVi
                                      ? 'Đã kết nối Firebase Firestore'
                                      : 'Connected to Firebase Firestore')
                                : (isVi
                                      ? 'Ngoại tuyến • Lưu tạm trên SQLite'
                                      : 'Offline • Saved locally on SQLite'),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: context.colors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 chỉ số nhanh: Gần nhất | Hàng chờ | Lịch sao lưu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: isDark
                  ? context.surfaceElevatedColor
                  : const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSyncMetricItem(
                    label: isVi ? 'Gần nhất' : 'Last Sync',
                    value: _formatLastSyncTime(lastSyncTime, isVi),
                    valueColor: context.colors.onSurface,
                  ),
                ),
                _buildVerticalStatDivider(),
                Expanded(
                  child: _buildSyncMetricItem(
                    label: isVi ? 'Hàng chờ' : 'Queue',
                    value: _pendingCount == 0
                        ? (isVi ? 'Đã đồng bộ' : 'Synced')
                        : (isVi ? '$_pendingCount mục' : '$_pendingCount pending'),
                    valueColor:
                        _pendingCount == 0 ? context.income : context.warning,
                  ),
                ),
                _buildVerticalStatDivider(),
                Expanded(
                  child: _buildSyncMetricItem(
                    label: isVi ? 'Tự sao lưu' : 'Auto Backup',
                    value: isVi ? '00:00 hằng ngày' : 'Daily 00:00',
                    valueColor: context.brandColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncMetricItem({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.colors.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildVerticalStatDivider() {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: context.dividerColor,
    );
  }

  /// Phần Sao lưu & Khôi phục (gom nút Tạo bản sao lưu mới vào đúng ngữ cảnh)
  Widget _buildCloudBackupsSection(bool isDark, bool isVi) {
    final hasHiddenBackups = _backups.length > _initialVisibleBackups;
    final visibleBackups = _showAllBackups
        ? _backups
        : _backups.take(_initialVisibleBackups).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(
              isVi ? 'SAO LƯU & KHÔI PHỤC' : 'BACKUP & RESTORE',
            ),
            InkWell(
              onTap: _isLoadingBackups ? null : _loadCloudBackups,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: context.brandColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVi ? 'Làm mới' : 'Refresh',
                      style: TextStyle(
                        fontSize: 12.5,
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

        // Nút tạo bản sao lưu mới đặt ngay đầu mục Sao lưu (thumb-friendly 48px)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brandColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isBusy ? null : _triggerCreateBackup,
            icon: _isCreatingBackup
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 20),
            label: Text(
              _isCreatingBackup
                  ? (isVi ? 'Đang tạo bản sao lưu...' : 'Creating backup...')
                  : (isVi ? 'Tạo bản sao lưu mới' : 'Create New Backup'),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Danh sách các bản sao lưu
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _buildCardContainer(
            isDark: isDark,
            children: [
              if (_isLoadingBackups && _backups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 26),
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
                )
              else if (_backups.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.colors.onSurfaceVariant.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.cloud_queue_rounded,
                          color: context.colors.onSurfaceVariant,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isVi
                              ? 'Chưa có bản sao lưu nào trên Firebase. Nhấn "Tạo bản sao lưu mới" để lưu trạng thái ví hiện tại.'
                              : 'No cloud backups yet. Tap "Create New Backup" to save your current wallet snapshot.',
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
              else ...[
                for (int i = 0; i < visibleBackups.length; i++) ...[
                  _buildBackupItemTile(
                    visibleBackups[i],
                    i == 0,
                    isDark,
                    isVi,
                  ),
                  if (i < visibleBackups.length - 1 || hasHiddenBackups)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                      color: context.dividerColor,
                    ),
                ],
                if (hasHiddenBackups)
                  InkWell(
                    onTap: () =>
                        setState(() => _showAllBackups = !_showAllBackups),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _showAllBackups
                                ? (isVi ? 'Thu gọn danh sách' : 'Show less')
                                : (isVi
                                      ? 'Xem thêm ${_backups.length - _initialVisibleBackups} bản cũ hơn'
                                      : 'Show ${_backups.length - _initialVisibleBackups} older backups'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.brandColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showAllBackups
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: context.brandColor,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Total Balance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.brandColor.withValues(
                    alpha: isDark ? 0.2 : 0.1,
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
            ],
          ),

          // Chi tiết các ví dạng chip gọn
          if (backup.wallets.isNotEmpty) ...[
            const SizedBox(height: 10),
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

          // Hàng nút thao tác công thái học: Khôi phục (chính) + Xóa (tách biệt bên phải)
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.brandColor.withValues(
                        alpha: 0.12,
                      ),
                      foregroundColor: context.brandColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: (_isCreatingBackup || _restoringBackupId != null)
                        ? null
                        : () => _confirmAndRestoreBackup(backup),
                    icon: isRestoringThis
                        ? SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              color: context.brandColor,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.restore_rounded, size: 18),
                    label: Text(
                      isRestoringThis
                          ? (isVi ? 'Đang khôi phục...' : 'Restoring...')
                          : (isVi ? 'Khôi phục bản này' : 'Restore This Backup'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              if (!backup.isLatestDoc) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: context.colors.onSurfaceVariant,
                      side: BorderSide(color: context.borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _restoringBackupId != null
                        ? null
                        : () => _confirmAndDeleteBackup(backup),
                    child: Tooltip(
                      message: isVi ? 'Xóa bản sao lưu' : 'Delete backup',
                      child: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard({required bool isDark, required bool isVi}) {
    return Container(
      decoration: BoxDecoration(
        color: context.expense.withValues(alpha: isDark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.expense.withValues(alpha: 0.28),
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          PageTransitions.slideRight(
            const DeleteConfirmationScreen(),
          ),
        ),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.expense.withValues(
                    alpha: isDark ? 0.22 : 0.12,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi
                          ? 'Xóa tài khoản vĩnh viễn'
                          : 'Delete Account Permanently',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.expense,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isVi
                          ? 'Xóa tài khoản và toàn bộ dữ liệu trên máy & đám mây'
                          : 'Permanently remove your account and all local & cloud data',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.colors.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: context.expense.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: color ?? context.colors.onSurfaceVariant,
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
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.02),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
                      height: 1.3,
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

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 62,
      endIndent: 16,
      color: context.dividerColor,
    );
  }
}
