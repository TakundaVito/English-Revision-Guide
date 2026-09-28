import 'package:emmaprep_admin/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows safe configuration guidance without local defines', (
    tester,
  ) async {
    await tester.pumpWidget(const AdminApp());
    expect(find.textContaining('needs configuration'), findsOneWidget);
  });

  group('admin input helpers', () {
    test('splitLines trims entries and removes blank rows', () {
      expect(splitLines(' First point \n\n Second point\n   \nThird point '), [
        'First point',
        'Second point',
        'Third point',
      ]);
    });

    test('input decoration preserves its label and optional hint', () {
      final decoration = input('Lesson title', 'Enter a clear title');
      expect(decoration.labelText, 'Lesson title');
      expect(decoration.hintText, 'Enter a clear title');
      expect(decoration.border, isA<OutlineInputBorder>());
    });

    test('network errors are reduced to a safe non-sensitive message', () {
      final message = safeFunctionError(Exception('secret internal detail'));
      expect(message, contains('Network request failed'));
      expect(message, isNot(contains('secret internal detail')));
    });
  });
}
