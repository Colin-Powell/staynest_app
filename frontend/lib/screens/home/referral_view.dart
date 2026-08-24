// lib/screens/referral_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:property_app/session/app_session.dart';

class ReferralView extends StatefulWidget {
  const ReferralView({super.key});

  @override
  State<ReferralView> createState() => _ReferralViewState();
}

class _ReferralViewState extends State<ReferralView> with TickerProviderStateMixin {
  late final AnimationController _pageCtrl;
  late final AnimationController _staggerCtrl;
  late final Animation<double> _pageFade;
  bool _howItWorksOpen = false;

  // Generate a deterministic referral code from the user's ID
  String get _referralCode {
    final userId = AppSession.currentUserId ?? '';
    if (userId.length >= 6) {
      return userId.replaceAll('-', '').substring(0, 6).toUpperCase();
    }
    // Fallback to name-based code
    final name = AppSession.currentUserName ?? 'GUEST';
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    return cleaned.length >= 4
        ? '${cleaned.substring(0, 4)}${DateTime.now().year % 100}'
        : 'SN${DateTime.now().millisecondsSinceEpoch % 9999}';
  }

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pageCtrl.forward().then((_) => _staggerCtrl.forward());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

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
        position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }

  void _copyReferralCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Referral code copied to clipboard!', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _shareInvite() async {
    final code = _referralCode;
    final name = AppSession.displayName;
    await Share.share(
      '$name is inviting you to StayNest!\n\n'
      'Use my referral code $code when you sign up and we both earn Ksh 500 once you complete your first booking.\n\n'
      'Download StayNest and find your perfect home today! ??',
      subject: 'Join StayNest with my referral code',
    );
  }

  @override
  Widget build(BuildContext context) {
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
        extendBodyBehindAppBar: true,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                _buildStaggered(
                  index: 0,
                  child: const Text('Invite & Earn',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                ),
                const SizedBox(height: 16),

                _buildStaggered(
                  index: 1,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, height: 1.5),
                      children: [
                        TextSpan(text: 'Invite friends & earn up to '),
                        TextSpan(text: 'Ksh 500', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w800)),
                        TextSpan(text: ' per successful referral.'),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Steps illustration — inline since we might not have SVG
                _buildStaggered(
                  index: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      _StepBubble(icon: Icons.share, label: 'Share\nCode'),
                      _StepArrow(),
                      _StepBubble(icon: Icons.person_add, label: 'Friend\nSigns Up'),
                      _StepArrow(),
                      _StepBubble(icon: Icons.wallet, label: 'Earn\nKsh 500'),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Referral Code Box
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Your Referral Code  ',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                          Text(_referralCode,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: codeBlue, letterSpacing: 1)),
                          const SizedBox(width: 10),
                          const Icon(Icons.content_copy_rounded, color: Color(0xFF9CA3AF), size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Invite Now Button
                _buildStaggered(
                  index: 4,
                  child: SizedBox(
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: _shareInvite,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Invite Now', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // How it works
                _buildStaggered(
                  index: 5,
                  child: GestureDetector(
                    onTap: () => setState(() => _howItWorksOpen = !_howItWorksOpen),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('How it works?',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                            AnimatedRotation(
                              turns: _howItWorksOpen ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                            ),
                          ],
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '1. Share your unique code with a friend.\n'
                              '2. They sign up using your referral code.\n'
                              '3. When they complete their first booking, you both receive Ksh 500 credit automatically added to your wallets.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.7),
                            ),
                          ),
                          crossFadeState: _howItWorksOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 250),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBubble extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StepBubble({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF4378FF).withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xFF4378FF), size: 26),
        ),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF4378FF), size: 20),
    );
  }
}
