import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/shared/widgets/cards/role_badge_chip.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';

void main() {
  group('RoleBadgeChip Widget', () {
    testWidgets('renders correct label for all roles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RoleBadgeChip(role: UserRole.student),
                RoleBadgeChip(role: UserRole.teacher),
                RoleBadgeChip(role: UserRole.cr),
                RoleBadgeChip(role: UserRole.admin),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Student'), findsOneWidget);
      expect(find.text('Professor / Faculty'), findsOneWidget);
      expect(find.text('Class Representative'), findsOneWidget);
      expect(find.text('Administrator'), findsOneWidget);
    });
  });
}
