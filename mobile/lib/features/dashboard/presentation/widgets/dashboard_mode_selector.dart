import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/storage/local_storage_service.dart';

enum DashboardMode { faculty, admin }

/// Remembers the last selected dashboard mode per user on this device.
class DashboardModePreference {
  DashboardModePreference._();

  static String _key(String userId) => 'dashboard_mode_$userId';

  static DashboardMode read(String userId) {
    if (!sl.isRegistered<LocalStorageService>()) return DashboardMode.faculty;
    final raw = sl<LocalStorageService>().getString(_key(userId));
    return raw == DashboardMode.admin.name ? DashboardMode.admin : DashboardMode.faculty;
  }

  static Future<void> write(String userId, DashboardMode mode) async {
    if (!sl.isRegistered<LocalStorageService>()) return;
    await sl<LocalStorageService>().setString(_key(userId), mode.name);
  }
}

/// Segmented "Faculty View | Admin View" switch shown under the dashboard
/// welcome header for the Chairman and for faculty with admin-view delegation.
class DashboardModeSelector extends StatelessWidget {
  final DashboardMode currentMode;
  final ValueChanged<DashboardMode> onModeChanged;

  /// Label for the admin segment, e.g. "Department Admin" for the Chairman or
  /// "Signup Committee" for delegated faculty.
  final String adminLabel;

  const DashboardModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.adminLabel = 'Admin View',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? const Color(0xFF13263E) : const Color(0xFFEEF2F7);
    final pillColor = isDark ? const Color(0xFF1E3A5F) : Colors.white;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: currentMode == DashboardMode.faculty ? 0 : segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _segment(
                    context,
                    mode: DashboardMode.faculty,
                    icon: Icons.school_outlined,
                    label: 'Faculty View',
                    activeColor: const Color(0xFF1D4ED8),
                    isDark: isDark,
                  ),
                  _segment(
                    context,
                    mode: DashboardMode.admin,
                    icon: Icons.admin_panel_settings_outlined,
                    label: adminLabel,
                    activeColor: const Color(0xFF7E22CE),
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required DashboardMode mode,
    required IconData icon,
    required String label,
    required Color activeColor,
    required bool isDark,
  }) {
    final isActive = currentMode == mode;
    final inactive = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final active = isDark ? Colors.white : activeColor;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: label,
        child: InkWell(
          key: ValueKey('dashboard_mode_${mode.name}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (isActive) return;
            HapticFeedback.selectionClick();
            onModeChanged(mode);
          },
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: isActive ? active : inactive),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      color: isActive ? active : inactive,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
