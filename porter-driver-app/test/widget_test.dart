import 'package:flutter_test/flutter_test.dart';
import 'package:porter_driver_app/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const PorterDriverApp());
    expect(find.text('Porter Driver'), findsOneWidget);
  });
}
