import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/app_logo.dart';
import '../../utils/page_transitions.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      title: 'Chi tiêu thông minh,\ntiết kiệm hơn mỗi ngày',
      description:
          'Ghi chép thu chi nhanh chóng, theo dõi trực quan theo danh mục và nắm bắt bức tranh tài chính toàn diện.',
      badgeText: 'Quản Lý Cá Nhân',
      primaryIcon: Icons.insights_rounded,
      has3DImage: true,
    ),
    _OnboardingItem(
      title: 'Trợ lý tài chính AI &\nGhi chép bằng giọng nói',
      description:
          'Trợ lý ảo Mono AI lắng nghe giọng nói tiếng Việt, tự động nhận diện danh mục và đưa ra lời khuyên chi tiêu bổ ích.',
      badgeText: 'Trợ Lý AI Mono',
      primaryIcon: Icons.auto_awesome_rounded,
      has3DImage: false,
    ),
    _OnboardingItem(
      title: 'Quỹ chi tiêu nhóm &\nBảo mật sinh trắc học',
      description:
          'Chia tiền nhóm sòng phẳng, thanh toán QR tiện lợi. Toàn bộ dữ liệu được bảo mật vân tay và hoạt động ngoại tuyến 100%.',
      badgeText: 'Nhóm & Bảo Mật',
      primaryIcon: Icons.shield_rounded,
      has3DImage: false,
    ),
  ];

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _navigateToRegister();
    }
  }

  void _navigateToRegister() {
    HapticFeedback.mediumImpact();
    Navigator.push(context, PageTransitions.slideRight(const RegisterScreen()));
  }

  void _navigateToLogin() {
    HapticFeedback.lightImpact();
    Navigator.push(context, PageTransitions.slideRight(const LoginScreen()));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : Colors.white,
      body: Stack(
        children: [
          // ═══ LỚP 1: NỀN QUẦNG SÁNG VÀ VÒNG TRÒN ARTWORK ═══
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: isDark ? 0.25 : 0.9,
              child: Image.asset(
                'assets/images/backgroud_onboarding.png',
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withValues(alpha: isDark ? 0.25 : 0.15),
                    primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ═══ LỚP 2: NỘI DUNG CHÍNH ═══
          SafeArea(
            child: Column(
              children: [
                // 1. TOP HEADER: LOGO MONO & NÚT BỎ QUA (SKIP)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo App thương hiệu chính thức
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppLogo.badge(
                            size: 38,
                            hasShadow: false,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          const SizedBox(width: 10),
                          AppLogo.wordmark(
                            height: 24,
                            color: isDark ? Colors.white : const Color(0xFF0F2625),
                          ),
                        ],
                      ),

                      // Nút Bỏ qua (Skip)
                      if (_currentPage < _items.length - 1)
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _pageController.animateToPage(
                              _items.length - 1,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Bỏ qua',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, size: 12),
                            ],
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),

                // 2. CAROUSEL PAGE VIEW
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildSlideContent(item, size, isDark, primaryColor);
                    },
                  ),
                ),

                // 3. PAGE INDICATOR (CHẤM TRÒN CHUYỂN TRANG CO DÃN MƯỢT MÀ)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_items.length, (index) {
                      final isSelected = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 7,
                        width: isSelected ? 24 : 7,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor
                              : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 8),

                // 4. CỤM NÚT HÀNH ĐỘNG ("BẮT ĐẦU" & "ĐÃ CÓ TÀI KHOẢN? ĐĂNG NHẬP")
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Nút chính: "Bắt đầu" (hoặc "Tiếp tục" ở các trang trước)
                      AnimatedScaleButton(
                        onTap: _nextPage,
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF68AEA9), Color(0xFF387A75)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF438883).withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentPage == _items.length - 1 ? 'Bắt đầu ngay' : 'Tiếp tục',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _currentPage == _items.length - 1
                                      ? Icons.rocket_launch_rounded
                                      : Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Nút phụ: "Đã có tài khoản? Đăng nhập"
                      AnimatedScaleButton(
                        onTap: _navigateToLogin,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Đã có tài khoản? ',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Đăng nhập',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideContent(
    _OnboardingItem item,
    Size size,
    bool isDark,
    Color primaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Phần hình minh họa
          Expanded(
            child: Center(
              child: item.has3DImage
                  ? Container(
                      width: size.width * 0.78,
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: Image.asset(
                        'assets/images/onboarding.png',
                        fit: BoxFit.contain,
                      ),
                    )
                  : _buildIllustratedFeatureCard(item, size, isDark, primaryColor),
            ),
          ),

          // Badge chủ đề nhỏ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.primaryIcon, size: 14, color: primaryColor),
                const SizedBox(width: 6),
                Text(
                  item.badgeText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Tiêu đề chính
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F2625),
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 10),

          // Mô tả phụ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              item.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildIllustratedFeatureCard(
    _OnboardingItem item,
    Size size,
    bool isDark,
    Color primaryColor,
  ) {
    final isAi = item.primaryIcon == Icons.auto_awesome_rounded;

    return Container(
      width: size.width * 0.78,
      height: 240,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162523) : const Color(0xFFF1F8F6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFDFEBE8),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Vòng tròn hào quang
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.15),
            ),
          ),

          // Biểu tượng trung tâm
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isAi
                        ? const [Color(0xFF00E5FF), Color(0xFF438883)]
                        : const [Color(0xFF438883), Color(0xFF2DD4BF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    item.primaryIcon,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Các chip tính năng con
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSubFeaturePill(
                    isAi ? 'Voice Tiếng Việt' : 'Chia đều hóa đơn',
                    isDark,
                    primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _buildSubFeaturePill(
                    isAi ? 'Gemini 2.5' : 'Offline 100%',
                    isDark,
                    primaryColor,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubFeaturePill(String text, bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F3330) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : const Color(0xFF475569),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String title;
  final String description;
  final String badgeText;
  final IconData primaryIcon;
  final bool has3DImage;

  const _OnboardingItem({
    required this.title,
    required this.description,
    required this.badgeText,
    required this.primaryIcon,
    required this.has3DImage,
  });
}
