import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/shared/widgets/states/app_loading_view.dart';
import 'package:cse_jnu_eduportal/shared/widgets/states/app_empty_state_view.dart';
import 'package:cse_jnu_eduportal/shared/widgets/states/app_error_state_view.dart';

void main() {
  group('State Feedback Views', () {
    testWidgets('AppLoadingView renders indicator and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLoadingView(message: 'Loading timetable...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading timetable...'), findsOneWidget);
    });

    testWidgets('AppEmptyStateView renders title, message, and triggers action callback', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyStateView(
              title: 'No Classes Today',
              message: 'Enjoy your weekend!',
              actionText: 'View Schedule',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('No Classes Today'), findsOneWidget);
      expect(find.text('Enjoy your weekend!'), findsOneWidget);
      expect(find.text('View Schedule'), findsOneWidget);

      await tester.tap(find.text('View Schedule'));
      expect(actionTriggered, isTrue);
    });

    testWidgets('AppErrorStateView renders error info and triggers retry callback', (tester) async {
      bool retryTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorStateView(
              title: 'Connection Failed',
              message: 'Please try again later.',
              onRetry: () => retryTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('Connection Failed'), findsOneWidget);
      expect(find.text('Please try again later.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retryTriggered, isTrue);
    });
  });
}
