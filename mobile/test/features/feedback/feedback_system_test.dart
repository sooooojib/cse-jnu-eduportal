import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/features/feedback/domain/entities/feedback_entities.dart';
import 'package:cse_jnu_eduportal/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:cse_jnu_eduportal/features/feedback/data/models/feedback_models.dart';
import 'package:cse_jnu_eduportal/features/feedback/presentation/controllers/feedback_controller.dart';
import 'package:cse_jnu_eduportal/features/feedback/presentation/screens/student_feedback_screen.dart';
import 'package:cse_jnu_eduportal/features/feedback/presentation/screens/teacher_feedback_screen.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MockFeedbackRepository extends Mock implements FeedbackRepository {}
class MockCurriculumRepository extends Mock implements CurriculumRepository {}
class MockFirebaseStorage extends Mock implements FirebaseStorage {}

void main() {
  late MockFeedbackRepository mockFeedbackRepo;
  late MockCurriculumRepository mockCurriculumRepo;

  final sampleAnonymousFeedback = FeedbackItem(
    id: 'fb-anon-1',
    teacherId: 'teacher-101',
    teacherName: 'Dr. Kamrul Hasan',
    courseId: 'c-3101',
    courseCode: 'CSE-3101',
    courseTitle: 'Database Systems',
    rating: 5,
    comments: 'Lectures were crystal clear and very engaging.',
    isAnonymous: true,
    studentId: 'ANONYMOUS',
    studentName: 'Anonymous Student',
    attachments: const [
      Attachment(
        id: 'att-1',
        fileName: 'screenshot.png',
        fileUrl: 'https://storage.googleapis.com/test/screenshot.png',
      ),
    ],
    replies: const [
      FeedbackReply(
        id: 'rep-1',
        teacherId: 'teacher-101',
        teacherName: 'Dr. Kamrul Hasan',
        replyText: 'Thank you for your feedback! Best of luck.',
        createdAt: '2026-10-20T10:00:00Z',
      ),
    ],
    createdAt: '2026-10-19T14:00:00Z',
  );

  final sampleNamedFeedback = FeedbackItem(
    id: 'fb-named-2',
    teacherId: 'teacher-101',
    teacherName: 'Dr. Kamrul Hasan',
    courseId: 'c-3101',
    courseCode: 'CSE-3101',
    courseTitle: 'Database Systems',
    rating: 4,
    comments: 'Good course, could use more practice problem sets.',
    isAnonymous: false,
    studentId: 'student-42',
    studentName: 'Sajib Ahmed',
    studentEmail: 'sajib@dept.jnu.ac.bd',
    attachments: const [],
    replies: const [],
    createdAt: '2026-10-19T15:30:00Z',
  );

  setUp(() {
    mockFeedbackRepo = MockFeedbackRepository();
    mockCurriculumRepo = MockCurriculumRepository();

    if (sl.isRegistered<FeedbackRepository>()) {
      sl.unregister<FeedbackRepository>();
    }
    sl.registerSingleton<FeedbackRepository>(mockFeedbackRepo);

    if (sl.isRegistered<CurriculumRepository>()) {
      sl.unregister<CurriculumRepository>();
    }
    sl.registerSingleton<CurriculumRepository>(mockCurriculumRepo);

    if (sl.isRegistered<FirebaseStorage>()) {
      sl.unregister<FirebaseStorage>();
    }
    sl.registerSingleton<FirebaseStorage>(MockFirebaseStorage());

    if (sl.isRegistered<FeedbackController>()) {
      sl.unregister<FeedbackController>();
    }
    sl.registerFactory<FeedbackController>(() => FeedbackController(
      submitFeedbackUseCase: SubmitFeedbackUseCase(mockFeedbackRepo),
      getMyFeedbackUseCase: GetMyFeedbackUseCase(mockFeedbackRepo),
      editFeedbackUseCase: EditFeedbackUseCase(mockFeedbackRepo),
      getTeacherFeedbackUseCase: GetTeacherFeedbackUseCase(mockFeedbackRepo),
      replyToFeedbackUseCase: ReplyToFeedbackUseCase(mockFeedbackRepo),
      editFeedbackReplyUseCase: EditFeedbackReplyUseCase(mockFeedbackRepo),
      getAdminFeedbackUseCase: GetAdminFeedbackUseCase(mockFeedbackRepo),
    ));

    when(() => mockCurriculumRepo.getMyCourses()).thenAnswer((_) async => [
      const Course(
        id: 'c-3101',
        code: 'CSE-3101',
        title: 'Database Systems',
        credit: 3.0,
        year: 3,
        semester: 1,
        courseType: 'THEORY',
        teacherId: 'teacher-101',
        teacherName: 'Dr. Kamrul Hasan',
      ),
    ]);

    when(() => mockCurriculumRepo.getAllTeachers()).thenAnswer((_) async => [
      {'id': 'teacher-101', 'name': 'Dr. Kamrul Hasan', 'designation': 'Professor'},
    ]);
  });

  tearDown(() {
    if (sl.isRegistered<FeedbackRepository>()) sl.unregister<FeedbackRepository>();
    if (sl.isRegistered<CurriculumRepository>()) sl.unregister<CurriculumRepository>();
    if (sl.isRegistered<FeedbackController>()) sl.unregister<FeedbackController>();
    if (sl.isRegistered<FirebaseStorage>()) sl.unregister<FirebaseStorage>();
  });

  group('Feedback Entities & Models Unit Tests', () {
    test('FeedbackItemModel deserializes anonymous feedback safely without identity leaks', () {
      final json = {
        'id': 'fb-100',
        'teacherId': 't-1',
        'teacherName': 'Prof. Kabir',
        'rating': 5,
        'comments': 'Great instruction.',
        'isAnonymous': true,
        'studentId': 'ANONYMOUS',
        'studentName': 'Anonymous Student',
        'attachments': [
          {
            'id': 'a-1',
            'fileName': 'notes.pdf',
            'fileUrl': 'https://firebasestorage.googleapis.com/test.pdf',
          }
        ],
        'replies': [
          {
            'id': 'r-1',
            'teacherId': 't-1',
            'teacherName': 'Prof. Kabir',
            'replyText': 'Thank you!',
            'createdAt': '2026-10-19T10:00:00Z',
          }
        ],
        'createdAt': '2026-10-19T09:00:00Z',
      };

      final model = FeedbackItemModel.fromJson(json);

      expect(model.id, 'fb-100');
      expect(model.isAnonymous, isTrue);
      expect(model.studentId, 'ANONYMOUS');
      expect(model.studentName, 'Anonymous Student');
      expect(model.studentEmail, isNull);
      expect(model.hasReplied, isTrue);
      expect(model.attachments.length, 1);
      expect(model.attachments.first.fileName, 'notes.pdf');
      expect(model.replies.length, 1);
      expect(model.replies.first.replyText, 'Thank you!');
    });

    test('FeedbackItemModel deserializes non-anonymous feedback with student details', () {
      final json = {
        'id': 'fb-101',
        'teacherId': 't-1',
        'teacherName': 'Prof. Kabir',
        'rating': 4,
        'comments': 'Helpful lab sessions.',
        'isAnonymous': false,
        'studentId': 'usr-999',
        'studentName': 'Sumaiya Akter',
        'studentEmail': 'sumaiya@dept.jnu.ac.bd',
        'attachments': <dynamic>[],
        'replies': <dynamic>[],
        'createdAt': '2026-10-19T09:00:00Z',
      };

      final model = FeedbackItemModel.fromJson(json);

      expect(model.isAnonymous, isFalse);
      expect(model.studentId, 'usr-999');
      expect(model.studentName, 'Sumaiya Akter');
      expect(model.studentEmail, 'sumaiya@dept.jnu.ac.bd');
      expect(model.hasReplied, isFalse);
    });
  });

  group('FeedbackController Unit Tests', () {
    test('fetchSubmissions loads student submissions successfully', () async {
      when(() => mockFeedbackRepo.getMySubmissions()).thenAnswer(
        (_) async => [sampleAnonymousFeedback, sampleNamedFeedback],
      );

      final controller = sl<FeedbackController>();
      await controller.fetchSubmissions();

      expect(controller.state, isA<FeedbackLoaded>());
      final state = controller.state as FeedbackLoaded;
      expect(state.submissions.length, 2);
      expect(state.submissions.first.isAnonymous, isTrue);
    });

    test('submitFeedback delegates to repository and refreshes submissions', () async {
      when(() => mockFeedbackRepo.submitFeedback(
        teacherId: any(named: 'teacherId'),
        courseId: any(named: 'courseId'),
        courseCode: any(named: 'courseCode'),
        courseTitle: any(named: 'courseTitle'),
        rating: any(named: 'rating'),
        comments: any(named: 'comments'),
        isAnonymous: any(named: 'isAnonymous'),
        attachments: any(named: 'attachments'),
      )).thenAnswer((_) async => sampleAnonymousFeedback);

      when(() => mockFeedbackRepo.getMySubmissions()).thenAnswer(
        (_) async => [sampleAnonymousFeedback],
      );

      final controller = sl<FeedbackController>();
      final success = await controller.submitFeedback(
        teacherId: 'teacher-101',
        rating: 5,
        comments: 'Excellent class interaction.',
        isAnonymous: true,
      );

      expect(success, isTrue);
      verify(() => mockFeedbackRepo.submitFeedback(
        teacherId: 'teacher-101',
        rating: 5,
        comments: 'Excellent class interaction.',
        isAnonymous: true,
        attachments: any(named: 'attachments'),
      )).called(1);
    });

    test('editFeedback updates submitted feedback and refreshes list', () async {
      when(() => mockFeedbackRepo.editFeedback(
        feedbackId: 'fb-anon-1',
        rating: 4,
        comments: 'Updated comments after reflection.',
        isAnonymous: true,
        attachments: any(named: 'attachments'),
      )).thenAnswer((_) async => sampleAnonymousFeedback);

      when(() => mockFeedbackRepo.getMySubmissions()).thenAnswer(
        (_) async => [sampleAnonymousFeedback],
      );

      final controller = sl<FeedbackController>();
      final success = await controller.editFeedback(
        feedbackId: 'fb-anon-1',
        rating: 4,
        comments: 'Updated comments after reflection.',
        isAnonymous: true,
      );

      expect(success, isTrue);
      verify(() => mockFeedbackRepo.editFeedback(
        feedbackId: 'fb-anon-1',
        rating: 4,
        comments: 'Updated comments after reflection.',
        isAnonymous: true,
        attachments: any(named: 'attachments'),
      )).called(1);
    });

    test('fetchTeacherFeedback queries teacher feedback with filters', () async {
      when(() => mockFeedbackRepo.getTeacherFeedback(
        teacherId: 'teacher-101',
        filter: 'ALL',
      )).thenAnswer((_) async => [sampleAnonymousFeedback, sampleNamedFeedback]);

      final controller = sl<FeedbackController>();
      await controller.fetchTeacherFeedback('teacher-101', filter: 'ALL');

      expect(controller.state, isA<FeedbackLoaded>());
      final state = controller.state as FeedbackLoaded;
      expect(state.teacherFeedback.length, 2);
      expect(state.teacherFilter, 'ALL');
    });

    test('replyToFeedback submits teacher reply and updates teacher view', () async {
      when(() => mockFeedbackRepo.replyToFeedback(
        feedbackId: 'fb-named-2',
        replyText: 'Thank you for the suggestion!',
        attachments: any(named: 'attachments'),
      )).thenAnswer((_) async => sampleNamedFeedback);

      when(() => mockFeedbackRepo.getTeacherFeedback(
        teacherId: 'teacher-101',
        filter: 'ALL',
      )).thenAnswer((_) async => [sampleNamedFeedback]);

      final controller = sl<FeedbackController>();
      final success = await controller.replyToFeedback(
        feedbackId: 'fb-named-2',
        replyText: 'Thank you for the suggestion!',
        teacherId: 'teacher-101',
      );

      expect(success, isTrue);
      verify(() => mockFeedbackRepo.replyToFeedback(
        feedbackId: 'fb-named-2',
        replyText: 'Thank you for the suggestion!',
        attachments: any(named: 'attachments'),
      )).called(1);
    });

    test('editFeedbackReply updates existing teacher reply', () async {
      when(() => mockFeedbackRepo.editFeedbackReply(
        feedbackId: 'fb-anon-1',
        replyId: 'rep-1',
        replyText: 'Updated faculty reply text.',
        attachments: any(named: 'attachments'),
      )).thenAnswer((_) async => sampleAnonymousFeedback);

      when(() => mockFeedbackRepo.getTeacherFeedback(
        teacherId: 'teacher-101',
        filter: 'ALL',
      )).thenAnswer((_) async => [sampleAnonymousFeedback]);

      final controller = sl<FeedbackController>();
      final success = await controller.editFeedbackReply(
        feedbackId: 'fb-anon-1',
        replyId: 'rep-1',
        replyText: 'Updated faculty reply text.',
        teacherId: 'teacher-101',
      );

      expect(success, isTrue);
      verify(() => mockFeedbackRepo.editFeedbackReply(
        feedbackId: 'fb-anon-1',
        replyId: 'rep-1',
        replyText: 'Updated faculty reply text.',
        attachments: any(named: 'attachments'),
      )).called(1);
    });
  });

  group('StudentFeedbackScreen Widget Tests', () {
    testWidgets('Renders course selector, star rating, comment field, and anonymous toggle', (tester) async {
      when(() => mockFeedbackRepo.getMySubmissions()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentFeedbackScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Course & Faculty Evaluation'), findsOneWidget);
      expect(find.text('Submit Anonymously'), findsOneWidget);
      expect(find.text('Submit Faculty Feedback'), findsOneWidget);
      expect(find.text('File Attachments'), findsOneWidget);
    });

    testWidgets('Toggling anonymous displays authoritative server-side security guarantee banner', (tester) async {
      when(() => mockFeedbackRepo.getMySubmissions()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentFeedbackScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially guarantee banner is hidden
      expect(find.textContaining('Authoritative Identity Protection'), findsNothing);

      // Scroll to and tap the anonymous switch
      await tester.ensureVisible(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Banner is now prominently displayed
      expect(find.textContaining('Authoritative Identity Protection: Your name and student ID are stripped at the server level'), findsOneWidget);
    });

    testWidgets('My Submissions tab displays student submissions, anonymous badge, and teacher reply', (tester) async {
      when(() => mockFeedbackRepo.getMySubmissions()).thenAnswer(
        (_) async => [sampleAnonymousFeedback],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentFeedbackScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to 'My Submissions' tab
      await tester.tap(find.text('My Submissions'));
      await tester.pumpAndSettle();

      // Verifies anonymous badge, teacher name, status badge, comments, and faculty reply
      expect(find.text('Dr. Kamrul Hasan'), findsAtLeastNWidgets(1));
      expect(find.text('ANONYMOUS'), findsOneWidget);
      expect(find.text('REPLIED'), findsOneWidget);
      expect(find.text('Lectures were crystal clear and very engaging.'), findsOneWidget);
      expect(find.text('Thank you for your feedback! Best of luck.'), findsOneWidget);
      expect(find.text('screenshot.png'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });
  });

  group('TeacherFeedbackScreen Widget Tests', () {
    testWidgets('Renders 3 filter tabs (All, Replied, Not Replied) and received feedback', (tester) async {
      when(() => mockFeedbackRepo.getTeacherFeedback(
        teacherId: 'teacher-101',
        filter: 'ALL',
      )).thenAnswer((_) async => [sampleAnonymousFeedback, sampleNamedFeedback]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeacherFeedbackScreen(teacherId: 'teacher-101'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Received Feedback'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Replied'), findsNWidgets(2)); // Tab title + card badge
      expect(find.text('Not Replied'), findsOneWidget);

      // Identity protection check: anonymous feedback displays 'Anonymous Student', never leaks UID
      expect(find.text('Anonymous Student'), findsOneWidget);
      expect(find.text('Sajib Ahmed'), findsOneWidget);

      // Reply status verification
      expect(find.text('Replied'), findsAtLeastNWidgets(1));
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Reply'), findsOneWidget);
    });

    testWidgets('Clicking Reply opens bottom sheet for composing teacher response', (tester) async {
      when(() => mockFeedbackRepo.getTeacherFeedback(
        teacherId: 'teacher-101',
        filter: 'ALL',
      )).thenAnswer((_) async => [sampleNamedFeedback]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeacherFeedbackScreen(teacherId: 'teacher-101'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Click on 'Reply' button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reply'));
      await tester.pumpAndSettle();

      expect(find.text('Reply to Feedback'), findsOneWidget);
      expect(find.text('Your Response'), findsOneWidget);
      expect(find.text('Send Reply'), findsOneWidget);
      expect(find.text('Add File'), findsOneWidget);
    });
  });
}
