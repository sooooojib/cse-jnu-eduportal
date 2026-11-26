import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/cache_metadata.dart';

/// Non-intrusive badge showing cached or stale data status
class CachedDataBadge extends StatelessWidget {
  final CacheMetadata metadata;
  final VoidCallback? onRefresh;

  const CachedDataBadge({
    super.key,
    required this.metadata,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (!metadata.isFromCache) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isStale = metadata.isStale;

    final bg = isStale
        ? (isDark ? const Color(0xFF3B1E08) : const Color(0xFFFEF3C7))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));

    final fg = isStale
        ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309))
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));

    final label = metadata.message ??
        (isStale ? 'Stale data · Connect to refresh' : 'Offline cache');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: fg.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isStale ? Icons.history_rounded : Icons.offline_pin_outlined,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRefresh,
              child: Icon(Icons.refresh_rounded, size: 14, color: fg),
            ),
          ],
        ],
      ),
    );
  }
}
