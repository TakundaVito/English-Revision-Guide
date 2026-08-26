import 'package:emma_prep_english/main.dart';
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

  testWidgets('shows Emmaculate personalised home screen', (tester) async {
    await tester.pumpWidget(const EmmaPrep());
    await tester.pumpAndSettle();
    expect(find.text('Emmaculate'), findsOneWidget);
    expect(find.text('Paper 1'), findsOneWidget);
    expect(find.text('Paper 2'), findsOneWidget);
  });
}
