import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/ai_config_service.dart';
import '../../services/gemini_ai_service.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/animated_scale_button.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final AiConfigService _configService = AiConfigService();
  final GeminiAiService _aiService = GeminiAiService();
  final TextEditingController _apiKeyController = TextEditingController();

  bool _obscureKey = true;
  bool _isTesting = false;
  bool? _testSuccess;
  int _selectedResponseDelayMs = 700;

  // Lựa chọn màu nhấn thương hiệu Mono luôn tươi sáng và rõ ràng ở cả hai chế độ
  static const Color _brandTeal = Color(0xFF438883);
  static const Color _brightMint = Color(0xFF5CB8B2);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await _configService.init();
    _apiKeyController.text = _configService.apiKey;

    _selectedResponseDelayMs = _configService.responseDelayMs;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final key = _apiKeyController.text.trim();
    await _configService.setApiKey(key);
    if (!mounted) return;
    TopToast.show(context, 'Đã lưu cấu hình API Key an toàn!');
  }

  Future<void> _testKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      TopToast.show(context, 'Vui lòng nhập API Key để kiểm tra');
      return;
    }

    setState(() {
      _isTesting = true;
      _testSuccess = null;
    });

    final success = await _aiService.testConnection(customApiKey: key);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = success;
      });

      if (success) {
        TopToast.show(context, 'Kết nối Google AI Studio thành công! 🚀');
      } else {
        TopToast.show(context, 'Không thể kết nối. Vui lòng kiểm tra lại Key');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasKey = _apiKeyController.text.trim().isNotEmpty;

    // Bảng màu tối cao cấp, tương phản tốt, không bị ám đen đục
    final cardBg = isDark ? const Color(0xFF162321) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334B48) : const Color(0xFFE2E8F0);
    final activeMint = isDark ? _brightMint : _brandTeal;

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // === HEADER APP BAR THEO PHONG CÁCH CHUẨN CỦA MONO ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Cài đặt Trợ lý AI Mono',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // === NỘI DUNG CUỘN CHÍNH ===
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ════════════ 1. BANNER HERO AI ════════════
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF1E3532), const Color(0xFF152725)]
                                : [const Color(0xFFE8F6F4), const Color(0xFFD6F0EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF385C57) : const Color(0xFF9FD7CF),
                            width: 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                              blurRadius: 12,
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
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_brandTeal, Color(0xFF285C57)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _brandTeal.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Google AI Studio (Gemini)',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: (hasKey ? const Color(0xFF22C55E) : Colors.orange)
                                                  .withValues(alpha: isDark ? 0.25 : 0.15),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: (hasKey ? const Color(0xFF22C55E) : Colors.orange)
                                                    .withValues(alpha: 0.5),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: hasKey ? const Color(0xFF22C55E) : Colors.orange,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  hasKey ? 'Đã cài đặt' : 'Chưa có Key',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: hasKey
                                                        ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
                                                        : (isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Trợ lý Mono sử dụng Gemini Flash siêu tốc để bóc tách giao dịch, báo cáo tài chính và gợi ý tiết kiệm thông minh.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF334155),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ════════════ 2. CẤU HÌNH API KEY ════════════
                      _buildSectionHeader(
                        icon: Icons.vpn_key_rounded,
                        title: 'Cấu hình API Key',
                        subtitle: 'Khóa API được mã hóa và bảo mật hoàn toàn trên thiết bị của bạn.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),

                      // Ô nhập API Key với độ tương phản cao
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _testSuccess == true
                                ? const Color(0xFF22C55E)
                                : (_testSuccess == false
                                    ? const Color(0xFFEF4444)
                                    : cardBorder),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _apiKeyController,
                          obscureText: _obscureKey,
                          style: TextStyle(
                            fontSize: 14.5,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Dán API Key (AIzaSy...) tại đây...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey.shade400,
                              fontSize: 13.5,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            prefixIcon: Icon(
                              Icons.key_rounded,
                              size: 20,
                              color: activeMint,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_apiKeyController.text.isNotEmpty)
                                  IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                                    ),
                                    tooltip: 'Xóa nội dung',
                                    onPressed: () {
                                      _apiKeyController.clear();
                                      setState(() {
                                        _testSuccess = null;
                                      });
                                    },
                                  ),
                                IconButton(
                                  icon: Icon(
                                    _obscureKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 20,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                  tooltip: _obscureKey ? 'Hiện khóa' : 'Ẩn khóa',
                                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                                ),
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: activeMint.withValues(alpha: isDark ? 0.2 : 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.content_paste_rounded,
                                      size: 18,
                                      color: activeMint,
                                    ),
                                  ),
                                  tooltip: 'Dán từ bộ nhớ tạm',
                                  onPressed: () async {
                                    final data = await Clipboard.getData('text/plain');
                                    if (data?.text != null) {
                                      _apiKeyController.text = data!.text!.trim();
                                      setState(() {});
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                          ),
                          onChanged: (_) => setState(() => _testSuccess = null),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Hàng nút tương tác: Kiểm tra kết nối & Lưu cấu hình
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedScaleButton(
                              onTap: _isTesting ? () {} : _testKey,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF223533) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF395753) : const Color(0xFFCBD5E1),
                                    width: 1.3,
                                  ),
                                ),
                                child: Center(
                                  child: _isTesting
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(activeMint),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _testSuccess == true
                                                  ? Icons.check_circle_rounded
                                                  : (_testSuccess == false
                                                      ? Icons.error_outline_rounded
                                                      : Icons.bolt_rounded),
                                              size: 19,
                                              color: _testSuccess == true
                                                  ? const Color(0xFF22C55E)
                                                  : (_testSuccess == false
                                                      ? const Color(0xFFEF4444)
                                                      : activeMint),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Kiểm tra kết nối',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AnimatedScaleButton(
                              onTap: _saveKey,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: _brandTeal,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _brandTeal.withValues(alpha: isDark ? 0.45 : 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.save_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Lưu cấu hình',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // ════════════ 4. ĐỘ TRỄ PHẢN HỒI CỦA MONO (RESPONSE DELAY) ════════════
                      _buildSectionHeader(
                        icon: Icons.timer_outlined,
                        title: 'Độ trễ phản hồi của Mono',
                        subtitle: 'Tùy chỉnh nhịp độ hiển thị phản hồi của Mono cho phù hợp với thói quen đọc và tốc độ mạng.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cardBorder, width: 1.3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Column(
                            children: [
                              _buildResponseDelayOption(
                                ms: 300,
                                title: 'Nhanh (300ms)',
                                subtitle: 'Phản hồi chớp nhoáng, tối ưu mạng mạnh',
                                isDark: isDark,
                                activeMint: activeMint,
                              ),
                              Divider(
                                height: 1,
                                color: isDark ? const Color(0xFF263937) : const Color(0xFFF1F5F9),
                              ),
                              _buildResponseDelayOption(
                                ms: 700,
                                title: 'Chuẩn (700ms)',
                                subtitle: 'Khuyên dùng (tự nhiên & cân bằng)',
                                isDark: isDark,
                                activeMint: activeMint,
                              ),
                              Divider(
                                height: 1,
                                color: isDark ? const Color(0xFF263937) : const Color(0xFFF1F5F9),
                              ),
                              _buildResponseDelayOption(
                                ms: 1500,
                                title: 'Thư thả (1500ms)',
                                subtitle: 'Bình tĩnh, phù hợp khi mạng chậm hoặc dễ xao nhãng',
                                isDark: isDark,
                                activeMint: activeMint,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ════════════ 5. HƯỚNG DẪN LẤY API KEY MIỄN PHÍ ════════════
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder, width: 1.3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: activeMint.withValues(alpha: isDark ? 0.25 : 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.help_outline_rounded, size: 20, color: activeMint),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Cách lấy Google AI Studio API Key miễn phí',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildGuideStep('1', 'Truy cập trang web Google AI Studio: aistudio.google.com', isDark, activeMint),
                            _buildGuideStep('2', 'Đăng nhập bằng tài khoản Google cá nhân của bạn', isDark, activeMint),
                            _buildGuideStep('3', 'Bấm nút "Get API Key" -> "Create API Key"', isDark, activeMint),
                            _buildGuideStep('4', 'Sao chép chuỗi mã khóa và dán vào ô nhập bên trên rồi bấm "Lưu cấu hình"', isDark, activeMint),
                            const SizedBox(height: 12),

                            // Nút sao chép liên kết nhanh
                            InkWell(
                              onTap: () {
                                Clipboard.setData(const ClipboardData(text: 'https://aistudio.google.com/'));
                                TopToast.show(context, 'Đã sao chép liên kết https://aistudio.google.com/ 📋');
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: activeMint.withValues(alpha: isDark ? 0.15 : 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: activeMint.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.copy_rounded, size: 16, color: activeMint),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Sao chép liên kết aistudio.google.com',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: activeMint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final activeMint = isDark ? _brightMint : _brandTeal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: activeMint),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white.withValues(alpha: 0.70) : Colors.grey.shade600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildResponseDelayOption({
    required int ms,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color activeMint,
  }) {
    final isSelected = _selectedResponseDelayMs == ms;
    return InkWell(
      onTap: () async {
        setState(() => _selectedResponseDelayMs = ms);
        await _configService.setResponseDelayMs(ms);
        if (mounted) {
          TopToast.show(context, 'Đã đặt độ trễ phản hồi: $title');
        }
      },
      child: Container(
        color: isSelected
            ? activeMint.withValues(alpha: isDark ? 0.22 : 0.08)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? activeMint : (isDark ? Colors.white38 : Colors.grey),
              size: 21,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white.withValues(alpha: 0.75) : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: activeMint.withValues(alpha: isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: activeMint.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  'Đang chọn',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: activeMint,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep(String number, String text, bool isDark, Color activeMint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: activeMint.withValues(alpha: isDark ? 0.28 : 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: activeMint.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: activeMint,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF334155),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
