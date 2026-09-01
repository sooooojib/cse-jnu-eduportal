import 'package:flutter/material.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/local_storage_service.dart';

/// Controller responsible for managing and persisting the application ThemeMode (Light, Dark, System).
class ThemeController extends ValueNotifier<ThemeMode> {
  final LocalStorageService _localStorageService;

  ThemeController({required LocalStorageService localStorageService})
      : _localStorageService = localStorageService,
        super(_parseThemeMode(localStorageService.getThemeMode()));

  static ThemeMode _parseThemeMode(String? saved) {
    if (saved == 'light') return ThemeMode.light;
    if (saved == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  /// Current active ThemeMode
  ThemeMode get themeMode => value;

  /// Quick boolean checks
  bool get isDarkMode => value == ThemeMode.dark;
  bool get isLightMode => value == ThemeMode.light;
  bool get isSystemMode => value == ThemeMode.system;

  /// Sets the application theme mode and persists it to local storage
  Future<void> setThemeMode(ThemeMode mode) async {
    if (value == mode) return;
    AppLogger.i('🌓 [Theme Engine] Switched mode: ${value.name.toUpperCase()} ➔ ${mode.name.toUpperCase()}');
    value = mode;
    await _localStorageService.setThemeMode(mode.name);
  }

  /// Convenient helper to switch directly to Light mode
  Future<void> setLight() async => setThemeMode(ThemeMode.light);

  /// Convenient helper to switch directly to Dark mode
  Future<void> setDark() async => setThemeMode(ThemeMode.dark);

  /// Convenient helper to switch directly to System default mode
  Future<void> setSystem() async => setThemeMode(ThemeMode.system);

  /// Toggles between Light and Dark mode based on current context brightness
  Future<void> toggleTheme(BuildContext context) async {
    final currentBrightness = Theme.of(context).brightness;
    if (currentBrightness == Brightness.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}
