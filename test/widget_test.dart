// Простой smoke test
import 'package:flutter_test/flutter_test.dart';
import 'package:psy_app/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const PsyApp());
    expect(find.byType(PsyApp), findsOneWidget);
  });
}