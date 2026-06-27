import 'package:apex/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The spotlight has an intentional looping pulse, so pumpAndSettle would never
// return. Pump a fixed window instead — long enough to run the post-frame
// measure and the 320ms re-measure timer.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final targetKey = GlobalKey();

  Future<void> pumpTour(
    WidgetTester tester, {
    required List<TourStep> steps,
    required VoidCallback onFinish,
    void Function(TourStep step)? onStep,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Scaffold(body: Center(child: SizedBox(key: targetKey, width: 50, height: 50))),
            OnboardingOverlay(steps: steps, onFinish: onFinish, onStep: onStep),
          ],
        ),
      ),
    );
    await settle(tester);
  }

  List<TourStep> steps() => [
        const TourStep(title: 'Welcome', body: 'Hi'),
        TourStep(targetKey: targetKey, title: 'Target', body: 'Look here'),
        const TourStep(title: 'End', body: 'Bye'),
      ];

  testWidgets('shows the step counter and advances with Next', (tester) async {
    await pumpTour(tester, steps: steps(), onFinish: () {});

    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    // No Back on the first step.
    expect(find.text('Back'), findsNothing);

    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('Back returns to the previous step', (tester) async {
    await pumpTour(tester, steps: steps(), onFinish: () {});
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Back'));
    await settle(tester);
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('Skip ends the tour immediately', (tester) async {
    var finished = 0;
    await pumpTour(tester, steps: steps(), onFinish: () => finished++);
    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(finished, 1);
  });

  testWidgets('last step shows Done and finishes', (tester) async {
    var finished = 0;
    await pumpTour(tester, steps: steps(), onFinish: () => finished++);
    await tester.tap(find.text('Next')); // -> 2/3
    await settle(tester);
    await tester.tap(find.text('Next')); // -> 3/3
    await settle(tester);
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(finished, 1);
  });

  testWidgets('reports the active step so the host can switch tabs',
      (tester) async {
    final seen = <int?>[];
    final s = [
      const TourStep(tab: 0, title: 'A', body: 'a'),
      const TourStep(tab: 3, title: 'B', body: 'b'),
    ];
    await pumpTour(tester, steps: s, onFinish: () {}, onStep: (step) => seen.add(step.tab));
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(seen, contains(0));
    expect(seen, contains(3));
  });
}
