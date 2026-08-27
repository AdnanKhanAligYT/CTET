import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/test_set.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/widgets/primary_button.dart';
import 'mock_test_taking_screen.dart';

/// Shown once before a Mock Test starts (not on resume — a resumed attempt
/// jumps straight back into MockTestTakingScreen) — bilingual instructions,
/// same convention as real competitive-exam software, then "Start Test"
/// opens the actual test.
class MockTestInstructionsScreen extends StatelessWidget {
  const MockTestInstructionsScreen({super.key, required this.testSet});

  final TestSet testSet;

  static const _points = [
    (
      'Internet connection stable rakhein — test ke dauran connection na tootne dein.',
      'Keep a stable internet connection — do not let it drop during the test.',
    ),
    (
      'Sabhi sawaalon ko attempt karne ki koshish karein.',
      'Attempt all questions.',
    ),
    (
      'Ye test latest exam pattern par aadharit hai.',
      'This test is based on the latest exam pattern.',
    ),
    (
      'Ek baar chuna gaya option kisi bhi samay badla ja sakta hai, jab tak Submit na karein.',
      'A selected option can be changed anytime until you submit.',
    ),
    (
      'Option chunne par turant sahi/galat nahi dikhaya jayega — result sirf submit karne ke baad milega.',
      'Selecting an option will not reveal whether it is correct — results are shown only after submitting.',
    ),
    (
      'Kisi bhi sawaal ko baad mein dekhne ke liye "Flag" kar sakte hain.',
      'You can "Flag" any question to revisit it later.',
    ),
    (
      'Upar-daayen navigator se kisi bhi sawaal par seedha ja sakte hain.',
      'Use the top-right navigator to jump directly to any question.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBannerAd(),
      appBar: AppBar(title: Text(testSet.name)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Instructions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'निर्देश',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  for (final point in _points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ', style: TextStyle(fontSize: 16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  point.$1,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  point.$2,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: PrimaryButton(
                  label: 'Start Test',
                  onPressed: () {
                    context.pushReplacement(
                      '/mock-test/take-v2',
                      extra: MockTestTakingArgs(
                        testSet: testSet,
                        resumeSession: null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
