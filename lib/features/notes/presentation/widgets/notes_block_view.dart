import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/notes_block.dart';
import '../../../../core/theme/app_colors.dart';

/// Splits `text` on `**word**` pairs into bold/regular [TextSpan]s — the
/// one inline-formatting convention every free-text field in a Notes
/// block shares (see supabase/migration_notes.sql), rather than storing
/// separate markup per field or pulling in a full markdown renderer for
/// just this one case.
List<TextSpan> _parseBoldSpans(String text, TextStyle? base) {
  final spans = <TextSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*');
  var last = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start), style: base));
    }
    spans.add(
      TextSpan(
        text: match.group(1),
        style: base?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
    last = match.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: base));
  }
  return spans;
}

class _BoldText extends StatelessWidget {
  const _BoldText(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(TextSpan(children: _parseBoldSpans(text, base)));
  }
}

/// Renders one [NotesBlock] according to its `blockType` — see the shape
/// documented per type in `supabase/migration_notes.sql`. An unrecognized
/// `blockType` (e.g. content authored for a future type not handled here
/// yet) simply renders nothing rather than crashing the whole chapter.
class NotesBlockView extends StatelessWidget {
  const NotesBlockView({super.key, required this.block});

  final NotesBlock block;

  @override
  Widget build(BuildContext context) {
    final content = block.content;
    switch (block.blockType) {
      case 'heading':
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: _BoldText(
            content['text'] as String? ?? '',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        );

      case 'subheading':
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: _BoldText(
            content['text'] as String? ?? '',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        );

      case 'paragraph':
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _BoldText(
            content['text'] as String? ?? '',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );

      case 'points':
        final items = (content['items'] as List?)?.cast<Object?>() ?? const [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(
                        child: _BoldText(
                          item.toString(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

      case 'table':
        final rows = (content['rows'] as List?)
            ?.map((r) => (r as List).map((c) => c.toString()).toList())
            .toList();
        if (rows == null || rows.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _NotesTable(rows: rows),
        );

      case 'image':
        final url = content['url'] as String?;
        if (url == null || url.isEmpty) return const SizedBox.shrink();
        final caption = content['caption'] as String?;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (context, _) => const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, _, _) => const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
              if (caption != null && caption.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        );

      case 'pdf_file':
      case 'pdf_link':
        final url = content['url'] as String?;
        final name = content['name'] as String? ?? 'PDF';
        if (url == null || url.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _NotesPdfLink(name: name, url: url),
        );

      case 'example':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _NotesExample(content: content),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _NotesTable extends StatelessWidget {
  const _NotesTable({required this.rows});

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

class _NotesPdfLink extends StatelessWidget {
  const _NotesPdfLink({required this.name, required this.url});

  final String name;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ),
    );
  }
}

/// A PYQ-style reference example — question with lettered options, the
/// correct one highlighted green (a static reveal, unlike the interactive
/// Mock Test option tiles, since this is reference content, not a quiz).
class _NotesExample extends StatelessWidget {
  const _NotesExample({required this.content});

  final Map<String, dynamic> content;

  @override
  Widget build(BuildContext context) {
    final question = content['question'] as String? ?? '';
    final options = (content['options'] as List?)?.cast<Object?>();
    final correctIndex = (content['correct_index'] as num?)?.toInt();
    final explanation = content['explanation'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.tileMockTest.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Example',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.tileMockTest,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _BoldText(question, style: Theme.of(context).textTheme.bodyMedium),
          if (options != null && options.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${String.fromCharCode(65 + i)}. ',
                      style: TextStyle(
                        fontWeight: i == correctIndex
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: i == correctIndex ? Colors.green : null,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        options[i].toString(),
                        style: TextStyle(
                          fontWeight: i == correctIndex
                              ? FontWeight.w800
                              : FontWeight.w400,
                          color: i == correctIndex ? Colors.green : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (explanation != null && explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            _BoldText(
              explanation,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
