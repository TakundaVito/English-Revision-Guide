import 'package:emma_prep_english/models/question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> validQuestion() => {
    'paper': 'Paper 2',
    'examStyle': 'zimsec-4005',
    'question': 'Which answer is correct?',
    'answers': ['A', 'B', 'C', 'D'],
    'correctIndex': 2,
    'explanation': 'C is supported by the passage.',
  };

  test('parses a valid ZIMSEC 4005 question', () {
    final question = Question.fromJson(validQuestion());

    expect(question.paper, 'Paper 2');
    expect(question.q, 'Which answer is correct?');
    expect(question.a, ['A', 'B', 'C', 'D']);
    expect(question.correct, 2);
    expect(question.why, 'C is supported by the passage.');
    expect(question.examStyle, 'zimsec-4005');
  });

  test('rejects a question from another exam style', () {
    final json = validQuestion()..['examStyle'] = 'other';

    expect(() => Question.fromJson(json), throwsFormatException);
  });

  test('rejects an invalid answer count or correct index', () {
    final tooFewAnswers = validQuestion()..['answers'] = ['A', 'B'];
    final invalidIndex = validQuestion()..['correctIndex'] = 4;

    expect(() => Question.fromJson(tooFewAnswers), throwsFormatException);
    expect(() => Question.fromJson(invalidIndex), throwsFormatException);
  });

  test('normalizes an unknown paper to Paper 1', () {
    final json = validQuestion()..['paper'] = 'Unknown';

    expect(Question.fromJson(json).paper, 'Paper 1');
  });
}
