import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/services/class_attendance_service.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../../../core/error/failures.dart';

abstract class AttendanceState {}
class AttendanceInitial extends AttendanceState {}
class AttendanceLoading extends AttendanceState {}
class AttendanceLoaded extends AttendanceState {
  final AttendanceSummary summary;
  AttendanceLoaded(this.summary);
}
class AttendanceError extends AttendanceState {
  final String message;
  AttendanceError(this.message);
}

/// Student summary + the teacher's live attendance session.
///
/// With a [service] (the app), the teacher gets: rotating codes, manual
/// (by-hand) sessions, live marks as students enter the code, auto-saved
/// taps, extend, finish (absent for everyone left), recent sessions and
/// course reports. Without it (older tests) the original flows still work.
class AttendanceController extends ChangeNotifier {
  final GetAttendanceSummaryUseCase getAttendanceSummaryUseCase;
  final VerifyAttendanceCodeUseCase verifyAttendanceCodeUseCase;
  final StartAttendanceSessionUseCase? startAttendanceSessionUseCase;
  final DeactivateAttendanceSessionUseCase? deactivateAttendanceSessionUseCase;
  final GetActiveAttendanceSessionUseCase? getActiveAttendanceSessionUseCase;
  final GetSessionRosterUseCase? getSessionRosterUseCase;
  final UpdateAttendanceRosterUseCase? updateAttendanceRosterUseCase;
  final ClassAttendanceService? service;

  /// Delay before taps are saved (several quick taps → one write).
  final Duration autoSaveDelay;

  AttendanceState _state = AttendanceInitial();
  bool _isSubmittingCode = false;

  // Teacher session state
  AttendanceSession? _activeSession;
  SessionRoster? _sessionRoster;
  List<AttendanceRosterItem> _editableRoster = [];
  bool _isStartingSession = false;
  bool _isDeactivatingSession = false;
  bool _isLoadingRoster = false;
  bool _isSavingRoster = false;
  String? _teacherErrorMessage;

  /// Students the teacher changed and not yet saved.
  final Set<String> _touched = {};
  Timer? _autoSaveTimer;
  Timer? _rotateTimer;
  StreamSubscription<List<AttendanceRosterItem>>? _marksSub;
  String _currentCode = '';
  DateTime? _codeIssuedAt;
  bool _lastSaveOk = true;

  AttendanceController({
    required this.getAttendanceSummaryUseCase,
    required this.verifyAttendanceCodeUseCase,
    this.startAttendanceSessionUseCase,
    this.deactivateAttendanceSessionUseCase,
    this.getActiveAttendanceSessionUseCase,
    this.getSessionRosterUseCase,
    this.updateAttendanceRosterUseCase,
    this.service,
    this.autoSaveDelay = const Duration(milliseconds: 700),
  });

  AttendanceState get state => _state;
  bool get isSubmittingCode => _isSubmittingCode;

  AttendanceSession? get activeSession => _activeSession;
  SessionRoster? get sessionRoster => _sessionRoster;
  List<AttendanceRosterItem> get editableRoster => _editableRoster;
  bool get isStartingSession => _isStartingSession;
  bool get isDeactivatingSession => _isDeactivatingSession;
  bool get isLoadingRoster => _isLoadingRoster;
  bool get isSavingRoster => _isSavingRoster;
  String? get teacherErrorMessage => _teacherErrorMessage;

  /// Code currently on the teacher's screen (rotates every 20 s).
  String get currentCode => _currentCode.isNotEmpty ? _currentCode : (_activeSession?.code ?? '');
  DateTime? get codeIssuedAt => _codeIssuedAt;

  /// Unsaved taps waiting for auto-save.
  bool get hasUnsavedChanges => _touched.isNotEmpty;
  bool get lastSaveOk => _lastSaveOk;

  int get presentCount => _editableRoster.where((r) => r.isPresent).length;
  int get lateCount => _editableRoster.where((r) => r.isLate).length;
  int get absentCount => _editableRoster.where((r) => !r.isPresent).length;

  // ─── Student ─────────────────────────────────────────────────────────────

  Future<void> fetchSummary() async {
    _state = AttendanceLoading();
    notifyListeners();

    try {
      final summary = await getAttendanceSummaryUseCase.execute();
      _state = AttendanceLoaded(summary);
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = AttendanceError(message);
      notifyListeners();
    }
  }

  /// Returns true on success. The result message is in [lastVerification].
  AttendanceVerificationResult? lastVerification;

  /// Student: classes of their semester open for attendance right now.
  List<AttendanceSession> _openSessions = const [];
  List<AttendanceSession> get openSessions => _openSessions;
  bool _loadingOpen = false;
  bool get isLoadingOpenSessions => _loadingOpen;

  Future<void> loadOpenSessions() async {
    if (service == null) return;
    _loadingOpen = true;
    notifyListeners();
    try {
      _openSessions = await service!.openSessionsForMe();
    } catch (_) {
      _openSessions = const [];
    }
    _loadingOpen = false;
    notifyListeners();
  }

