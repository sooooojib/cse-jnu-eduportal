import 'dart:async';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/cr/data/repositories/cr_transfer_repository.dart';
import 'package:cse_jnu_eduportal/features/cr/domain/entities/cr_transfer.dart';
import 'package:cse_jnu_eduportal/features/cr/presentation/screens/my_class_screen.dart';
import 'package:cse_jnu_eduportal/features/cr/presentation/widgets/cr_transfer_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthController extends Mock implements AuthController {}

/// In-memory fake that mimics the Firestore-backed repository.
class FakeCrTransferRepository implements CrTransferRepository {
  List<User> classmates;
  final _outgoing = StreamController<CrTransfer?>.broadcast();
  final _incoming = StreamController<List<CrTransfer>>.broadcast();
  CrTransfer? lastRequested;
  CrTransfer? accepted;
  CrTransfer? declined;
  bool cancelled = false;
  List<CrTransfer> initialIncoming;

  FakeCrTransferRepository({this.classmates = const [], this.initialIncoming = const []});

  @override
  Future<List<User>> getClassmates(User me) async => classmates;

  @override
  Stream<CrTransfer?> watchOutgoing(String fromUid) => _outgoing.stream;

  @override
  Stream<List<CrTransfer>> watchIncoming(String toUid) async* {
    yield initialIncoming;
    yield* _incoming.stream;
  }

  void emitOutgoing(CrTransfer? t) => _outgoing.add(t);

  @override
  Future<void> requestTransfer({required User from, required User to}) async {
    lastRequested = CrTransfer(
      fromUid: from.id, fromName: from.fullName, toUid: to.id, toName: to.fullName,
      year: from.year!, semester: from.semester!, session: from.session!, status: CrTransferStatus.pending,
    );
    emitOutgoing(lastRequested);
  }

  @override
  Future<void> cancel(String fromUid) async {
    cancelled = true;
    emitOutgoing(null);
  }

  @override
  Future<void> decline(CrTransfer transfer) async => declined = transfer;

  @override
  Future<void> accept(CrTransfer transfer, {required String myUid}) async => accepted = transfer;
}

const cr = User(
  id: 'cr', email: 'cr@x.bd', fullName: 'Old CR', role: UserRole.cr,
  studentId: 'B21001', year: 3, semester: 1, session: '2021-2022',
);
const alice = User(
  id: 'alice', email: 'a@x.bd', fullName: 'Alice Rahman', role: UserRole.student,
  studentId: 'B21002', year: 3, semester: 1, session: '2021-2022',
);
const bob = User(
  id: 'bob', email: 'b@x.bd', fullName: 'Bob Hasan', role: UserRole.student,
  studentId: 'B21003', year: 3, semester: 1, session: '2021-2022',
);

