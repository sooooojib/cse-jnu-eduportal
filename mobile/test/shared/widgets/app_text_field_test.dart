import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/shared/widgets/inputs/app_text_field.dart';

void main() {
  group('AppTextField Widget', () {
    testWidgets('renders label, hint, and accepts user text input', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              controller: controller,
              label: 'Email Address',
              hint: 'Enter your email',
            ),
          ),
        ),
      );

      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'student@cse.jnu.ac.bd');
      expect(controller.text, 'student@cse.jnu.ac.bd');
    });

    testWidgets('password field obscures text and toggles visibility on icon tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Password',
              isPassword: true,
            ),
          ),
        ),
      );

      final editableTextFinder = find.byType(EditableText);
      EditableText editableText = tester.widget<EditableText>(editableTextFinder);
      expect(editableText.obscureText, isTrue);

      // Tap toggle icon
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      editableText = tester.widget<EditableText>(editableTextFinder);
      expect(editableText.obscureText, isFalse);
    });

    testWidgets('displays validation error message when validator fails', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AppTextField(
                label: 'Student ID',
                validator: (val) => val == null || val.isEmpty ? 'Student ID is required' : null,
              ),
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();

      expect(find.text('Student ID is required'), findsOneWidget);
    });
  });
}
