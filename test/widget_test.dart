import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders basic shell widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('StyleBridge AI'),
        ),
      ),
    );

    expect(find.text('StyleBridge AI'), findsOneWidget);
  });
}
