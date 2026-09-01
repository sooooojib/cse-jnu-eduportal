import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/core/utils/validators.dart';

void main() {
  group('Validators Utility', () {
    test('email validator should validate any correct email and reject invalid formats', () {
      expect(Validators.email('student@cse.jnu.ac.bd'), isNull);
      expect(Validators.email('hasan@jnu.ac.bd'), isNull);
      expect(Validators.email('someone@gmail.com'), isNull);
      expect(Validators.email('user@yahoo.com'), isNull);
      expect(Validators.email('invalid-email'), isNotNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email(null), isNotNull);
    });

    test('password validator should enforce complexity (length, upper, lower, digit, special)', () {
      expect(Validators.password('SecurePass123!'), isNull);
      expect(Validators.password('short1!'), isNotNull); // < 8 chars
      expect(Validators.password('nouppercase123!'), isNotNull);
      expect(Validators.password('NOLOWERCASE123!'), isNotNull);
      expect(Validators.password('NoDigitsSpecial!'), isNotNull);
      expect(Validators.password('NoSpecialChar123'), isNotNull);
    });

    test('studentId validator should enforce B followed by 9 numbers (total 10 characters)', () {
      expect(Validators.studentId('B210305015'), isNull);
      expect(Validators.studentId('b200305001'), isNull);
      expect(Validators.studentId('B190305123'), isNull);
      expect(Validators.studentId('12345'), isNotNull);
      expect(Validators.studentId('B21030501'), isNotNull); // 9 chars (only 8 digits)
      expect(Validators.studentId('B2103050155'), isNotNull); // 11 chars (10 digits)
      expect(Validators.studentId('C210305015'), isNotNull); // starts with C
      expect(Validators.studentId('2022CSE015'), isNotNull); // old format
    });

    test('phone validator should validate Bangladeshi phone numbers', () {
      expect(Validators.phone('01712345678'), isNull);
      expect(Validators.phone('+8801812345678'), isNull);
      expect(Validators.phone('01200000000'), isNotNull); // 012 is invalid operator
      expect(Validators.phone('12345'), isNotNull);
    });

    test('attendanceCode validator should enforce exact 6-character length', () {
      expect(Validators.attendanceCode('849201'), isNull);
      expect(Validators.attendanceCode('123'), isNotNull);
      expect(Validators.attendanceCode('1234567'), isNotNull);
    });
  });
}