  /// With [sessionId] the code is checked against that one class only.
  Future<bool> submitVerificationCode(String code, {String? courseId, String? sessionId}) async {
    _isSubmittingCode = true;
    notifyListeners();

    try {
      lastVerification = (service != null && sessionId != null)
          ? await service!.markWithCode(code, sessionId: sessionId)
          : await verifyAttendanceCodeUseCase.execute(code, courseId: courseId);
      if (service != null) loadOpenSessions();
      await fetchSummary();
      _isSubmittingCode = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmittingCode = false;
      notifyListeners();
      rethrow;
    }
  }

  // ─── Teacher: session ───────────────────────────────────────────────────

  Future<void> loadActiveSession(String courseId) async {
    if (getActiveAttendanceSessionUseCase == null) return;
    try {
      _teacherErrorMessage = null;
      final session = await getActiveAttendanceSessionUseCase!.execute(courseId: courseId);
      _activeSession = session;
      if (session != null) {
        await loadSessionRoster(session.id);
        _goLive(session, issueCodeNow: true);
      } else {
        _stopLive();
        _editableRoster = [];
        _sessionRoster = null;
      }
      notifyListeners();
    } catch (e) {
      _teacherErrorMessage = e is Failure ? e.message : e.toString();
      notifyListeners();
    }
  }

