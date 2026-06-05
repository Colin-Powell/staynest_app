// lib/screens/referral_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ReferralView extends StatefulWidget {
  const ReferralView({super.key});

  @override
  State<ReferralView> createState() => _ReferralViewState();
}

class _ReferralViewState extends State<ReferralView>
    with TickerProviderStateMixin {
  late final AnimationController _pageCtrl;
  late final AnimationController _staggerCtrl;
  late final Animation<double> _pageFade;

  @override
  void initState() {
    super.initState();
    // Base entrance animation
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);

    // Staggered cascade animation for the elements
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pageCtrl.forward().then((_) => _staggerCtrl.forward());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  /// Staggered sliding fade animation helper
  Widget _buildStaggered({required int index, required Widget child}) {
    final double start = (index * 0.1).clamp(0.0, 1.0);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  void _copyReferralCode() {
    Clipboard.setData(const ClipboardData(text: 'ESQ234'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Referral code copied to clipboard!',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Exact colors picked from the design
    const Color bgColor = Color(0xFF161C2D);
    const Color primaryBlue = Color(0xFF4378FF);
    const Color codeBlue = Color(0xFF3F3CD4);

    return FadeTransition(
      opacity: _pageFade,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        // Extend body behind AppBar so the content perfectly centers
        extendBodyBehindAppBar: true,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // 1. Title
                _buildStaggered(
                  index: 0,
                  child: const Text(
                    'Invite & Earn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Subtitle
                _buildStaggered(
                  index: 1,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(text: 'Invite your friends and\n'),
                        TextSpan(text: 'earn up to '),
                        TextSpan(
                          text: 'Ksh 500',
                          style: TextStyle(color: primaryBlue),
                        ),
                      ],
                    ),
                  ),
                ),

                // Flexible space pushes illustration to middle
                const Spacer(flex: 2),

                // 3. Image Illustration
                _buildStaggered(
                  index: 2,
                  child: SvgPicture.asset(
                    'assets/images/referal.svg',
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                ),

                const Spacer(flex: 3),

                // 4. Referral Code Box
                _buildStaggered(
                  index: 3,
                  child: GestureDetector(
                    onTap: _copyReferralCode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Your Referral code ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'ESQ234',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: codeBlue,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.content_copy_rounded,
                            color: Color(0xFF111827),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Invite Now Button
                _buildStaggered(
                  index: 4,
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        // Open native share functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Opening Share Options...')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
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
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 6. How it works Text Button
                _buildStaggered(
                  index: 5,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        // Navigate to How it works modal/screen
                      },
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'How it works?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom spacing for screens without physical home button
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