void main() {
  late MockAuthController auth;

  setUp(() {
    auth = MockAuthController();
    when(() => auth.refreshCurrentUser()).thenAnswer((_) async {});
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('My Class (CR)', () {
    testWidgets('lists classmates of the same semester & session and sends a transfer request', (tester) async {
      when(() => auth.currentUser).thenReturn(cr);
      final repo = FakeCrTransferRepository(classmates: [alice, bob]);

      await tester.pumpWidget(MaterialApp(home: MyClassScreen(repository: repo, authController: auth)));
      await tester.pumpAndSettle();

      expect(find.text('Year 3 · Semester 1 · Session 2021-2022'), findsOneWidget);
      expect(find.text('Alice Rahman'), findsOneWidget);
      expect(find.text('Bob Hasan'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('make_cr_alice')));
      await tester.pumpAndSettle();
      expect(find.text('Transfer CR role?'), findsOneWidget);
      await tester.tap(find.text('Send Request'));
      await tester.pumpAndSettle();

      expect(repo.lastRequested?.toUid, 'alice');
      // Pending banner appears and further offers are disabled until it resolves.
      expect(find.byKey(const ValueKey('cr_transfer_pending_banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('make_cr_bob')), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.cancelled, isTrue);
    });

    testWidgets('search filters classmates', (tester) async {
      when(() => auth.currentUser).thenReturn(cr);
      final repo = FakeCrTransferRepository(classmates: [alice, bob]);
      await tester.pumpWidget(MaterialApp(home: MyClassScreen(repository: repo, authController: auth)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bob');
      await tester.pumpAndSettle();
      expect(find.text('Bob Hasan'), findsOneWidget);
      expect(find.text('Alice Rahman'), findsNothing);
    });

    testWidgets('explains when the CR has no session', (tester) async {
      when(() => auth.currentUser).thenReturn(const User(
        id: 'cr2', email: 'c@x.bd', fullName: 'No Session CR', role: UserRole.cr, year: 3, semester: 1,
      ));
      await tester.pumpWidget(MaterialApp(
        home: MyClassScreen(repository: FakeCrTransferRepository(), authController: auth),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Session Not Set'), findsOneWidget);
    });

    testWidgets('old CR app reloads its profile when the classmate accepts', (tester) async {
      when(() => auth.currentUser).thenReturn(cr);
      final repo = FakeCrTransferRepository(classmates: [alice]);
      await tester.pumpWidget(wrap(MyClassCard(repository: repo, authController: auth)));
      await tester.pump();

      repo.emitOutgoing(const CrTransfer(
        fromUid: 'cr', fromName: 'Old CR', toUid: 'alice', toName: 'Alice Rahman',
        year: 3, semester: 1, session: '2021-2022', status: CrTransferStatus.accepted,
      ));
      await tester.pump();
      verify(() => auth.refreshCurrentUser()).called(1);
    });
  });

  group('CR role invitation (student)', () {
    const offer = CrTransfer(
      fromUid: 'cr', fromName: 'Old CR', toUid: 'alice', toName: 'Alice Rahman',
      year: 3, semester: 1, session: '2021-2022', status: CrTransferStatus.pending,
    );

    testWidgets('student accepts and the app reloads into the CR role', (tester) async {
      when(() => auth.currentUser).thenReturn(alice);
      final repo = FakeCrTransferRepository(initialIncoming: [offer]);
      await tester.pumpWidget(wrap(CrTransferInvitationCard(repository: repo, authController: auth)));
      await tester.pumpAndSettle();

      expect(find.text('CR Role Offered'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(find.text('Become the Class Representative?'), findsOneWidget);
      await tester.tap(find.text('Accept').last);
      await tester.pumpAndSettle();

      expect(repo.accepted, offer);
      verify(() => auth.refreshCurrentUser()).called(1);
    });

    testWidgets('student declines', (tester) async {
      when(() => auth.currentUser).thenReturn(alice);
      final repo = FakeCrTransferRepository(initialIncoming: [offer]);
      await tester.pumpWidget(wrap(CrTransferInvitationCard(repository: repo, authController: auth)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decline').last);
      await tester.pumpAndSettle();

      expect(repo.declined, offer);
      expect(repo.accepted, isNull);
    });

    testWidgets('shows nothing when there is no offer', (tester) async {
      when(() => auth.currentUser).thenReturn(bob);
      await tester.pumpWidget(wrap(CrTransferInvitationCard(repository: FakeCrTransferRepository(), authController: auth)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cr_transfer_invitation')), findsNothing);
    });
  });

  group('My Class (student)', () {
    const offer = CrTransfer(
      fromUid: 'cr', fromName: 'Old CR', toUid: 'alice', toName: 'Alice Rahman',
      year: 3, semester: 1, session: '2021-2022', status: CrTransferStatus.pending,
    );

    testWidgets('student sees every classmate with their role, but cannot offer the CR role', (tester) async {
      when(() => auth.currentUser).thenReturn(alice);
      final repo = FakeCrTransferRepository(classmates: [cr, bob]);
      await tester.pumpWidget(MaterialApp(home: MyClassScreen(repository: repo, authController: auth)));
      await tester.pumpAndSettle();

      expect(find.text('Alice Rahman (You)'), findsOneWidget);
      expect(find.text('Old CR'), findsOneWidget);
      expect(find.text('Bob Hasan'), findsOneWidget);
      // Role badges: one CR, the rest Students.
      expect(find.descendant(of: find.byKey(const ValueKey('classmate_cr')), matching: find.text('CR')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('classmate_bob')), matching: find.text('Student')), findsOneWidget);
      expect(find.text('3 students · 1 CR'), findsOneWidget);
      // No transfer actions for students.
      expect(find.textContaining('Make CR'), findsNothing);
    });

    testWidgets('CR Requests tab shows the offer with a count badge and lets the student accept', (tester) async {
      when(() => auth.currentUser).thenReturn(alice);
      final repo = FakeCrTransferRepository(classmates: [cr, bob], initialIncoming: [offer]);
      await tester.pumpWidget(MaterialApp(home: MyClassScreen(repository: repo, authController: auth)));
      await tester.pumpAndSettle();

      // Count badge on the tab.
      expect(find.descendant(of: find.byKey(const ValueKey('cr_requests_tab')), matching: find.text('1')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('cr_requests_tab')));
      await tester.pumpAndSettle();
      expect(find.text('CR Role Offered'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept').last);
      await tester.pumpAndSettle();
      expect(repo.accepted, offer);
      verify(() => auth.refreshCurrentUser()).called(1);
    });

    testWidgets('opens directly on the CR Requests tab and shows an empty state when there is no offer', (tester) async {
      when(() => auth.currentUser).thenReturn(bob);
      await tester.pumpWidget(MaterialApp(
        home: MyClassScreen(repository: FakeCrTransferRepository(), authController: auth, initialTab: 1),
      ));
      await tester.pumpAndSettle();
      expect(find.text('No CR Requests'), findsOneWidget);
    });

    testWidgets('CR sees their pending offer in the Requests tab and can cancel it', (tester) async {
      when(() => auth.currentUser).thenReturn(cr);
      final repo = FakeCrTransferRepository(classmates: [alice]);
      await tester.pumpWidget(MaterialApp(home: MyClassScreen(repository: repo, authController: auth, initialTab: 1)));
      await tester.pumpAndSettle();
      expect(find.text('No Active Request'), findsOneWidget);

      repo.emitOutgoing(const CrTransfer(
        fromUid: 'cr', fromName: 'Old CR', toUid: 'alice', toName: 'Alice Rahman',
        year: 3, semester: 1, session: '2021-2022', status: CrTransferStatus.pending,
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cr_outgoing_request')), findsOneWidget);
      expect(find.text('Waiting for reply'), findsOneWidget);

      await tester.tap(find.text('Cancel Request'));
      await tester.pumpAndSettle();
      expect(repo.cancelled, isTrue);
    });

    testWidgets('dashboard My Class card highlights an offer for the student', (tester) async {
      when(() => auth.currentUser).thenReturn(alice);
      final repo = FakeCrTransferRepository(initialIncoming: [offer]);
      await tester.pumpWidget(wrap(MyClassCard(repository: repo, authController: auth)));
      await tester.pumpAndSettle();
      expect(find.text('CR offer'), findsOneWidget);
      expect(find.textContaining('offered you the CR role'), findsOneWidget);
    });
  });
}
