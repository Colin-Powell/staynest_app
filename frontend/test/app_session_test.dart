import 'package:flutter_test/flutter_test.dart';
import 'package:property_app/session/app_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSession.reset();
  });

  test('session snapshot preserves tokens and profile data', () {
    AppSession.updateCurrentUser({
      'id': '42',
      'name': 'Ada Lovelace',
      'email': 'ada@example.com',
      'phone': '123456789',
      'avatar': 'https://cdn.example.com/avatar.jpg',
      'role': 'tenant',
      'verified': true,
    });
    AppSession.apiToken = 'access-token';
    AppSession.refreshToken = 'refresh-token';

    final snapshot = AppSession.toSessionSnapshot();

    AppSession.reset();
    AppSession.applySessionSnapshot(snapshot);

    expect(AppSession.currentUserId, '42');
    expect(AppSession.currentUserName, 'Ada Lovelace');
    expect(AppSession.currentUserEmail, 'ada@example.com');
    expect(AppSession.currentUserAvatar, 'https://cdn.example.com/avatar.jpg');
    expect(AppSession.apiToken, 'access-token');
    expect(AppSession.refreshToken, 'refresh-token');
    expect(AppSession.currentUserVerified, isTrue);
  });

  test('persisted session restores tokens and profile data', () async {
    AppSession.updateCurrentUser({
      'id': '99',
      'name': 'Grace Hopper',
      'email': 'grace@example.com',
      'phone': '555',
      'avatar': 'https://cdn.example.com/grace.jpg',
      'role': 'landlord',
      'verified': true,
    });
    AppSession.apiToken = 'persisted-token';
    AppSession.refreshToken = 'persisted-refresh';

    await AppSession.persistSession();
    AppSession.currentRole = 'tenant';
    AppSession.currentUserId = null;
    AppSession.currentUserName = null;
    AppSession.currentUserEmail = null;
    AppSession.currentUserPhone = null;
    AppSession.currentUserAvatar = null;
    AppSession.currentUserVerified = false;
    AppSession.apiToken = null;
    AppSession.refreshToken = null;
    await AppSession.restoreSession();

    expect(AppSession.currentUserId, '99');
    expect(AppSession.currentUserName, 'Grace Hopper');
    expect(AppSession.currentUserEmail, 'grace@example.com');
    expect(AppSession.apiToken, 'persisted-token');
    expect(AppSession.refreshToken, 'persisted-refresh');
    expect(AppSession.isLandlord, isTrue);
  });
}
