import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../controllers/notification_controller.dart';
import '../../domain/entities/notification_entities.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  late final NotificationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = sl<NotificationController>();
    _controller.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              await _controller.markAllAsRead();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read.')),
                );
              }
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final state = _controller.state;

          if (state is NotificationLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
          }

          if (state is NotificationError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                  const SizedBox(height: 8),
                  Text(state.message),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => _controller.fetchNotifications(), child: const Text('Retry')),
                ],
              ),
            );
          }

          final notifications = state is NotificationLoaded ? state.feed.notifications : <AppNotification>[];

          if (notifications.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.notifications_none, size: 44, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No notifications right now.',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primaryLight,
            onRefresh: () => _controller.fetchNotifications(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notif = notifications[index];

                return GestureDetector(
                  onTap: () {
                    if (!notif.isRead) {
                      _controller.markAsRead(notif.id);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: notif.isRead
                          ? (isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight)
                          : (isDark ? AppColors.primaryLight.withOpacity(0.12) : const Color(0xFFECFDF5)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: notif.isRead
                            ? (isDark ? AppColors.outlineDark.withOpacity(0.15) : AppColors.outlineLight.withOpacity(0.15))
                            : AppColors.primaryLight.withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: notif.isRead
                                ? Colors.grey.withOpacity(0.15)
                                : AppColors.primaryLight.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIconForType(notif.notificationType),
                            size: 20,
                            color: notif.isRead ? Colors.grey : AppColors.primaryLight,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif.title,
                                      style: TextStyle(
                                        fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (!notif.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notif.body,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notif.createdAt.length >= 10 ? notif.createdAt.substring(0, 10) : notif.createdAt,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toUpperCase()) {
      case 'ATTENDANCE_VERIFIED':
      case 'ATTENDANCE':
        return Icons.fact_check_outlined;
      case 'COUNSELING_APPROVED':
      case 'COUNSELING_SLOT':
        return Icons.support_agent;
      case 'FEEDBACK_RECEIVED':
      case 'FEEDBACK_REPLY':
        return Icons.rate_review_outlined;
      case 'SEMESTER_UPGRADE':
        return Icons.upgrade;
      default:
        return Icons.notifications_active_outlined;
    }
  }
}
