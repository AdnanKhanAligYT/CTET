import 'package:flutter_test/flutter_test.dart';
import 'package:ctet_tet_prep/core/services/name_suggestion_service.dart';

void main() {
  final service = NameSuggestionService();

  test('splits on dots and strips trailing digits', () {
    final result = service.suggestFromEmail('mohammad.adnan7275@gmail.com');
    expect(result.name, 'Mohammad Adnan');
    expect(result.source, NameSuggestionSource.separator);
  });

  test('splits on underscores', () {
    final result = service.suggestFromEmail('mohammad_adnan@gmail.com');
    expect(result.name, 'Mohammad Adnan');
    expect(result.source, NameSuggestionSource.separator);
  });

  test('splits on hyphens', () {
    final result = service.suggestFromEmail('Mohammad-Adnan@gmail.com');
    expect(result.name, 'Mohammad Adnan');
  });

  test('uses the common-name dictionary for concatenated local-parts', () {
    final result = service.suggestFromEmail('mohammadadnan7275@gmail.com');
    expect(result.name, 'Mohammad Adnan');
    expect(result.source, NameSuggestionSource.dictionary);
  });

  test('matches another concatenated common name', () {
    final result = service.suggestFromEmail('rahulverma99@yahoo.com');
    expect(result.name, 'Rahul Verma');
    expect(result.source, NameSuggestionSource.dictionary);
  });

  test('falls back to a single title-cased word when nothing matches', () {
    final result = service.suggestFromEmail('xyzuser123@example.com');
    expect(result.name, 'Xyzuser');
    expect(result.source, NameSuggestionSource.fallback);
  });

  test('handles an email with no local part gracefully', () {
    final result = service.suggestFromEmail('@example.com');
    expect(result.name, '');
  });

  test('prefers the longest dictionary match (priyanka over priya)', () {
    final result = service.suggestFromEmail('priyankasharma@example.com');
    expect(result.name, 'Priyanka Sharma');
  });
}
