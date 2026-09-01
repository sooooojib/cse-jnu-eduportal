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
  ScheduleLoaded({required this.slots, this.selectedDay});
}
class ScheduleError extends ScheduleState {
  final String message;
  ScheduleError(this.message);
}

class ScheduleController extends ChangeNotifier {
  final GetScheduleUseCase getScheduleUseCase;
  ScheduleState _state = ScheduleInitial();
  String? _currentDay;

  ScheduleController({required this.getScheduleUseCase});

  ScheduleState get state => _state;
  String? get currentDay => _currentDay;

  Future<void> fetchSchedule({String? day}) async {
    _currentDay = day;
    _state = ScheduleLoading();
    notifyListeners();

    try {
      final slots = await getScheduleUseCase.execute(day: day);
      _state = ScheduleLoaded(slots: slots, selectedDay: day);
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = ScheduleError(message);
      notifyListeners();
    }
  }
}

abstract class ExamsState {}
class ExamsInitial extends ExamsState {}
class ExamsLoading extends ExamsState {}
class ExamsLoaded extends ExamsState {
  final List<Exam> exams;
  ExamsLoaded(this.exams);
}
class ExamsError extends ExamsState {
  final String message;
  ExamsError(this.message);
}

class ExamsController extends ChangeNotifier {
  final GetExamsUseCase getExamsUseCase;
  ExamsState _state = ExamsInitial();

  ExamsController({required this.getExamsUseCase});

  ExamsState get state => _state;

  Future<void> fetchExams() async {
    _state = ExamsLoading();
    notifyListeners();

    try {
      final exams = await getExamsUseCase.execute();
      _state = ExamsLoaded(exams);
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = ExamsError(message);
      notifyListeners();
    }
  }
}
