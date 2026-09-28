import 'package:emma_prep_english/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home exposes its core navigation at a narrow phone size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Home(Store()))));
    await tester.pumpAndSettle();

    expect(find.text('48-hour Paper 1 route'), findsOneWidget);
    expect(find.text('Paper 1'), findsOneWidget);
    expect(find.text('Paper 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remote notice presents both title and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RemoteNoticeCard(
            title: 'New revision pack',
            message: 'Paper 2 questions are ready.',
            icon: Icons.campaign_rounded,
          ),
        ),
      ),
    );

    expect(find.text('New revision pack'), findsOneWidget);
    expect(find.text('Paper 2 questions are ready.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text remains renderable on the accessibility page', (
    tester,
  ) async {
    final store = Store()..textScale = 1.4;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: AccessibilityPage(store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AccessibilityPage), findsOneWidget);
    expect(find.textContaining('Accessibility'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('company evaluation guide exposes a structured review plan', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: EvaluationGuidePage(Store())));

    expect(find.text('Company evaluation'), findsOneWidget);
    expect(find.textContaining('Welcome'), findsOneWidget);
    expect(find.text('Review the curriculum'), findsOneWidget);
    expect(find.text('Complete a quiz'), findsOneWidget);
    expect(find.text('Test offline use'), findsOneWidget);
    expect(find.text('Check accessibility'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Inspect progress tracking'),
      200,
    );
    expect(find.text('Inspect progress tracking'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Start evaluating'), 200);
    expect(find.text('Start evaluating'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
