import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/shared/widgets/buttons/app_primary_button.dart';
import 'package:cse_jnu_eduportal/shared/widgets/buttons/app_secondary_button.dart';
import 'package:cse_jnu_eduportal/shared/widgets/buttons/app_text_button.dart';

void main() {
  group('Button Widgets', () {
    testWidgets('AppPrimaryButton renders text and fires callback on tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppPrimaryButton(
              text: 'Log In',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Log In'), findsOneWidget);
      await tester.tap(find.byType(AppPrimaryButton));
      expect(tapped, isTrue);
    });

    testWidgets('AppPrimaryButton displays loading spinner and disables taps when isLoading is true', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppPrimaryButton(
              text: 'Submit',
              isLoading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit'), findsNothing);

      await tester.tap(find.byType(AppPrimaryButton));
      expect(tapped, isFalse);
    });

    testWidgets('AppSecondaryButton renders with outlined border and text', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSecondaryButton(
              text: 'Cancel',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.byType(AppSecondaryButton));
      expect(tapped, isTrue);
    });

    testWidgets('AppTextButton renders text and triggers callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextButton(
              text: 'Need assistance?',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Need assistance?'), findsOneWidget);
      await tester.tap(find.byType(AppTextButton));
      expect(tapped, isTrue);
    });
  });
}
