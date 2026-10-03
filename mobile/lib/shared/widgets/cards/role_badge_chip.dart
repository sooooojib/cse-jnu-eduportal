import 'package:flutter/material.dart';
import '../../../core/constants/role_constants.dart';
import '../../../app/theme/role_colors.dart';

class RoleBadgeChip extends StatelessWidget {
  final UserRole role;
  final bool isCompact;

  const RoleBadgeChip({
    super.key,
    required this.role,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = RoleColors.forRole(role, isDark: isDark);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.background.withValues(alpha: 0.35) : colors.background,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: isDark ? colors.border.withValues(alpha: 0.45) : colors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            role.label,
            style: TextStyle(
              color: colors.text,
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
