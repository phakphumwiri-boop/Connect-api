import 'package:flutter_test/flutter_test.dart';
import 'package:ish_app/main.dart';

void main() {
  testWidgets('Connect Machine Lab dashboard renders', (tester) async {
    await tester.pumpWidget(const IshApp());

    expect(find.text('Connect Machine Lab'), findsOneWidget);
    expect(find.text('เชื่อมต่อ Python API'), findsOneWidget);
    expect(find.text('Admin token'), findsOneWidget);
  });
}
