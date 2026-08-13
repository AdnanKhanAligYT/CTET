import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/exam_node.dart';
import '../../../../core/models/test_set.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/load_error.dart';
import '../../../../core/widgets/network_logo_avatar.dart';
import '../../../profile/application/profile_controller.dart';
import '../../data/exam_catalog_repository.dart';

/// First screen behind both the "Mock Test" and "Previous Year Questions"
/// dashboard tiles — same screen, same data source, just a different
/// [type] so the next screen (PaperListScreen -> TestSetListScreen) knows
/// which list of test sets to eventually show. Scoped to the student's
/// own exam selection (profile.exams) — someone preparing only for CTET
/// Paper 1 shouldn't have to wade through every other state's TET here.
class ExamListScreen extends ConsumerStatefulWidget {
  const ExamListScreen({super.key, required this.type});

  final TestSetType type;

  @override
  ConsumerState<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends ConsumerState<ExamListScreen> {
  final _repository = ExamCatalogRepository();
  bool _loading = true;
  String? _error;
  List<ExamNode> _exams = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref.read(userProfileProvider.future);
      final exams = await _repository.fetchTopLevelExams(
        widget.type,
        allowedNames: profile?.exams,
      );
      if (!mounted) return;
      setState(() {
        _exams = exams;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == TestSetType.mockTest
        ? 'Mock Test'
        : 'Previous Year Questions';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: LoadError(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: _exams.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aapke chune hue exam(s) ke liye abhi kuch add nahi hua hai.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _exams.length,
                itemBuilder: (context, index) {
                  final exam = _exams[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: NetworkLogoAvatar(
                        url: exam.logoUrl,
                        fallbackIcon: Icons.school_outlined,
                        fallbackColor: AppColors.tileMockTest,
                      ),
                      title: Text(
                        exam.name,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _repository.recordExamOpened(exam.id);
                        context.push(
                          '/mock-test/papers?type=${widget.type.value}',
                          extra: exam,
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
