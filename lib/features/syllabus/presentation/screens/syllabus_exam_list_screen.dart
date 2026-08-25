import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/exam_node.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/load_error.dart';
import '../../../../core/widgets/network_logo_avatar.dart';
import '../../../profile/application/profile_controller.dart';
import '../../../mock_test/data/exam_catalog_repository.dart';
import '../syllabus_navigation.dart';

/// First screen behind the "Syllabus Tracker" dashboard tile — same exam
/// catalog, same logos, same drill-down feel as Mock Test/PYQ
/// (ExamListScreen -> PaperListScreen), just walking straight through to
/// the syllabus for whichever paper the student ends up on instead of a
/// test-set list. Scoped to the student's own exam selection, same as
/// ExamListScreen.
class SyllabusExamListScreen extends ConsumerStatefulWidget {
  const SyllabusExamListScreen({super.key});

  @override
  ConsumerState<SyllabusExamListScreen> createState() =>
      _SyllabusExamListScreenState();
}

class _SyllabusExamListScreenState
    extends ConsumerState<SyllabusExamListScreen> {
  final _repository = ExamCatalogRepository();
  bool _loading = true;
  String? _error;
  List<ExamNode> _exams = const [];
  String? _openingId;

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
      final exams = await _repository.fetchTopLevelExamsForSyllabus(
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

  Future<void> _open(ExamNode exam) async {
    if (_openingId != null) return;
    setState(() => _openingId = exam.id);
    try {
      await navigateIntoSyllabusNode(
        context: context,
        repository: _repository,
        node: exam,
        marksExamFallback: exam.name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Syllabus';

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
                        fallbackIcon: Icons.checklist_outlined,
                        fallbackColor: AppColors.tileSyllabus,
                      ),
                      title: Text(
                        exam.name,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      trailing: _openingId == exam.id
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      enabled: _openingId == null,
                      onTap: () => _open(exam),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
