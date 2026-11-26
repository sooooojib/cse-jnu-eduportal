import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/features/admin/domain/repositories/admin_repository.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/signup_request.dart';
import 'package:cse_jnu_eduportal/features/profile/data/models/semester_upgrade_request_model.dart';
import 'package:cse_jnu_eduportal/features/profile/domain/entities/semester_status.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/widgets/teacher_requests_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAdminRepository extends Mock implements AdminRepository {}

void main() {
  late MockAdminRepository repo;

  const student = SignupRequest(
    id: 'req_s', email: 'new@x.bd', fullName: 'Sumaiya Akter Mim', role: UserRole.student,
    studentId: 'B220305029', session: '2022-2023', status: 'PENDING', createdAt: '2026-11-26T10:00:00Z',
  );
  const teacher = SignupRequest(
    id: 'req_t', email: 't@x.bd', fullName: 'Dr. New Teacher', role: UserRole.teacher,
    status: 'PENDING', createdAt: '2026-11-26T10:00:00Z',
  );
  const good = SemesterUpgradeRequest(
    id: 'sem_ok', studentId: 's1', studentName: 'Kazi Mahfuzur Rahman', studentRoll: 'B210305002',
    currentYear: 2, currentSemester: 2, requestedYear: 3, requestedSemester: 1, status: 'PENDING',
    createdAt: '2026-11-26T10:00:00Z',
  );
  const missing = SemesterUpgradeRequest(
    id: 'sem_missing', studentId: 's2', studentName: 'Fatima Zohra', studentRoll: '2023CSE012',
    currentYear: 2, currentSemester: 1, requestedYear: 0, requestedSemester: 0, status: 'PENDING',
    createdAt: '2026-11-26T10:00:00Z',
  );

  setUp(() {
    repo = MockAdminRepository();
    when(() => repo.getPendingSignupRequests()).thenAnswer((_) async => [student, teacher]);
    when(() => repo.getPendingSemesterRequests()).thenAnswer((_) async => [good, missing]);
    when(() => repo.approveSemesterUpgrade(requestId: any(named: 'requestId'))).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: DelegateAdminView(repository: repo))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('two tabs with counts; teacher signups are not listed', (tester) async {
    await pump(tester);
    expect(find.text('Signups (1)'), findsOneWidget);
    expect(find.text('Semester (2)'), findsOneWidget);
    expect(find.text('Sumaiya Akter Mim'), findsOneWidget);
    expect(find.text('Dr. New Teacher'), findsNothing);

    await tester.tap(find.text('Semester (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Kazi Mahfuzur Rahman'), findsOneWidget);
    expect(find.textContaining('Year 3 · Sem 1', findRichText: true), findsOneWidget);
    expect(find.textContaining('Requested semester missing', findRichText: true), findsOneWidget);
  });

  testWidgets('filters: signups by session, semester requests by current semester', (tester) async {
    const other = SignupRequest(
      id: 'req_o', email: 'o@x.bd', fullName: 'Older Batch Student', role: UserRole.student,
      studentId: 'B200305001', session: '2020-2021', status: 'PENDING', createdAt: '2026-11-20T10:00:00Z',
    );
    when(() => repo.getPendingSignupRequests()).thenAnswer((_) async => [student, other, teacher]);
    await pump(tester);

    // Signups tab: session dropdown.
    expect(find.text('Sumaiya Akter Mim'), findsOneWidget);
    expect(find.text('Older Batch Student'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('requests_session_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2020-2021').last);
    await tester.pumpAndSettle();
    expect(find.text('Older Batch Student'), findsOneWidget);
    expect(find.text('Sumaiya Akter Mim'), findsNothing);
    expect(find.text('Signups (2)'), findsOneWidget); // tab count stays the total

    // Semester tab: current-semester dropdown.
    await tester.tap(find.text('Semester (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('requests_level_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Year 2 · Sem 2').last);
    await tester.pumpAndSettle();
    expect(find.text('Kazi Mahfuzur Rahman'), findsOneWidget);
    expect(find.text('Fatima Zohra'), findsNothing);
  });

  testWidgets('tapping a semester request opens details; Approve moves the student', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Semester (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('semester_sem_ok')));
    await tester.pumpAndSettle();
    expect(find.text('Wants'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('request_approve')));
    await tester.pumpAndSettle();
    verify(() => repo.approveSemesterUpgrade(requestId: 'sem_ok')).called(1);
  });

  testWidgets('a request with no requested semester can only be rejected', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Semester (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('semester_sem_missing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('request_approve')), findsNothing);
    expect(find.byKey(const ValueKey('request_reject')), findsOneWidget);
    expect(find.textContaining('can only be rejected'), findsOneWidget);
  });

  test('older requests stored as targetYear / targetSemester read correctly', () {
    final m = SemesterUpgradeRequestModel.fromJson({
      'id': 'x', 'studentId': 's', 'studentName': 'A', 'currentYear': 3, 'currentSemester': 1,
      'targetYear': 3, 'targetSemester': 2, 'status': 'PENDING', 'notes': 'Passed finals',
    });
    expect(m.requestedLabel, 'Year 3 · Sem 2');
    expect(m.notes, 'Passed finals');
    final none = SemesterUpgradeRequestModel.fromJson({'id': 'y', 'studentId': 's', 'status': 'PENDING'});
    expect(none.hasRequestedLevel, isFalse);
  });
}
