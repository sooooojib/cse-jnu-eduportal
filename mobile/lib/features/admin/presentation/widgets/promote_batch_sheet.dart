import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/services/batch_promotion_service.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

/// Admin / Chairman: move a whole semester (optionally one session) to the
/// next semester. Pick → preview → promote.
class PromoteBatchSheet extends StatefulWidget {
  final BatchPromotionService? service;
  const PromoteBatchSheet({super.key, this.service});

  static Future<void> show(BuildContext context, {BatchPromotionService? service}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => PromoteBatchSheet(service: service),
    );
  }

  @override
  State<PromoteBatchSheet> createState() => _PromoteBatchSheetState();
}

class _PromoteBatchSheetState extends State<PromoteBatchSheet> {
  static const _levels = [(1, 1), (1, 2), (2, 1), (2, 2), (3, 1), (3, 2), (4, 1)];

  late final BatchPromotionService _service = widget.service ?? BatchPromotionService();
  (int, int) _level = (1, 1);
  String? _session; // null = every session
  List<BatchStudent>? _students;
  final Set<String> _selected = {};
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.preview(year: _level.$1, semester: _level.$2);
      if (!mounted) return;
      setState(() {
        _students = list;
        if (_session != null && !list.any((s) => s.session == _session)) _session = null;
        _selected
          ..clear()
          ..addAll(_visible.map((s) => s.id));
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load students. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<BatchStudent> get _visible =>
      (_students ?? const []).where((s) => _session == null || s.session == _session).toList();

  List<String> get _sessions {
    final set = <String>{for (final s in _students ?? const <BatchStudent>[]) if ((s.session ?? '').isNotEmpty) s.session!};
    return set.toList()..sort();
  }

  Future<void> _promote() async {
    final next = BatchPromotionService.nextOf(_level.$1, _level.$2)!;
    final ids = _visible.where((s) => _selected.contains(s.id)).map((s) => s.id).toList();
    final crs = _visible.where((s) => s.isCr && _selected.contains(s.id)).map((s) => s.name).toList();
    final ok = await AppConfirmationDialog.show(
      context: context,
      title: 'Promote ${ids.length} students?',
      message: 'Year ${_level.$1}, Semester ${_level.$2}${_session == null ? '' : ' (session $_session)'} → '
          'Year ${next.$1}, Semester ${next.$2}.'
          '${crs.isEmpty ? '' : ' ${crs.join(', ')} stay CR of the batch.'}'
          ' Their pending semester requests are closed.',
      confirmText: 'Promote',
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final actor = sl.isRegistered<AuthController>() ? sl<AuthController>().currentUser?.id ?? '' : '';
      final moved = await _service.promote(
        year: _level.$1,
        semester: _level.$2,
        studentIds: ids,
        actorId: actor,
      );
      messenger.showSnackBar(SnackBar(content: Text('$moved students moved to Year ${next.$1}, Semester ${next.$2}.')));
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not promote: ${friendlyError(e)}'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = BatchPromotionService.nextOf(_level.$1, _level.$2)!;
    final visible = _visible;
    final count = visible.where((s) => _selected.contains(s.id)).length;
    final muted = Theme.of(context).textTheme.bodySmall?.color;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Promote batch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Move a whole semester to the next one. CRs stay CR of their batch.',
                style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<(int, int)>(
                    initialValue: _level,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'From', isDense: true, border: OutlineInputBorder()),
                    items: [
                      for (final l in _levels) DropdownMenuItem(value: l, child: Text('Year ${l.$1} · Sem ${l.$2}')),
                    ],
                    onChanged: _loading || _saving
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() => _level = v);
                            _load();
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('session-${_level.$1}-${_level.$2}-${_sessions.length}'),
                    initialValue: _session,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Session', isDense: true, border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All sessions')),
                      for (final s in _sessions) DropdownMenuItem<String?>(value: s, child: Text(s)),
                    ],
                    onChanged: _loading || _saving
                        ? null
                        : (v) => setState(() {
                              _session = v;
                              _selected
                                ..clear()
                                ..addAll(_visible.map((s) => s.id));
                            }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('To: Year ${next.$1}, Semester ${next.$2}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const Divider(height: 24),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, textAlign: TextAlign.center))
                      : visible.isEmpty
                          ? Center(child: Text('No students in this semester.', style: TextStyle(color: muted)))
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (_, i) {
                                final s = visible[i];
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: _selected.contains(s.id),
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(() => v == true ? _selected.add(s.id) : _selected.remove(s.id)),
                                  title: Text(s.isCr ? '${s.name}  · CR' : s.name),
                                  subtitle: Text([s.roll, if ((s.session ?? '').isNotEmpty) s.session!].join(' · ')),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: count == 0 || _saving || _loading ? null : _promote,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Promote $count students'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
