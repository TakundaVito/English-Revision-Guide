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

  testWidgets('shows Emmaculate personalised home screen', (tester) async {
    await tester.pumpWidget(const EmmaPrep());
    await tester.pumpAndSettle();
    expect(find.text('Emmaculate'), findsOneWidget);
    expect(find.text('Paper 1'), findsOneWidget);
    expect(find.text('Paper 2'), findsOneWidget);
  });
}
