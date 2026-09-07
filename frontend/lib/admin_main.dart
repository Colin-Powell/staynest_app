import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:property_app/app_theme.dart';
import 'package:property_app/screens/super_admin/super_admin_login.dart';
import 'package:property_app/screens/super_admin/super_admin_shell.dart';
import 'package:property_app/session/app_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: 'config.env');
  } on FileNotFoundError {
    debugPrint('No config.env found; using default API configuration.');
  } catch (error) {
    debugPrint('Unable to load config.env: $error');
  }

  await AppSession.restoreSession();
  await AppSession.initializeAppInfo();
  runApp(const StayNestAdminApp());
}

class StayNestAdminApp extends StatelessWidget {
  const StayNestAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = AppSession.currentRole.toLowerCase() == 'admin';

    return MaterialApp(
      title: 'StayNest Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeForRole('admin'),
      initialRoute: isAdmin ? '/super_admin' : '/',
      routes: {
        '/': (_) => const SuperAdminLoginView(),
        '/super_admin': (_) => const SuperAdminShell(),
      },
    );
  }
}
