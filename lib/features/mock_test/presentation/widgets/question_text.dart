import 'package:flutter/material.dart';

import '../../../../core/models/question.dart';

/// Renders a question's "Q<n>. " prefixed text, inserting its optional
/// table and any images at their literal markers within [Question.text]:
/// "{{table}}" for the table, "{{img}}" for an image. Content with no
/// markers falls back to table-above-text (mirrors the reference PHP
/// app's take_test.php), with images appended below.
///
/// Images need no per-image number: each "{{img}}" marker is filled, in
/// the order markers appear in the text, by the next entry in
/// [Question.images] — so a marker can be placed above the text, in the
/// middle, or at the end, and authors never have to track an index.
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

  static final RegExp _markerPattern = RegExp(r'\{\{table\}\}|\{\{img\}\}');

  @override
  Widget build(BuildContext context) {
    final isUrdu = question.isUrdu;
    final content = _buildContent(isUrdu);

    if (!isUrdu) return content;
    return Directionality(textDirection: TextDirection.rtl, child: content);
  }

  Widget _buildContent(bool isUrdu) {
    final crossAxis = isUrdu
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final text = question.text;
    final table = question.table;
    final images = question.images;

    final matches = _markerPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      final children = <Widget>[
        if (table != null && table.isNotEmpty) ...[
          _QuestionTable(rows: table),
          const SizedBox(height: 10),
        ],
        _prefixedText(text, isUrdu, true),
        for (final url in images) ...[
          const SizedBox(height: 10),
          _QuestionImage(url: url),
        ],
      ];
      return Column(crossAxisAlignment: crossAxis, children: children);
    }

    final children = <Widget>[];
    var cursor = 0;
    var imageIndex = 0;
    var usedTable = false;
    var prefixed = false;

    void addText(String chunk) {
      if (chunk.trim().isEmpty) return;
      if (children.isNotEmpty) children.add(const SizedBox(height: 10));
      children.add(_prefixedText(chunk, isUrdu, !prefixed));
      prefixed = true;
    }

    void addWidget(Widget widget) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 10));
      children.add(widget);
    }

    for (final match in matches) {
      addText(text.substring(cursor, match.start));
      cursor = match.end;
      switch (match.group(0)) {
        case '{{table}}':
          if (table != null && table.isNotEmpty && !usedTable) {
            addWidget(_QuestionTable(rows: table));
            usedTable = true;
          }
        case '{{img}}':
          if (imageIndex < images.length) {
            addWidget(_QuestionImage(url: images[imageIndex]));
            imageIndex++;
          }
      }
    }
    addText(text.substring(cursor));

    // Any table/images the author forgot to mark get appended, so nothing
    // uploaded is ever silently dropped.
    if (table != null && table.isNotEmpty && !usedTable) {
      children.insert(0, const SizedBox(height: 10));
      children.insert(0, _QuestionTable(rows: table));
    }
    for (; imageIndex < images.length; imageIndex++) {
      addWidget(_QuestionImage(url: images[imageIndex]));
    }

    return Column(crossAxisAlignment: crossAxis, children: children);
  }

  Widget _prefixedText(String text, bool isUrdu, bool withPrefix) {
    if (!withPrefix) {
      return Text(
        text,
        style: style,
        textAlign: isUrdu ? TextAlign.right : null,
      );
    }
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

/// A single figure/diagram referenced by a "{{img}}" marker.
class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: double.infinity,
        height: 200,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}
