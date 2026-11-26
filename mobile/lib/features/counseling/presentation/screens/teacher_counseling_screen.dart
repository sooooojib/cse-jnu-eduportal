import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/counseling_controller.dart';
import '../../domain/entities/counseling_entities.dart';
import '../widgets/create_counseling_slot_dialog.dart';

class TeacherCounselingScreen extends StatefulWidget {
  final CounselingController? controller;
  final AuthController? authController;
  final bool showAppBar;

  const TeacherCounselingScreen({
    super.key,
    this.controller,
    this.authController,
    this.showAppBar = true,
  });

  @override
  State<TeacherCounselingScreen> createState() => _TeacherCounselingScreenState();
}

class _TeacherCounselingScreenState extends State<TeacherCounselingScreen> with SingleTickerProviderStateMixin {
  late final CounselingController _controller;
  late final AuthController _authController;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? sl<CounselingController>();
    _authController = widget.authController ?? sl<AuthController>();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _teacherUid => _authController.currentUser?.id ?? '';

  Future<void> _loadData() async {
    if (_teacherUid.isNotEmpty) {
      await _controller.fetchTeacherData(_teacherUid);
    }
  }

  Future<void> _handleApprove(CounselingBooking booking) async {
    TimeOfDay parseTime(String t) {
      try {
        final parts = t.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {
        return const TimeOfDay(hour: 10, minute: 0);
      }
    }

    String formatTime(TimeOfDay t) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    TimeOfDay selectedStartTime = parseTime(booking.startTime);
    TimeOfDay selectedEndTime = parseTime(booking.endTime);
    final messageController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final startFormatted = formatTime(selectedStartTime);
            final endFormatted = formatTime(selectedEndTime);
            final isTimeModified = startFormatted != booking.startTime || endFormatted != booking.endTime;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 22),
                  SizedBox(width: 8),
                  Text('Approve Appointment'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirm booking for ${booking.studentName ?? "Student"} on ${booking.slotDate}?\n'
                        'This will atomically lock this office slot and mark any competing requests as rejected.',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      // Session Time Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Session Time (Tap to adjust)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          if (isTimeModified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Modified',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedStartTime,
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    selectedStartTime = picked;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F1E33) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isTimeModified
                                        ? Colors.orange.withOpacity(0.4)
                                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primaryLight),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Start Time', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(
                                          startFormatted,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedEndTime,
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    selectedEndTime = picked;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F1E33) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isTimeModified
                                        ? Colors.orange.withOpacity(0.4)
                                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primaryLight),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('End Time', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(
                                          endFormatted,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Message to Student (Optional)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: messageController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'e.g. Please meet at Room 501. Bring your thesis draft and presentation slides...',
                          hintStyle: const TextStyle(fontSize: 12),
                          contentPadding: const EdgeInsets.all(12),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F1E33) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm & Lock Slot'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        final teacherMessage = messageController.text.trim();
        final startStr = formatTime(selectedStartTime);
        final endStr = formatTime(selectedEndTime);
        await _controller.approveRequest(
          booking.id,
          message: teacherMessage.isNotEmpty ? teacherMessage : null,
          startTime: startStr,
          endTime: endStr,
          teacherId: _teacherUid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment approved and counseling slot confirmed!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '').replaceAll('ServerException: ', '')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleReject(CounselingBooking booking) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to decline the request from ${booking.studentName ?? "Student"}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason (optional, e.g. "Attend office hours")',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _controller.rejectRequest(
          booking.id,
          reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
          teacherId: _teacherUid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment request declined.'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '').replaceAll('ServerException: ', '')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleDeleteSlot(CounselingSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Office Slot?'),
        content: Text('Delete your slot for ${slot.slotDate} (${slot.startTime} - ${slot.endTime})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _controller.deleteSlot(slot.id, teacherId: _teacherUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Counseling slot deleted.'), backgroundColor: Colors.grey),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '').replaceAll('ServerException: ', '')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _openCreateSlotDialog() {
    CreateCounselingSlotDialog.show(
      context,
      controller: _controller,
      teacherId: _teacherUid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;

        if (state is CounselingLoading && !_controller.isActionLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is CounselingError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final loaded = state is CounselingLoaded ? state : null;
        final requests = loaded?.teacherRequests ?? [];
        final slots = loaded?.teacherSlots ?? [];

        return TabBarView(
          controller: _tabController,
          children: [
            _buildRequestsTab(requests, isDark),
            _buildSlotsTab(slots, isDark),
          ],
        );
      },
    );

    return Scaffold(
      backgroundColor: widget.showAppBar ? null : Colors.transparent,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Faculty Counseling',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              bottom: TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryLight,
                unselectedLabelColor: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                indicatorColor: AppColors.primaryLight,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.inbox_rounded),
                    text: 'Requests',
                  ),
                  Tab(
                    icon: Icon(Icons.calendar_month_rounded),
                    text: 'My Office Slots',
                  ),
                ],
              ),
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _openCreateSlotDialog,
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Slot', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: widget.showAppBar
          ? content
          : Column(
              children: [
                Container(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: const [
                        Tab(text: 'Requests'),
                        Tab(text: 'My Office Slots'),
                      ],
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            ),
    );
  }

  Widget _buildRequestsTab(List<CounselingBooking> requests, bool isDark) {
    if (requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 64,
                    color: isDark ? AppColors.outlineDark.withOpacity(0.4) : AppColors.outlineLight.withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Appointment Requests',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Students who request your counseling slots will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final req = requests[index];
          return _buildRequestCard(req, isDark);
        },
      ),
    );
  }

  Widget _buildRequestCard(CounselingBooking req, bool isDark) {
    Color statusColor;
    String statusLabel;
    switch (req.status) {
      case 'APPROVED':
        statusColor = Colors.green;
        statusLabel = 'Approved / Confirmed';
        break;
      case 'REJECTED':
        statusColor = Colors.redAccent;
        statusLabel = 'Declined';
        break;
      case 'CANCELLED':
        statusColor = Colors.grey;
        statusLabel = 'Cancelled';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'Pending Review';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.outlineDark.withOpacity(0.15) : AppColors.outlineLight.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  req.studentName ?? 'Student Request',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Purpose Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              req.category,
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Date & Time
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${req.slotDate} • ${req.startTime} - ${req.endTime}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),

          if (req.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark.withOpacity(0.5) : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Agenda: ${req.notes}',
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
          ],

          if (req.rejectionReason != null && req.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${req.rejectionReason}',
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],

          // Actions for Pending Requests
          if (req.status == 'PENDING') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _controller.isActionLoading ? null : () => _handleReject(req),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _controller.isActionLoading ? null : () => _handleApprove(req),
                    child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotsTab(List<CounselingSlot> slots, bool isDark) {
    if (slots.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 64,
                    color: isDark ? AppColors.outlineDark.withOpacity(0.4) : AppColors.outlineLight.withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Counseling Slots Created',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Publish your office hours so students can request appointments.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openCreateSlotDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Slot'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: slots.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final slot = slots[index];
          final isBooked = slot.isBooked;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.outlineDark.withOpacity(0.15) : AppColors.outlineLight.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isBooked ? Icons.lock_clock_rounded : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: isBooked ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              slot.slotDate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isBooked ? Colors.orange : Colors.green).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isBooked ? 'Booked' : 'Available',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isBooked ? Colors.orange : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${slot.startTime} - ${slot.endTime}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      if (slot.notes != null && slot.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          slot.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                          ),
                        ),
                      ],
                      if (slot.bookedStudentName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Booked with: ${slot.bookedStudentName}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isBooked)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _handleDeleteSlot(slot),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
