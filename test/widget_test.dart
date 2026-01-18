import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:android_test/main.dart';

void main() {
  testWidgets('Home screen displays three buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify that the home screen has the three main buttons
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);
    expect(find.text('Solo'), findsOneWidget);

    // Verify the banner is displayed
    expect(find.text('Esperanto Critique Tool'), findsWidgets);
  });

  testWidgets('Solo mode navigates to game screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap the Solo button
    await tester.tap(find.text('Solo'));
    await tester.pumpAndSettle();

    // Verify we're on the game screen
    expect(find.text('Mode: solo'), findsOneWidget);
  });

  testWidgets('Counter increments in game screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Navigate to Solo game
    await tester.tap(find.text('Solo'));
    await tester.pumpAndSettle();

    // Verify initial counter
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the increment button
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify counter incremented
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Host screen shows game name input', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap the Host button
    await tester.tap(find.text('Host'));
    await tester.pumpAndSettle();

    // Verify we're on the host screen with name input
    expect(find.text('Enter Game Name:'), findsOneWidget);
    expect(find.text('Start Hosting'), findsOneWidget);
  });
}
