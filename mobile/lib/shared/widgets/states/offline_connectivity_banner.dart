import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/network/network_info.dart';

class OfflineConnectivityBanner extends StatelessWidget {
  final NetworkInfo? networkInfo;
  final VoidCallback? onRetry;

  const OfflineConnectivityBanner({
    super.key,
    this.networkInfo,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final info = networkInfo ?? (sl.isRegistered<NetworkInfo>() ? sl<NetworkInfo>() : null);
    if (info == null) return const SizedBox.shrink();

    return ValueListenableBuilder<NetworkStatus>(
      valueListenable: info.statusNotifier,
      builder: (context, status, _) {
        if (status == NetworkStatus.online) {
          return const SizedBox.shrink();
        }

        Color bg;
        Color fg;
        IconData icon;
        String message;
        bool showRetry = false;

        switch (status) {
          case NetworkStatus.offline:
            bg = const Color(0xFFB45309); // Amber 700
            fg = Colors.white;
            icon = Icons.wifi_off_rounded;
            message = 'Offline Mode — Showing cached data. Server actions disabled.';
            showRetry = true;
            break;
          case NetworkStatus.reconnecting:
            bg = const Color(0xFF1E40AF); // Blue 800
            fg = Colors.white;
            icon = Icons.sync_rounded;
            message = 'Connecting to JnU EduPortal server...';
            break;
          case NetworkStatus.reconnected:
            bg = AppColors.primary; // Emerald
            fg = Colors.white;
            icon = Icons.check_circle_rounded;
            message = 'Back online · Reconnected to server.';
            break;
          case NetworkStatus.slow:
            bg = const Color(0xFFD97706); // Amber 600
            fg = Colors.white;
            icon = Icons.speed_rounded;
            message = 'Slow or unstable network connection detected.';
            showRetry = true;
            break;
          case NetworkStatus.online:
            return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showRetry) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRetry ?? () => info.checkConnectivity(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 12, color: fg),
                        const SizedBox(width: 4),
                        Text(
                          'Retry',
                          style: TextStyle(
                            color: fg,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
