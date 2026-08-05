import 'package:flutter/material.dart' show ThemeMode;

/// How the student's display name was originally populated. Kept so the
/// Edit Profile screen and any future analytics can tell an auto-suggested
/// name apart from one the student typed themselves.
enum DisplayNameSource { email, manual, phoneManual }

/// The student's theme choice. Defaults to `system` so a fresh install
/// matches the phone's own light/dark setting out of the box — students
/// only ever see an explicit `light`/`dark` override if they picked one
/// themselves in Edit Profile.
enum AppThemePreference { system, light, dark }

AppThemePreference _themePreferenceFromString(String? value) {
  switch (value) {
    case 'light':
      return AppThemePreference.light;
    case 'dark':
      return AppThemePreference.dark;
    default:
      return AppThemePreference.system;
  }
}

extension AppThemePreferenceX on AppThemePreference {
  String toStorageString() {
    switch (this) {
      case AppThemePreference.light:
        return 'light';
      case AppThemePreference.dark:
        return 'dark';
      case AppThemePreference.system:
        return 'system';
    }
  }

  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }
}

DisplayNameSource _sourceFromString(String? value) {
  switch (value) {
    case 'email':
      return DisplayNameSource.email;
    case 'phone-manual':
      return DisplayNameSource.phoneManual;
    default:
      return DisplayNameSource.manual;
  }
}

String _sourceToString(DisplayNameSource source) {
  switch (source) {
    case DisplayNameSource.email:
      return 'email';
    case DisplayNameSource.phoneManual:
      return 'phone-manual';
    case DisplayNameSource.manual:
      return 'manual';
  }
}

/// Mirrors a `public.profiles` row (see `supabase/schema.sql`) — the fields
/// intentionally match the reference Edit Profile screen (Designation,
/// Institution, City, Exams, Email, Phone, ...).
class UserProfile {
  const UserProfile({
    required this.uid,
    this.displayName = '',
    this.displayNameSource = DisplayNameSource.manual,
    this.email,
    this.phone,
    this.photoURL,
    this.aboutYou = '',
    this.accountType = 'free',
    this.designation = '',
    this.institution = '',
    this.city = '',
    this.cityAutoFilled = false,
    this.exams = const [],
    this.passwordSet = false,
    this.language = 'hi',
    this.themePreference = AppThemePreference.system,
  });

  final String uid;
  final String displayName;
  final DisplayNameSource displayNameSource;
  final String? email;
  final String? phone;
  final String? photoURL;
  final String aboutYou;
  final String accountType;
  final String designation;
  final String institution;
  final String city;
  final bool cityAutoFilled;
  final List<String> exams;
  final bool passwordSet;
  final String language;
  final AppThemePreference themePreference;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      displayName: map['display_name'] as String? ?? '',
      displayNameSource: _sourceFromString(
        map['display_name_source'] as String?,
      ),
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      photoURL: map['photo_url'] as String?,
      aboutYou: map['about_you'] as String? ?? '',
      accountType: map['account_type'] as String? ?? 'free',
      designation: map['designation'] as String? ?? '',
      institution: map['institution'] as String? ?? '',
      city: map['city'] as String? ?? '',
      cityAutoFilled: map['city_auto_filled'] as bool? ?? false,
      exams:
          (map['exams'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      passwordSet: map['password_set'] as bool? ?? false,
      language: map['language'] as String? ?? 'hi',
      themePreference: _themePreferenceFromString(
        map['theme_preference'] as String?,
      ),
    );
  }

  /// Row payload for an upsert into `public.profiles`. `id` is included so
  /// callers can `upsert` directly without juggling a separate primary key
  /// parameter.
  Map<String, dynamic> toMap() {
    return {
      'id': uid,
      'display_name': displayName,
      'display_name_source': _sourceToString(displayNameSource),
      'email': email,
      'phone': phone,
      'photo_url': photoURL,
      'about_you': aboutYou,
      'account_type': accountType,
      'designation': designation,
      'institution': institution,
      'city': city,
      'city_auto_filled': cityAutoFilled,
      'exams': exams,
      'password_set': passwordSet,
      'language': language,
      'theme_preference': themePreference.toStorageString(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    DisplayNameSource? displayNameSource,
    String? email,
    String? phone,
    String? photoURL,
    String? aboutYou,
    String? accountType,
    String? designation,
    String? institution,
    String? city,
    bool? cityAutoFilled,
    List<String>? exams,
    bool? passwordSet,
    String? language,
    AppThemePreference? themePreference,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      displayNameSource: displayNameSource ?? this.displayNameSource,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoURL: photoURL ?? this.photoURL,
      aboutYou: aboutYou ?? this.aboutYou,
      accountType: accountType ?? this.accountType,
      designation: designation ?? this.designation,
      institution: institution ?? this.institution,
      city: city ?? this.city,
      cityAutoFilled: cityAutoFilled ?? this.cityAutoFilled,
      exams: exams ?? this.exams,
      passwordSet: passwordSet ?? this.passwordSet,
      language: language ?? this.language,
      themePreference: themePreference ?? this.themePreference,
    );
  }

  /// A profile only counts as "set up" once the student has confirmed a
  /// name and picked at least one exam — used by the router to decide
  /// whether to force a first-time visitor into Profile Setup.
  bool get isSetupComplete => displayName.isNotEmpty && exams.isNotEmpty;
}
