import 'package:flutter/material.dart';

import '../../../../core/models/question.dart';

/// Renders a question's "Q<n>. " prefixed text, inserting its optional
/// table (if any) at the literal "{{table}}" marker — or above the text
/// when no marker is present. Mirrors the reference PHP app's own table
/// placement rule (take_test.php's buildQuestionText). Falls back to a
/// plain bold-prefixed line when the question has no table.
class QuestionText extends StatelessWidget {
  const QuestionText({
    super.key,
    required this.question,
    required this.number,
    this.style,
  });

  final Question question;
  final int number;
  final TextStyle? style;

  static const _marker = '{{table}}';

  @override
  Widget build(BuildContext context) {
    final isUrdu = question.isUrdu;
    final crossAxis = isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final table = question.table;
    Widget content;
    if (table == null || table.isEmpty) {
      content = _prefixedText(question.text, isUrdu);
    } else {
      final text = question.text;
      final markerIndex = text.indexOf(_marker);
      if (markerIndex < 0) {
        // No marker — table goes above the (still Q-prefixed) text.
        content = Column(
          crossAxisAlignment: crossAxis,
          children: [
            _QuestionTable(rows: table),
            const SizedBox(height: 10),
            _prefixedText(text, isUrdu),
          ],
        );
      } else {
        final before = text.substring(0, markerIndex);
        final after = text.substring(markerIndex + _marker.length);
        content = Column(
          crossAxisAlignment: crossAxis,
          children: [
            if (before.trim().isNotEmpty) ...[
              _prefixedText(before, isUrdu),
              const SizedBox(height: 10),
            ],
            _QuestionTable(rows: table),
            if (after.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              before.trim().isEmpty
                  ? _prefixedText(after, isUrdu)
                  : Text(
                      after,
                      style: style,
                      textAlign: isUrdu ? TextAlign.right : null,
                    ),
            ],
          ],
        );
      }
    }

    if (!isUrdu) return content;
    return Directionality(textDirection: TextDirection.rtl, child: content);
  }

  Widget _prefixedText(String text, bool isUrdu) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Q$number. ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: text),
        ],
      ),
      style: style,
      textAlign: isUrdu ? TextAlign.right : null,
    );
  }
}

class _QuestionTable extends StatelessWidget {
  const _QuestionTable({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white24 : Colors.black26;
    final headerFill = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.06,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: borderColor),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: r == 0 ? BoxDecoration(color: headerFill) : null,
              children: [
                for (final cell in rows[r])
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      cell,
                      style: TextStyle(
                        fontWeight: r == 0 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
