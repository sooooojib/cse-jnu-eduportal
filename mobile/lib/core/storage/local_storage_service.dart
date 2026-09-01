import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

abstract class LocalStorageService {
  Future<void> setThemeMode(String mode);
  String? getThemeMode();
  Future<void> setActiveSemester(int year, int semester);
  (int year, int semester)? getActiveSemester();
  Future<void> setString(String key, String value);
  String? getString(String key);
  Future<void> setBool(String key, bool value);
  bool? getBool(String key);
  Future<void> remove(String key);
  Future<void> clear();
}

class LocalStorageServiceImpl implements LocalStorageService {
  final SharedPreferences prefs;

  LocalStorageServiceImpl({required this.prefs});

  @override
  Future<void> setThemeMode(String mode) async {
    await prefs.setString(AppConstants.keyThemeMode, mode);
  }

  @override
  String? getThemeMode() {
    return prefs.getString(AppConstants.keyThemeMode);
  }

  @override
  Future<void> setActiveSemester(int year, int semester) async {
    await prefs.setString(AppConstants.keyActiveSemester, '$year,$semester');
  }

  @override
  (int year, int semester)? getActiveSemester() {
    final raw = prefs.getString(AppConstants.keyActiveSemester);
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length == 2) {
      final y = int.tryParse(parts[0]);
      final s = int.tryParse(parts[1]);
      if (y != null && s != null) return (y, s);
    }
    return null;
  }

  @override
  Future<void> setString(String key, String value) async {
    await prefs.setString(key, value);
  }

  @override
  String? getString(String key) {
    return prefs.getString(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await prefs.setBool(key, value);
  }

  @override
  bool? getBool(String key) {
    return prefs.getBool(key);
  }

  @override
  Future<void> remove(String key) async {
    await prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    await prefs.clear();
  }
}
