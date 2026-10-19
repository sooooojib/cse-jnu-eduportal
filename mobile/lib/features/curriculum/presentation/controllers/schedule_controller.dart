import 'package:flutter/foundation.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../../domain/repositories/curriculum_repository.dart';
import '../../../../core/error/failures.dart';

abstract class ScheduleState {}

class ScheduleInitial extends ScheduleState {}

class ScheduleLoading extends ScheduleState {}

class ScheduleLoaded extends ScheduleState {
  final List<ScheduleSlot> slots;
  final String? selectedDay;
  final bool isCalendarView;
  final int? selectedYear;
  final int? selectedSemester;
  final String? selectedTeacherId;

  ScheduleLoaded({
    required this.slots,
    this.selectedDay,
    this.isCalendarView = false,
    this.selectedYear,
    this.selectedSemester,
    this.selectedTeacherId,
  });

  ScheduleLoaded copyWith({
    List<ScheduleSlot>? slots,
    String? selectedDay,
    bool? isCalendarView,
    int? selectedYear,
    int? selectedSemester,
    String? selectedTeacherId,
  }) {
    return ScheduleLoaded(
      slots: slots ?? this.slots,
      selectedDay: selectedDay ?? this.selectedDay,
      isCalendarView: isCalendarView ?? this.isCalendarView,
      selectedYear: selectedYear ?? this.selectedYear,
      selectedSemester: selectedSemester ?? this.selectedSemester,
      selectedTeacherId: selectedTeacherId ?? this.selectedTeacherId,
    );
  }
}

class ScheduleError extends ScheduleState {
  final String message;
  ScheduleError(this.message);
}

class ScheduleController extends ChangeNotifier {
  final GetScheduleUseCase getScheduleUseCase;
  final CreateScheduleSlotUseCase? createScheduleSlotUseCase;
  final UpdateScheduleSlotUseCase? updateScheduleSlotUseCase;
  final DeleteScheduleSlotUseCase? deleteScheduleSlotUseCase;
  final GetTeacherAvailabilityUseCase? getTeacherAvailabilityUseCase;
  final GetWhatsAppBroadcastUseCase? getWhatsAppBroadcastUseCase;
  final GetAllCoursesUseCase? getAllCoursesUseCase;
  final GetAllTeachersUseCase? getAllTeachersUseCase;

  ScheduleState _state = ScheduleInitial();
  String? _currentDay;
  int? _currentYear;
  int? _currentSemester;
  String? _currentTeacherId;
  bool _isCalendarView = false;
  bool _isSubmitting = false;
  String? _actionError;
  String? _actionSuccess;

  ScheduleController({
    required this.getScheduleUseCase,
    this.createScheduleSlotUseCase,
    this.updateScheduleSlotUseCase,
    this.deleteScheduleSlotUseCase,
    this.getTeacherAvailabilityUseCase,
    this.getWhatsAppBroadcastUseCase,
    this.getAllCoursesUseCase,
    this.getAllTeachersUseCase,
  });

  ScheduleState get state => _state;
  String? get currentDay => _currentDay;
  int? get currentYear => _currentYear;
  int? get currentSemester => _currentSemester;
  String? get currentTeacherId => _currentTeacherId;
  bool get isCalendarView => _isCalendarView;
  bool get isSubmitting => _isSubmitting;
  String? get actionError => _actionError;
  String? get actionSuccess => _actionSuccess;

  void toggleViewMode() {
    _isCalendarView = !_isCalendarView;
    if (_state is ScheduleLoaded) {
      _state = (_state as ScheduleLoaded).copyWith(isCalendarView: _isCalendarView);
    }
    notifyListeners();
  }

  void clearActionFeedback() {
    _actionError = null;
    _actionSuccess = null;
    notifyListeners();
  }

