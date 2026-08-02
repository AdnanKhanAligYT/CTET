import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/user_profile.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../profile/application/profile_controller.dart';

/// Shown after phone OTP signup — a phone number carries no name, so unlike
/// the email flow there is nothing to suggest here.
class ManualNameScreen extends ConsumerStatefulWidget {
  const ManualNameScreen({super.key});

  @override
  ConsumerState<ManualNameScreen> createState() => _ManualNameScreenState();
}

class _ManualNameScreenState extends ConsumerState<ManualNameScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await ref
        .read(profileControllerProvider.notifier)
        .createInitialProfile(
          displayName: name,
          source: DisplayNameSource.phoneManual,
        );
    if (!mounted) return;
    context.go('/profile/edit?firstTime=true');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('What should we call you?')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(label: 'Your Name', controller: _nameController),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Continue',
                isLoading: _saving,
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
