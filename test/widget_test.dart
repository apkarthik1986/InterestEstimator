import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interest_estimator/main.dart';

void main() {
  testWidgets('App displays main UI elements', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Check app bar title
    expect(find.text('Pawn Broker Interest'), findsOneWidget);
    
    // Check input fields
    expect(find.text('Loan Amount'), findsOneWidget);
    expect(find.text('Loan Date'), findsOneWidget);
    
    // Check settings and reset buttons in app bar
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('Interest rate is displayed and default is 2.0', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Check that default interest rate is displayed
    expect(find.textContaining('2.00% per month'), findsOneWidget);
    
    // Check Change button to access settings
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('Settings dialog can be opened', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Find and tap the settings icon
    final settingsButton = find.byIcon(Icons.settings);
    expect(settingsButton, findsOneWidget);
    
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();
    
    // Settings dialog should appear
    expect(find.text('⚙️ Base Settings'), findsOneWidget);
    expect(find.text('Interest Rate (% per month)'), findsOneWidget);
  });

  testWidgets('Date picker can be opened', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Find and tap the date picker
    final datePicker = find.text('Select loan date');
    expect(datePicker, findsOneWidget);
    
    await tester.tap(datePicker);
    await tester.pumpAndSettle();
    
    // Date picker dialog should appear
    expect(find.text('Select Loan Date'), findsOneWidget);
  });

  testWidgets('Print button is not visible when no results are displayed', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Print button should not be visible when no results
    expect(find.byIcon(Icons.print), findsNothing);
    expect(find.text('Print / Save PDF'), findsNothing);
  });
}
