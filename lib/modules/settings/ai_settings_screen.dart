import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/ai_config_service.dart';
import '../../services/local_qwen_service.dart';
import '../../services/gemini_ai_service.dart';
import '../../services/language_service.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/animated_scale_button.dart';
import '../../core/theme/app_theme.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final AiConfigService _configService = AiConfigService();
  final LocalQwenService _localQwenService = LocalQwenService();
  final GeminiAiService _geminiService = GeminiAiService();

  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  bool _obscureKey = true;
  bool _isTestingLocal = false;
  bool? _testLocalSuccess;
  String? _testLocalMessage;

  bool _isTestingCloud = false;

  int _selectedResponseDelayMs = 700;
  int _selectedSilenceMs = 2000;
  String _selectedEngineMode = 'local_qwen';
  String _selectedLocalModel = 'qwen2.5:1.5b';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await _configService.init();
    _selectedEngineMode = _configService.engineMode;
    _selectedLocalModel = _configService.localModelName;
    _endpointController.text = _configService.localEndpoint;
    _apiKeyController.text = _configService.apiKey;
    _selectedResponseDelayMs = _configService.responseDelayMs;
    _selectedSilenceMs = _configService.voiceSilenceDurationMs;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveLocalConfig() async {
    final endpoint = _endpointController.text.trim();
    await _configService.setLocalEndpoint(endpoint);
    await _configService.setLocalModelName(_selectedLocalModel);
    await _configService.setEngineMode(_selectedEngineMode);
    if (!mounted) return;
    TopToast.show(
      context,
      LanguageScope.of(context).isVietnamese
          ? 'Đã lưu cấu hình Trợ lý Local Qwen 2.5 thành công!'
          : 'Local Qwen 2.5 Assistant settings saved successfully!',
    );
  }

  Future<void> _testLocalModel() async {
    setState(() {
      _isTestingLocal = true;
      _testLocalSuccess = null;
      _testLocalMessage = null;
    });

    final res = await _localQwenService.testConnection(
      customEndpoint: _endpointController.text.trim(),
      customModel: _selectedLocalModel,
    );

    if (mounted) {
      setState(() {
        _isTestingLocal = false;
        _testLocalSuccess = res['success'] as bool? ?? false;
        _testLocalMessage = res['message'] as String?;
      });

      if (_testLocalSuccess == true) {
        TopToast.show(
          context,
          LanguageScope.of(context).isVietnamese
              ? 'Đã kết nối Qwen 2.5 thành công! ⚡'
              : 'Connected to Qwen 2.5 successfully! ⚡',
        );
      } else {
        TopToast.show(
          context,
          LanguageScope.of(context).isVietnamese
              ? 'Không tìm thấy server. Mono sẽ dùng Offline Engine 0ms.'
              : 'Server not found. Mono will use 0ms Offline Engine.',
        );
      }
    }
  }

  Future<void> _testCloudKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      TopToast.show(
        context,
        LanguageScope.of(context).isVietnamese
            ? 'Vui lòng nhập API Key để kiểm tra'
            : 'Please enter an API Key to test',
      );
      return;
    }

    setState(() {
      _isTestingCloud = true;
    });

    final success = await _geminiService.testConnection(customApiKey: key);

    if (mounted) {
      setState(() {
        _isTestingCloud = false;
      });

      if (success) {
        TopToast.show(
          context,
          LanguageScope.of(context).isVietnamese
              ? 'Kết nối Google AI Studio thành công! 🚀'
              : 'Connected to Google AI Studio successfully! 🚀',
        );
      } else {
        TopToast.show(
          context,
          LanguageScope.of(context).isVietnamese
              ? 'Không thể kết nối. Vui lòng kiểm tra lại Key'
              : 'Failed to connect. Please check your Key',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = context.cardBg;
    final cardBorder = context.borderColor;
    final activeMint = context.brandColor;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : context.brandColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // === HEADER APP BAR CHUẨN MONO ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    isVi
                        ? 'Cài đặt Trợ lý AI Mono'
                        : 'Mono AI Assistant Settings',
                    style: const TextStyle(
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ════════════ 1. BANNER HERO LOCAL AI ════════════
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF1A3330),
                                    const Color(0xFF132624),
                                  ]
                                : [
                                    const Color(0xFFE6F7F4),
                                    const Color(0xFFD3EFEA),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: activeMint.withValues(
                              alpha: isDark ? 0.4 : 0.5,
                            ),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.35 : 0.05,
                              ),
                              blurRadius: 14,
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
                                    gradient: LinearGradient(
                                      colors: [
                                        activeMint,
                                        activeMint.withValues(alpha: 0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: activeMint.withValues(
                                          alpha: 0.45,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.memory_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Local AI: Qwen 2.5 1.5B',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: context.colors.onSurface,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981)
                                                  .withValues(
                                                    alpha: isDark ? 0.25 : 0.15,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFF10B981,
                                                ).withValues(alpha: 0.5),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFF10B981,
                                                        ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  '100% Offline',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF4ADE80,
                                                          )
                                                        : const Color(
                                                            0xFF15803D,
                                                          ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        isVi
                                            ? 'Trợ lý Mono chạy cục bộ trên thiết bị của bạn. Dữ liệu thu chi, số dư ví không bao giờ rời khỏi điện thoại, tuyệt đối bảo mật và riêng tư.'
                                            : 'Mono Assistant runs locally on your device. Transaction records and balances never leave your phone, ensuring 100% privacy.',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color:
                                              context.colors.onSurfaceVariant,
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

                      // ════════════ 2. CHỌN MÔ HÌNH LOCAL ════════════
                      _buildSectionHeader(
                        context,
                        icon: Icons.psychology_rounded,
                        title: isVi
                            ? 'Cấu hình Mô hình Trí tuệ Nhân tạo'
                            : 'AI Model Configuration',
                        subtitle: isVi
                            ? 'Chọn mức độ thông minh phù hợp với cấu hình thiết bị của bạn.'
                            : 'Choose intelligence level matching your device specs.',
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
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.3 : 0.04,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Column(
                            children: [
                              _buildModelOption(
                                context,
                                modelKey: 'qwen2.5:1.5b',
                                title: 'Qwen 2.5 1.5B-Instruct',
                                badge: isVi
                                    ? 'Khuyên dùng (Pixel 7a)'
                                    : 'Recommended (Pixel 7a)',
                                subtitle: isVi
                                    ? 'Độ thông minh cao nhất, bóc tách tiếng Việt và lập luận tài chính xuất sắc (~980MB RAM)'
                                    : 'Highest intelligence, outstanding parsing and financial reasoning (~980MB RAM)',
                                isDark: isDark,
                                activeMint: activeMint,
                              ),
                              Divider(height: 1, color: context.dividerColor),
                              _buildModelOption(
                                context,
                                modelKey: 'qwen2.5:0.5b',
                                title: 'Qwen 2.5 0.5B-Instruct',
                                badge: isVi
                                    ? 'Siêu nhẹ & Tiết kiệm'
                                    : 'Ultra-light & Efficient',
                                subtitle: isVi
                                    ? 'Phản hồi chớp nhoáng, tối ưu hóa cho máy cấu hình nhẹ và tiết kiệm pin (~390MB RAM)'
                                    : 'Instant response, optimized for lightweight devices and battery saving (~390MB RAM)',
                                isDark: isDark,
                                activeMint: activeMint,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ════════════ 3. CỔNG KẾT NỐI LOCAL AI ════════════
                      _buildSectionHeader(
                        context,
                        icon: Icons.hub_rounded,
                        title: isVi
                            ? 'Cổng kết nối Local AI (Endpoint)'
                            : 'Local AI Connection Port (Endpoint)',
                        subtitle: isVi
                            ? 'Mono kết nối trực tiếp với On-Device Inference hoặc máy chủ Ollama trên máy tính khi chạy dev.'
                            : 'Mono connects directly to on-device inference or dev host Ollama server.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _testLocalSuccess == true
                                ? const Color(0xFF22C55E)
                                : (_testLocalSuccess == false
                                      ? const Color(0xFFF59E0B)
                                      : cardBorder),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.35 : 0.04,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _endpointController,
                          style: TextStyle(
                            fontSize: 14,
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.w500,
                            color: context.colors.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: isVi
                                ? 'VD: http://10.0.2.2:11434 hoặc http://127.0.0.1:11434'
                                : 'E.g.: http://10.0.2.2:11434 or http://127.0.0.1:11434',
                            hintStyle: TextStyle(
                              color: context.colors.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.lan_rounded,
                              size: 20,
                              color: activeMint,
                            ),
                            suffixIcon: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: activeMint.withValues(
                                    alpha: isDark ? 0.2 : 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.content_paste_rounded,
                                  size: 18,
                                  color: activeMint,
                                ),
                              ),
                              tooltip: isVi ? 'Dán địa chỉ' : 'Paste address',
                              onPressed: () async {
                                final data = await Clipboard.getData(
                                  'text/plain',
                                );
                                if (data?.text != null) {
                                  _endpointController.text = data!.text!.trim();
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                          onChanged: (_) => setState(() {
                            _testLocalSuccess = null;
                            _testLocalMessage = null;
                          }),
                        ),
                      ),

                      if (_testLocalMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (_testLocalSuccess == true
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B))
                                    .withValues(alpha: isDark ? 0.18 : 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  (_testLocalSuccess == true
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFF59E0B))
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _testLocalMessage!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _testLocalSuccess == true
                                  ? (isDark
                                        ? const Color(0xFF6EE7B7)
                                        : const Color(0xFF065F46))
                                  : (isDark
                                        ? const Color(0xFFFCD34D)
                                        : const Color(0xFF92400E)),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Hàng nút tương tác: Kiểm tra kết nối & Lưu cấu hình
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedScaleButton(
                              onTap: _isTestingLocal ? () {} : _testLocalModel,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: context.cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: context.borderColor,
                                    width: 1.3,
                                  ),
                                ),
                                child: Center(
                                  child: _isTestingLocal
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  activeMint,
                                                ),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _testLocalSuccess == true
                                                  ? Icons.check_circle_rounded
                                                  : (_testLocalSuccess == false
                                                        ? Icons
                                                              .warning_amber_rounded
                                                        : Icons.bolt_rounded),
                                              size: 19,
                                              color: _testLocalSuccess == true
                                                  ? const Color(0xFF22C55E)
                                                  : (_testLocalSuccess == false
                                                        ? const Color(
                                                            0xFFF59E0B,
                                                          )
                                                        : activeMint),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isVi
                                                  ? 'Kiểm tra Qwen 2.5'
                                                  : 'Test Qwen 2.5',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13.5,
                                                color: context.colors.onSurface,
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
                              onTap: _saveLocalConfig,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: activeMint,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeMint.withValues(
                                        alpha: isDark ? 0.45 : 0.3,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.save_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isVi ? 'Lưu cấu hình' : 'Save Config',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
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

                      // ════════════ 4. ĐỘ TRỄ PHẢN HỒI CỦA MONO ════════════
                      _buildSectionHeader(
                        context,
                        icon: Icons.timer_outlined,
                        title: isVi
                            ? 'Độ trễ phản hồi của Mono'
                            : 'Mono Response Delay',
                        subtitle: isVi
                            ? 'Tùy chỉnh nhịp độ hiển thị phản hồi của Mono cho phù hợp với thói quen đọc.'
                            : 'Adjust typing rhythm of Mono responses to match your reading speed.',
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
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.3 : 0.04,
                              ),
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
                                context,
                                ms: 300,
                                title: isVi ? 'Nhanh (300ms)' : 'Fast (300ms)',
                                subtitle: isVi
                                    ? 'Phản hồi chớp nhoáng, tức thì'
                                    : 'Lightning-fast, immediate',
                                isDark: isDark,
                                activeMint: activeMint,
                              ),
                              Divider(height: 1, color: context.dividerColor),
                              _buildResponseDelayOption(
                                context,
                                ms: 700,
                                title: isVi
                                    ? 'Chuẩn (700ms)'
                                    : 'Standard (700ms)',
                                subtitle: isVi
                                    ? 'Khuyên dùng (tự nhiên & cân bằng)'
                                    : 'Recommended (natural & balanced)',
                                isDark: isDark,
                                activeMint: activeMint,
                              ),
                              Divider(height: 1, color: context.dividerColor),
                              _buildResponseDelayOption(
                                context,
                                ms: 1500,
                                title: isVi
                                    ? 'Thư thả (1500ms)'
                                    : 'Relaxed (1500ms)',
                                subtitle: isVi
                                    ? 'Bình tĩnh, nhịp nhàng'
                                    : 'Steady, paced',
                                isDark: isDark,
                                activeMint: activeMint,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ════════════ 5. THỜI GIAN CHỜ IM LẶNG GIỌNG NÓI ════════════
                      _buildSectionHeader(
                        context,
                        icon: Icons.mic_rounded,
                        title: isVi
                            ? 'Khoảng chờ khi nói (Voice Silence)'
                            : 'Voice Silence Wait Time',
                        subtitle: isVi
                            ? 'Thời gian yên lặng trước khi Mono tự động gửi câu lệnh.'
                            : 'Silence duration before Mono automatically sends your query.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cardBorder, width: 1.3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Column(
                            children: [
                              _buildSilenceOption(
                                context,
                                ms: 1500,
                                title: isVi ? '1.5 giây' : '1.5 seconds',
                                subtitle: isVi
                                    ? 'Dành cho người nói nhanh và dứt khoát'
                                    : 'For quick, decisive speakers',
                                isDark: isDark,
                                activeMint: activeMint,
                              ),
                              Divider(height: 1, color: context.dividerColor),
                              _buildSilenceOption(
                                context,
                                ms: 2000,
                                title: isVi
                                    ? '2.0 giây (Mặc định)'
                                    : '2.0 seconds (Default)',
                                subtitle: isVi
                                    ? 'Cân bằng, tránh bị ngắt lời giữa chừng'
                                    : 'Balanced, avoids mid-sentence cutoffs',
                                isDark: isDark,
                                activeMint: activeMint,
                              ),
                              Divider(height: 1, color: context.dividerColor),
                              _buildSilenceOption(
                                context,
                                ms: 3000,
                                title: isVi ? '3.0 giây' : '3.0 seconds',
                                subtitle: isVi
                                    ? 'Dành cho người nói chậm, có khoảng nghỉ dài'
                                    : 'For relaxed speakers with longer pauses',
                                isDark: isDark,
                                activeMint: activeMint,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ════════════ 6. TÙY CHỌN DỰ PHÒNG CLOUD GEMINI ════════════
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Icon(
                                Icons.cloud_queue_rounded,
                                size: 18,
                                color: activeMint,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isVi
                                    ? 'Cấu hình Dự phòng Cloud (Tùy chọn)'
                                    : 'Cloud Backup Configuration (Optional)',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isVi
                                        ? 'Bạn có thể nhập Google Gemini API Key làm phương án dự phòng khi cần so sánh hiệu năng:'
                                        : 'You can enter a Google Gemini API Key as a fallback benchmark:',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: context.colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _apiKeyController,
                                    obscureText: _obscureKey,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: context.colors.onSurface,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: isVi
                                          ? 'Dán API Key (AIzaSy...) dự phòng...'
                                          : 'Paste backup API Key (AIzaSy...)...',
                                      hintStyle: TextStyle(
                                        color: context.colors.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: context.borderColor,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: context.borderColor,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: activeMint,
                                          width: 1.5,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureKey
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                          size: 18,
                                          color:
                                              context.colors.onSurfaceVariant,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscureKey = !_obscureKey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _isTestingCloud
                                            ? null
                                            : _testCloudKey,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: context.cardBg,
                                          foregroundColor:
                                              context.colors.onSurface,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            side: BorderSide(
                                              color: context.borderColor,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        icon: Icon(
                                          Icons.bolt_rounded,
                                          size: 16,
                                          color: activeMint,
                                        ),
                                        label: Text(
                                          isVi
                                              ? 'Kiểm tra Key Cloud'
                                              : 'Test Cloud Key',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          await _configService.setApiKey(
                                            _apiKeyController.text.trim(),
                                          );
                                          if (!context.mounted) return;
                                          TopToast.show(
                                            context,
                                            isVi
                                                ? 'Đã lưu API Key dự phòng!'
                                                : 'Backup API Key saved successfully!',
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: activeMint,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.save_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          isVi ? 'Lưu Key' : 'Save Key',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final activeMint = context.brandColor;
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
                color: context.colors.onSurface,
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
              fontSize: 12.5,
              color: context.colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelOption(
    BuildContext context, {
    required String modelKey,
    required String title,
    required String badge,
    required String subtitle,
    required bool isDark,
    required Color activeMint,
  }) {
    final isSelected = _selectedLocalModel == modelKey;
    return InkWell(
      onTap: () async {
        final isVi = LanguageScope.of(this.context).isVietnamese;
        setState(() => _selectedLocalModel = modelKey);
        await _configService.setLocalModelName(modelKey);
        if (!mounted) return;
        TopToast.show(
          this.context,
          isVi ? 'Đã chọn mô hình: $title' : 'Selected model: $title',
        );
      },
      child: Container(
        color: isSelected
            ? activeMint.withValues(alpha: isDark ? 0.22 : 0.08)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? activeMint : context.colors.onSurfaceVariant,
              size: 21,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 14.5,
                          color: context.colors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: activeMint.withValues(
                            alpha: isDark ? 0.3 : 0.15,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: activeMint,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseDelayOption(
    BuildContext context, {
    required int ms,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color activeMint,
  }) {
    final isSelected = _selectedResponseDelayMs == ms;
    return InkWell(
      onTap: () async {
        final isVi = LanguageScope.of(this.context).isVietnamese;
        setState(() => _selectedResponseDelayMs = ms);
        await _configService.setResponseDelayMs(ms);
        if (!mounted) return;
        TopToast.show(
          this.context,
          isVi
              ? 'Đã đặt độ trễ phản hồi: $title'
              : 'Response delay set: $title',
        );
      },
      child: Container(
        color: isSelected
            ? activeMint.withValues(alpha: isDark ? 0.22 : 0.08)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? activeMint : context.colors.onSurfaceVariant,
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 14,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSilenceOption(
    BuildContext context, {
    required int ms,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color activeMint,
  }) {
    final isSelected = _selectedSilenceMs == ms;
    return InkWell(
      onTap: () async {
        final isVi = LanguageScope.of(this.context).isVietnamese;
        setState(() => _selectedSilenceMs = ms);
        await _configService.setVoiceSilenceDurationMs(ms);
        if (!mounted) return;
        TopToast.show(
          this.context,
          isVi
              ? 'Đã đặt khoảng chờ giọng nói: $title'
              : 'Voice silence duration set: $title',
        );
      },
      child: Container(
        color: isSelected
            ? activeMint.withValues(alpha: isDark ? 0.22 : 0.08)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? activeMint : context.colors.onSurfaceVariant,
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 14,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
