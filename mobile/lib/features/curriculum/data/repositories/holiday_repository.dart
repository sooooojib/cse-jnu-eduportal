import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/utils/class_time.dart';

/// Official department / university holiday stored in `holidays/{yyyy-MM-dd}`.
class DepartmentHoliday extends Equatable {
  final String date; // yyyy-MM-dd
  final String title;
  final String? createdBy;

  const DepartmentHoliday({
    required this.date,
    required this.title,
    this.createdBy,
  });

  @override
  List<Object?> get props => [date, title, createdBy];
}

abstract class HolidayRepository {
  Future<List<DepartmentHoliday>> listHolidays();
  Future<Map<String, String>> holidayMap();
  Future<void> saveHoliday({
    required DateTime date,
    required String title,
    String? createdBy,
  });
  Future<void> deleteHoliday(String dateKey);
}

class HolidayRepositoryImpl implements HolidayRepository {
  final FirebaseFirestore _firestore;

  HolidayRepositoryImpl({required FirebaseFirestore firestore}) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('holidays');

  @override
  Future<List<DepartmentHoliday>> listHolidays() async {
    try {
      final snap = await _col.orderBy('date').get();
      return snap.docs.map((d) {
        final data = d.data();
        final date = (data['date'] as String?)?.trim();
        return DepartmentHoliday(
          date: (date != null && date.isNotEmpty) ? date : d.id,
          title: (data['title'] as String? ?? 'University Holiday').trim(),
          createdBy: data['createdBy'] as String?,
        );
      }).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<Map<String, String>> holidayMap() async {
    try {
      final list = await listHolidays();
      return {for (final h in list) h.date: h.title};
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<void> saveHoliday({
    required DateTime date,
    required String title,
    String? createdBy,
  }) async {
    try {
      final key = ClassTime.dateKey(date);
      final cleanTitle = title.trim();
      await _col.doc(key).set({
        'date': key,
        'title': cleanTitle.isEmpty ? 'University Holiday' : cleanTitle,
        if (createdBy != null && createdBy.isNotEmpty) 'createdBy': createdBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> deleteHoliday(String dateKey) async {
    try {
      await _col.doc(dateKey).delete();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
