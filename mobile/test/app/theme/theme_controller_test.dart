import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/app/theme/theme_controller.dart';
import 'package:cse_jnu_eduportal/core/storage/local_storage_service.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  late MockLocalStorageService mockStorage;
  late ThemeController themeController;

  setUp(() {
    mockStorage = MockLocalStorageService();
    when(() => mockStorage.getThemeMode()).thenReturn('system');
    when(() => mockStorage.setThemeMode(any())).thenAnswer((_) async {});
  });

  group('ThemeController', () {
    test('initializes with system theme by default', () {
      themeController = ThemeController(localStorageService: mockStorage);

      expect(themeController.themeMode, equals(ThemeMode.system));
      expect(themeController.isSystemMode, isTrue);
      expect(themeController.isDarkMode, isFalse);
      expect(themeController.isLightMode, isFalse);
    });

    test('initializes with saved dark theme from storage', () {
      when(() => mockStorage.getThemeMode()).thenReturn('dark');
      themeController = ThemeController(localStorageService: mockStorage);

      expect(themeController.themeMode, equals(ThemeMode.dark));
      expect(themeController.isDarkMode, isTrue);
    });

    test('initializes with saved light theme from storage', () {
      when(() => mockStorage.getThemeMode()).thenReturn('light');
      themeController = ThemeController(localStorageService: mockStorage);

      expect(themeController.themeMode, equals(ThemeMode.light));
      expect(themeController.isLightMode, isTrue);
    });

    test('setThemeMode updates theme and persists preference', () async {
      themeController = ThemeController(localStorageService: mockStorage);

      await themeController.setThemeMode(ThemeMode.dark);

      expect(themeController.themeMode, equals(ThemeMode.dark));
      verify(() => mockStorage.setThemeMode('dark')).called(1);

      await themeController.setLight();
      expect(themeController.themeMode, equals(ThemeMode.light));
      verify(() => mockStorage.setThemeMode('light')).called(1);

      await themeController.setSystem();
      expect(themeController.themeMode, equals(ThemeMode.system));
      verify(() => mockStorage.setThemeMode('system')).called(1);
    });
  });
}
