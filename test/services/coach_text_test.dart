import 'package:emma_prep_english/services/coach_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('coachDisplayText', () {
    test('removes hidden reasoning and markdown decoration', () {
      const raw =
          '<think>private chain of thought</think>\n'
          '## Revision plan\n**Read** the passage.';

      expect(coachDisplayText(raw), 'Revision plan\nRead the passage.');
    });

    test('normalizes escaped lines, bullets and excess spacing', () {
      const raw = r'- First point\n* Second point\n\n\nFinal point';

      expect(
        coachDisplayText(raw),
        '• First point\n• Second point\n\nFinal point',
      );
    });

    test('handles empty and fenced responses safely', () {
      expect(coachDisplayText('  '), isEmpty);
      expect(coachDisplayText('```markdown\nAnswer\n```'), 'Answer');
    });
  });
}
