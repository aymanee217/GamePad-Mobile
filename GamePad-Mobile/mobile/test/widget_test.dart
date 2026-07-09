import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gamepad_mobile/main.dart';

void main() {
  testWidgets('App renders controller screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GamePadApp()));
    expect(find.text('GamePad Mobile'), findsOneWidget);
  });
}
