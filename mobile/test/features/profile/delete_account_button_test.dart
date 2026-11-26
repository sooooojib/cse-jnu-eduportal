import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/features/auth/data/services/account_deletion_service.dart';
import 'package:cse_jnu_eduportal/features/profile/presentation/widgets/delete_account_button.dart';

class _MockService extends Mock implements AccountDeletionService {}

void main() {
  late _MockService service;
  late bool deleted;

  Future<void> pump(WidgetTester tester) async {
    deleted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DeleteAccountButton(service: service, onDeleted: () async => deleted = true),
      ),
    ));
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
  }

  setUp(() => service = _MockService());

  testWidgets('asks for the password before deleting', (tester) async {
    await pump(tester);
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your password.'), findsOneWidget);
    verifyNever(() => service.deleteMyAccount(password: any(named: 'password')));
  });

  testWidgets('shows the reason and stays open when deletion is refused', (tester) async {
    when(() => service.deleteMyAccount(password: any(named: 'password')))
        .thenThrow(const AccountDeletionException('Wrong password.'));
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'nope');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong password.'), findsOneWidget);
    expect(deleted, isFalse);
  });

  testWidgets('deletes and signs out on success', (tester) async {
    when(() => service.deleteMyAccount(password: any(named: 'password'))).thenAnswer((_) async {});
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'secret123');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    verify(() => service.deleteMyAccount(password: 'secret123')).called(1);
    expect(deleted, isTrue);
    expect(find.text('Delete your account?'), findsNothing);
  });
}
