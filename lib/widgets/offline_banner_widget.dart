import 'package:flutter/material.dart';
import '../services/language_service.dart';
import '../services/connectivity_service.dart';
import '../core/theme/app_theme.dart';

/// Widget hiển thị banner "Đang offline" ở đầu màn hình khi mất mạng.
/// Tự động ẩn khi có mạng trở lại, phong cách Fintech Minimal.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService().onlineStream,
      initialData: ConnectivityService().isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isOnline ? 0 : 24,
          width: double.infinity,
          color: AppColors.warningAmber,
          child: isOnline
              ? const SizedBox.shrink()
              : Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        LanguageScope.of(context).isVietnamese
                            ? 'Đang offline — Dữ liệu sẽ tự động đồng bộ khi có mạng'
                            : 'Offline mode — Changes will sync when reconnected',
                        style: AppTextStyles.captionSmall.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
