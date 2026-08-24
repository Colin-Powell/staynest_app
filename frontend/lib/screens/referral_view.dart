import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Make sure flutter_svg is added to pubspec.yaml
import 'package:property_app/session/app_session.dart';

class ReferralView extends StatelessWidget {
  const ReferralView({super.key});

  // Original Logic: Preserved exactly as requested
  String get _referralCode {
    final userId = AppSession.currentUserId ?? '';
    if (userId.length >= 6) {
      return userId.replaceAll('-', '').substring(0, 6).toUpperCase();
    }
    final name = (AppSession.currentUserName ?? 'GUEST')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    return name.length >= 4
        ? '${name.substring(0, 4)}${DateTime.now().year % 100}'
        : 'SN${DateTime.now().millisecondsSinceEpoch % 9999}';
  }

  @override
  Widget build(BuildContext context) {
    final code = _referralCode;
    
    // Theme colors extracted from your design
    const backgroundColor = Color(0xFF162137); 
    const accentBlue = Color(0xFF4B7FFF); 

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // Title
              const Text(
                'Invite & Earn',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              
              // Subtitle (Using RichText to highlight 'Ksh 500' in blue)
              // Note: Corrected the typo in the design from "op to" to "up to"
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(text: 'Invite your friends and\nearn up to '),
                    TextSpan(
                      text: 'Ksh 500',
                      style: TextStyle(color: accentBlue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              // SVG Illustration
              Expanded(
                child: SvgPicture.asset(
                  'assets/images/referal.svg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 40),
              
              // White Referral Code Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Your Referral code  ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: accentBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        // Original Logic: Copy to clipboard
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Referral code copied')),
                        );
                      },
                      child: const Icon(
                        Icons.copy_outlined,
                        size: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Blue Invite Now Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Share.share(
                      'Join StayNest with my referral code $code.'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Invite Now',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Bottom Action Text
              GestureDetector(
                onTap: () {
                  // TODO: Add logic for "How it works?"
                },
                child: const Text(
                  'How it works?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}