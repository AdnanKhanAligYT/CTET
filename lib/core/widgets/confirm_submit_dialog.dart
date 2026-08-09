import 'package:flutter/material.dart';

/// Shared "submit this test now?" confirmation — behind every test flow's
/// bottom "Submit & Finish" button (Mock Test / PYQ / Subject Wise
/// Revision / daily due-today practice), so submitting mid-test always
/// asks first and the wording can't drift between flows. Returns true
/// only if the student confirmed.
Future<bool> confirmSubmitTest({
  required BuildContext context,
  required int attempted,
  required int total,
}) async {
  final remaining = total - attempted;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Test submit karna hai?'),
      content: Text(
        remaining > 0
            ? 'Aapne $total me se $attempted questions attempt kiye hain. '
                  'Baaki $remaining questions skip ho jayenge aur result abhi '
                  'tak attempt kiye gaye questions ke hisab se banega.'
            : 'Aapne saare $total questions attempt kar liye hain.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Submit'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
