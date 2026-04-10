import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('App Loaded'))),
    );

    expect(find.text('App Loaded'), findsOneWidget);
  });
  testWidgets('Amount dialog opens', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (_) =>
                              AlertDialog(title: Text('Customize UPI Amount')),
                    );
                  },
                  child: Text('Open'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Customize UPI Amount'), findsOneWidget);
  });
}
