import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cse_jnu_eduportal/app/theme/theme_controller.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/core/storage/local_storage_service.dart';
import 'package:cse_jnu_eduportal/features/admin/domain/repositories/admin_repository.dart';
import 'package:cse_jnu_eduportal/features/admin/presentation/screens/admin_management_screens.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:cse_jnu_eduportal/features/profile/data/models/semester_upgrade_request_model.dart';
import 'package:cse_jnu_eduportal/features/profile/domain/entities/semester_status.dart';
import 'package:cse_jnu_eduportal/features/profile/domain/repositories/semester_repository.dart';
import 'package:cse_jnu_eduportal/features/profile/presentation/controllers/profile_controller.dart';
import 'package:cse_jnu_eduportal/features/profile/presentation/screens/student_profile_screen.dart';

class MockSemesterRepository extends Mock implements SemesterRepository {}
class MockAdminRepository extends Mock implements AdminRepository {}
class MockAuthController extends Mock implements AuthController {}
class MockCurriculumRepository extends Mock implements CurriculumRepository {}
class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSemesterRepository mockSemesterRepo;
  late MockAdminRepository mockAdminRepo;
  late MockAuthController mockAuthController;
  late MockCurriculumRepository mockCurriculumRepo;
  late MockLocalStorageService mockStorage;

  final testStudent = User(
    id: 'student-001',
    fullName: 'Sajib Ahmed',
    email: 'sajib@cse.jnu.ac.bd',
    role: UserRole.student,
    studentId: 'B210305015',
    year: 3,
    semester: 1,
    isActive: true,
  );

  final pendingRequest = SemesterUpgradeRequest(
    id: 'req-001',
    studentId: 'student-001',
    studentName: 'Sajib Ahmed',
    studentRoll: 'B210305015',
    currentYear: 3,
    currentSemester: 1,
    requestedYear: 3,
    requestedSemester: 2,
    status: 'PENDING',
    createdAt: '2026-10-19T10:00:00Z',
  );

  setUp(() {
    mockSemesterRepo = MockSemesterRepository();
    mockAdminRepo = MockAdminRepository();
    mockAuthController = MockAuthController();
    mockCurriculumRepo = MockCurriculumRepository();
    mockStorage = MockLocalStorageService();

    when(() => mockAuthController.currentUser).thenReturn(testStudent);
    when(() => mockAuthController.addListener(any())).thenReturn(null);
    when(() => mockAuthController.removeListener(any())).thenReturn(null);
    when(() => mockStorage.getThemeMode()).thenReturn('system');
    when(() => mockCurriculumRepo.getMyCourses()).thenAnswer((_) async => []);

    if (sl.isRegistered<LocalStorageService>()) sl.unregister<LocalStorageService>();
    if (sl.isRegistered<ThemeController>()) sl.unregister<ThemeController>();
    if (sl.isRegistered<AuthController>()) sl.unregister<AuthController>();
    if (sl.isRegistered<GetMyCoursesUseCase>()) sl.unregister<GetMyCoursesUseCase>();
    if (sl.isRegistered<ProfileController>()) sl.unregister<ProfileController>();

    sl.registerLazySingleton<LocalStorageService>(() => mockStorage);
    sl.registerLazySingleton<ThemeController>(() => ThemeController(localStorageService: sl()));
    sl.registerLazySingleton<AuthController>(() => mockAuthController);
    sl.registerLazySingleton<GetMyCoursesUseCase>(() => GetMyCoursesUseCase(mockCurriculumRepo));
  });

  tearDown(() {
    sl.reset();
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. DOMAIN & MODEL TESTS
  // ─────────────────────────────────────────────────────────────────────────────
  group('1. SemesterStatus Entity & Model Tests', () {
    test('State 1: No enrollment state invariants', () {
      const statusNoEnroll = SemesterStatus(
        currentYear: null,
        currentSemester: null,
        status: 'NO_ENROLLMENT',
      );
      expect(statusNoEnroll.isNoEnrollment, isTrue);
      expect(statusNoEnroll.isPending, isFalse);
      expect(statusNoEnroll.isApproved, isFalse);
      expect(statusNoEnroll.isRejected, isFalse);

      const statusNone = SemesterStatus(
        currentYear: null,
        currentSemester: null,
        status: 'NONE',
      );
      expect(statusNone.isNoEnrollment, isTrue);
    });

    test('State 2: Pending request invariants', () {
      const statusPending = SemesterStatus(
        requestId: 'req-123',
        currentYear: 2,
        currentSemester: 2,
        requestedYear: 3,
        requestedSemester: 1,
        status: 'PENDING',
      );
      expect(statusPending.isPending, isTrue);
      expect(statusPending.hasPendingRequest, isTrue);
      expect(statusPending.isNoEnrollment, isFalse);
      expect(statusPending.isApproved, isFalse);
      expect(statusPending.isRejected, isFalse);
      expect(statusPending.requestId, 'req-123');
    });

    test('State 3: Approved / Active state invariants', () {
      const statusActive = SemesterStatus(
        currentYear: 3,
        currentSemester: 1,
        status: 'ACTIVE',
      );
      expect(statusActive.isApproved, isTrue);
      expect(statusActive.isPending, isFalse);
      expect(statusActive.isRejected, isFalse);
      expect(statusActive.isNoEnrollment, isFalse);

      const statusApproved = SemesterStatus(
        currentYear: 3,
        currentSemester: 2,
        status: 'APPROVED',
      );
      expect(statusApproved.isApproved, isTrue);
    });

    test('State 4: Rejected state invariants and dismissal metadata', () {
      const statusRejected = SemesterStatus(
        requestId: 'req-rejected-99',
        currentYear: 2,
        currentSemester: 2,
        requestedYear: 3,
        requestedSemester: 1,
        status: 'REJECTED',
        rejectionReason: 'Prerequisite courses not completed.',
      );
      expect(statusRejected.isRejected, isTrue);
      expect(statusRejected.isPending, isFalse);
      expect(statusRejected.isApproved, isFalse);
      expect(statusRejected.isNoEnrollment, isFalse);
      expect(statusRejected.rejectionReason, 'Prerequisite courses not completed.');
      expect(statusRejected.requestId, 'req-rejected-99');
    });

    test('SemesterUpgradeRequestModel serialization and deserialization', () {
      final json = {
        'id': 'req-999',
        'studentId': 'std-42',
        'studentName': 'Fatima Khan',
        'studentRoll': 'B200305001',
        'currentYear': 4,
        'currentSemester': 1,
        'requestedYear': 4,
        'requestedSemester': 2,
        'status': 'PENDING',
        'createdAt': '2026-10-15T08:30:00Z',
      };

      final model = SemesterUpgradeRequestModel.fromJson(json);
      expect(model.id, 'req-999');
      expect(model.studentId, 'std-42');
      expect(model.studentName, 'Fatima Khan');
      expect(model.studentRoll, 'B200305001');
      expect(model.requestedYear, 4);
      expect(model.requestedSemester, 2);
      expect(model.status, 'PENDING');

      final serialized = model.toJson();
      expect(serialized['id'], 'req-999');
      expect(serialized['studentName'], 'Fatima Khan');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. PROFILE CONTROLLER UNIT TESTS
  // ─────────────────────────────────────────────────────────────────────────────
  group('2. ProfileController Workflow Tests', () {
    test('fetchSemesterStatus updates state to ProfileLoaded on success', () async {
      const sampleStatus = SemesterStatus(
        currentYear: 3,
        currentSemester: 1,
        status: 'ACTIVE',
      );
      when(() => mockSemesterRepo.getStatus()).thenAnswer((_) async => sampleStatus);

      final controller = ProfileController(
        getSemesterStatusUseCase: GetSemesterStatusUseCase(mockSemesterRepo),
        requestSemesterUpgradeUseCase: RequestSemesterUpgradeUseCase(mockSemesterRepo),
        changeSemesterUpgradeRequestUseCase: ChangeSemesterUpgradeRequestUseCase(mockSemesterRepo),
        dismissSemesterRejectionUseCase: DismissSemesterRejectionUseCase(mockSemesterRepo),
      );

      expect(controller.state, isA<ProfileInitial>());
      await controller.fetchSemesterStatus();

      expect(controller.state, isA<ProfileLoaded>());
      final loaded = controller.state as ProfileLoaded;
      expect(loaded.semesterStatus.currentYear, 3);
      expect(loaded.semesterStatus.isApproved, isTrue);
    });

    test('fetchSemesterStatus handles error gracefully', () async {
      when(() => mockSemesterRepo.getStatus()).thenThrow(Exception('Network timeout'));

      final controller = ProfileController(
        getSemesterStatusUseCase: GetSemesterStatusUseCase(mockSemesterRepo),
        requestSemesterUpgradeUseCase: RequestSemesterUpgradeUseCase(mockSemesterRepo),
      );

      await controller.fetchSemesterStatus();
      expect(controller.state, isA<ProfileError>());
      expect((controller.state as ProfileError).message, contains('Network timeout'));
    });

    test('requestUpgrade transitions state to pending request', () async {
      const pendingStatus = SemesterStatus(
        requestId: 'req-new',
        currentYear: 3,
        currentSemester: 1,
        requestedYear: 3,
        requestedSemester: 2,
        status: 'PENDING',
      );
      when(() => mockSemesterRepo.requestUpgrade(
            requestedYear: 3,
            requestedSemester: 2,
          )).thenAnswer((_) async => pendingStatus);

      final controller = ProfileController(
        getSemesterStatusUseCase: GetSemesterStatusUseCase(mockSemesterRepo),
        requestSemesterUpgradeUseCase: RequestSemesterUpgradeUseCase(mockSemesterRepo),
      );

      final success = await controller.requestUpgrade(requestedYear: 3, requestedSemester: 2);
      expect(success, isTrue);
      expect(controller.state, isA<ProfileLoaded>());
      final loaded = controller.state as ProfileLoaded;
      expect(loaded.semesterStatus.isPending, isTrue);
      expect(loaded.semesterStatus.requestedYear, 3);
      expect(loaded.semesterStatus.requestedSemester, 2);
    });

    test('changeUpgradeRequest updates existing pending request target semester', () async {
      const changedStatus = SemesterStatus(
        requestId: 'req-001',
        currentYear: 3,
        currentSemester: 1,
        requestedYear: 4,
        requestedSemester: 1,
        status: 'PENDING',
      );
      when(() => mockSemesterRepo.changeUpgradeRequest(
            requestId: 'req-001',
            requestedYear: 4,
            requestedSemester: 1,
          )).thenAnswer((_) async => changedStatus);

      final controller = ProfileController(
        getSemesterStatusUseCase: GetSemesterStatusUseCase(mockSemesterRepo),
        requestSemesterUpgradeUseCase: RequestSemesterUpgradeUseCase(mockSemesterRepo),
        changeSemesterUpgradeRequestUseCase: ChangeSemesterUpgradeRequestUseCase(mockSemesterRepo),
      );

      final success = await controller.changeUpgradeRequest(
        requestId: 'req-001',
        requestedYear: 4,
        requestedSemester: 1,
      );
      expect(success, isTrue);
      expect(controller.state, isA<ProfileLoaded>());
      final loaded = controller.state as ProfileLoaded;
      expect(loaded.semesterStatus.requestedYear, 4);
      expect(loaded.semesterStatus.requestedSemester, 1);
    });

    test('dismissRejection calls repository and refreshes status to clean state', () async {
      const activeStatus = SemesterStatus(
        currentYear: 3,
        currentSemester: 1,
        status: 'ACTIVE',
      );
      when(() => mockSemesterRepo.dismissRejection(requestId: 'req-rej-1')).thenAnswer((_) async {});
      when(() => mockSemesterRepo.getStatus()).thenAnswer((_) async => activeStatus);

      final controller = ProfileController(
        getSemesterStatusUseCase: GetSemesterStatusUseCase(mockSemesterRepo),
        requestSemesterUpgradeUseCase: RequestSemesterUpgradeUseCase(mockSemesterRepo),
        changeSemesterUpgradeRequestUseCase: ChangeSemesterUpgradeRequestUseCase(mockSemesterRepo),
        dismissSemesterRejectionUseCase: DismissSemesterRejectionUseCase(mockSemesterRepo),
      );

      final success = await controller.dismissRejection(requestId: 'req-rej-1');
      expect(success, isTrue);
      verify(() => mockSemesterRepo.dismissRejection(requestId: 'req-rej-1')).called(1);
      verify(() => mockSemesterRepo.getStatus()).called(1);
      expect(controller.state, isA<ProfileLoaded>());
      expect((controller.state as ProfileLoaded).semesterStatus.isApproved, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. STUDENT PROFILE SCREEN WIDGET TESTS (ALL 4 STATES)
  // ─────────────────────────────────────────────────────────────────────────────
  group('3. StudentProfileScreen Semester UI Workflow (4 States)', () {
    testWidgets('State 1: Renders No Enrollment state and opens initial enrollment dialog', (tester) async {
      const noEnrollStatus = SemesterStatus(
        currentYear: null,
        currentSemester: null,
        status: 'NO_ENROLLMENT',
      );
      when(() => mockSemesterRepo.getStatus()).thenAnswer((_) async => noEnrollStatus);

      final controller = ProfileController(
        getSemesterStatusUseCase: GetSemesterStatusUseCase(mockSemesterRepo),
        requestSemesterUpgradeUseCase: RequestSemesterUpgradeUseCase(mockSemesterRepo),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentProfileScreen(profileController: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NO ENROLLMENT'), findsOneWidget);
      expect(find.text('Current Enrolled: Not Enrolled'), findsOneWidget);
      expect(find.text('Submit Initial Enrollment Request'), findsOneWidget);

      await tester.tap(find.text('Submit Initial Enrollment Request'));
      await tester.pumpAndSettle();

      expect(find.text('Initial Semester Enrollment'), findsOneWidget);
      expect(find.text('Target Year'), findsOneWidget);
      expect(find.text('Target Semester'), findsOneWidget);
    });

    testWidgets('State 2: Renders Pending state and opens Change Request dialog', (tester) async {
      const pendingStatus = SemesterStatus(
        requestId: 'req-pending-1',
        currentYear: 3,
        currentSemester: 1,
        requestedYear: 3,
        requestedSemester: 2,
        status: 'PENDING',
      );
      when(() => mockSemesterRepo.getStatus()).thenAnswer((_) async => pendingStatus);

      final controller = ProfileController(
        getSemesterStatusUseCase: GetSemesterStatusUseCase(mockSemesterRepo),
        requestSemesterUpgradeUseCase: RequestSemesterUpgradeUseCase(mockSemesterRepo),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentProfileScreen(profileController: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PENDING'), findsOneWidget);
      expect(find.textContaining('Upgrade request to Year 3, Sem 2 is pending'), findsOneWidget);
      expect(find.text('Change Request'), findsOneWidget);

      await tester.tap(find.text('Change Request'));
      await tester.pumpAndSettle();

      expect(find.text('Change Enrollment Request'), findsOneWidget);
      expect(find.text('Update Request'), findsOneWidget);
    });

    testWidgets('State 3: Renders Active/Approved state and allows requesting upgrade', (tester) async {
      const activeStatus = SemesterStatus(
        currentYear: 3,
        currentSemester: 1,
        status: 'ACTIVE',
      );
      when(() => mockSemesterRepo.getStatus()).thenAnswer((_) async => activeStatus);

      final controller = ProfileController(
        getSemesterStatusUseCase: GetSemesterStatusUseCase(mockSemesterRepo),
        requestSemesterUpgradeUseCase: RequestSemesterUpgradeUseCase(mockSemesterRepo),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentProfileScreen(profileController: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Current Enrolled: Year 3, Semester 1'), findsOneWidget);
      expect(find.text('Request Semester Upgrade'), findsOneWidget);

      await tester.tap(find.text('Request Semester Upgrade'));
      await tester.pumpAndSettle();

      expect(find.text('Request Semester Upgrade'), findsNWidgets(2)); // Card label + dialog title
      expect(find.text('Submit Request'), findsOneWidget);
    });

    testWidgets('State 4: Renders Rejected state with reason, Dismiss and Re-apply buttons', (tester) async {
      const rejectedStatus = SemesterStatus(
        requestId: 'req-rej-42',
        currentYear: 3,
        currentSemester: 1,
        requestedYear: 3,
        requestedSemester: 2,
        status: 'REJECTED',
        rejectionReason: 'Fee payment pending for current semester.',
      );
      when(() => mockSemesterRepo.getStatus()).thenAnswer((_) async => rejectedStatus);
      when(() => mockSemesterRepo.dismissRejection(requestId: 'req-rej-42')).thenAnswer((_) async {});

      final controller = ProfileController(
        getSemesterStatusUseCase: GetSemesterStatusUseCase(mockSemesterRepo),
        requestSemesterUpgradeUseCase: RequestSemesterUpgradeUseCase(mockSemesterRepo),
        dismissSemesterRejectionUseCase: DismissSemesterRejectionUseCase(mockSemesterRepo),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentProfileScreen(profileController: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.textContaining('Reason: Fee payment pending for current semester.'), findsOneWidget);
      expect(find.text('Dismiss Rejection'), findsOneWidget);
      expect(find.text('Re-apply'), findsOneWidget);

      await tester.tap(find.text('Dismiss Rejection'));
      await tester.pumpAndSettle();

      verify(() => mockSemesterRepo.dismissRejection(requestId: 'req-rej-42')).called(1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. ADMIN SEMESTER REQUESTS SCREEN WORKFLOW TESTS
  // ─────────────────────────────────────────────────────────────────────────────
  group('4. Admin Semester Requests Screen Workflow Tests', () {
    testWidgets('Renders petitions list and filter chips', (tester) async {
      when(() => mockAdminRepo.getAllSemesterRequests(statusFilter: any(named: 'statusFilter')))
          .thenAnswer((_) async => [pendingRequest]);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSemesterRequestsScreen(repository: mockAdminRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Semester Promotion Petitions'), findsOneWidget);
      expect(find.text('PENDING'), findsWidgets);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);

      expect(find.text('Sajib Ahmed'), findsOneWidget);
      expect(find.textContaining('Y3S1 ➔ Y3S2'), findsOneWidget);
    });

    testWidgets('Tapping request card opens Request Details modal', (tester) async {
      when(() => mockAdminRepo.getAllSemesterRequests(statusFilter: any(named: 'statusFilter')))
          .thenAnswer((_) async => [pendingRequest]);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSemesterRequestsScreen(repository: mockAdminRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the card
      await tester.tap(find.text('Sajib Ahmed'));
      await tester.pumpAndSettle();

      expect(find.text('Request Details'), findsOneWidget);
      expect(find.text('Current Standing'), findsOneWidget);
      expect(find.text('Requested Standing'), findsOneWidget);
      expect(find.text('Year 3, Semester 1'), findsOneWidget);
      expect(find.text('Year 3, Semester 2'), findsOneWidget);
      expect(find.text('Approve Promotion'), findsOneWidget);
      expect(find.text('Reject Petition'), findsOneWidget);
    });

    testWidgets('Approving petition calls repository and displays feedback', (tester) async {
      when(() => mockAdminRepo.getAllSemesterRequests(statusFilter: any(named: 'statusFilter')))
          .thenAnswer((_) async => [pendingRequest]);
      when(() => mockAdminRepo.approveSemesterUpgrade(requestId: 'req-001')).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSemesterRequestsScreen(repository: mockAdminRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Approve button directly on list card
      await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Approve Semester Upgrade?'), findsOneWidget);
      await tester.tap(find.text('Approve Promotion'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.approveSemesterUpgrade(requestId: 'req-001')).called(1);
      expect(find.text('Sajib Ahmed promoted successfully.'), findsOneWidget);
    });

    testWidgets('Rejecting petition prompts for reason and calls repository', (tester) async {
      when(() => mockAdminRepo.getAllSemesterRequests(statusFilter: any(named: 'statusFilter')))
          .thenAnswer((_) async => [pendingRequest]);
      when(() => mockAdminRepo.rejectSemesterUpgrade(
            requestId: 'req-001',
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSemesterRequestsScreen(repository: mockAdminRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Reject button directly on list card
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
      await tester.pumpAndSettle();

      expect(find.text('Reject Semester Request'), findsOneWidget);
      expect(find.text('Rejection Reason'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Reject'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.rejectSemesterUpgrade(
            requestId: 'req-001',
            reason: any(named: 'reason'),
          )).called(1);
      expect(find.textContaining('Rejected request for Sajib Ahmed'), findsOneWidget);
    });

    testWidgets('Prevents double-processing gracefully when repository throws error', (tester) async {
      when(() => mockAdminRepo.getAllSemesterRequests(statusFilter: any(named: 'statusFilter')))
          .thenAnswer((_) async => [pendingRequest]);
      when(() => mockAdminRepo.approveSemesterUpgrade(requestId: 'req-001')).thenThrow(
        Exception('This request has already been processed with status APPROVED. Cannot process twice.'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSemesterRequestsScreen(repository: mockAdminRepo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve Promotion'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cannot process twice'), findsOneWidget);
    });
  });
}
