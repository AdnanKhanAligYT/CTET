import 'package:flutter/material.dart';

/// Placeholder theme only — deliberately using Flutter's default Material 3
/// look with a single seed color. The real typography/branding pass
/// (professional font pairing, exact palette) is reserved for the design
/// phase later in the project plan; this just needs to exist so every
/// screen has a working light/dark `ThemeData` today.
class AppTheme {
  static const _seedColor = Color(0xFF0EA5E9);

  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }
}
