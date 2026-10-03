import 'package:flutter/material.dart';
import '../../../../core/utils/context_extensions.dart';

class AdminUserDirectoryBanner extends StatelessWidget {
  final int totalUsers;
  final VoidCallback onTap;

  const AdminUserDirectoryBanner({
    super.key,
    required this.totalUsers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF7E22CE).withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7E22CE).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9333EA), Color(0xFF7E22CE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'User Directory',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF7E22CE).withValues(alpha: 0.15)
                              : const Color(0xFFFAF5FF),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF7E22CE).withValues(alpha: 0.3)
                                : const Color(0xFFE9D5FF),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$totalUsers Accounts',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search records across Teachers, Students & CRs',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF7E22CE),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
