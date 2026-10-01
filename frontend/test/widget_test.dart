// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:property_app/main.dart' as app;
import 'package:property_app/screens/auth/login_view.dart';
import 'package:property_app/screens/home/home_view.dart';
import 'package:property_app/screens/home/profile_view.dart';
import 'package:property_app/screens/landlord/listing_flow.dart';
import 'package:property_app/session/app_session.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AppSession.reset();
  });

  tearDown(() {
    AppSession.reset();
  });

  testWidgets('Smoke test (app loads)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const app.PropertyApp());
    // Let any splash/init timers fire before the widget tree is torn down.
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify we rendered something from the app.
    expect(find.byType(MaterialApp), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Mobile login opens as a full-page route',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const app.PropertyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginView), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Listing title edits are cached as a draft',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api');
    AppSession.reset();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(home: AddListingFlow()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Harbor apartment');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    final cachedDraft = preferences.getString('staynest.local_draft.anonymous');
    expect(cachedDraft, contains('Harbor apartment'));

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Home view uses the active session avatar and name',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    AppSession.currentUserName = 'Amina Kariuki';
    AppSession.currentUserEmail = 'amina.kariuki@example.com';
    AppSession.currentUserAvatar = 'assets/images/profile.jpg'; // non-default

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeView(),
      ),
    );

    expect(find.text('Hello, Amina Kariuki 👋'), findsOneWidget);
    expect(find.byType(Icon), findsWidgets);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Profile view uses the active session avatar and name',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

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
    expect(find.byType(Icon), findsWidgets);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
