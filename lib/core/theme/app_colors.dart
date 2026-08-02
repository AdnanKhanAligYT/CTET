import 'package:flutter/material.dart';

/// Brand palette, pulled from the reference app's Edit Profile screen: a
/// deep navy for buttons/links/icons on a white surface, with a light gray
/// border/divider color for the boxed form fields. Kept as flat constants
/// (not a seed-generated scheme) so the exact accent color from the
/// reference is reproduced precisely rather than approximated.
class AppColors {
  const AppColors._();

  static const navy = Color(0xFF16234B);
  static const navyDark = Color(0xFF0E1730);
  static const navyLight = Color(0xFF2E4270);

  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBackground = Color(0xFFFAFAFC);
  static const lightBorder = Color(0xFFE1E3E8);
  static const lightTextPrimary = Color(0xFF16181D);
  static const lightTextSecondary = Color(0xFF6B7280);

  static const darkSurface = Color(0xFF161A22);
  static const darkBackground = Color(0xFF0D0F14);
  static const darkBorder = Color(0xFF2A2F3A);
  static const darkTextPrimary = Color(0xFFF2F3F5);
  static const darkTextSecondary = Color(0xFF9CA3AF);

  static const error = Color(0xFFD64545);

  /// Flat colors for the "Other Options" icon badges on Edit Profile —
  /// each option gets its own color the way the reference screen does
  /// (lock = blue, language = amber, dark mode = indigo, delete/logout =
  /// red) rather than one uniform icon color.
  static const optionSetPassword = Color(0xFF2F6FED);
  static const optionLanguage = Color(0xFFE8873C);
  static const optionDarkMode = Color(0xFF4C3FCF);
  static const optionDestructive = Color(0xFFE24C4C);

  /// Flat colors for the dashboard's study-tool quick-link tiles — same
  /// "one flat color per icon" idea as the Edit Profile options above.
  static const tileMockTest = Color(0xFF2F6FED);
  static const tileSyllabus = Color(0xFFE8873C);
  static const tileDictionary = Color(0xFF12977A);
  static const tileTimetable = Color(0xFF4C3FCF);
  static const tileNotepad = Color(0xFFB5541F);
}
