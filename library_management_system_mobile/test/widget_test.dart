import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:library_management_system_mobile/main.dart';

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MyApp());

  await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the main sections of the home page',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('Good morning, Alex'), findsOneWidget);
    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('Due soon'), findsOneWidget);
    expect(find.text('Browse by category'), findsOneWidget);
    expect(find.text('New arrivals'), findsOneWidget);
    expect(find.text('Popular this week'), findsOneWidget);

    // Bottom navigation
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('My books'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('category chip filters the popular list',
      (WidgetTester tester) async {
    await pumpApp(tester);

    // Before filtering, a Fiction book is visible in the popular list.
    expect(find.text('Jane Eyre'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Mystery'));
    await tester.pump();

    expect(find.text('Popular in Mystery'), findsOneWidget);
    expect(find.text('The Hound of the Baskervilles'), findsWidgets);
    expect(find.text('Jane Eyre'), findsNothing);

    // Selecting "All" restores the full list.
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pump();

    expect(find.text('Popular this week'), findsOneWidget);
    expect(find.text('Jane Eyre'), findsWidgets);
  });

  testWidgets('tapping a bottom navigation item selects it',
      (WidgetTester tester) async {
    await pumpApp(tester);

    NavigationBar bar() =>
        tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(bar().selectedIndex, 0);

    await tester.tap(find.text('Explore'));
    await tester.pump();

    expect(bar().selectedIndex, 1);
  });
}