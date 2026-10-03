import 'package:flutter/material.dart';
import '../../../../core/utils/context_extensions.dart';

class AdminSystemStatusCard extends StatelessWidget {
  const AdminSystemStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E22CE).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF7E22CE), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Admin Control & Authority',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You are authenticated with Superuser administrative privileges. All moderation actions, user provisioning, and semester updates take immediate effect departmental-wide.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'System Operational',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'v2.4.1 (Firebase Engine)',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
