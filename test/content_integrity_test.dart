import 'package:emma_prep_english/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bundled curriculum integrity', () {
    test('lesson identifiers are unique and required content is present', () {
      expect(lessons, isNotEmpty);
      expect(
        lessons.map((lesson) => lesson.id).toSet(),
        hasLength(lessons.length),
      );

      for (final lesson in lessons) {
        expect(lesson.id.trim(), isNotEmpty, reason: 'lesson id');
        expect(
          const {'Paper 1', 'Paper 2'},
          contains(lesson.paper),
          reason: lesson.id,
        );
        expect(lesson.title.trim(), isNotEmpty, reason: lesson.id);
        expect(lesson.sub.trim(), isNotEmpty, reason: lesson.id);
        expect(lesson.intro.trim(), isNotEmpty, reason: lesson.id);
        expect(lesson.notes, isNotEmpty, reason: lesson.id);
        expect(lesson.check, isNotEmpty, reason: lesson.id);
        expect(
          lesson.notes.every((item) => item.trim().isNotEmpty),
          isTrue,
          reason: '${lesson.id} has a blank note',
        );
        expect(
          lesson.check.every((item) => item.trim().isNotEmpty),
          isTrue,
          reason: '${lesson.id} has a blank checklist item',
        );
      }
    });

    test('both examination papers have meaningful lesson coverage', () {
      for (final paper in const ['Paper 1', 'Paper 2']) {
        expect(
          lessons.where((lesson) => lesson.paper == paper).length,
          greaterThanOrEqualTo(3),
          reason: '$paper needs enough material to be a useful course',
        );
      }
    });

    test('question bank is valid, explained, and covers both papers', () {
      expect(bank, isNotEmpty);
      for (final question in bank) {
        expect(const {'Paper 1', 'Paper 2'}, contains(question.paper));
        expect(question.examStyle, 'zimsec-4005');
        expect(question.q.trim(), isNotEmpty);
        expect(question.a, hasLength(4), reason: question.q);
        expect(
          question.a.every((answer) => answer.trim().isNotEmpty),
          isTrue,
          reason: question.q,
        );
        expect(question.a.toSet(), hasLength(4), reason: question.q);
        expect(question.correct, inInclusiveRange(0, 3), reason: question.q);
        expect(question.why.trim(), isNotEmpty, reason: question.q);
      }

      expect(bank.any((question) => question.paper == 'Paper 1'), isTrue);
      expect(bank.any((question) => question.paper == 'Paper 2'), isTrue);
    });
  });

  group('remote curriculum validation', () {
    test('lesson JSON is normalized to the supported paper names', () {
      final paperTwo = Lesson.fromJson({
        'id': 'summary',
        'paper': 'Paper 2',
        'title': 'Summary writing',
        'subtitle': 'Select and combine points',
        'introduction': 'A focused introduction.',
        'notes': ['Find the focus.'],
        'checklist': ['Count the words.'],
      });
      final unknownPaper = Lesson.fromJson({
        'id': 'unknown',
        'paper': 'Paper 3',
        'title': 'Fallback lesson',
      });

      expect(paperTwo.id, 'remote-summary');
      expect(paperTwo.paper, 'Paper 2');
      expect(paperTwo.notes, ['Find the focus.']);
      expect(unknownPaper.paper, 'Paper 1');
    });

    test('question JSON accepts only a valid ZIMSEC four-option item', () {
      final valid = Question.fromJson({
        'paper': 'Paper 1',
        'examStyle': 'zimsec-4005',
        'question': 'Choose the best opening.',
        'answers': ['A', 'B', 'C', 'D'],
        'correctIndex': 2,
        'explanation': 'C establishes the purpose and audience.',
      });
      expect(valid.correct, 2);

      for (final invalid in <Map<String, dynamic>>[
        {
          'paper': 'Paper 1',
          'examStyle': 'general-english',
          'answers': ['A', 'B', 'C', 'D'],
          'correctIndex': 0,
        },
        {
          'paper': 'Paper 1',
          'examStyle': 'zimsec-4005',
          'answers': ['A', 'B', 'C'],
          'correctIndex': 0,
        },
        {
          'paper': 'Paper 1',
          'examStyle': 'zimsec-4005',
          'answers': ['A', 'B', 'C', 'D'],
          'correctIndex': 4,
        },
      ]) {
        expect(() => Question.fromJson(invalid), throwsFormatException);
      }
    });
  });
}
