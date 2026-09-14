import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:property_app/app_theme.dart';
import 'package:property_app/screens/super_admin/super_admin_shell.dart';
import 'package:property_app/screens/super_admin/super_admin_login.dart';
import 'package:property_app/session/app_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // GoogleFonts.config.allowRuntimeFetching = false;

  try {
    await dotenv.load(fileName: 'config.env');
  } on FileNotFoundError {
    debugPrint('No config.env found; using default API configuration.');
  } catch (err) {
    debugPrint('dotenv load failed: $err');
  }

  await AppSession.restoreSession();
  await AppSession.initializeAppInfo();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  runApp(const SuperAdminApp());
}

class SuperAdminApp extends StatelessWidget {
  const SuperAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = AppSession.isAdmin;

    return MaterialApp(
      title: 'StayNest Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeForRole('admin'),
      initialRoute: isAdmin ? '/super_admin' : '/super_admin/login',
      routes: {
        '/super_admin/login': (context) => const SuperAdminLoginView(),
        '/super_admin': (context) => const SuperAdminShell(),
      },
    );
  }
}
