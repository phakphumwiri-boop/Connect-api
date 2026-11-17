import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('ISH app displays the chat screen', (tester) async {
    await tester.pumpWidget(const IshApp());

    expect(find.text('ISH Assistant'), findsOneWidget);
    expect(find.text('ส่งข้อความเพื่อเริ่มสนทนากับ ISH'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
