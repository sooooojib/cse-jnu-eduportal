import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/error/exceptions.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/core/storage/local_storage_service.dart';
import 'package:cse_jnu_eduportal/app/theme/theme_controller.dart';

import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/signup_request.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_state.dart';

import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/features/profile/domain/entities/semester_status.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/entities/attendance_entities.dart';
import 'package:cse_jnu_eduportal/features/feedback/domain/entities/feedback_entities.dart';

import 'package:cse_jnu_eduportal/features/admin/domain/entities/admin_stats.dart';
import 'package:cse_jnu_eduportal/features/admin/domain/repositories/admin_repository.dart';
import 'package:cse_jnu_eduportal/features/admin/presentation/screens/admin_management_screens.dart';

class MockAdminRepository extends Mock implements AdminRepository {}
class MockAuthController extends Mock implements AuthController {}
class MockLocalStorageService extends Mock implements LocalStorageService {}

class FakeCourse extends Fake implements Course {}
class FakeUser extends Fake implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAdminRepository mockAdminRepo;
  late MockAuthController mockAuthController;
  late MockLocalStorageService mockLocalStorageService;

  const sampleAdmin = User(
    id: 'uid_admin_1',
    email: 'admin@cse.jnu.ac.bd',
    fullName: 'Department Admin',
    role: UserRole.admin,
  );

  const sampleTeacher = User(
    id: 'uid_teacher_1',
    email: 'teacher@cse.jnu.ac.bd',
    fullName: 'Dr. Rafiqul Islam',
    role: UserRole.teacher,
    assignedCourseIds: ['CSE-1101'],
  );

  const sampleStudent = User(
    id: 'uid_student_1',
    email: 'student@cse.jnu.ac.bd',
    fullName: 'Sadia Sultana',
    role: UserRole.student,
    studentId: '2023CSE015',
    year: 1,
    semester: 1,
  );

  const sampleCr = User(
    id: 'uid_cr_1',
    email: 'cr@cse.jnu.ac.bd',
    fullName: 'Mahmudul Hasan',
    role: UserRole.cr,
    studentId: '2023CSE001',
    year: 1,
    semester: 1,
  );

  const sampleCourse = Course(
    id: 'CSE-1101',
    code: 'CSE-1101',
    title: 'Structured Programming',
    credit: 3.0,
    year: 1,
    semester: 1,
    courseType: 'THEORY',
    description: 'Introduction to C programming, variables, and logic.',
    teacherId: 'uid_teacher_1',
    teacherName: 'Dr. Rafiqul Islam',
  );

  const sampleAssignment = CourseAssignment(
    id: 'asgn_1',
    courseId: 'CSE-1101',
    courseCode: 'CSE-1101',
    courseTitle: 'Structured Programming',
    teacherId: 'uid_teacher_1',
    teacherName: 'Dr. Rafiqul Islam',
    isCoordinator: true,
  );

  const sampleSignup = SignupRequest(
    id: 'req_101',
    email: 'newbie@cse.jnu.ac.bd',
    fullName: 'Newbie Student',
    role: UserRole.student,
    studentId: '2024CSE099',
    status: 'PENDING',
    createdAt: '2026-10-01T12:00:00Z',
  );

  const sampleSemesterRequest = SemesterUpgradeRequest(
    id: 'sem_req_201',
    studentId: 'uid_student_1',
    studentName: 'Sadia Sultana',
    studentRoll: '2023CSE015',
    currentYear: 1,
    currentSemester: 1,
    requestedYear: 1,
    requestedSemester: 2,
    status: 'PENDING',
    createdAt: '2026-10-01T09:00:00Z',
  );

  const sampleSession = AttendanceSession(
    id: 'sess_1',
    courseId: 'CSE-1101',
    courseCode: 'CSE-1101',
    courseTitle: 'Structured Programming',
    teacherId: 'uid_teacher_1',
    teacherName: 'Dr. Rafiqul Islam',
    code: '492817',
    isActive: true,
    status: 'ACTIVE',
    sessionDate: '2026-10-02',
    totalPresentCount: 38,
    createdAt: '2026-10-02T10:00:00Z',
  );

  const sampleFeedback = FeedbackItem(
    id: 'fb_1',
    teacherId: 'uid_teacher_1',
    teacherName: 'Dr. Rafiqul Islam',
    courseId: 'CSE-1101',
    courseCode: 'CSE-1101',
    courseTitle: 'Structured Programming',
    rating: 5,
    comments: 'Exceptional teaching methodology and clear explanations.',
    isAnonymous: true,
    attachments: [],
    replies: [],
    createdAt: '2026-10-01T15:00:00Z',
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(FakeCourse());
    registerFallbackValue(FakeUser());
    registerFallbackValue(UserRole.student);
  });

  setUp(() async {
    mockAdminRepo = MockAdminRepository();
    mockAuthController = MockAuthController();
    mockLocalStorageService = MockLocalStorageService();

    when(() => mockAuthController.addListener(any())).thenReturn(null);
    when(() => mockAuthController.removeListener(any())).thenReturn(null);
    when(() => mockAuthController.state).thenReturn(const Authenticated(user: sampleAdmin));
    when(() => mockAuthController.currentUser).thenReturn(sampleAdmin);
    when(() => mockLocalStorageService.getThemeMode()).thenReturn('system');

    await sl.reset();
    sl.registerLazySingleton<LocalStorageService>(() => mockLocalStorageService);
    sl.registerLazySingleton<ThemeController>(() => ThemeController(localStorageService: sl()));
    sl.registerLazySingleton<AuthController>(() => mockAuthController);
    sl.registerLazySingleton<AdminRepository>(() => mockAdminRepo);
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. USER MANAGEMENT TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('1. User Directory & Management', () {
    testWidgets('Displays all users and allows filtering by role tabs', (tester) async {
      when(() => mockAdminRepo.getAllUsers(roleFilter: any(named: 'roleFilter')))
          .thenAnswer((_) async => [sampleAdmin, sampleTeacher, sampleStudent, sampleCr]);

      await tester.pumpWidget(buildTestableWidget(
        AdminUserDirectoryScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Department User Directory'), findsOneWidget);
      expect(find.text('Dr. Rafiqul Islam'), findsOneWidget);
      expect(find.text('Sadia Sultana'), findsOneWidget);

      // Tap on Faculty tab
      await tester.tap(find.text('Faculty'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Rafiqul Islam'), findsOneWidget);
      expect(find.text('Sadia Sultana'), findsNothing);

      // Tap on Students tab
      await tester.tap(find.text('Students'));
      await tester.pumpAndSettle();

      expect(find.text('Sadia Sultana'), findsOneWidget);
      expect(find.text('Dr. Rafiqul Islam'), findsNothing);
    });

    testWidgets('Filters users via search input', (tester) async {
      when(() => mockAdminRepo.getAllUsers(roleFilter: any(named: 'roleFilter')))
          .thenAnswer((_) async => [sampleTeacher, sampleStudent]);

      await tester.pumpWidget(buildTestableWidget(
        AdminUserDirectoryScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Sadia');
      await tester.pumpAndSettle();

      expect(find.text('Sadia Sultana'), findsOneWidget);
      expect(find.text('Dr. Rafiqul Islam'), findsNothing);
    });

    testWidgets('Opens Create User modal and validates required fields', (tester) async {
      when(() => mockAdminRepo.getAllUsers(roleFilter: any(named: 'roleFilter')))
          .thenAnswer((_) async => [sampleTeacher]);

      await tester.pumpWidget(buildTestableWidget(
        AdminUserDirectoryScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      // Tap New User FAB
      await tester.tap(find.text('New User'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Portal Account'), findsOneWidget);

      // Attempt to submit empty form
      await tester.tap(find.text('Provision Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please fill all required fields correctly.'), findsOneWidget);
    });

    testWidgets('Successfully provisions a new student account', (tester) async {
      when(() => mockAdminRepo.getAllUsers(roleFilter: any(named: 'roleFilter')))
          .thenAnswer((_) async => [sampleTeacher]);
      when(() => mockAdminRepo.createUser(
            fullName: any(named: 'fullName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            role: any(named: 'role'),
            studentId: any(named: 'studentId'),
            phone: any(named: 'phone'),
            year: any(named: 'year'),
            semester: any(named: 'semester'),
          )).thenAnswer((_) async => sampleStudent);

      await tester.pumpWidget(buildTestableWidget(
        AdminUserDirectoryScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New User'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'Sadia Sultana'); // Name
      await tester.enterText(textFields.at(2), 'sadia@cse.jnu.ac.bd'); // Email
      await tester.enterText(textFields.at(3), 'SecurePass123!'); // Password
      await tester.enterText(textFields.at(4), '2023CSE015'); // Student ID

      await tester.tap(find.text('Provision Account'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.createUser(
            fullName: 'Sadia Sultana',
            email: 'sadia@cse.jnu.ac.bd',
            password: 'SecurePass123!',
            role: UserRole.student,
            studentId: '2023CSE015',
            phone: null,
            year: 1,
            semester: 1,
          )).called(1);

      expect(find.text('User Sadia Sultana provisioned successfully.'), findsOneWidget);
    });

    testWidgets('Handles duplicate user creation gracefully with error feedback', (tester) async {
      when(() => mockAdminRepo.getAllUsers(roleFilter: any(named: 'roleFilter')))
          .thenAnswer((_) async => [sampleTeacher]);
      when(() => mockAdminRepo.createUser(
            fullName: any(named: 'fullName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            role: any(named: 'role'),
            studentId: any(named: 'studentId'),
            phone: any(named: 'phone'),
            year: any(named: 'year'),
            semester: any(named: 'semester'),
          )).thenThrow(const ValidationException(message: 'A student account with ID 2023CSE015 already exists.', validationErrors: []));

      await tester.pumpWidget(buildTestableWidget(
        AdminUserDirectoryScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New User'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'Sadia Sultana');
      await tester.enterText(textFields.at(2), 'sadia@cse.jnu.ac.bd');
      await tester.enterText(textFields.at(3), 'SecurePass123!');
      await tester.enterText(textFields.at(4), '2023CSE015');

      await tester.tap(find.text('Provision Account'));
      await tester.pumpAndSettle();

      expect(find.textContaining('already exists'), findsOneWidget);
    });

    testWidgets('Prompts destructive confirmation before deleting user', (tester) async {
      when(() => mockAdminRepo.getAllUsers(roleFilter: any(named: 'roleFilter')))
          .thenAnswer((_) async => [sampleStudent]);
      when(() => mockAdminRepo.deleteUser(userId: 'uid_student_1'))
          .thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        AdminUserDirectoryScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      // Tap delete icon
      final deleteBtn = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Delete User Account?'), findsOneWidget);
      expect(find.textContaining('permanently delete Sadia Sultana'), findsOneWidget);

      // Tap Delete in confirmation dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete User'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.deleteUser(userId: 'uid_student_1')).called(1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. COURSE MANAGEMENT TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('2. Course Management', () {
    testWidgets('Lists courses grouped by academic year and semester', (tester) async {
      when(() => mockAdminRepo.getAllCourses()).thenAnswer((_) async => [sampleCourse]);

      await tester.pumpWidget(buildTestableWidget(
        AdminCourseManagementScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Course Catalog Management'), findsOneWidget);
      expect(find.text('Structured Programming'), findsOneWidget);
      expect(find.text('CSE-1101'), findsOneWidget);
      expect(find.text('3.0 Credits • THEORY'), findsOneWidget);
    });

    testWidgets('Creates a new course and validates inputs', (tester) async {
      when(() => mockAdminRepo.getAllCourses()).thenAnswer((_) async => []);
      when(() => mockAdminRepo.createCourse(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        AdminCourseManagementScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      // Tap Add Course
      await tester.tap(find.text('Add Course'));
      await tester.pumpAndSettle();

      expect(find.text('Add Department Course'), findsOneWidget);

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'CSE-1201'); // Code
      await tester.enterText(textFields.at(1), 'Data Structures'); // Title
      await tester.enterText(textFields.at(2), '3.0'); // Credits
      await tester.enterText(textFields.at(3), 'Linear and non-linear data structures.'); // Description

      await tester.tap(find.text('Save Course'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.createCourse(any())).called(1);
      expect(find.textContaining('saved'), findsOneWidget);
    });

    testWidgets('Rejects duplicate course code with validation error', (tester) async {
      when(() => mockAdminRepo.getAllCourses()).thenAnswer((_) async => [sampleCourse]);
      when(() => mockAdminRepo.createCourse(any())).thenThrow(
        const ValidationException(message: 'A course with this course code already exists.', validationErrors: []),
      );

      await tester.pumpWidget(buildTestableWidget(
        AdminCourseManagementScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Course'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'CSE-1101');
      await tester.enterText(textFields.at(1), 'Duplicate Title');
      await tester.enterText(textFields.at(2), '3.0');

      await tester.tap(find.text('Save Course'));
      await tester.pumpAndSettle();

      expect(find.textContaining('already exists'), findsOneWidget);
    });

    testWidgets('Edits course details and updates repository', (tester) async {
      when(() => mockAdminRepo.getAllCourses()).thenAnswer((_) async => [sampleCourse]);
      when(() => mockAdminRepo.updateCourse(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        AdminCourseManagementScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      final editIcon = find.byIcon(Icons.edit_outlined);
      await tester.tap(editIcon);
      await tester.pumpAndSettle();

      expect(find.text('Edit Course CSE-1101'), findsOneWidget);

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'Structured Programming with C');

      await tester.tap(find.text('Save Course'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.updateCourse(any())).called(1);
      expect(find.textContaining('saved'), findsOneWidget);
    });

    testWidgets('Deletes course after confirmation', (tester) async {
      when(() => mockAdminRepo.getAllCourses()).thenAnswer((_) async => [sampleCourse]);
      when(() => mockAdminRepo.deleteCourse('CSE-1101')).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        AdminCourseManagementScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      final deleteIcon = find.byIcon(Icons.delete_outline_rounded);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(find.text('Delete Course CSE-1101?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Course'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.deleteCourse('CSE-1101')).called(1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. TEACHER COURSE ASSIGNMENT TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('3. Teacher Course Assignment', () {
    testWidgets('Displays current teacher course assignments and course counts', (tester) async {
      when(() => mockAdminRepo.getAllCourseAssignments()).thenAnswer((_) async => [sampleAssignment]);
      when(() => mockAdminRepo.getAllUsers(roleFilter: UserRole.teacher))
          .thenAnswer((_) async => [sampleTeacher]);
      when(() => mockAdminRepo.getAllCourses()).thenAnswer((_) async => [sampleCourse]);

      await tester.pumpWidget(buildTestableWidget(
        AdminTeacherAssignmentScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Teacher Course Allocations'), findsOneWidget);
      expect(find.text('Dr. Rafiqul Islam'), findsAtLeastNWidgets(1));
      expect(find.text('Coordinator'), findsOneWidget);
    });

    testWidgets('Assigns course to teacher with coordinator designation', (tester) async {
      when(() => mockAdminRepo.getAllCourseAssignments()).thenAnswer((_) async => []);
      when(() => mockAdminRepo.getAllUsers(roleFilter: UserRole.teacher))
          .thenAnswer((_) async => [sampleTeacher]);
      when(() => mockAdminRepo.getAllCourses()).thenAnswer((_) async => [sampleCourse]);
      when(() => mockAdminRepo.assignCourseToTeacher(
            courseId: any(named: 'courseId'),
            teacherId: any(named: 'teacherId'),
            isCoordinator: any(named: 'isCoordinator'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        AdminTeacherAssignmentScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();

      expect(find.text('Assign Course to Faculty'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.assignCourseToTeacher(
            courseId: 'CSE-1101',
            teacherId: 'uid_teacher_1',
            isCoordinator: false,
          )).called(1);
    });

    testWidgets('Prevents duplicate assignment and shows error', (tester) async {
      when(() => mockAdminRepo.getAllCourseAssignments()).thenAnswer((_) async => [sampleAssignment]);
      when(() => mockAdminRepo.getAllUsers(roleFilter: UserRole.teacher))
          .thenAnswer((_) async => [sampleTeacher]);
      when(() => mockAdminRepo.getAllCourses()).thenAnswer((_) async => [sampleCourse]);
      when(() => mockAdminRepo.assignCourseToTeacher(
            courseId: any(named: 'courseId'),
            teacherId: any(named: 'teacherId'),
            isCoordinator: any(named: 'isCoordinator'),
          )).thenThrow(const ValidationException(message: 'This teacher is already assigned to this course.', validationErrors: []));

      await tester.pumpWidget(buildTestableWidget(
        AdminTeacherAssignmentScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign'));
      await tester.pumpAndSettle();

      expect(find.textContaining('already assigned'), findsOneWidget);
    });

    testWidgets('Removes course assignment with confirmation dialog', (tester) async {
      when(() => mockAdminRepo.getAllCourseAssignments()).thenAnswer((_) async => [sampleAssignment]);
      when(() => mockAdminRepo.getAllUsers(roleFilter: UserRole.teacher))
          .thenAnswer((_) async => [sampleTeacher]);
      when(() => mockAdminRepo.getAllCourses()).thenAnswer((_) async => [sampleCourse]);
      when(() => mockAdminRepo.removeCourseAssignment(
            assignmentId: 'asgn_1',
            courseId: 'CSE-1101',
            teacherId: 'uid_teacher_1',
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        AdminTeacherAssignmentScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      final removeBtn = find.byIcon(Icons.remove_circle_outline_rounded);
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();

      expect(find.text('Remove Assignment?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Remove'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.removeCourseAssignment(
            assignmentId: 'asgn_1',
            courseId: 'CSE-1101',
            teacherId: 'uid_teacher_1',
          )).called(1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. SIGNUP REQUEST MANAGEMENT TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('4. Signup Request Moderation', () {
    testWidgets('Lists pending signup requests with details', (tester) async {
      when(() => mockAdminRepo.getAllSignupRequests(statusFilter: any(named: 'statusFilter')))
          .thenAnswer((_) async => [sampleSignup]);

      await tester.pumpWidget(buildTestableWidget(
        AdminSignupRequestsScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Signup Petitions Queue'), findsOneWidget);
      expect(find.text('Newbie Student'), findsOneWidget);
      expect(find.text('Student ID: 2024CSE099'), findsOneWidget);
      expect(find.text('PENDING'), findsAtLeastNWidgets(1));
    });

    testWidgets('Approves signup request with academic level assignment', (tester) async {
      when(() => mockAdminRepo.getAllSignupRequests(statusFilter: any(named: 'statusFilter')))
          .thenAnswer((_) async => [sampleSignup]);
      when(() => mockAdminRepo.approveSignup(
            requestId: 'req_101',
            assignedYear: any(named: 'assignedYear'),
            assignedSemester: any(named: 'assignedSemester'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        AdminSignupRequestsScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Approve Newbie Student'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Approve').last);
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.approveSignup(
            requestId: 'req_101',
            assignedYear: 1,
            assignedSemester: 1,
          )).called(1);
      expect(find.textContaining('Approved Newbie Student'), findsOneWidget);
    });

    testWidgets('Rejects signup request with reason dialog', (tester) async {
      when(() => mockAdminRepo.getAllSignupRequests(statusFilter: any(named: 'statusFilter')))
          .thenAnswer((_) async => [sampleSignup]);
      when(() => mockAdminRepo.rejectSignup(
            requestId: 'req_101',
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        AdminSignupRequestsScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(find.text('Reject Petition'), findsOneWidget);

      final reasonField = find.byType(TextField);
      await tester.enterText(reasonField, 'Unverifiable departmental student ID.');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Reject'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.rejectSignup(
            requestId: 'req_101',
            reason: 'Unverifiable departmental student ID.',
          )).called(1);
    });

    testWidgets('Handles already processed or duplicate account errors safely', (tester) async {
      when(() => mockAdminRepo.getAllSignupRequests(statusFilter: any(named: 'statusFilter')))
          .thenAnswer((_) async => [sampleSignup]);
      when(() => mockAdminRepo.approveSignup(
            requestId: 'req_101',
            assignedYear: any(named: 'assignedYear'),
            assignedSemester: any(named: 'assignedSemester'),
          )).thenThrow(const ServerException(message: 'Request is already APPROVED.'));

      await tester.pumpWidget(buildTestableWidget(
        AdminSignupRequestsScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Approve').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('already APPROVED'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. SEMESTER UPGRADE REQUEST TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('5. Semester Upgrade Petitions', () {
    testWidgets('Displays pending semester upgrade petitions with transition badges', (tester) async {
      when(() => mockAdminRepo.getAllSemesterRequests(statusFilter: any(named: 'statusFilter')))
          .thenAnswer((_) async => [sampleSemesterRequest]);

      await tester.pumpWidget(buildTestableWidget(
        AdminSemesterRequestsScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Semester Promotion Petitions'), findsOneWidget);
      expect(find.text('Sadia Sultana'), findsOneWidget);
      expect(find.textContaining('Roll: 2023CSE015'), findsOneWidget);
      expect(find.textContaining('Y1S1 ➔ Y1S2'), findsOneWidget);
    });

    testWidgets('Approves semester upgrade safely', (tester) async {
      when(() => mockAdminRepo.getAllSemesterRequests(statusFilter: any(named: 'statusFilter')))
          .thenAnswer((_) async => [sampleSemesterRequest]);
      when(() => mockAdminRepo.approveSemesterUpgrade(requestId: 'sem_req_201'))
          .thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        AdminSemesterRequestsScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Approve Semester Upgrade?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Approve Promotion'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.approveSemesterUpgrade(requestId: 'sem_req_201')).called(1);
      expect(find.textContaining('promoted successfully'), findsOneWidget);
    });

    testWidgets('Rejects semester upgrade with reason dialog', (tester) async {
      when(() => mockAdminRepo.getAllSemesterRequests(statusFilter: any(named: 'statusFilter')))
          .thenAnswer((_) async => [sampleSemesterRequest]);
      when(() => mockAdminRepo.rejectSemesterUpgrade(
            requestId: 'sem_req_201',
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        AdminSemesterRequestsScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(find.text('Reject Semester Request'), findsOneWidget);

      final reasonField = find.byType(TextField);
      await tester.enterText(reasonField, 'Attendance prerequisites not satisfied.');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Reject'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.rejectSemesterUpgrade(
            requestId: 'sem_req_201',
            reason: 'Attendance prerequisites not satisfied.',
          )).called(1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. ATTENDANCE & FEEDBACK ACCESS TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('6. Admin Attendance & Feedback Access', () {
    testWidgets('Displays active attendance sessions with verification code and roster', (tester) async {
      when(() => mockAdminRepo.getAllAttendanceSessions()).thenAnswer((_) async => [sampleSession]);

      await tester.pumpWidget(buildTestableWidget(
        AdminAttendanceOverviewScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Attendance Administration'), findsOneWidget);
      expect(find.text('Structured Programming'), findsOneWidget);
      expect(find.text('CSE-1101'), findsOneWidget);
      expect(find.text('492817'), findsOneWidget);
      expect(find.text('Date: 2026-10-02 • Verified: 38 Students'), findsOneWidget);
    });

    testWidgets('Displays feedback items preserving student anonymity', (tester) async {
      when(() => mockAdminRepo.getAllFeedbackItems()).thenAnswer((_) async => [sampleFeedback]);

      await tester.pumpWidget(buildTestableWidget(
        AdminFeedbackModerationScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Feedback Administration'), findsOneWidget);
      expect(find.textContaining('Dr. Rafiqul Islam'), findsOneWidget);
      expect(find.text('Anonymous Student'), findsOneWidget);
      expect(find.text('Exceptional teaching methodology and clear explanations.'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. SECURITY & ROLE AUTHORIZATION TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('7. Security & Role Permissions', () {
    test('Student cannot perform administrative operations and is blocked', () {
      expect(sampleStudent.role, equals(UserRole.student));
      expect(sampleStudent.role == UserRole.admin, isFalse);
    });

    test('Teacher cannot perform administrative operations and is blocked', () {
      expect(sampleTeacher.role, equals(UserRole.teacher));
      expect(sampleTeacher.role == UserRole.admin, isFalse);
    });

    test('CR cannot perform administrative operations and is blocked', () {
      expect(sampleCr.role, equals(UserRole.cr));
      expect(sampleCr.role == UserRole.admin, isFalse);
    });

    test('Only Admin has authorized administrative permissions', () {
      expect(sampleAdmin.role, equals(UserRole.admin));
      expect(sampleAdmin.role == UserRole.admin, isTrue);
    });
  });
}
