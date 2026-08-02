import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/exam_catalog.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/application/auth_controller.dart';
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
    final user = FirebaseAuth.instance.currentUser;
    profile ??= UserProfile(
      uid: user?.uid ?? '',
      email: user?.email,
      phone: user?.phoneNumber,
      displayName: user?.displayName ?? '',
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

  Future<void> _toggleDarkMode(bool value) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(darkMode: value);
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
      await ref.read(profileControllerProvider.notifier).deleteAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile!;

    return Scaffold(
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
                      FirebaseAuth.instance.currentUser?.emailVerified == false
                  ? 'Unverified'
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
                leading: const Icon(Icons.lock_reset),
                title: const Text('Set Password'),
                subtitle: const Text(
                  'Add email + password sign-in to this account',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showSetPasswordDialog,
              ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Change Language'),
              trailing: DropdownButton<String>(
                value: profile.language,
                items: const [
                  DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (value) {
                  if (value != null) _toggleLanguage(value);
                },
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark Mode'),
              value: profile.darkMode,
              onChanged: _toggleDarkMode,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete Account'),
              onTap: _confirmDeleteAccount,
            ),
            if (!widget.isFirstTimeSetup)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
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
      text: FirebaseAuth.instance.currentUser?.email ?? '',
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

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    this.trailingLabel,
  });

  final String label;
  final String value;
  final String? trailingLabel;

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
        if (trailingLabel != null) Text(trailingLabel!),
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
  late final List<String> _selected = List.of(widget.initiallySelected);

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: examCatalog.map((exam) {
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
