import 'package:flutter/material.dart';
import '../../../../core/utils/class_time.dart';

/// Picks a time; returns "hh:mm AM" or null when dismissed.
typedef ClassTimePicker = Future<String?> Function(BuildContext context, String? current);

/// Two simple fields, **From** (start) and **To** (end). Tapping either opens
/// the clock. Changing From keeps the class length (To moves along).
///
/// Used by the class-change form (move / extra) and the routine editor.
class TimeRangeField extends StatelessWidget {
  final String? start;
  final String? end;
  final void Function(String? start, String? end) onChanged;

  /// Length used when From is set and there is no To yet.
  final int defaultMinutes;

  const TimeRangeField({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    this.defaultMinutes = 90,
  });

  /// Tests can replace the clock dialog.
  @visibleForTesting
  static ClassTimePicker? debugPicker;

  static Future<String?> _pick(BuildContext context, String? current, int fallback) async {
    final override = debugPicker;
    if (override != null) return override(context, current);
    final m = ClassTime.toMinutes(current ?? '') ?? fallback;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
    return t == null ? null : ClassTime.format(t.hour * 60 + t.minute);
  }

  Future<void> _pickStart(BuildContext context) async {
    final v = await _pick(context, start, 540);
    if (v == null) return;
    final newStart = ClassTime.toMinutes(v)!;
    final oldStart = ClassTime.toMinutes(start ?? '');
    final oldEnd = ClassTime.toMinutes(end ?? '');
    final length = (oldStart != null && oldEnd != null && oldEnd > oldStart) ? oldEnd - oldStart : defaultMinutes;
    final newEnd = (newStart + length).clamp(0, 23 * 60 + 59);
    onChanged(v, ClassTime.format(newEnd));
  }

  Future<void> _pickEnd(BuildContext context) async {
    final fallback = (ClassTime.toMinutes(start ?? '') ?? 540) + defaultMinutes;
    final v = await _pick(context, end, fallback);
    if (v == null) return;
    onChanged(start, v);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _box(context, 'From', start, const ValueKey('time_from'), () => _pickStart(context))),
        const SizedBox(width: 10),
        Expanded(child: _box(context, 'To', end, const ValueKey('time_to'), () => _pickEnd(context))),
      ],
    );
  }

  Widget _box(BuildContext context, String label, String? value, Key key, VoidCallback onTap) {
    final muted = Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF94A3B8);
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: const Icon(Icons.schedule_rounded, size: 20),
        ),
        child: Text(
          value ?? 'Set time',
          style: TextStyle(
            fontSize: 15,
            fontWeight: value == null ? FontWeight.w400 : FontWeight.w700,
            color: value == null ? muted : null,
          ),
        ),
      ),
    );
  }
}
