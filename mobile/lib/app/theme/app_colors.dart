import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary (Emerald Scholar)
  static const Color primary = Color(0xFF006948);
  static const Color primaryLight = Color(0xFF00855D);
  static const Color primaryDark = Color(0xFF005137);
  static const Color primaryContainer = Color(0xFF85F8C4);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF002114);

  // Neutral Surfaces (Light)
  static const Color surfaceLight = Color(0xFFF8F9FF);
  static const Color surfaceContainerLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color onSurfaceLight = Color(0xFF0B1C30);
  static const Color onSurfaceVariantLight = Color(0xFF3D4A42);
  static const Color outlineLight = Color(0xFFBCCAC0);
  static const Color outlineVariantLight = Color(0xFFE2E8F0);

  // Neutral Surfaces (Dark)
  static const Color surfaceDark = Color(0xFF0B1C30);
  static const Color surfaceContainerDark = Color(0xFF13263E);
  static const Color surfaceContainerHighDark = Color(0xFF1D3552);
  static const Color onSurfaceDark = Color(0xFFF8F9FF);
  static const Color onSurfaceVariantDark = Color(0xFFCBD5E1);
  static const Color outlineDark = Color(0xFF475569);

  // Obsidian Terminal (Attendance Session)
  static const Color terminalCanvas = Color(0xFF18181B);
  static const Color terminalGlow = Color(0xFF34D399);
  static const Color terminalText = Color(0xFF34D399);
  static const Color terminalPod = Color(0xFF022C2B);

  // System Feedback
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF047857);
  static const Color warning = Color(0xFFC2410C);
  static const Color info = Color(0xFF1D4ED8);

  // Auth Gradients & Canvas
  static const LinearGradient authGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF1F2F1),
      Color(0xFFF6F5EA),
      Color(0xFFF0DFA1),
    ],
  );

  static const LinearGradient darkAuthGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0B1C30),
      Color(0xFF13263E),
      Color(0xFF022C2B),
    ],
  );
}
