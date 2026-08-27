import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/ad_service.dart';
import '../../data/mock_test_repository.dart';
import '../subject_style.dart';

/// Behind a Subject Wise Revision subject tap — lists that subject's
/// pre-computed blocks (see migration_subject_blocks.sql): "CDP 1st",
/// "CDP 2nd", etc., each a frozen, complete chunk of 30 questions (60 for
/// SST). A block only exists once enough questions have been uploaded to
/// fill it — there's never a trailing partial one — and its membership
/// never changes once created, so "CDP 1st" always means the same
/// questions. This list is just one cheap query now instead of fetching
/// every question in the subject to compute where the boundaries fall.
class SubjectBlockListScreen extends StatefulWidget {
  const SubjectBlockListScreen({super.key, required this.subject});

  final String subject;

  @override
  State<SubjectBlockListScreen> createState() =>
      _SubjectBlockListScreenState();
}

class _SubjectBlockListScreenState extends State<SubjectBlockListScreen> {
  final _repository = MockTestRepository();
  bool _loading = true;
  String? _errorMessage;
  List<({int blockIndex, List<String> questionIds})> _blocks = const [];
  Map<int, int> _openCounts = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final blocks = await _repository.fetchSubjectBlocks(widget.subject);
      final openCounts = await _repository.fetchSubjectBlockOpenCounts(
        widget.subject,
      );
      if (!mounted) return;
      setState(() {
        _blocks = blocks;
        _openCounts = openCounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = subjectStyleFor(widget.subject);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.subject)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.subject)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_errorMessage!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      bottomNavigationBar: const AppBannerAd(),
      appBar: AppBar(title: Text(widget.subject)),
      body: SafeArea(
        child: _blocks.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Abhi is subject ka pehla poora block ban nahi paya — thode aur questions upload hone chahiye.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _blocks.length,
                itemBuilder: (context, index) {
                  final block = _blocks[index];
                  // Only the topmost block is free — every other one shows
                  // a full-screen interstitial ad first, same rule as the
                  // Mock Test / PYQ test list (see [isFree] there).
                  final isFree = index == 0;
                  final destination =
                      '/mock-test/take?subject=${Uri.encodeComponent(widget.subject)}&block=${block.blockIndex}';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: style.color,
                        child: Icon(style.icon, color: Colors.white),
                      ),
                      title: Text(
                        '${widget.subject} ${_ordinal(index + 1)}',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: style.color,
                            ),
                      ),
                      subtitle: Text(
                        'Opened ${_openCounts[block.blockIndex] ?? 0}x',
                      ),
                      trailing: isFree
                          ? const Icon(Icons.chevron_right)
                          : const Icon(Icons.lock_outline, size: 20),
                      onTap: () {
                        _repository.recordSubjectBlockOpened(
                          widget.subject,
                          block.blockIndex,
                        );
                        if (isFree) {
                          context.push(destination);
                        } else {
                          AdService.showBeforeOpeningContent(
                            () => context.push(destination),
                            ignoreCooldown: true,
                          );
                        }
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// 1 -> "1st", 2 -> "2nd", 3 -> "3rd", 4 -> "4th", 11-13 -> "th" (English
/// ordinal suffix rules, including the 11th/12th/13th exception).
String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}
