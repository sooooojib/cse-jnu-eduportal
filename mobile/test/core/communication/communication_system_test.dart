import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cse_jnu_eduportal/core/utils/bangladeshi_phone_utils.dart';
import 'package:cse_jnu_eduportal/core/communication/whatsapp_share_service.dart';
import 'package:cse_jnu_eduportal/core/communication/whatsapp_share_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('STAGE 28: Bangladeshi Phone Number Normalization Tests', () {
    test('1. Cleans punctuation, dashes, spaces and international prefix', () {
      expect(BangladeshiPhoneUtils.clean('+880 1712-345 678'), '+8801712345678');
      expect(BangladeshiPhoneUtils.clean('(018) 12-345678'), '01812345678');
      expect(BangladeshiPhoneUtils.clean(''), '');
      expect(BangladeshiPhoneUtils.clean(null), '');
    });

    test('2. Accurately identifies all authorized BD operators', () {
      // Grameenphone
      final gp = BangladeshiPhoneUtils.normalize('01712345678');
      expect(gp.isValid, isTrue);
      expect(gp.operator, 'Grameenphone');
      expect(gp.national, '01712345678');
      expect(gp.international, '+8801712345678');
      expect(gp.whatsAppNumber, '8801712345678');

      final gp2 = BangladeshiPhoneUtils.normalize('+8801311223344');
      expect(gp2.isValid, isTrue);
      expect(gp2.operator, 'Grameenphone');

      // Banglalink
      final bl = BangladeshiPhoneUtils.normalize('01912345678');
      expect(bl.isValid, isTrue);
      expect(bl.operator, 'Banglalink');

      final bl2 = BangladeshiPhoneUtils.normalize('8801400112233');
      expect(bl2.isValid, isTrue);
      expect(bl2.operator, 'Banglalink');

      // Robi & Airtel
      final robi = BangladeshiPhoneUtils.normalize('01812345678');
      expect(robi.isValid, isTrue);
      expect(robi.operator, 'Robi');

      final airtel = BangladeshiPhoneUtils.normalize('01612345678');
      expect(airtel.isValid, isTrue);
      expect(airtel.operator, 'Robi');

      // Teletalk
      final tt = BangladeshiPhoneUtils.normalize('01512345678');
      expect(tt.isValid, isTrue);
      expect(tt.operator, 'Teletalk');
    });

    test('3. Rejects invalid operator prefixes and wrong lengths', () {
      final invalidPrefix = BangladeshiPhoneUtils.normalize('01112345678');
      expect(invalidPrefix.isValid, isFalse);
      expect(invalidPrefix.error, contains('Invalid operator prefix'));

      final tooShort = BangladeshiPhoneUtils.normalize('0171234');
      expect(tooShort.isValid, isFalse);
      expect(tooShort.error, contains('11 digits'));

      final tooLong = BangladeshiPhoneUtils.normalize('01712345678999');
      expect(tooLong.isValid, isFalse);

      expect(BangladeshiPhoneUtils.isValid('01712345678'), isTrue);
      expect(BangladeshiPhoneUtils.isValid('01112345678'), isFalse);
    });

    test('4. Formats display representation', () {
      expect(BangladeshiPhoneUtils.formatDisplay('01712345678'), '01712-345678');
      expect(BangladeshiPhoneUtils.formatDisplay('+8801812345678'), '01812-345678');
      expect(BangladeshiPhoneUtils.toWhatsAppNumber('+880 1712-345678'), '8801712345678');
    });
  });

  group('STAGE 28: WhatsAppShareService Deep Link & Isolation Tests', () {
    test('5. buildNativeAppUri and buildWebUri encode text and phone correctly', () {
      const routine = 'CSE JnU Routine:\nCSE 3101 at 10:00 AM';
      final nativeUri = WhatsAppShareService.buildNativeAppUri(
        text: routine,
        recipientPhone: '01712345678',
      );

      expect(nativeUri.scheme, 'whatsapp');
      expect(nativeUri.host, 'send');
      expect(nativeUri.queryParameters['phone'], '8801712345678');
      expect(nativeUri.queryParameters['text'], routine);

      final webUri = WhatsAppShareService.buildWebUri(
        text: routine,
        recipientPhone: '+8801712345678',
      );

      expect(webUri.host, 'wa.me');
      expect(webUri.path, '/8801712345678');
      expect(webUri.queryParameters['text'], routine);
    });

    test('6. shareRoutine successfully opens native WhatsApp when available', () async {
      final service = WhatsAppShareService(
        launchHandler: (uri, {mode = LaunchMode.platformDefault}) async {
          if (uri.scheme == 'whatsapp') return true;
          return false;
        },
      );

      final res = await service.shareRoutine(
        text: 'Tomorrow Routine',
        recipientPhone: '01712345678',
      );

      expect(res.success, isTrue);
      expect(res.method, WhatsAppShareMethod.nativeApp);
      expect(res.deepLinkUsed, contains('whatsapp://send?phone=8801712345678'));
    });

    test('7. shareRoutine cascades to Web/wa.me when native app is not installed', () async {
      final service = WhatsAppShareService(
        launchHandler: (uri, {mode = LaunchMode.platformDefault}) async {
          if (uri.scheme == 'whatsapp') return false; // Native app fails
          if (uri.host == 'wa.me') return true; // Web URL succeeds
          return false;
        },
      );

      final res = await service.shareRoutine(
        text: 'Tomorrow Routine',
        recipientPhone: '01712345678',
      );

      expect(res.success, isTrue);
      expect(res.method, WhatsAppShareMethod.browserWeb);
      expect(res.deepLinkUsed, contains('https://wa.me/8801712345678'));
    });

    test('8. shareRoutine falls back to Clipboard when both native and web launch fail', () async {
      final service = WhatsAppShareService(
        launchHandler: (uri, {mode = LaunchMode.platformDefault}) async {
          throw Exception('Device has no compatible browser or intent handler');
        },
      );

      final res = await service.shareRoutine(
        text: 'Algorithm Lab at 10 AM',
        copyToClipboardOnFallback: true,
      );

      expect(res.success, isTrue);
      expect(res.method, WhatsAppShareMethod.copiedToClipboard);
      expect(res.message, contains('Routine text was copied to clipboard!'));
    });

    test('9. Rejects invalid recipient phone without throwing an unhandled exception', () async {
      final service = WhatsAppShareService();
      final res = await service.shareRoutine(
        text: 'Routine',
        recipientPhone: '01112345678', // Invalid prefix
      );

      expect(res.success, isFalse);
      expect(res.method, WhatsAppShareMethod.failed);
      expect(res.message, contains('Invalid operator prefix'));
    });
  });

  group('STAGE 28: WhatsAppShareDialog Widget Presentation & User Flow Tests', () {
    testWidgets('10. Renders dialog with routine text and direct recipient input', (tester) async {
      const routine = 'CSE 3101: Operating Systems\n10:00 AM - 11:30 AM\nRoom 402';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WhatsAppShareDialog(
              title: 'WhatsApp Routine Broadcast',
              subtitle: 'Tomorrow (Monday) — 3 Classes',
              messageText: routine,
            ),
          ),
        ),
      );

      expect(find.text('WhatsApp Routine Broadcast'), findsOneWidget);
      expect(find.text('Tomorrow (Monday) — 3 Classes'), findsOneWidget);
      expect(find.text(routine), findsOneWidget);
      expect(find.text('Direct Recipient (Optional)'), findsOneWidget);
      expect(find.text('Share WhatsApp'), findsOneWidget);
      expect(find.text('Copy Message'), findsOneWidget);
    });

    testWidgets('11. Entering valid BD phone shows operator chip and updates button label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WhatsAppShareDialog(
              title: 'WhatsApp Broadcast',
              subtitle: 'Tomorrow',
              messageText: 'Class Routine',
            ),
          ),
        ),
      );

      // Enter valid Grameenphone number
      await tester.enterText(find.byType(TextField), '01712345678');
      await tester.pumpAndSettle();

      expect(find.text('Operator: Grameenphone'), findsOneWidget);
      expect(find.text('Target: 8801712345678'), findsOneWidget);
      expect(find.text('Send to Contact'), findsOneWidget);

      // Change to valid Banglalink number
      await tester.enterText(find.byType(TextField), '01999887766');
      await tester.pumpAndSettle();

      expect(find.text('Operator: Banglalink'), findsOneWidget);
      expect(find.text('Target: 8801999887766'), findsOneWidget);
    });

    testWidgets('12. Entering invalid phone number displays validation warning', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WhatsAppShareDialog(
              title: 'WhatsApp Broadcast',
              subtitle: 'Tomorrow',
              messageText: 'Class Routine',
            ),
          ),
        ),
      );

      // Enter invalid prefix
      await tester.enterText(find.byType(TextField), '01112345678');
      await tester.pumpAndSettle();

      expect(find.textContaining('Invalid operator prefix'), findsOneWidget);
    });

    testWidgets('13. Tapping Copy Text copies routine and shows confirmation snackbar', (tester) async {
      String? copiedContent;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedContent = (methodCall.arguments as Map)['text'];
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => WhatsAppShareDialog.show(
                  ctx,
                  title: 'WhatsApp Broadcast',
                  subtitle: 'Tomorrow',
                  messageText: 'Sample Routine Text',
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Message'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Routine copied to clipboard'), findsOneWidget);
      expect(copiedContent, 'Sample Routine Text');
    });

    testWidgets('14. Tapping Share executes share service safely', (tester) async {
      bool serviceInvoked = false;
      final mockService = WhatsAppShareService(
        launchHandler: (uri, {mode = LaunchMode.platformDefault}) async {
          serviceInvoked = true;
          return true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => WhatsAppShareDialog.show(
                  ctx,
                  title: 'WhatsApp Broadcast',
                  subtitle: 'Tomorrow',
                  messageText: 'Sample Routine Text',
                  shareService: mockService,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share WhatsApp'));
      await tester.pumpAndSettle();

      expect(serviceInvoked, isTrue);
      expect(find.text('Launched WhatsApp app successfully.'), findsOneWidget);
    });
  });
}
