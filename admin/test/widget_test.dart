import 'package:emmaprep_admin/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows safe configuration guidance without local defines', (
    tester,
  ) async {
    await tester.pumpWidget(const AdminApp());
    expect(find.textContaining('needs configuration'), findsOneWidget);
  });
}
