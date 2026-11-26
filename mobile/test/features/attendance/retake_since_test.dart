import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/services/class_attendance_service.dart';
import 'package:cse_jnu_eduportal/features/cr/data/datasources/cr_remote_datasource.dart';
import 'package:cse_jnu_eduportal/features/curriculum/data/models/curriculum_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Retake classes count from the enrollment date', () {
    final helpers = <String, String? Function(Map<String, dynamic>)>{
      'service': ClassAttendanceServiceImpl.enrolledSinceKey,
      'dashboard': CrRemoteDataSourceImpl.enrolledSinceKey,
    };
    for (final h in helpers.entries) {
      test('${h.key}: enrolledOn, then createdAt, else null', () {
        expect(h.value({'enrolledOn': '2026-11-20'}), '2026-11-20');
        expect(h.value({'createdAt': Timestamp.fromDate(DateTime(2026, 11, 3, 15))}), '2026-11-03');
        expect(h.value({'enrolledOn': 'garbage', 'createdAt': '2026-10-01T08:00:00Z'}), '2026-10-01');
        expect(h.value(const {}), isNull);
      });
    }
  });

  test('EnrollmentModel exposes the RETAKE type', () {
    final retake = EnrollmentModel.fromJson({'id': 'a', 'courseId': 'CSE-2101', 'studentId': 's', 'type': 'RETAKE'});
    final admin = EnrollmentModel.fromJson({'id': 'b', 'courseId': 'CSE-2101', 'studentId': 's'});
    expect(retake.isRetake, isTrue);
    expect(retake.enrolledCourseIds, ['CSE-2101']);
    expect(admin.isRetake, isFalse);
  });
}
