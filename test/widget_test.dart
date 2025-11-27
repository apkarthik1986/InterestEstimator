import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interest_estimator/main.dart';

void main() {
  testWidgets('App displays welcome message', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Welcome to Interest Estimator'), findsOneWidget);
    expect(find.text('Your app is ready!'), findsOneWidget);
    expect(find.text('Interest Estimator'), findsOneWidget);
  });
}
