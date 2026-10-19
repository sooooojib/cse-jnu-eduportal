import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/core/error/failures.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/curriculum/data/models/curriculum_models.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/controllers/schedule_controller.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/exam_details_dialog.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/exam_form_dialog.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/exam_management_view.dart';
import 'package:cse_jnu_eduportal/shared/widgets/dialogs/app_confirmation_dialog.dart';

class MockCurriculumRepository extends Mock implements CurriculumRepository {}
class MockAuthController extends Mock implements AuthController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCurriculumRepository mockRepo;
  late MockAuthController mockAuth;

  final sampleStudent = User(
    id: 'student_1',
    email: 'student@cse.jnu.ac.bd',
    fullName: 'Sadia Rahman',
    role: UserRole.student,
    year: 3,
    semester: 1,
  );

  final sampleCr = User(
    id: 'cr_1',
    email: 'cr@cse.jnu.ac.bd',
    fullName: 'Tanzil Ahmed (CR)',
    role: UserRole.cr,
    year: 3,
    semester: 1,
  );

  final sampleTeacher = User(
    id: 'teacher_1',
    email: 'teacher@cse.jnu.ac.bd',
    fullName: 'Dr. Md. Abu Layek',
    role: UserRole.teacher,
    assignedCourseIds: const ['cse_3101'],
  );

  final sampleAdmin = User(
    id: 'admin_1',
    email: 'admin@cse.jnu.ac.bd',
    fullName: 'Dept Admin',
    role: UserRole.admin,
  );

  final sampleCourse1 = const Course(
    id: 'cse_3101',
    code: 'CSE 3101',
    title: 'Operating Systems',
    credit: 3.0,
    year: 3,
    semester: 1,
    courseType: 'THEORY',
  );

  final sampleCourse2 = const Course(
    id: 'cse_3103',
    code: 'CSE 3103',
    title: 'Database Systems',
    credit: 3.0,
    year: 3,
    semester: 1,
    courseType: 'THEORY',
  );

  // Future exam
  final upcomingExam = Exam(
    id: 'exam_up_1',
    courseId: 'cse_3101',
    courseCode: 'CSE 3101',
    courseTitle: 'Operating Systems',
    title: 'Mid-Term Examination',
    examDate: '2028-11-20',
    startTime: '10:00 AM',
    endTime: '12:00 PM',
    room: 'Room 401',
    year: 3,
    semester: 1,
    type: 'MID_TERM',
    instructions: 'Calculators are allowed.',
    invigilatorName: 'Dr. Md. Abu Layek',
  );

  // Past exam
  final pastExam = Exam(
    id: 'exam_past_1',
    courseId: 'cse_3103',
    courseCode: 'CSE 3103',
    courseTitle: 'Database Systems',
    title: 'Class Test 1',
    examDate: '2024-01-10',
    startTime: '09:00 AM',
    endTime: '10:00 AM',
    room: 'Room 402',
    year: 3,
    semester: 1,
    type: 'CT',
  );

  setUpAll(() {
    registerFallbackValue(upcomingExam);
  });

  setUp(() {
    mockRepo = MockCurriculumRepository();
    mockAuth = MockAuthController();

    when(() => mockAuth.currentUser).thenReturn(sampleCr);

    if (sl.isRegistered<CurriculumRepository>()) sl.unregister<CurriculumRepository>();
    sl.registerLazySingleton<CurriculumRepository>(() => mockRepo);

    if (sl.isRegistered<AuthController>()) sl.unregister<AuthController>();
    sl.registerLazySingleton<AuthController>(() => mockAuth);

    if (sl.isRegistered<GetExamsUseCase>()) sl.unregister<GetExamsUseCase>();
    sl.registerLazySingleton<GetExamsUseCase>(() => GetExamsUseCase(mockRepo));

    if (sl.isRegistered<CreateExamUseCase>()) sl.unregister<CreateExamUseCase>();
    sl.registerLazySingleton<CreateExamUseCase>(() => CreateExamUseCase(mockRepo));

    if (sl.isRegistered<UpdateExamUseCase>()) sl.unregister<UpdateExamUseCase>();
    sl.registerLazySingleton<UpdateExamUseCase>(() => UpdateExamUseCase(mockRepo));

    if (sl.isRegistered<DeleteExamUseCase>()) sl.unregister<DeleteExamUseCase>();
    sl.registerLazySingleton<DeleteExamUseCase>(() => DeleteExamUseCase(mockRepo));

    if (sl.isRegistered<GetAllCoursesUseCase>()) sl.unregister<GetAllCoursesUseCase>();
    sl.registerLazySingleton<GetAllCoursesUseCase>(() => GetAllCoursesUseCase(mockRepo));

    if (sl.isRegistered<ExamsController>()) sl.unregister<ExamsController>();
    sl.registerFactory<ExamsController>(() => ExamsController(
      getExamsUseCase: sl(),
      createExamUseCase: sl(),
      updateExamUseCase: sl(),
      deleteExamUseCase: sl(),
      getAllCoursesUseCase: sl(),
    ));
  });

  group('STAGE 22: Exam Entity & Model Tests', () {
    test('1. Exam isPast getter correctly detects future vs past dates', () {
      expect(upcomingExam.isPast, false);
      expect(pastExam.isPast, true);
    });

    test('2. Exam copyWith updates fields cleanly', () {
      final updated = upcomingExam.copyWith(
        title: 'Updated Final Exam',
        room: 'Room 501',
        type: 'FINAL',
      );
      expect(updated.title, 'Updated Final Exam');
      expect(updated.room, 'Room 501');
      expect(updated.type, 'FINAL');
      expect(updated.courseCode, 'CSE 3101');
    });

    test('3. ExamModel converts to/from JSON accurately', () {
      final model = ExamModel(
        id: 'ex_1',
        courseId: 'c1',
        courseCode: 'CSE 1101',
        courseTitle: 'Structured Programming',
        title: 'Quiz 1',
        examDate: '2027-02-15',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        room: 'Lab 1 (Networking)',
        year: 1,
        semester: 1,
        type: 'QUIZ',
        instructions: 'No devices allowed',
        invigilatorName: 'Prof. X',
      );

      final json = model.toJson();
      final reconstituted = ExamModel.fromJson(json);

      expect(reconstituted.id, 'ex_1');
      expect(reconstituted.courseCode, 'CSE 1101');
      expect(reconstituted.type, 'QUIZ');
      expect(reconstituted.instructions, 'No devices allowed');
    });
  });

  group('STAGE 22: ExamsController Tests', () {
    test('4. ExamsController separates upcoming and past exams with sorting', () async {
      when(() => mockRepo.getExams(
        year: any(named: 'year'),
        semester: any(named: 'semester'),
        courseId: any(named: 'courseId'),
      )).thenAnswer((_) async => [upcomingExam, pastExam]);

      final controller = sl<ExamsController>();
      await controller.fetchExams(year: 3, semester: 1);

      expect(controller.state, isA<ExamsLoaded>());
      final loaded = controller.state as ExamsLoaded;
      expect(loaded.upcomingExams.length, 1);
      expect(loaded.upcomingExams.first.id, 'exam_up_1');
      expect(loaded.pastExams.length, 1);
      expect(loaded.pastExams.first.id, 'exam_past_1');
    });

    test('5. ExamsController filters by exam type and course', () async {
      final quizExam = upcomingExam.copyWith(id: 'exam_quiz', type: 'QUIZ');
      when(() => mockRepo.getExams(
        year: any(named: 'year'),
        semester: any(named: 'semester'),
        courseId: any(named: 'courseId'),
      )).thenAnswer((_) async => [upcomingExam, quizExam, pastExam]);

      final controller = sl<ExamsController>();
      await controller.fetchExams();

      controller.setFilter(type: 'QUIZ');
      final loaded = controller.state as ExamsLoaded;
      expect(loaded.filteredUpcoming.length, 1);
      expect(loaded.filteredUpcoming.first.id, 'exam_quiz');

      controller.clearFilter();
      expect((controller.state as ExamsLoaded).filteredUpcoming.length, 2);
    });

    test('6. ExamsController createExam executes and refreshes', () async {
      when(() => mockRepo.createExam(any())).thenAnswer((_) async => upcomingExam);
      when(() => mockRepo.getExams(
        year: any(named: 'year'),
        semester: any(named: 'semester'),
        courseId: any(named: 'courseId'),
      )).thenAnswer((_) async => [upcomingExam]);

      final controller = sl<ExamsController>();
      final success = await controller.createExam(upcomingExam);

      expect(success, true);
      expect(controller.actionSuccess, contains('Exam scheduled'));
      verify(() => mockRepo.createExam(any())).called(1);
    });

    test('7. ExamsController deleteExam executes and handles error', () async {
      when(() => mockRepo.deleteExam('exam_up_1')).thenThrow(ServerFailure(message: 'Permission denied'));

      final controller = sl<ExamsController>();
      final success = await controller.deleteExam('exam_up_1');

      expect(success, false);
      expect(controller.actionError, 'Permission denied');
    });
  });

  group('STAGE 22: Role Authorization & Modification Permission Tests', () {
    testWidgets('8. Regular Student cannot modify or delete exams in ExamDetailsDialog', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(sampleStudent);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ExamDetailsDialog.show(
                  context: context,
                  exam: upcomingExam,
                  userRole: UserRole.student,
                  userYear: 3,
                  userSemester: 1,
                  userId: 'student_1',
                ),
                child: const Text('Open Details'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      // Exam details visible
      expect(find.text('Mid-Term Examination'), findsOneWidget);
      expect(find.textContaining('Operating Systems'), findsOneWidget);
      expect(find.text('Room 401'), findsOneWidget);

      // Edit and Delete buttons MUST NOT be visible for student
      expect(find.text('Edit'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('9. Authorized CR can see Edit and Delete buttons for their cohort', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(sampleCr);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ExamDetailsDialog.show(
                  context: context,
                  exam: upcomingExam, // Year 3, Semester 1
                  userRole: UserRole.cr,
                  userYear: 3,
                  userSemester: 1,
                  userId: 'cr_1',
                ),
                child: const Text('Open Details'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      // CR for Year 3 Semester 1 CAN modify this exam
      expect(find.text('Edit'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('10. CR from another cohort CANNOT modify exam of different cohort', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ExamDetailsDialog.show(
                  context: context,
                  exam: upcomingExam, // Year 3, Semester 1
                  userRole: UserRole.cr,
                  userYear: 4, // Year 4 CR!
                  userSemester: 1,
                  userId: 'cr_4_1',
                ),
                child: const Text('Open Details'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      // Unauthorized CR cannot edit or delete
      expect(find.text('Edit'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('11. Delete exam triggers AppConfirmationDialog before executing', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(sampleCr);
      when(() => mockRepo.deleteExam('exam_up_1')).thenAnswer((_) async {});
      when(() => mockRepo.getExams(
        year: any(named: 'year'),
        semester: any(named: 'semester'),
        courseId: any(named: 'courseId'),
      )).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ExamDetailsDialog.show(
                  context: context,
                  exam: upcomingExam,
                  userRole: UserRole.cr,
                  userYear: 3,
                  userSemester: 1,
                  userId: 'cr_1',
                ),
                child: const Text('Open Details'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      // Tap Delete icon
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      // AppConfirmationDialog pops up
      expect(find.text('Delete Exam Schedule?'), findsOneWidget);
      expect(find.text('Delete Exam'), findsOneWidget);

      // Tap Confirm Delete
      await tester.tap(find.text('Delete Exam'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteExam('exam_up_1')).called(1);
    });
  });

  group('STAGE 22: Exam Form Validation Tests', () {
    testWidgets('12. ExamFormDialog rejects empty title and validates times', (tester) async {
      when(() => mockRepo.getAllCourses(year: 3, semester: 1)).thenAnswer((_) async => [sampleCourse1, sampleCourse2]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ExamFormDialog.show(
                  context: context,
                  userRole: UserRole.cr,
                  defaultYear: 3,
                  defaultSemester: 1,
                ),
                child: const Text('Open Form'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule Examination'), findsOneWidget);

      // Clear title
      final titleField = find.widgetWithText(TextFormField, 'Mid-Term Examination');
      await tester.enterText(titleField, '');

      // Tap Schedule Exam
      await tester.tap(find.text('Schedule Exam'));
      await tester.pumpAndSettle();

      // Title validation error triggered
      expect(find.text('Exam title is required'), findsOneWidget);
    });
  });

  group('STAGE 22: ExamManagementView Widget & Tabs Tests', () {
    testWidgets('13. ExamManagementView switches between Upcoming and Past tabs', (tester) async {
      when(() => mockRepo.getExams(
        year: any(named: 'year'),
        semester: any(named: 'semester'),
        courseId: any(named: 'courseId'),
      )).thenAnswer((_) async => [upcomingExam, pastExam]);
      when(() => mockRepo.getAllCourses(year: any(named: 'year'), semester: any(named: 'semester')))
          .thenAnswer((_) async => [sampleCourse1, sampleCourse2]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamManagementView(
              userRole: UserRole.cr,
              academicYear: 3,
              academicSemester: 1,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Upcoming Tab is default
      expect(find.text('Upcoming (1)'), findsOneWidget);
      expect(find.text('Past (1)'), findsOneWidget);
      expect(find.text('Operating Systems'), findsOneWidget);

      // Switch to Past tab
      await tester.tap(find.text('Past (1)'));
      await tester.pumpAndSettle();

      // Past exam is displayed
      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('Class Test 1'), findsOneWidget);
    });

    testWidgets('14. ExamManagementView shows error view and retries on failure', (tester) async {
      when(() => mockRepo.getExams(
        year: any(named: 'year'),
        semester: any(named: 'semester'),
        courseId: any(named: 'courseId'),
      )).thenThrow(ServerFailure(message: 'Network connection failure'));
      when(() => mockRepo.getAllCourses(year: any(named: 'year'), semester: any(named: 'semester')))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamManagementView(
              userRole: UserRole.student,
              academicYear: 3,
              academicSemester: 1,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Exams'), findsOneWidget);
      expect(find.text('Network connection failure'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Now set mock to succeed on retry
      when(() => mockRepo.getExams(
        year: any(named: 'year'),
        semester: any(named: 'semester'),
        courseId: any(named: 'courseId'),
      )).thenAnswer((_) async => [upcomingExam]);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Operating Systems'), findsOneWidget);
    });

    testWidgets('15. ExamManagementView shows empty state when no exams exist', (tester) async {
      when(() => mockRepo.getExams(
        year: any(named: 'year'),
        semester: any(named: 'semester'),
        courseId: any(named: 'courseId'),
      )).thenAnswer((_) async => []);
      when(() => mockRepo.getAllCourses(year: any(named: 'year'), semester: any(named: 'semester')))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamManagementView(
              userRole: UserRole.cr,
              academicYear: 3,
              academicSemester: 1,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No upcoming exams scheduled.'), findsOneWidget);
      expect(find.text('Schedule an Exam'), findsOneWidget);
    });
  });
}
