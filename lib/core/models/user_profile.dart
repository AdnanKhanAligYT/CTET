import 'package:cloud_firestore/cloud_firestore.dart';

/// How the student's display name was originally populated. Kept so the
/// Edit Profile screen and any future analytics can tell an auto-suggested
/// name apart from one the student typed themselves.
enum DisplayNameSource { email, manual, phoneManual }

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

/// Mirrors the `/users/{uid}` Firestore document described in the project
/// plan — the fields intentionally match the reference Edit Profile screen
/// (Designation, Institution, City, Exams, Email, Phone, ...).
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
    this.darkMode = false,
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
  final bool darkMode;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      displayNameSource: _sourceFromString(map['displayNameSource'] as String?),
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      photoURL: map['photoURL'] as String?,
      aboutYou: map['aboutYou'] as String? ?? '',
      accountType: map['accountType'] as String? ?? 'free',
      designation: map['designation'] as String? ?? '',
      institution: map['institution'] as String? ?? '',
      city: map['city'] as String? ?? '',
      cityAutoFilled: map['cityAutoFilled'] as bool? ?? false,
      exams:
          (map['exams'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      passwordSet: map['passwordSet'] as bool? ?? false,
      language: map['language'] as String? ?? 'hi',
      darkMode: map['darkMode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap({bool isCreate = false}) {
    final map = <String, dynamic>{
      'displayName': displayName,
      'displayNameSource': _sourceToString(displayNameSource),
      'email': email,
      'phone': phone,
      'photoURL': photoURL,
      'aboutYou': aboutYou,
      'accountType': accountType,
      'designation': designation,
      'institution': institution,
      'city': city,
      'cityAutoFilled': cityAutoFilled,
      'exams': exams,
      'passwordSet': passwordSet,
      'language': language,
      'darkMode': darkMode,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isCreate) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
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
    bool? darkMode,
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
      darkMode: darkMode ?? this.darkMode,
    );
  }

  /// A profile only counts as "set up" once the student has confirmed a
  /// name and picked at least one exam — used by the router to decide
  /// whether to force a first-time visitor into Profile Setup.
  bool get isSetupComplete => displayName.isNotEmpty && exams.isNotEmpty;
}
