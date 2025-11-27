import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interest_estimator/main.dart';

void main() {
  testWidgets('App displays main UI elements', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Check app bar title
    expect(find.text('Pawn Broker Interest'), findsOneWidget);
    
    // Check input fields
    expect(find.text('Loan Amount'), findsOneWidget);
    expect(find.text('Interest Rate (% per month)'), findsOneWidget);
    expect(find.text('Loan Date'), findsOneWidget);
    
    // Check calculate button
    expect(find.text('Calculate Interest'), findsOneWidget);
    
    // Check reset button
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('Interest rate has default value of 2.0', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Find all TextFormField widgets
    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(2));
    
    // Check that default interest rate is 2.0
    expect(find.text('2.0'), findsOneWidget);
  });

  testWidgets('Date picker can be opened', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Find and tap the date picker
    final datePicker = find.text('Select loan date');
    expect(datePicker, findsOneWidget);
    
    await tester.tap(datePicker);
    await tester.pumpAndSettle();
    
    // Date picker dialog should appear
    expect(find.text('Select Loan Date'), findsOneWidget);
  });

  testWidgets('Calculate button is disabled without date', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Find the calculate button
    final calculateButton = find.widgetWithText(FilledButton, 'Calculate Interest');
    expect(calculateButton, findsOneWidget);
    
    // Button should be disabled (onPressed is null)
    final button = tester.widget<FilledButton>(calculateButton);
    expect(button.onPressed, isNull);
  });
}
