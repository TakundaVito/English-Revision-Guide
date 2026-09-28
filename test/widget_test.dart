import 'package:emma_prep_english/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every bundled lesson has a practical example and task', () {
    expect(lessons, isNotEmpty);
    for (final lesson in lessons) {
      final example = practicalExample(lesson);
      expect(example.worked.trim(), isNotEmpty, reason: lesson.id);
      expect(example.task.trim(), isNotEmpty, reason: lesson.id);
    }
  });

  test('remote practice rejects non-ZIMSEC and malformed questions', () {
    expect(
      () => Question.fromJson({
        'paper': 'Paper 2',
        'examStyle': 'general-english',
        'question': 'Unrelated trivia',
        'answers': ['A', 'B', 'C', 'D'],
        'correctIndex': 0,
        'explanation': 'Not curriculum content',
      }),
      throwsFormatException,
    );
    expect(
      () => Question.fromJson({
        'paper': 'Paper 2',
        'examStyle': 'zimsec-4005',
        'question': 'Malformed question',
        'answers': ['Only one answer'],
        'correctIndex': 0,
      }),
      throwsFormatException,
    );
  });

  test('valid ZIMSEC 4005 remote question is accepted', () {
    final question = Question.fromJson({
      'paper': 'Paper 2',
      'examStyle': 'zimsec-4005',
      'question': 'Which answer paraphrases the sentence accurately?',
      'answers': ['A', 'B', 'C', 'D'],
      'correctIndex': 1,
      'explanation': 'B preserves the original meaning in new words.',
    });
    expect(question.paper, 'Paper 2');
    expect(question.examStyle, 'zimsec-4005');
  });

  test('key Paper 1 crash lessons include model answers', () {
    const ids = {
      'p1-description-2024',
      'p1-statement-story-2024',
      'p1-argument-2024',
      'p1-open-title-2024',
      'p1-guided-letter-2024',
    };
    for (final lesson in lessons.where((lesson) => ids.contains(lesson.id))) {
      expect(modelAnswerFor(lesson), isNotNull, reason: lesson.id);
      expect(
        modelAnswerFor(lesson)!.length,
        greaterThan(500),
        reason: lesson.id,
      );
    }
  });

  test('coach output never exposes hidden reasoning or markdown noise', () {
    final displayed = coachDisplayText(
      '<think>Private chain of thought</think>\n**Answer**\n- Read the command word.',
    );
    expect(displayed, isNot(contains('Private chain of thought')));
    expect(displayed, isNot(contains('<think>')));
    expect(displayed, isNot(contains('**')));
    expect(displayed, contains('• Read the command word.'));
  });

  testWidgets('learner home contains only product-facing content', (
    tester,
  ) async {
    await tester.pumpWidget(const EmmaPrep());
    expect(find.text('POWERED BY'), findsOneWidget);
    expect(find.text('TAKUNDA VITO'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('Student'), findsOneWidget);
    expect(find.textContaining('private edition'), findsNothing);
    expect(find.text('48-hour Paper 1 route'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Paper 1'), findsOneWidget);
    expect(find.text('Paper 2'), findsOneWidget);
  });

  testWidgets('shows a remotely supplied home notice', (tester) async {
    final store = Store()
      ..announcements.add({
        'title': 'New practice available',
        'message': 'Open Paper 2 to try the new questions.',
      });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Home(store))));
    expect(find.text('New practice available'), findsOneWidget);
    expect(find.text('Open Paper 2 to try the new questions.'), findsOneWidget);
  });
}
