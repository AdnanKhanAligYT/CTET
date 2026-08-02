import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/user_profile.dart';
import '../../../../core/services/name_suggestion_service.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../profile/application/profile_controller.dart';

/// Shown right after email signup. The suggested name is always editable
/// and never saved until the student confirms it here — an imperfect
/// guess from `NameSuggestionService` is fine because of that.
class SuggestedNameScreen extends ConsumerStatefulWidget {
  const SuggestedNameScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<SuggestedNameScreen> createState() =>
      _SuggestedNameScreenState();
}

class _SuggestedNameScreenState extends ConsumerState<SuggestedNameScreen> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final suggestion = const NameSuggestionService().suggestFromEmail(
      widget.email,
    );
    _nameController = TextEditingController(text: suggestion.name);
  }

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
          source: DisplayNameSource.email,
        );
    if (!mounted) return;
    context.go('/profile/edit?firstTime=true');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Your Name')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'We think your name is:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              AppTextField(label: 'Your Name', controller: _nameController),
              const SizedBox(height: 8),
              Text(
                'You can change this if it\'s not quite right.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Looks good, Continue',
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