  Future<void> fetchSchedule({
    String? day,
    int? year,
    int? semester,
    String? teacherId,
  }) async {
    _currentDay = day;
    _currentYear = year ?? _currentYear;
    _currentSemester = semester ?? _currentSemester;
    _currentTeacherId = teacherId ?? _currentTeacherId;
    _state = ScheduleLoading();
    notifyListeners();

    try {
      final slots = await getScheduleUseCase.execute(
        day: day == 'ALL' ? null : day,
        year: _currentYear,
        semester: _currentSemester,
        teacherId: _currentTeacherId,
      );
      _state = ScheduleLoaded(
        slots: slots,
        selectedDay: day,
        isCalendarView: _isCalendarView,
        selectedYear: _currentYear,
        selectedSemester: _currentSemester,
        selectedTeacherId: _currentTeacherId,
      );
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = ScheduleError(message);
      notifyListeners();
    }
  }

  Future<bool> createSlot(ScheduleSlot slot) async {
    if (createScheduleSlotUseCase == null) {
      _actionError = 'Slot creation service unavailable.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _actionError = null;
    _actionSuccess = null;
    notifyListeners();

    try {
      final created = await createScheduleSlotUseCase!.execute(slot);
      _isSubmitting = false;
      _actionSuccess = 'Class scheduled successfully: ${created.courseCode} (${created.startTime} - ${created.endTime})';
      await fetchSchedule(
        day: _currentDay,
        year: _currentYear,
        semester: _currentSemester,
        teacherId: _currentTeacherId,
      );
      return true;
    } catch (e) {
      _isSubmitting = false;
      _actionError = e is Failure ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSlot(ScheduleSlot slot) async {
    if (updateScheduleSlotUseCase == null) {
      _actionError = 'Slot update service unavailable.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _actionError = null;
    _actionSuccess = null;
    notifyListeners();

    try {
      final updated = await updateScheduleSlotUseCase!.execute(slot);
      _isSubmitting = false;
      _actionSuccess = 'Class updated successfully: ${updated.courseCode}';
      await fetchSchedule(
        day: _currentDay,
        year: _currentYear,
        semester: _currentSemester,
        teacherId: _currentTeacherId,
      );
      return true;
    } catch (e) {
      _isSubmitting = false;
      _actionError = e is Failure ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSlot(String slotId) async {
    if (deleteScheduleSlotUseCase == null) {
      _actionError = 'Slot deletion service unavailable.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _actionError = null;
    _actionSuccess = null;
    notifyListeners();

    try {
      await deleteScheduleSlotUseCase!.execute(slotId);
      _isSubmitting = false;
      _actionSuccess = 'Class schedule slot removed successfully.';
      await fetchSchedule(
        day: _currentDay,
        year: _currentYear,
        semester: _currentSemester,
        teacherId: _currentTeacherId,
      );
      return true;
    } catch (e) {
      _isSubmitting = false;
      _actionError = e is Failure ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<TeacherAvailability?> fetchTeacherAvailability({
    required String teacherId,
    required String dayOfWeek,
    String? date,
  }) async {
    if (getTeacherAvailabilityUseCase == null) return null;
    try {
      return await getTeacherAvailabilityUseCase!.execute(
        teacherId: teacherId,
        dayOfWeek: dayOfWeek,
        date: date,
      );
    } catch (e) {
      _actionError = e is Failure ? e.message : e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<WhatsAppBroadcastData?> fetchWhatsAppBroadcast({int? year, int? semester}) async {
    if (getWhatsAppBroadcastUseCase == null) return null;
    try {
      return await getWhatsAppBroadcastUseCase!.execute(year: year, semester: semester);
    } catch (e) {
      _actionError = e is Failure ? e.message : e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<List<Course>> fetchAvailableCourses({int? year, int? semester}) async {
    if (getAllCoursesUseCase == null) return const [];
    try {
      return await getAllCoursesUseCase!.execute(year: year, semester: semester);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, String>>> fetchAvailableTeachers() async {
    if (getAllTeachersUseCase == null) return const [];
    try {
      return await getAllTeachersUseCase!.execute();
    } catch (_) {
      return const [];
    }
  }
}

abstract class ExamsState {}

class ExamsInitial extends ExamsState {}

class ExamsLoading extends ExamsState {}

class ExamsLoaded extends ExamsState {
  final List<Exam> exams;
  final List<Exam> upcomingExams;
  final List<Exam> pastExams;
  final String? filterCourseId;
  final String? filterType;

  ExamsLoaded({
    required this.exams,
    List<Exam>? upcomingExams,
    List<Exam>? pastExams,
    this.filterCourseId,
    this.filterType,
  })  : upcomingExams = upcomingExams ?? _sortUpcoming(exams.where((e) => !e.isPast).toList()),
        pastExams = pastExams ?? _sortPast(exams.where((e) => e.isPast).toList());

  static List<Exam> _sortUpcoming(List<Exam> list) {
    list.sort((a, b) {
      final dateCmp = a.examDate.compareTo(b.examDate);
      if (dateCmp != 0) return dateCmp;
      return a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  static List<Exam> _sortPast(List<Exam> list) {
    list.sort((a, b) {
      final dateCmp = b.examDate.compareTo(a.examDate);
      if (dateCmp != 0) return dateCmp;
      return b.startTime.compareTo(a.startTime);
    });
    return list;
  }

  List<Exam> get filteredUpcoming {
    return upcomingExams.where((e) {
      if (filterCourseId != null && filterCourseId!.isNotEmpty && e.courseId != filterCourseId) {
        return false;
      }
      if (filterType != null && filterType!.isNotEmpty && e.type.toUpperCase() != filterType!.toUpperCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Exam> get filteredPast {
    return pastExams.where((e) {
      if (filterCourseId != null && filterCourseId!.isNotEmpty && e.courseId != filterCourseId) {
        return false;
      }
      if (filterType != null && filterType!.isNotEmpty && e.type.toUpperCase() != filterType!.toUpperCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  ExamsLoaded copyWith({
    List<Exam>? exams,
    List<Exam>? upcomingExams,
    List<Exam>? pastExams,
    String? filterCourseId,
    bool clearCourseFilter = false,
    String? filterType,
    bool clearTypeFilter = false,
  }) {
    return ExamsLoaded(
      exams: exams ?? this.exams,
      upcomingExams: upcomingExams ?? this.upcomingExams,
      pastExams: pastExams ?? this.pastExams,
      filterCourseId: clearCourseFilter ? null : (filterCourseId ?? this.filterCourseId),
      filterType: clearTypeFilter ? null : (filterType ?? this.filterType),
    );
  }
}

class ExamsError extends ExamsState {
  final String message;
  ExamsError(this.message);
}

class ExamsController extends ChangeNotifier {
  final GetExamsUseCase getExamsUseCase;
  final CreateExamUseCase? createExamUseCase;
  final UpdateExamUseCase? updateExamUseCase;
  final DeleteExamUseCase? deleteExamUseCase;
  final GetAllCoursesUseCase? getAllCoursesUseCase;

  ExamsState _state = ExamsInitial();
  bool _isSubmitting = false;
  String? _actionError;
  String? _actionSuccess;
  int? _currentYear;
  int? _currentSemester;
  String? _currentCourseId;
  String? _filterType;

  ExamsController({
    required this.getExamsUseCase,
    this.createExamUseCase,
    this.updateExamUseCase,
    this.deleteExamUseCase,
    this.getAllCoursesUseCase,
  });

  ExamsState get state => _state;
  bool get isSubmitting => _isSubmitting;
  String? get actionError => _actionError;
  String? get actionSuccess => _actionSuccess;
  int? get currentYear => _currentYear;
  int? get currentSemester => _currentSemester;
  String? get currentCourseId => _currentCourseId;
  String? get filterType => _filterType;

  void clearFeedback() {
    _actionError = null;
    _actionSuccess = null;
    notifyListeners();
  }

  void setFilter({String? courseId, String? type}) {
    _currentCourseId = courseId;
    _filterType = type;
    if (_state is ExamsLoaded) {
      _state = (_state as ExamsLoaded).copyWith(
        filterCourseId: courseId,
        clearCourseFilter: courseId == null,
        filterType: type,
        clearTypeFilter: type == null,
      );
      notifyListeners();
    }
  }

  void clearFilter() {
    _currentCourseId = null;
    _filterType = null;
    if (_state is ExamsLoaded) {
      _state = (_state as ExamsLoaded).copyWith(
        clearCourseFilter: true,
        clearTypeFilter: true,
      );
      notifyListeners();
    }
  }

  Future<void> fetchExams({int? year, int? semester, String? courseId}) async {
    _currentYear = year ?? _currentYear;
    _currentSemester = semester ?? _currentSemester;
    _currentCourseId = courseId ?? _currentCourseId;

    _state = ExamsLoading();
    notifyListeners();

    try {
      final exams = await getExamsUseCase.execute(
        year: _currentYear,
        semester: _currentSemester,
        courseId: _currentCourseId,
      );

      final upcoming = exams.where((e) => !e.isPast).toList();
      upcoming.sort((a, b) {
        final dateCmp = a.examDate.compareTo(b.examDate);
        if (dateCmp != 0) return dateCmp;
        return a.startTime.compareTo(b.startTime);
      });

      final past = exams.where((e) => e.isPast).toList();
      past.sort((a, b) {
        final dateCmp = b.examDate.compareTo(a.examDate);
        if (dateCmp != 0) return dateCmp;
        return b.startTime.compareTo(a.startTime);
      });

      _state = ExamsLoaded(
        exams: exams,
        upcomingExams: upcoming,
        pastExams: past,
        filterCourseId: _currentCourseId,
        filterType: _filterType,
      );
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = ExamsError(message);
      notifyListeners();
    }
  }

  Future<bool> createExam(Exam exam) async {
    if (createExamUseCase == null) {
      _actionError = 'Exam creation service is currently unavailable.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _actionError = null;
    _actionSuccess = null;
    notifyListeners();

    try {
      final created = await createExamUseCase!.execute(exam);
      _isSubmitting = false;
      _actionSuccess = 'Exam scheduled: ${created.courseCode} on ${created.examDate}';
      await fetchExams(year: _currentYear, semester: _currentSemester, courseId: _currentCourseId);
      return true;
    } catch (e) {
      _isSubmitting = false;
      _actionError = e is Failure ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateExam(Exam exam) async {
    if (updateExamUseCase == null) {
      _actionError = 'Exam update service is currently unavailable.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _actionError = null;
    _actionSuccess = null;
    notifyListeners();

    try {
      await updateExamUseCase!.execute(exam);
      _isSubmitting = false;
      _actionSuccess = 'Exam updated successfully.';
      await fetchExams(year: _currentYear, semester: _currentSemester, courseId: _currentCourseId);
      return true;
    } catch (e) {
      _isSubmitting = false;
      _actionError = e is Failure ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExam(String examId) async {
    if (deleteExamUseCase == null) {
      _actionError = 'Exam deletion service is currently unavailable.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _actionError = null;
    _actionSuccess = null;
    notifyListeners();

    try {
      await deleteExamUseCase!.execute(examId);
      _isSubmitting = false;
      _actionSuccess = 'Exam schedule removed successfully.';
      await fetchExams(year: _currentYear, semester: _currentSemester, courseId: _currentCourseId);
      return true;
    } catch (e) {
      _isSubmitting = false;
      _actionError = e is Failure ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Course>> fetchAvailableCourses({int? year, int? semester}) async {
    if (getAllCoursesUseCase == null) return const [];
    try {
      return await getAllCoursesUseCase!.execute(year: year, semester: semester);
    } catch (_) {
      return const [];
    }
  }
}
