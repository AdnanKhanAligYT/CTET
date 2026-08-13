import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/test_set.dart';
import '../../data/test_set_repository.dart';
import 'named_test_screen.dart';

/// Landing pad for a notification's "open this specific test" deep link —
/// only a test_set_id travels in the push payload, not a full TestSet
/// object (unlike normal in-app navigation, which always already has one
/// in hand via `extra`), so this screen fetches it once, then hands off to
/// whichever flow that test set actually belongs to (Mock Test's
/// instructions -> take-v2, or PYQ's named-test flow) and removes itself
/// from the stack.
class DeepLinkTestOpenScreen extends StatefulWidget {
  const DeepLinkTestOpenScreen({super.key, required this.testSetId});

  final String testSetId;

  @override
  State<DeepLinkTestOpenScreen> createState() =>
      _DeepLinkTestOpenScreenState();
}

class _DeepLinkTestOpenScreenState extends State<DeepLinkTestOpenScreen> {
  final _repository = TestSetRepository();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final testSet = await _repository.fetchTestSetById(widget.testSetId);
      if (!mounted) return;
      if (testSet == null) {
        setState(() => _error = 'Ye test ab available nahi hai.');
        return;
      }
      // A set cross-listed into both flows (types contains both) defaults
      // to the Mock Test instructions flow — same choice the admin tool's
      // "Test Start Karo" buttons make elsewhere for a dual-listed set.
      if (testSet.types.contains(TestSetType.mockTest)) {
        context.pushReplacement('/mock-test/instructions', extra: testSet);
      } else {
        context.pushReplacement(
          '/mock-test/named',
          extra: NamedTestArgs(testSet: testSet),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
