import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyView extends StatelessWidget {
  final VoidCallback? onBack;

  const PrivacyPolicyView({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    const policy = '''Privacy & Data Retention Policy

We collect minimal profile information (budget, status, household size, pets, preferred categories and cities) to personalize property recommendations when you opt-in. Your consent is required to enable personalized recommendations.

Data retention: By default, we retain profile data for 365 days. You can request deletion of your profile data at any time via the app settings or by contacting support.

Purpose: We use this data solely to improve property discovery and recommendation quality and do not share personally-identifying information with third parties except as required by law.

Rights: You may view, update, or delete your profile and revoke consent at any time.

Contact: privacy@staynest.example (replace with actual contact)
''';

    return Scaffold(
      appBar: AppBar(
        leading: onBack == null
            ? null
            : IconButton(
                tooltip: 'Back to profile',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: const Text('Privacy & Data Policy'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(policy,
              style: GoogleFonts.poppins(fontSize: 14, height: 1.5)),
        ),
      ),
    );
  }
}
