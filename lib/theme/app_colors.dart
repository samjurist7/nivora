import 'package:flutter/material.dart';

/// Modern color palette inspired by Spotify/Instagram aesthetics
/// Following Material Design 3 guidelines
class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF8B85FF);
  static const Color primaryDark = Color(0xFF3D34C7);

  // Secondary Accent Colors
  static const Color secondary = Color(0xFF00D9A0);
  static const Color secondaryLight = Color(0xFF00FFC3);
  static const Color secondaryDark = Color(0xFF00A880);

  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF6C63FF),
    Color(0xFF5A52E6),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFF00D9A0),
    Color(0xFF00B8D4),
  ];

  static const List<Color> sunsetGradient = [
    Color(0xFFFF6B6B),
    Color(0xFFFF8E53),
  ];

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0F0F5);
  static const Color lightOnBackground = Color(0xFF1A1A2E);
  static const Color lightOnSurface = Color(0xFF2D2D44);
  static const Color lightOnSurfaceVariant = Color(0xFF6B6B80);
  static const Color lightOutline = Color(0xFFE0E0E8);
  static const Color lightOutlineVariant = Color(0xFFF0F0F5);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkSurfaceVariant = Color(0xFF252540);
  static const Color darkOnBackground = Color(0xFFFAFAFA);
  static const Color darkOnSurface = Color(0xFFE8E8F0);
  static const Color darkOnSurfaceVariant = Color(0xFF9A9AB0);
  static const Color darkOutline = Color(0xFF3A3A55);
  static const Color darkOutlineVariant = Color(0xFF2A2A40);

  // Status Colors
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFB300);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF29B6F6);

  // Shadow Colors
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowDark = Color(0x40000000);
}
