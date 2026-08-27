import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/models/user_profile.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../mock_test/data/exam_catalog_repository.dart';
import '../../application/profile_controller.dart';

/// Single screen reused for both first-time profile setup (right after
/// signup, `isFirstTimeSetup: true`) and later edits from the dashboard —
/// field order and grouping mirror the reference app's Edit Profile screen
/// (Designation, Institution, City, Exams, Email, Phone, then an "Other
/// Options" section for Set Password / Change Language / Dark Mode /
/// Delete Account / Logout).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, this.isFirstTimeSetup = false});

  final bool isFirstTimeSetup;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _institutionController = TextEditingController();
  final _cityController = TextEditingController();

  UserProfile? _profile;
  List<String> _selectedExams = [];
  bool _loading = true;
  bool _saving = false;
  bool _cityLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    UserProfile? profile;
    try {
      profile = await ref.read(userProfileProvider.future);
    } catch (_) {
      // Fall through to the default below.
    }
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    // Email/phone signups store the confirmed name under `display_name`;
    // Google sign-in (signInWithIdToken) never gets that call, so it only
    // ever has Google's own `full_name`/`name` + `avatar_url`/`picture`
    // claims — fall back through both so a first-time Google student still
    // lands here with their real name and photo pre-filled.
    final googleName = metadata?['full_name'] as String? ?? metadata?['name'] as String?;
    final googlePhoto = metadata?['avatar_url'] as String? ?? metadata?['picture'] as String?;
    profile ??= UserProfile(
      uid: user?.id ?? '',
      email: user?.email,
      phone: user?.phone,
      displayName: (metadata?['display_name'] as String?) ?? googleName ?? '',
      photoURL: googlePhoto,
      designation: 'Student',
    );
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _nameController.text = profile!.displayName;
      _aboutController.text = profile.aboutYou;
      _institutionController.text = profile.institution;
      _cityController.text = profile.city;
      _selectedExams = List.of(profile.exams);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _institutionController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _resendVerificationEmail() async {
    final sent = await ref
        .read(authControllerProvider.notifier)
        .resendEmailVerification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Verification email sent — check your inbox.'
              : 'Could not send verification email.',
        ),
      ),
    );
  }

  Future<void> _autoFillCity() async {
    setState(() => _cityLoading = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return; // Never block profile completion on location permission.
      }
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await geocoding.Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final city = placemarks.isNotEmpty
          ? (placemarks.first.locality ??
                placemarks.first.subAdministrativeArea)
          : null;
      if (city != null && city.isNotEmpty && mounted) {
        setState(() => _cityController.text = city);
      }
    } catch (_) {
      // Silently ignore — city is a nice-to-have, not a blocker.
    } finally {
      if (mounted) setState(() => _cityLoading = false);
    }
  }

  Future<void> _openChangeExamSheet() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExamPickerSheet(initiallySelected: _selectedExams),
    );
    if (result != null) setState(() => _selectedExams = result);
  }

  Future<void> _save() async {
    // HomeGate won't consider setup complete without at least one exam
    // (see UserProfile.isSetupComplete) — without this check, clicking
    // Continue with no exam picked used to silently save and bounce the
    // student right back to this same screen with no explanation.
    if (_selectedExams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Continue karne se pehle kam se kam ek exam chuno.'),
        ),
      );
      return;
    }
    final base = _profile!;
    setState(() => _saving = true);
    final updated = base.copyWith(
      displayName: _nameController.text.trim(),
      aboutYou: _aboutController.text.trim(),
      institution: _institutionController.text.trim(),
      city: _cityController.text.trim(),
      cityAutoFilled: false,
      exams: _selectedExams,
      designation: base.designation.isEmpty ? 'Student' : base.designation,
    );
    await ref.read(profileControllerProvider.notifier).updateProfile(updated);
    if (!mounted) return;
    if (widget.isFirstTimeSetup) {
      context.go('/');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _setThemePreference(AppThemePreference preference) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(themePreference: preference);
    setState(() => _profile = updated);
    await ref.read(profileControllerProvider.notifier).updateProfile(updated);
  }

  Future<void> _toggleLanguage(String language) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(language: language);
    setState(() => _profile = updated);
    await ref.read(profileControllerProvider.notifier).updateProfile(updated);
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This permanently deletes your profile and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(profileControllerProvider.notifier).deleteAccount();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account delete nahi ho paya: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile!;

    return Scaffold(
      bottomNavigationBar: const AppBannerAd(),
      appBar: AppBar(
        title: Text(
          widget.isFirstTimeSetup ? 'Set Up Your Profile' : 'Edit Profile',
        ),
        automaticallyImplyLeading: !widget.isFirstTimeSetup,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundImage: profile.photoURL != null
                    ? NetworkImage(profile.photoURL!)
                    : null,
                child: profile.photoURL == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            AppTextField(label: 'Name', controller: _nameController),
            const SizedBox(height: 16),
            AppTextField(
              label: 'About yourself',
              controller: _aboutController,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _ReadOnlyRow(
              label: 'Account type',
              value: profile.accountType == 'premium' ? 'Premium' : 'Free',
              trailingLabel: 'Upgrade',
            ),
            const SizedBox(height: 16),
            _ReadOnlyRow(
              label: 'Designation',
              value: profile.designation.isEmpty
                  ? 'Student'
                  : profile.designation,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Institution',
              controller: _institutionController,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'City',
              controller: _cityController,
              suffixIcon: _cityLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: _autoFillCity,
                      child: const Text('Auto Fill'),
                    ),
            ),
            const SizedBox(height: 16),
            _ExamsRow(
              exams: _selectedExams,
              onChangeExam: _openChangeExamSheet,
            ),
            const SizedBox(height: 16),
            _ReadOnlyRow(
              label: 'Email',
              value: profile.email ?? 'Not linked',
              trailingLabel:
                  profile.email != null &&
                      Supabase.instance.client.auth.currentUser
                              ?.emailConfirmedAt ==
                          null
                  ? 'Resend verification'
                  : null,
              onTrailingTap:
                  profile.email != null &&
                      Supabase.instance.client.auth.currentUser
                              ?.emailConfirmedAt ==
                          null
                  ? _resendVerificationEmail
                  : null,
            ),
            const SizedBox(height: 16),
            _ReadOnlyRow(label: 'Phone', value: profile.phone ?? 'Not linked'),
            const SizedBox(height: 32),
            Text(
              'Other Options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            if (!profile.passwordSet)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const _OptionIconBadge(
                  icon: Icons.lock_reset,
                  color: AppColors.optionSetPassword,
                ),
                title: const Text('Set Password'),
                subtitle: const Text(
                  'Add email + password sign-in to this account',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showSetPasswordDialog,
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const _OptionIconBadge(
                icon: Icons.translate,
                color: AppColors.optionLanguage,
              ),
              title: const Text('Change Language'),
              trailing: DropdownButton<String>(
                value: profile.language,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (value) {
                  if (value != null) _toggleLanguage(value);
                },
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const _OptionIconBadge(
                icon: Icons.dark_mode_outlined,
                color: AppColors.optionDarkMode,
              ),
              title: const Text('Theme'),
              subtitle: const Text('"System" matches your phone automatically'),
              trailing: DropdownButton<AppThemePreference>(
                value: profile.themePreference,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: AppThemePreference.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: AppThemePreference.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: AppThemePreference.dark,
                    child: Text('Dark'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) _setThemePreference(value);
                },
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const _OptionIconBadge(
                icon: Icons.delete_outline,
                color: AppColors.optionDestructive,
              ),
              title: const Text('Delete Account'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _confirmDeleteAccount,
            ),
            if (!widget.isFirstTimeSetup)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const _OptionIconBadge(
                  icon: Icons.logout,
                  color: AppColors.optionDestructive,
                ),
                title: const Text('Logout'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
              ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: widget.isFirstTimeSetup ? 'Continue' : 'Save',
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSetPasswordDialog() async {
    final emailController = TextEditingController(
      text: Supabase.instance.client.auth.currentUser?.email ?? '',
    );
    final passwordController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(label: 'Email', controller: emailController),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Password',
              controller: passwordController,
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final password = passwordController.text;
              Navigator.of(dialogContext).pop();
              // Linking happens through AuthController (FirebaseAuth), then
              // the profile flag is updated separately via
              // ProfileController — kept as two calls on purpose so an
              // auth-link failure never gets confused with a Firestore
              // write failure.
              final linked = await ref
                  .read(authControllerProvider.notifier)
                  .linkEmailPassword(email: email, password: password);
              if (linked) {
                await ref
                    .read(profileControllerProvider.notifier)
                    .markPasswordSet();
              } else if (mounted) {
                final error = ref.read(authControllerProvider).errorMessage;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error ?? 'Could not set password.')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// The small colored rounded-square icon used for every row in "Other
/// Options" — one flat color per option (see `AppColors.option*`), matching
/// the reference app's Edit Profile screen rather than a single uniform
/// icon color.
class _OptionIconBadge extends StatelessWidget {
  const _OptionIconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    this.trailingLabel,
    this.onTrailingTap,
  });

  final String label;
  final String value;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        if (trailingLabel != null)
          onTrailingTap != null
              ? TextButton(onPressed: onTrailingTap, child: Text(trailingLabel!))
              : Text(trailingLabel!),
      ],
    );
  }
}

class _ExamsRow extends StatelessWidget {
  const _ExamsRow({required this.exams, required this.onChangeExam});

  final List<String> exams;
  final VoidCallback onChangeExam;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exams', style: Theme.of(context).textTheme.labelMedium),
              Text(
                exams.isEmpty ? 'No exam selected' : exams.join(' & '),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        TextButton(onPressed: onChangeExam, child: const Text('Change Exam')),
      ],
    );
  }
}

class _ExamPickerSheet extends StatefulWidget {
  const _ExamPickerSheet({required this.initiallySelected});

  final List<String> initiallySelected;

  @override
  State<_ExamPickerSheet> createState() => _ExamPickerSheetState();
}

class _ExamPickerSheetState extends State<_ExamPickerSheet> {
  final _repository = ExamCatalogRepository();
  late final List<String> _selected = List.of(widget.initiallySelected);
  bool _loading = true;
  String? _error;
  List<String> _examOptions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final names = await _repository.fetchTopLevelExamNames();
      if (!mounted) return;
      setState(() {
        _examOptions = names;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select your exam(s)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // Fetched fresh from the admin-managed catalog every time this
            // sheet opens (rather than a hardcoded list) — the choices
            // offered here always match whatever exams the admin has
            // actually added content for.
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_examOptions.isEmpty)
              const Text('Abhi koi exam add nahi hua hai.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _examOptions.map((exam) {
                  final selected = _selected.contains(exam);
                  return FilterChip(
                    label: Text(exam),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selected.add(exam);
                        } else {
                          _selected.remove(exam);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
      ),
    );
  }
}
