import 'package:emma_prep_english/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Emmaculate personalised home screen', (tester) async {
    await tester.pumpWidget(const EmmaPrep());
    await tester.pumpAndSettle();
    expect(find.text('Emmaculate ✦'), findsOneWidget);
    expect(find.text('Paper 1'), findsOneWidget);
    expect(find.text('Paper 2'), findsOneWidget);
  });
}
