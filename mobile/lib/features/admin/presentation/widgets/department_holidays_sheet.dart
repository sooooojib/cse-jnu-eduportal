import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../curriculum/data/repositories/holiday_repository.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

/// Bottom sheet for Admin / Chairman to manage official department holidays.
class DepartmentHolidaysSheet extends StatefulWidget {
  final HolidayRepository? repository;

  const DepartmentHolidaysSheet({super.key, this.repository});

  static Future<bool?> show(BuildContext context, {HolidayRepository? repository}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DepartmentHolidaysSheet(repository: repository),
    );
  }

  @override
  State<DepartmentHolidaysSheet> createState() => _DepartmentHolidaysSheetState();
}

class _DepartmentHolidaysSheetState extends State<DepartmentHolidaysSheet> {
  static final _fmt = DateFormat('EEE, MMM d, yyyy');

  late final HolidayRepository _repo;
  final _titleCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<DepartmentHoliday> _holidays = const [];
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? sl<HolidayRepository>();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.listHolidays();
      if (!mounted) return;
      setState(() {
        _holidays = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Select holiday date',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _addHoliday() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a holiday name (e.g. Victory Day).')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = sl.isRegistered<AuthController>() ? sl<AuthController>().currentUser?.id : null;
      await _repo.saveHoliday(date: _selectedDate, title: title, createdBy: uid);
      _titleCtrl.clear();
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save holiday: ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeHoliday(DepartmentHoliday holiday) async {
    try {
      await _repo.deleteHoliday(holiday.date);
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not remove holiday: ${friendlyError(e)}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_busy_rounded, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Department Holidays',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context, _changed),
              ),
            ],
          ),
          Text(
            'Classes on holiday dates are cleared automatically and excluded from missed-class monitoring.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleCtrl,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Holiday Title',
              hintText: 'e.g. Victory Day, Eid Holiday',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) => _addHoliday(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _saving ? null : _addHoliday,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Holiday'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                : _holidays.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No holidays added yet.',
                            style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _holidays.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final h = _holidays[i];
                          final parsed = DateTime.tryParse(h.date);
                          final label = parsed != null ? _fmt.format(parsed) : h.date;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF13263E) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.celebration_outlined, size: 18, color: Color(0xFFD97706)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                      Text(label, style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.grey[700])),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove holiday',
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                  onPressed: () => _removeHoliday(h),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
