import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/services/ad_service.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/timetable_repository.dart';
import '../../domain/timetable_block.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _repository = TimetableRepository();
  bool _loading = true;
  List<TimetableBlock> _blocks = const [];

  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    final blocks = await _repository.fetchBlocks(uid);
    blocks.sort((a, b) {
      final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (dayCompare != 0) return dayCompare;
      return a.startMinutes.compareTo(b.startMinutes);
    });
    if (!mounted) return;
    setState(() {
      _blocks = blocks;
      _loading = false;
    });
  }

  Future<void> _toggleDone(TimetableBlock block) async {
    final uid = _uid;
    if (uid == null) return;
    final newDone = !block.done;
    setState(() {
      _blocks = [
        for (final b in _blocks)
          if (b.id == block.id) b.copyWith(done: newDone) else b,
      ];
    });
    await _repository.setDone(uid, block.id, newDone);
  }

  Future<void> _deleteBlock(TimetableBlock block) async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _blocks = _blocks.where((b) => b.id != block.id).toList());
    await _repository.deleteBlock(uid, block.id);
  }

  Future<void> _openAddSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddBlockSheet(),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final grouped = <int, List<TimetableBlock>>{};
    for (final block in _blocks) {
      grouped.putIfAbsent(block.dayOfWeek, () => []).add(block);
    }

    return Scaffold(
      bottomNavigationBar: const AppBannerAd(),
      appBar: AppBar(title: const Text('Timetable')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: _blocks.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No study blocks yet — tap + to add your weekly schedule.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  for (var day = 1; day <= 7; day++)
                    if (grouped.containsKey(day)) ...[
                      Text(
                        weekdayNames[day - 1],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final block in grouped[day]!)
                        _BlockRow(
                          block: block,
                          onToggleDone: () => _toggleDone(block),
                          onDelete: () => _deleteBlock(block),
                        ),
                      const SizedBox(height: 20),
                    ],
                ],
              ),
      ),
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.block,
    required this.onToggleDone,
    required this.onDelete,
  });

  final TimetableBlock block;
  final VoidCallback onToggleDone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Checkbox(value: block.done, onChanged: (_) => onToggleDone()),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.subject,
                  style: TextStyle(
                    decoration: block.done ? TextDecoration.lineThrough : null,
                    color: block.done
                        ? Theme.of(context).textTheme.bodySmall?.color
                        : null,
                  ),
                ),
                Text(
                  block.timeRangeLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AddBlockSheet extends StatefulWidget {
  const _AddBlockSheet();

  @override
  State<_AddBlockSheet> createState() => _AddBlockSheetState();
}

class _AddBlockSheetState extends State<_AddBlockSheet> {
  final _repository = TimetableRepository();
  final _subjectController = TextEditingController();
  int _dayOfWeek = 1;
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 19, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final subject = _subjectController.text.trim();
    if (uid == null || subject.isEmpty) return;

    setState(() => _saving = true);
    await _repository.addBlock(
      uid,
      TimetableBlock(
        id: '',
        dayOfWeek: _dayOfWeek,
        startMinutes: _start.hour * 60 + _start.minute,
        endMinutes: _end.hour * 60 + _end.minute,
        subject: subject,
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Study Block',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _dayOfWeek,
              decoration: const InputDecoration(labelText: 'Day'),
              items: [
                for (var i = 1; i <= 7; i++)
                  DropdownMenuItem(value: i, child: Text(weekdayNames[i - 1])),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _dayOfWeek = value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text('Start: ${_start.format(context)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text('End: ${_end.format(context)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Subject / Topic'),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Add', isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
