import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/curriculum/data/repositories/exam_support_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/services/exam_rules.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/controllers/schedule_controller.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/exam_form_dialog.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/exam_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCurriculumRepository extends Mock implements CurriculumRepository {}

class MockAuthController extends Mock implements AuthController {}

class FakeSupport implements ExamSupportRepository {
  final List<Exam> exams;
  final List<ScheduleSlot> classes;
  final List<(String, String)> notified = [];
  FakeSupport({this.exams = const [], this.classes = const []});
  @override
  Future<List<Exam>> examsOn(String dateKey) async => exams.where((e) => e.examDate == dateKey).toList();
  @override
  Future<List<ScheduleSlot>> classesOn(DateTime date) async => classes;
  @override
  Future<List<String>> knownRooms() async => ['Room 401', 'Room 402', 'Hardware Lab 2'];
  @override
  Future<void> cancel(Exam exam, {String? reason}) async {}
  @override
  Future<void> notifySemester(Exam exam, {required String title, required String body, required User sender}) async =>
      notified.add((title, body));
}

const cr = User(id: 'cr', email: 'c@x.bd', fullName: 'CR', role: UserRole.cr, year: 3, semester: 1);
const teacher = User(id: 't1', email: 't@x.bd', fullName: 'T', role: UserRole.teacher, assignedCourseIds: ['CSE-3101']);
const chairman = User(id: 'ch', email: 'h@x.bd', fullName: 'H', role: UserRole.chairman);
const student = User(id: 's', email: 's@x.bd', fullName: 'S', role: UserRole.student, year: 3, semester: 1);

Exam exam(String id,
        {String type = 'MID_TERM', String date = '2026-12-10', String start = '10:00 AM', String end = '12:00 PM',
        String room = 'Room 401', int year = 3, int sem = 1, String courseId = 'CSE-3101', String? invigilatorId,
        String status = 'SCHEDULED'}) =>
    Exam(
      id: id, courseId: courseId, courseCode: courseId, courseTitle: 'Operating Systems', title: 'Mid-Term Examination',
      examDate: date, startTime: start, endTime: end, room: room, year: year, semester: sem, type: type,
      invigilatorId: invigilatorId, status: status,
    );

ScheduleSlot cls(String id, {int year = 2, String room = 'Room 401', String teacherId = 't9'}) => ScheduleSlot(
      id: id, courseId: 'CSE-2101', courseCode: 'CSE-2101', courseTitle: 'Data Structures', teacherId: teacherId,
      teacherName: 'X', dayOfWeek: 'THURSDAY', startTime: '11:00 AM', endTime: '12:30 PM', room: room,
      targetYear: year, targetSemester: 1,
    );

