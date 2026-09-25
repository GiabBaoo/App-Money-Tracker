import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/sync_service.dart';
import '../../services/connectivity_service.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../widgets/top_toast.dart';
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

    setState(() => _isManualSyncing = true);
    try {
      final success = await _syncService.syncAll();
      await _loadPendingCount();

      if (mounted) {
        if (success) {
          TopToast.show(context, 'Đồng bộ dữ liệu lên Firebase thành công!');
        } else {
          if (!_connectivity.isOnline) {
            TopToast.show(context, 'Không có kết nối mạng. Dữ liệu đã lưu ở SQLite.', isError: true);
          } else {
            TopToast.show(context, 'Đồng bộ hoàn tất (đã cập nhật phiên bản mới nhất).');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        TopToast.show(context, 'Lỗi đồng bộ: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isManualSyncing = false);
      }
    }
  }

  void _clearCache() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
        ),
        title: Text(
          'Xóa bộ nhớ đệm (Cache)',
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Thao tác này sẽ dọn dẹp các tệp hình ảnh tạm thời và bộ nhớ đệm hiển thị để giải phóng dung lượng. Dữ liệu thu chi của bạn hoàn toàn không bị ảnh hưởng.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Hủy', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF438883),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              Navigator.pop(dialogCtx);
              TopToast.show(context, 'Đã dọn sạch bộ nhớ đệm ứng dụng!');
            },
            child: const Text('Dọn dẹp ngay'),
          ),
        ],
      ),
    );
  }

  void _clearOldTransactions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
        ),
        title: Text(
          'Dọn dẹp dữ liệu thu/chi cũ',
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Hệ thống sẽ xóa toàn bộ các giao dịch thu/chi từ tháng 8 trở về trước đó trên máy và đồng bộ lên đám mây. Dữ liệu từ tháng 9 trở đi vẫn được giữ an toàn.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Hủy', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final count = await TransactionRepository().purgeHistoryBeforeSeptember2026();
              await _loadPendingCount();
              if (mounted) {
                TopToast.show(
                  context,
                  count > 0
                      ? 'Đã xóa thành công $count giao dịch từ tháng 8 trở về trước!'
                      : 'Không còn giao dịch nào từ tháng 8 trở về trước.',
                );
              }
            },
            child: const Text('Xóa dữ liệu cũ'),
          ),
        ],
      ),
    );
  }

  String _formatLastSyncTime(DateTime? time) {
    if (time == null) return 'Chưa đồng bộ phiên này';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    return DateFormat('HH:mm - dd/MM/yyyy').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = _connectivity.isOnline;
    final isSyncing = _isManualSyncing || _syncService.isSyncing;
    final lastSyncTime = _syncService.lastSyncTime;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
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
                  const Text(
                    'Dữ liệu và riêng tư',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
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
                      _buildSyncHeroCard(isDark, isOnline, isSyncing, lastSyncTime),
                      const SizedBox(height: 24),

                      // Section 1: QUẢN LÝ DỮ LIỆU
                      _buildSectionTitle('QUẢN LÝ DỮ LIỆU'),
                      _buildCardContainer(
                        isDark: isDark,
                        children: [
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.data_usage_rounded,
                            title: 'Sử dụng dữ liệu',
                            subtitle: 'Kiểm soát mức tiêu thụ dữ liệu mạng và bộ nhớ',
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideRight(const DataUsageScreen()),
                            ),
                          ),
                          _buildDivider(isDark),
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.cleaning_services_rounded,
                            title: 'Dọn dẹp bộ nhớ đệm (Cache)',
                            subtitle: 'Giải phóng dung lượng hình ảnh tạm',
                            onTap: _clearCache,
                          ),
                          _buildDivider(isDark),
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.auto_delete_outlined,
                            title: 'Dọn dẹp dữ liệu thu/chi cũ',
                            subtitle: 'Xóa toàn bộ giao dịch từ tháng 8 trở về trước',
                            onTap: _clearOldTransactions,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section 2: CHÍNH SÁCH BẢO VỆ RIÊNG TƯ
                      _buildSectionTitle('CHÍNH SÁCH & BẢO MẬT'),
                      _buildCardContainer(
                        isDark: isDark,
                        children: [
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.privacy_tip_outlined,
                            title: 'Chính sách bảo mật',
                            subtitle: 'Tìm hiểu cách chúng tôi bảo vệ thông tin của bạn',
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideRight(const PrivacyPolicyScreen()),
                            ),
                          ),
                          _buildDivider(isDark),
                          _buildSettingRow(
                            isDark: isDark,
                            icon: Icons.lock_person_outlined,
                            title: 'Quyền sở hữu dữ liệu',
                            subtitle: 'Dữ liệu tài chính chỉ thuộc về bạn và luôn được mã hóa',
                            badge: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF438883).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'An toàn',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF438883),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section 3: VÙNG NGUY HIỂM (Danger Zone)
                      _buildSectionTitle('VÙNG NGUY HIỂM'),
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
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFE63946), size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Xóa tài khoản vĩnh viễn',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFE63946),
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Xóa tài khoản và toàn bộ dữ liệu trên đám mây',
                                          style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.25),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
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
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
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
                  color: isOnline
                      ? const Color(0xFF438883).withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: isOnline ? const Color(0xFF438883) : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đồng bộ đám mây Firebase',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
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
                            color: isOnline ? const Color(0xFF2ECC71) : Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'Đang kết nối Firestore' : 'Chế độ ngoại tuyến (SQLite)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.grey.shade600,
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
              color: isDark ? const Color(0xFF383838) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đồng bộ gần nhất',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatLastSyncTime(lastSyncTime),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Hàng chờ đồng bộ',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _pendingCount == 0 ? 'Đã đồng bộ 100%' : '$_pendingCount mục chờ đẩy',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _pendingCount == 0 ? const Color(0xFF438883) : Colors.orange,
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
                backgroundColor: const Color(0xFF438883),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: isSyncing ? null : _triggerManualSync,
              child: isSyncing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Đang đồng bộ dữ liệu...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sync_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Đồng bộ ngay bây giờ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
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
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
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
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8F5F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF438883), size: 22),
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
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
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
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
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
      color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
    );
  }
}
