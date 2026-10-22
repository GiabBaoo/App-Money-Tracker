import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_widget_service.dart';
import '../core/theme/app_theme.dart';

enum MonoToastType {
  success,
  error,
  warning,
  info,
}

/// Hệ thống thông báo nổi Liquid Capsule Toast hiện đại v2.0
/// Độc lập hoàn toàn với Scaffold, bo góc 24px, đổ bóng kính mờ và tự động thích ứng Sáng / Tối.
class MonoToast {
  static OverlayEntry? _currentEntry;

  /// Hiển thị Toast với tham số (context, message, {type, duration, onDismiss})
  static void show(
    BuildContext context,
    String message, {
    MonoToastType type = MonoToastType.info,
    Duration duration = const Duration(milliseconds: 2600),
    VoidCallback? onDismiss,
  }) {
    showCustom(
      context,
      message: message,
      type: type,
      duration: duration,
      onDismiss: onDismiss,
    );
  }

  static void showCustom(
    BuildContext? context, {
    required String message,
    MonoToastType type = MonoToastType.info,
    Duration duration = const Duration(milliseconds: 2600),
    VoidCallback? onDismiss,
  }) {
    if (message.trim().isEmpty) return;

    // Kích hoạt phản hồi rung xúc giác tinh tế (Haptic Feedback)
    if (type == MonoToastType.error) {
      HapticFeedback.heavyImpact();
    } else if (type == MonoToastType.warning) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    _currentEntry?.remove();
    _currentEntry = null;

    OverlayState? overlay;
    bool isDark = false;

    if (context != null && context.mounted) {
      overlay = Overlay.maybeOf(context, rootOverlay: true);
      isDark = Theme.of(context).brightness == Brightness.dark;
    }

    if (overlay == null) {
      final navKey = AppWidgetService.instance.navigatorKey;
      if (navKey?.currentState?.overlay != null) {
        overlay = navKey!.currentState!.overlay;
        final currentCtx = navKey.currentContext;
        if (currentCtx != null && currentCtx.mounted) {
          isDark = Theme.of(currentCtx).brightness == Brightness.dark;
        }
      }
    }

    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _MonoToastWidget(
        message: message,
        type: type,
        isDark: isDark,
        duration: duration,
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
          onDismiss?.call();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void success(
    dynamic contextOrMessage, [
    String? positionalMessage,
  ]) {
    _dispatch(contextOrMessage, positionalMessage, MonoToastType.success, const Duration(milliseconds: 2600));
  }

  static void error(
    dynamic contextOrMessage, [
    String? positionalMessage,
  ]) {
    _dispatch(contextOrMessage, positionalMessage, MonoToastType.error, const Duration(milliseconds: 3000));
  }

  static void warning(
    dynamic contextOrMessage, [
    String? positionalMessage,
  ]) {
    _dispatch(contextOrMessage, positionalMessage, MonoToastType.warning, const Duration(milliseconds: 2800));
  }

  static void info(
    dynamic contextOrMessage, [
    String? positionalMessage,
  ]) {
    _dispatch(contextOrMessage, positionalMessage, MonoToastType.info, const Duration(milliseconds: 2600));
  }

  static void _dispatch(
    dynamic contextOrMessage,
    String? positionalMessage,
    MonoToastType type,
    Duration duration,
  ) {
    BuildContext? ctx;
    String msg = '';

    if (contextOrMessage is BuildContext) {
      ctx = contextOrMessage;
      if (positionalMessage != null) {
        msg = positionalMessage;
      }
    } else if (contextOrMessage is String) {
      msg = contextOrMessage;
      if (positionalMessage != null && msg.isEmpty) {
        msg = positionalMessage;
      }
    }

    showCustom(ctx, message: msg, type: type, duration: duration);
  }
}

class _MonoToastWidget extends StatefulWidget {
  final String message;
  final MonoToastType type;
  final bool isDark;
  final VoidCallback onDismiss;
  final Duration duration;

  const _MonoToastWidget({
    required this.message,
    required this.type,
    required this.isDark,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_MonoToastWidget> createState() => _MonoToastWidgetState();
}

class _MonoToastWidgetState extends State<_MonoToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _slideAnimation = Tween<double>(begin: -45.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _animController.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  _ToastColorConfig _getColorConfig(BuildContext context) {
    final isDark = context.isDarkMode;
    switch (widget.type) {
      case MonoToastType.success:
        return _ToastColorConfig(
          bg: isDark ? AppColors.incomeBgDark : context.income,
          border: AppColors.incomeEmeraldLight.withValues(alpha: 0.45),
          icon: AppColors.incomeEmeraldLight,
          iconData: Icons.check_circle_rounded,
        );
      case MonoToastType.error:
        return _ToastColorConfig(
          bg: isDark ? AppColors.expenseBgDark : context.expense,
          border: AppColors.expenseRoseLight.withValues(alpha: 0.45),
          icon: AppColors.expenseRoseLight,
          iconData: Icons.error_rounded,
        );
      case MonoToastType.warning:
        return _ToastColorConfig(
          bg: isDark ? AppColors.warningBgDark : context.warning,
          border: AppColors.warningAmberLight.withValues(alpha: 0.45),
          icon: AppColors.warningAmberLight,
          iconData: Icons.warning_rounded,
        );
      case MonoToastType.info:
        return _ToastColorConfig(
          bg: isDark ? AppColors.transferBgDark : context.transfer,
          border: AppColors.transferIndigoLight.withValues(alpha: 0.45),
          icon: AppColors.transferIndigoLight,
          iconData: Icons.info_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final config = _getColorConfig(context);
    final isDark = context.isDarkMode;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: Center(
            child: ClipRRect(
              borderRadius: AppRadius.dialog,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: config.bg.withValues(alpha: isDark ? 0.92 : 0.96),
                    borderRadius: AppRadius.dialog,
                    border: Border.all(color: config.border, width: 1.2),
                    boxShadow: AppShadows.floating(isDark),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(config.iconData, color: config.icon, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: context.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastColorConfig {
  final Color bg;
  final Color border;
  final Color icon;
  final IconData iconData;

  _ToastColorConfig({
    required this.bg,
    required this.border,
    required this.icon,
    required this.iconData,
  });
}
