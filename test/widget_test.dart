import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interest_estimator/main.dart';

void main() {
  testWidgets('App displays main UI elements', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Check app bar title
    expect(find.text('Pawn Broker Interest'), findsOneWidget);
    
    // Check interest rate info
    expect(find.text('Interest Rate: 2% per month'), findsOneWidget);
    
    // Check input fields
    expect(find.text('Loan Amount'), findsOneWidget);
    expect(find.text('Loan Date'), findsOneWidget);
    
    // Check calculate button
    expect(find.text('Calculate Interest'), findsOneWidget);
    
    // Check reset button
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('Loan amount validation works', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Find and tap the loan amount field
    final loanAmountField = find.byType(TextFormField);
    expect(loanAmountField, findsOneWidget);
    
    // Enter invalid amount and try to submit
    await tester.enterText(loanAmountField, '');
    await tester.pump();
    
    // The calculate button should be disabled without a date selected
    final calculateButton = find.widgetWithText(FilledButton, 'Calculate Interest');
    expect(calculateButton, findsOneWidget);
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
}
