import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter/material.dart';

import '../../../../core/models/dictionary_word.dart';
import '../../../../core/services/spaced_repetition_service.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/dictionary_repository.dart';

/// Flashcard-style review: word first, tap to reveal its meaning +
/// example, then "Don't Know" / "Know It" — mirrors the mock-test due-
/// today loop but without multiple-choice options, since a vocabulary
/// word is a recall exercise, not a pick-one question.
class WordReviewScreen extends StatefulWidget {
  const WordReviewScreen({super.key, required this.dueWords});

  final List<DictionaryWord> dueWords;

  @override
  State<WordReviewScreen> createState() => _WordReviewScreenState();
}

class _WordReviewScreenState extends State<WordReviewScreen> {
  final _repository = DictionaryRepository();
  final _spacedRepetition = const SpacedRepetitionService();

  int _currentIndex = 0;
  bool _revealed = false;
  int _knownCount = 0;
  int _reviewedCount = 0;

  DictionaryWord get _currentWord => widget.dueWords[_currentIndex];

  Future<void> _answer(bool knewIt) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final updated = _spacedRepetition.recordAnswer(
        itemId: _currentWord.id,
        current: null,
        wasCorrect: knewIt,
      );
      await _repository.saveProgress(user.id, updated);
    }
    setState(() {
      _reviewedCount++;
      if (knewIt) _knownCount++;
    });
    if (_currentIndex + 1 < widget.dueWords.length) {
      setState(() {
        _currentIndex++;
        _revealed = false;
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reviewed $_reviewedCount words — $_knownCount known'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final word = _currentWord;
    return Scaffold(
      appBar: AppBar(
        title: Text('Word ${_currentIndex + 1} of ${widget.dueWords.length}'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _revealed = true),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          word.word,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),
                        if (!_revealed)
                          Text(
                            'Tap to reveal meaning',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        else ...[
                          if (word.meaningHi.isNotEmpty)
                            Text(word.meaningHi, textAlign: TextAlign.center),
                          if (word.meaningEn.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                word.meaningEn,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          if (word.exampleSentence.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                '"${word.exampleSentence}"',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (_revealed)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _answer(false),
                        child: const Text('Don\'t Know'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Know It',
                        onPressed: () => _answer(true),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
