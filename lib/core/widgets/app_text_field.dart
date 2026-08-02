import 'package:flutter/material.dart';

/// Shared text field wrapper so every form in the app gets the same label
/// style, spacing, and error-display behaviour without repeating
/// `InputDecoration` boilerplate on every screen.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.suffixIcon,
    this.autofillHints,
    this.validator,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      autofillHints: autofillHints,
      validator: validator,
      maxLines: obscureText ? 1 : maxLines,
      decoration: InputDecoration(
        // Border/fill/label colors all come from the app-wide
        // InputDecorationTheme (see core/theme/app_theme.dart) so every
        // field looks identical without repeating styling here.
        labelText: label,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
