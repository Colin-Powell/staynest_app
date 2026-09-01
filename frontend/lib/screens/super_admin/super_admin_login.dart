import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/utils/responsive_layout.dart';

class SuperAdminLoginView extends StatefulWidget {
  const SuperAdminLoginView({super.key});

  @override
  State<SuperAdminLoginView> createState() => _SuperAdminLoginViewState();
}

class _SuperAdminLoginViewState extends State<SuperAdminLoginView> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = RemoteDatabaseRepository();
      final user = await repo.authenticate(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (user == null) {
        throw Exception('Invalid credentials');
      }

      AppSession.updateCurrentUser(user);
      AppSession.apiToken = user['token']?.toString() ?? user['accessToken']?.toString() ?? AppSession.apiToken;
      AppSession.refreshToken = user['refreshToken']?.toString() ?? AppSession.refreshToken;
      await AppSession.persistSession();

      if (AppSession.currentRole.toLowerCase() != 'admin') {
        // Kick them out if they aren't actually an admin
        await AppSession.reset();
        setState(() {
          _errorMessage = 'Unauthorized. This portal is strictly for administrators.';
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/super_admin');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: ResponsiveLayout.isDesktopOrLarger(context)
                ? BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: StayNestColors.outlineLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                    size: 64, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Admin Portal',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Sign in to manage the StayNest platform',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: StayNestColors.textSecondaryLight,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: StayNestColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                        color: StayNestColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Admin Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Sign In',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                
              ],
            ),
          ),
        ),
      ),
    );
  }
}
