// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:property_app/main.dart' as app;
import 'package:property_app/screens/home/home_view.dart';
import 'package:property_app/screens/home/profile_view.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/shared.dart';

void main() {
  setUp(() {
    AppSession.reset();
  });

  tearDown(() {
    AppSession.reset();
  });

  testWidgets('Smoke test (app loads)', (WidgetTester tester) async {
    await tester.pumpWidget(const app.PropertyApp());
    // Let any splash/init timers fire before the widget tree is torn down.
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify we rendered something from the app.
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Home view uses the active session avatar and name',
      (WidgetTester tester) async {
    AppSession.currentUserName = 'Amina Kariuki';
    AppSession.currentUserEmail = 'amina.kariuki@example.com';
    AppSession.currentUserAvatar = 'assets/images/profile.jpg';

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeView(),
      ),
    );

    expect(find.text('Hello, Amina Kariuki 👋'), findsOneWidget);
    expect(find.byType(Avatar), findsOneWidget);
  });

  testWidgets('Profile view uses the active session avatar and name',
      (WidgetTester tester) async {
    AppSession.currentUserName = 'Amina Kariuki';
    AppSession.currentUserEmail = 'amina.kariuki@example.com';
    AppSession.currentUserAvatar = 'assets/images/profile.jpg';

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileView(),
      ),
    );

    expect(find.text('Amina Kariuki'), findsOneWidget);
    expect(find.text('amina.kariuki@example.com'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });
}
