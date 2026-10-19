import 'package:flutter/foundation.dart';
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

class AttendanceController extends ChangeNotifier {
  final GetAttendanceSummaryUseCase getAttendanceSummaryUseCase;
  final VerifyAttendanceCodeUseCase verifyAttendanceCodeUseCase;
  final StartAttendanceSessionUseCase? startAttendanceSessionUseCase;
  final DeactivateAttendanceSessionUseCase? deactivateAttendanceSessionUseCase;
  final GetActiveAttendanceSessionUseCase? getActiveAttendanceSessionUseCase;
  final GetSessionRosterUseCase? getSessionRosterUseCase;
  final UpdateAttendanceRosterUseCase? updateAttendanceRosterUseCase;

  AttendanceState _state = AttendanceInitial();
  bool _isSubmittingCode = false;

  // Teacher Attendance Terminal State
  AttendanceSession? _activeSession;
  SessionRoster? _sessionRoster;
  List<AttendanceRosterItem> _editableRoster = [];
  bool _isStartingSession = false;
  bool _isDeactivatingSession = false;
  bool _isLoadingRoster = false;
  bool _isSavingRoster = false;
  String? _teacherErrorMessage;

  AttendanceController({
    required this.getAttendanceSummaryUseCase,
    required this.verifyAttendanceCodeUseCase,
    this.startAttendanceSessionUseCase,
    this.deactivateAttendanceSessionUseCase,
    this.getActiveAttendanceSessionUseCase,
    this.getSessionRosterUseCase,
    this.updateAttendanceRosterUseCase,
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

  int get presentCount => _editableRoster.where((r) => r.status == 'PRESENT').length;
  int get absentCount => _editableRoster.where((r) => r.status != 'PRESENT').length;

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

  Future<bool> submitVerificationCode(String code, {String? courseId}) async {
    _isSubmittingCode = true;
    notifyListeners();

    try {
      await verifyAttendanceCodeUseCase.execute(code, courseId: courseId);
      // Refresh summary automatically after marking present
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

  // Teacher terminal actions
  Future<void> loadActiveSession(String courseId) async {
    if (getActiveAttendanceSessionUseCase == null) return;
    try {
      _teacherErrorMessage = null;
      final session = await getActiveAttendanceSessionUseCase!.execute(courseId: courseId);
      _activeSession = session;
      if (session != null) {
        await loadSessionRoster(session.id);
      }
      notifyListeners();
    } catch (e) {
      _teacherErrorMessage = e is Failure ? e.message : e.toString();
      notifyListeners();
    }
  }

  Future<AttendanceSession> startSession({required String courseId, int? durationMinutes}) async {
    if (startAttendanceSessionUseCase == null) {
      throw const ServerFailure(message: 'Start attendance usecase not configured');
    }

    _isStartingSession = true;
    _teacherErrorMessage = null;
    notifyListeners();

    try {
      final session = await startAttendanceSessionUseCase!.execute(
        courseId: courseId,
        durationMinutes: durationMinutes,
      );
      _activeSession = session;
      _isStartingSession = false;
      await loadSessionRoster(session.id);
      notifyListeners();
      return session;
    } catch (e) {
      _isStartingSession = false;
      _teacherErrorMessage = e is Failure ? e.message : e.toString();
      notifyListeners();
      rethrow;
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

  Future<void> loadSessionRoster(String sessionId) async {
    if (getSessionRosterUseCase == null) return;

    _isLoadingRoster = true;
    _teacherErrorMessage = null;
    notifyListeners();

    try {
      final rosterData = await getSessionRosterUseCase!.execute(sessionId: sessionId);
      _sessionRoster = rosterData;
      _editableRoster = List.from(rosterData.roster);
      _isLoadingRoster = false;
      notifyListeners();
    } catch (e) {
      _isLoadingRoster = false;
      _teacherErrorMessage = e is Failure ? e.message : e.toString();
      notifyListeners();
    }
  }

  void toggleStudentStatus(String studentId) {
    final index = _editableRoster.indexWhere((r) => r.studentId == studentId);
    if (index != -1) {
      final current = _editableRoster[index];
      final newStatus = current.status == 'PRESENT' ? 'ABSENT' : 'PRESENT';
      _editableRoster[index] = current.copyWith(
        status: newStatus,
        isManualOverride: true,
      );
      notifyListeners();
    }
  }

  void markAll(String status) {
    _editableRoster = _editableRoster.map((item) {
      return item.copyWith(
        status: status,
        isManualOverride: true,
      );
    }).toList();
    notifyListeners();
  }

  Future<void> saveRoster() async {
    final sessionId = _activeSession?.id ?? _sessionRoster?.sessionId;
    if (updateAttendanceRosterUseCase == null || sessionId == null) return;

    _isSavingRoster = true;
    _teacherErrorMessage = null;
    notifyListeners();

    try {
      await updateAttendanceRosterUseCase!.execute(
        sessionId: sessionId,
        updates: _editableRoster,
      );
      _isSavingRoster = false;
      await loadSessionRoster(sessionId);
      notifyListeners();
    } catch (e) {
      _isSavingRoster = false;
      _teacherErrorMessage = e is Failure ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
