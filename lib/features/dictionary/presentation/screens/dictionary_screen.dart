import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter/material.dart';

import '../../../../core/models/dictionary_word.dart';
import '../../../../core/services/spaced_repetition_service.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/dictionary_repository.dart';
import 'word_review_screen.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _repository = DictionaryRepository();
  final _spacedRepetition = const SpacedRepetitionService();

  bool _loading = true;
  List<DictionaryWord> _allWords = const [];
  List<DictionaryWord> _dueWords = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final words = await _repository.fetchAllWords();
    final progress = await _repository.fetchProgress(user.id);
    final due = words
        .where((w) => _spacedRepetition.isDueToday(progress[w.id]))
        .toList();
    if (!mounted) return;
    setState(() {
      _allWords = words;
      _dueWords = due;
      _loading = false;
    });
  }

  Future<void> _startReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WordReviewScreen(dueWords: _dueWords)),
    );
    _load(); // refresh due count after review
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dictionary')),
      body: SafeArea(
        child: _allWords.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No words have been added yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_dueWords.isNotEmpty) ...[
                    Text(
                      '${_dueWords.length} word${_dueWords.length == 1 ? '' : 's'} due today',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Start Review',
                      onPressed: _startReview,
                    ),
                    const SizedBox(height: 28),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Text('No words due today — all caught up!'),
                    ),
                  Text(
                    'All Words (${_allWords.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final word in _allWords)
                    ExpansionTile(
                      title: Text(word.word),
                      childrenPadding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 12,
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (word.meaningHi.isNotEmpty)
                                Text(word.meaningHi),
                              if (word.meaningEn.isNotEmpty)
                                Text(
                                  word.meaningEn,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (word.exampleSentence.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '"${word.exampleSentence}"',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
