import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// Widget hiển thị banner "Đang offline" ở đầu màn hình khi mất mạng.
/// Tự động ẩn khi có mạng trở lại.
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
          height: isOnline ? 0 : 22,
          width: double.infinity,
          color: const Color(0xFFEA580C),
          child: isOnline
              ? const SizedBox.shrink()
              : const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 6),
                      Text(
                        'Đang offline — Dữ liệu sẽ đồng bộ khi có mạng',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
