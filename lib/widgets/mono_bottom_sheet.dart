import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Modal Bottom Sheet phong cách Mono v2.0 - Fintech Modern UI
/// Bo góc trên 24px (AppRadius.bottomSheet), tích hợp thanh kéo Drag Handle Pill,
/// viền phản quang Specular Highlight và nền kính mờ thích ứng
class MonoBottomSheet {
  /// Hiển thị Modal Bottom Sheet chuẩn hóa
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useSafeArea = true,
    Color? barrierColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.55),
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => MonoBottomSheetContainer(child: builder(ctx)),
    );
  }
}

/// Khung chứa BottomSheet tiêu chuẩn với viền specular highlight, thanh kéo và bo góc 24px
class MonoBottomSheetContainer extends StatelessWidget {
  final Widget child;
  final bool showDragHandle;
  final EdgeInsetsGeometry? padding;
  final double? maxHeightFactor;

  const MonoBottomSheetContainer({
    super.key,
    required this.child,
    this.showDragHandle = true,
    this.padding,
    this.maxHeightFactor = 0.9,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final sheetTheme = Theme.of(context).bottomSheetTheme;
    final baseBg =
        sheetTheme.backgroundColor ??
        (isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight);
    final bgColor = baseBg.withValues(alpha: isDark ? 0.96 : 0.98);
    final topBorderColor = isDark
        ? AppColors.borderDarkHighlight
        : context.borderColor;
    final dragHandleColor =
        sheetTheme.dragHandleColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.28)
            : const Color(0xFFCBD5E1));

    Widget content = Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.bottomSheet,
        border: Border(
          top: BorderSide(color: topBorderColor, width: 1.2),
          left: BorderSide(
            color: topBorderColor.withValues(alpha: 0.4),
            width: 0.6,
          ),
          right: BorderSide(
            color: topBorderColor.withValues(alpha: 0.4),
            width: 0.6,
          ),
        ),
        boxShadow: AppShadows.modal(isDark),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDragHandle) ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: dragHandleColor,
                      borderRadius: AppRadius.pill,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: AppRadius.bottomSheet,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: maxHeightFactor != null
            ? FractionallySizedBox(
                heightFactor: null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * maxHeightFactor!,
                  ),
                  child: content,
                ),
              )
            : content,
      ),
    );
  }
}