void main() {
  group('Who may schedule what', () {
    test('CR: own semester, every type except Final', () {
      expect(ExamPermissions.typesFor(cr), isNot(contains('FINAL')));
      expect(ExamPermissions.typesFor(cr), contains('MID_TERM'));
      expect(ExamPermissions.canManage(cr, exam('a')), isTrue);
      expect(ExamPermissions.canManage(cr, exam('a', type: 'FINAL')), isFalse);
      expect(ExamPermissions.canManage(cr, exam('a', year: 2)), isFalse);
    });

    test('Teacher: own courses (including Final); Chairman: any; student: none', () {
      expect(ExamPermissions.canManage(teacher, exam('a', type: 'FINAL')), isTrue);
      expect(ExamPermissions.canManage(teacher, exam('a', courseId: 'CSE-1101')), isFalse);
      expect(ExamPermissions.canManage(chairman, exam('a', courseId: 'CSE-1101')), isTrue);
      expect(ExamPermissions.canManage(student, exam('a')), isFalse);
      expect(ExamPermissions.canDelete(cr), isFalse);
      expect(ExamPermissions.canDelete(chairman), isTrue);
    });
  });

  group('Exam clash check', () {
    test('room taken by another exam, and the semester already sitting an exam', () {
      final clashes = ExamClashes.find(
        exam: exam('new', start: '11:00 AM', end: '01:00 PM'),
        examsThatDay: [exam('old', courseId: 'CSE-3102')],
        classesThatDay: const [],
      );
      expect(clashes.map((c) => c.kind), containsAll(['ROOM', 'BATCH']));
    });

    test('room taken by another semester\'s class; own semester\'s class is fine', () {
      final other = ExamClashes.find(exam: exam('new'), examsThatDay: const [], classesThatDay: [cls('c')]);
      expect(other.single.kind, 'ROOM');
      final own = ExamClashes.find(exam: exam('new'), examsThatDay: const [], classesThatDay: [cls('c', year: 3)]);
      expect(own, isEmpty);
    });

    test('invigilator teaching another class; cancelled exams and itself are ignored', () {
      final busy = ExamClashes.find(
        exam: exam('new', room: 'Room 999', invigilatorId: 't9'),
        examsThatDay: const [],
        classesThatDay: [cls('c', room: 'Room 501')],
      );
      expect(busy.single.kind, 'TEACHER');
      final ignored = ExamClashes.find(
        exam: exam('same'),
        examsThatDay: [exam('same'), exam('x', status: 'CANCELLED')],
        classesThatDay: const [],
      );
      expect(ignored, isEmpty);
    });

    test('a class shows "exam in this slot" for its own semester', () {
      final slot = cls('c', year: 3);
      expect(ExamClashes.examsDuring(slot, '2026-12-10', [exam('e')]), hasLength(1));
      expect(ExamClashes.examsDuring(slot, '2026-12-11', [exam('e')]), isEmpty);
      expect(ExamClashes.examsDuring(slot, '2026-12-10', [exam('e', status: 'CANCELLED')]), isEmpty);
    });
  });

  test('friendly dates', () {
    final now = DateTime(2026, 11, 26, 9);
    expect(ExamDates.relative('2026-11-26', now), 'Today');
    expect(ExamDates.relative('2026-11-27', now), 'Tomorrow');
    expect(ExamDates.relative('2026-11-29', now), 'in 3 days');
  });

  testWidgets('exam card: cancelled is struck through with the reason; postponed shows where from', (tester) async {
    final cancelled = exam('a', status: 'CANCELLED').copyWith(statusNote: 'Strike');
    final moved = exam('b').copyWith(previousDate: '2026-12-08', previousStartTime: '10:00 AM');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Column(children: [ExamTile(exam: cancelled), ExamTile(exam: moved)])),
    ));
    expect(find.text('Cancelled: Strike'), findsOneWidget);
    expect(find.textContaining('Postponed from'), findsOneWidget);
  });

  group('Exam form', () {
    late MockCurriculumRepository repo;
    late MockAuthController auth;
    late FakeSupport support;

    const os = Course(id: 'CSE-3101', code: 'CSE-3101', title: 'Operating Systems', credit: 3, year: 3, semester: 1,
        courseType: 'THEORY', teacherId: 't1');

    setUp(() {
      repo = MockCurriculumRepository();
      auth = MockAuthController();
      when(() => auth.currentUser).thenReturn(cr);
      when(() => repo.getAllCourses(year: any(named: 'year'), semester: any(named: 'semester')))
          .thenAnswer((_) async => [os]);
      if (sl.isRegistered<CurriculumRepository>()) sl.unregister<CurriculumRepository>();
      if (sl.isRegistered<AuthController>()) sl.unregister<AuthController>();
      if (sl.isRegistered<ExamsController>()) sl.unregister<ExamsController>();
      if (sl.isRegistered<ExamSupportRepository>()) sl.unregister<ExamSupportRepository>();
      if (sl.isRegistered<GetAllCoursesUseCase>()) sl.unregister<GetAllCoursesUseCase>();
      if (sl.isRegistered<GetExamsUseCase>()) sl.unregister<GetExamsUseCase>();
      sl.registerLazySingleton<CurriculumRepository>(() => repo);
      sl.registerLazySingleton<AuthController>(() => auth);
      sl.registerLazySingleton<GetAllCoursesUseCase>(() => GetAllCoursesUseCase(repo));
      sl.registerLazySingleton<GetExamsUseCase>(() => GetExamsUseCase(repo));
      sl.registerFactory<ExamsController>(() => ExamsController(getExamsUseCase: sl(), getAllCoursesUseCase: sl()));
      support = FakeSupport(exams: [exam('busy', date: '2026-12-10', courseId: 'CSE-3102')]);
      sl.registerLazySingleton<ExamSupportRepository>(() => support);
    });

    tearDown(() {
      if (sl.isRegistered<ExamSupportRepository>()) sl.unregister<ExamSupportRepository>();
    });

    Future<void> open(WidgetTester tester, {Exam? existing}) async {
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ExamFormDialog(userRole: UserRole.cr, defaultYear: 3, defaultSemester: 1, existingExam: existing),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('CR does not get the Final type', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('exam_type_MID_TERM')), findsOneWidget);
      expect(find.byKey(const ValueKey('exam_type_FINAL')), findsNothing);
    });

    testWidgets('a clash with another exam of the semester blocks saving and says why', (tester) async {
      await open(tester, existing: exam('mine', date: '2026-12-10', start: '11:00 AM', end: '01:00 PM', room: 'Room 402'));
      expect(find.byKey(const ValueKey('exam_clashes')), findsOneWidget);
      expect(find.textContaining('already has an exam (CSE-3102)'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('exam_save'))).onPressed, isNull);
    });
  });
}
