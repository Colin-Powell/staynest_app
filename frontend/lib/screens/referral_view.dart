import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Make sure flutter_svg is added to pubspec.yaml
import 'package:property_app/session/app_session.dart';

class ReferralView extends StatelessWidget {
  final VoidCallback? onBack;

  const ReferralView({super.key, this.onBack});

  String get _referralCode =>
      AppSession.referralCode?.trim().toUpperCase() ?? '';

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
              if (onBack != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back to profile',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                ),
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
                      code.isEmpty ? 'Unavailable' : code,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: code.isEmpty ? Colors.black54 : accentBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: code.isEmpty
                          ? null
                          : () {
                              // Original Logic: Copy to clipboard
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Referral code copied')),
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
                  onPressed: code.isEmpty
                      ? null
                      : () => Share.share(
                          'Join StayNest with my referral code $code. https://staynest.top/register?ref=$code'),
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