  Future<AttendanceSession> startSession({
    required String courseId,
    int? durationMinutes,
    String mode = 'CODE',
    int lateAfterMinutes = 10,
    String? slotId,
  }) async {
    if (service == null && startAttendanceSessionUseCase == null) {
      throw const ServerFailure(message: 'Start attendance usecase not configured');
    }

    _isStartingSession = true;
    _teacherErrorMessage = null;
    notifyListeners();

    try {
      final session = service != null
          ? await service!.startClassSession(
              courseId: courseId,
              mode: mode,
              durationMinutes: durationMinutes ?? 15,
              lateAfterMinutes: lateAfterMinutes,
              slotId: slotId,
            )
          : await startAttendanceSessionUseCase!.execute(courseId: courseId, durationMinutes: durationMinutes);
      _activeSession = session;
      _currentCode = session.code;
      _codeIssuedAt = DateTime.now();
      _isStartingSession = false;
      await loadSessionRoster(session.id);
      _goLive(session);
      notifyListeners();
      return session;
    } catch (e) {
      _isStartingSession = false;
      _teacherErrorMessage = e is Failure ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Rotating code + live marks (only with the service).
  void _goLive(AttendanceSession session, {bool issueCodeNow = false}) {
    _stopLive();
    final svc = service;
    if (svc == null) return;
    if (session.isActive && !session.isManualMode) {
      if (issueCodeNow) _rotate(session.id);
      _rotateTimer = Timer.periodic(ClassAttendanceService.rotateEvery, (_) => _rotate(session.id));
    }
    try {
      _marksSub = svc.watchMarks(session.id).listen(_mergeMarks, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _rotate(String sessionId) async {
    try {
      final code = await service!.rotateCode(sessionId);
      if (_activeSession?.id != sessionId) return;
      _currentCode = code;
      _codeIssuedAt = DateTime.now();
      notifyListeners();
    } catch (_) {
      // Keep the last code; the next tick tries again.
    }
  }

  void _stopLive() {
    _rotateTimer?.cancel();
    _rotateTimer = null;
    _marksSub?.cancel();
    _marksSub = null;
  }

  /// Students marking themselves appear live, without undoing teacher taps
  /// that are not saved yet.
  void _mergeMarks(List<AttendanceRosterItem> marks) {
    final byId = {for (final m in marks) m.studentId: m};
    var changed = false;
    _editableRoster = _editableRoster.map((r) {
      final m = byId[r.studentId];
      if (m == null || _touched.contains(r.studentId)) return r;
      if (m.status == r.status && m.markedBy == r.markedBy) return r;
      changed = true;
      return r.copyWith(status: m.status, markedBy: m.markedBy, isManualOverride: m.markedBy == 'TEACHER');
    }).toList();
    // Someone who marked but is not on the list yet (e.g. enrolled later).
    for (final m in marks) {
      if (_editableRoster.every((r) => r.studentId != m.studentId)) {
        _editableRoster = [..._editableRoster, m];
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Stops rotating the code (e.g. when the screen closes).
  void pauseLive() => _stopLive();

  Future<void> extendSession({int minutes = 5}) async {
    final s = _activeSession;
    if (s == null || service == null) return;
    try {
      final next = await service!.extendSession(s.id, minutes: minutes);
      _activeSession = s.copyWith(expiresAt: next);
      notifyListeners();
    } catch (e) {
      _teacherErrorMessage = e is Failure ? e.message : e.toString();
      notifyListeners();
    }
  }

  Future<void> deactivateSession(String sessionId) async {
    if (deactivateAttendanceSessionUseCase == null) return;

    _isDeactivatingSession = true;
    _teacherErrorMessage = null;
    notifyListeners();

    try {
      await deactivateAttendanceSessionUseCase!.execute(sessionId: sessionId);
      if (_activeSession?.id == sessionId) {
        _stopLive();
        _activeSession = null;
        _sessionRoster = null;
        _editableRoster = [];
      }
      _isDeactivatingSession = false;
      notifyListeners();
    } catch (e) {
      _isDeactivatingSession = false;
      _teacherErrorMessage = e is Failure ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Close & save: saves pending taps, records everyone left as absent, and
  /// closes the session.
  Future<void> finishSession() async {
    final s = _activeSession;
    if (s == null) return;
    if (service == null) return deactivateSession(s.id);

    _isDeactivatingSession = true;
    _teacherErrorMessage = null;
    notifyListeners();
    try {
      await saveRoster();
      await service!.finishSession(sessionId: s.id, roster: _editableRoster);
      _stopLive();
      _activeSession = null;
      _sessionRoster = null;
      _editableRoster = [];
      _isDeactivatingSession = false;
      notifyListeners();
    } catch (e) {
      _isDeactivatingSession = false;
      _teacherErrorMessage = e is Failure ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ─── Teacher: roster ────────────────────────────────────────────────────

  Future<void> loadSessionRoster(String sessionId) async {
    if (getSessionRosterUseCase == null) return;

    _isLoadingRoster = true;
    _teacherErrorMessage = null;
    notifyListeners();

    try {
      final rosterData = await getSessionRosterUseCase!.execute(sessionId: sessionId);
      _sessionRoster = rosterData;
      _editableRoster = List.from(rosterData.roster);
      _touched.clear();
      _isLoadingRoster = false;
      notifyListeners();
    } catch (e) {
      _isLoadingRoster = false;
      _teacherErrorMessage = e is Failure ? e.message : e.toString();
      notifyListeners();
    }
  }

  /// Opens a past session (last 7 days) to correct it.
  Future<void> openPastSession(AttendanceSession session) async {
    _stopLive();
    _activeSession = null;
    await loadSessionRoster(session.id);
    _goLive(session);
  }

  void _touch(String studentId) {
    _touched.add(studentId);
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    if (service == null) return; // older flow: explicit Save
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(autoSaveDelay, () => saveRoster().catchError((_) {}));
  }

  void toggleStudentStatus(String studentId) {
    final index = _editableRoster.indexWhere((r) => r.studentId == studentId);
    if (index != -1) {
      final current = _editableRoster[index];
      final newStatus = current.isPresent ? 'ABSENT' : 'PRESENT';
      _editableRoster[index] = current.copyWith(status: newStatus, isManualOverride: true, markedBy: 'TEACHER');
      _touch(studentId);
      notifyListeners();
    }
  }

  void setStudentStatus(String studentId, String status) {
    final index = _editableRoster.indexWhere((r) => r.studentId == studentId);
    if (index != -1) {
      final current = _editableRoster[index];
      if (current.status == status) return;
      _editableRoster[index] = current.copyWith(status: status, isManualOverride: true, markedBy: 'TEACHER');
      _touch(studentId);
      notifyListeners();
    }
  }

  void markAll(String status) {
    _editableRoster = _editableRoster.map((item) {
      if (item.status == status) return item;
      _touched.add(item.studentId);
      return item.copyWith(status: status, isManualOverride: true, markedBy: 'TEACHER');
    }).toList();
    _scheduleAutoSave();
    notifyListeners();
  }

  /// Saves only the students the teacher changed (never overwrites a
  /// student's own mark that arrived meanwhile).
  Future<void> saveRoster() async {
    _autoSaveTimer?.cancel();
    final sessionId = _activeSession?.id ?? _sessionRoster?.sessionId;
    if (sessionId == null) return;
    if (service == null && updateAttendanceRosterUseCase == null) return;
    final pending = _editableRoster.where((r) => _touched.contains(r.studentId)).toList();
    if (pending.isEmpty && service != null) return;

    _isSavingRoster = true;
    _teacherErrorMessage = null;
    notifyListeners();

    try {
      if (service != null) {
        await service!.saveMarks(sessionId: sessionId, items: pending);
      } else {
        await updateAttendanceRosterUseCase!.execute(sessionId: sessionId, updates: pending);
      }
      _touched.removeAll(pending.map((p) => p.studentId));
      _lastSaveOk = true;
      _isSavingRoster = false;
      if (service == null) await loadSessionRoster(sessionId);
      notifyListeners();
    } catch (e) {
      _isSavingRoster = false;
      _lastSaveOk = false;
      _teacherErrorMessage = e is Failure ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ─── Teacher: history & reports ─────────────────────────────────────────

  Future<List<AttendanceSession>> recentSessions() async => service?.recentSessions() ?? const [];

  Future<CourseAttendanceReport?> courseReport(String courseId) async => service?.courseReport(courseId);

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _stopLive();
    super.dispose();
  }
}
