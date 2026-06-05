import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PaymentMethodsViewScreen extends StatefulWidget {
  final VoidCallback onBack;

  const PaymentMethodsViewScreen({super.key, required this.onBack});

  @override
  State<PaymentMethodsViewScreen> createState() =>
      _PaymentMethodsViewScreenState();
}

class _PaymentMethodsViewScreenState extends State<PaymentMethodsViewScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pageCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _pageFade = CurvedAnimation(
    parent: _pageCtrl,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _pageSlide = Tween<Offset>(
    begin: const Offset(0.05, 0),
    end: Offset.zero,
  ).animate(_pageFade);

  late List<AnimationController> _itemCtrls;
  late List<Animation<double>> _itemFades;
  late List<Animation<Offset>> _itemSlides;

  @override
  void initState() {
    super.initState();
    _pageCtrl.forward();
    _initAnimations();
  }

  void _initAnimations() {
    // 3 items: Mpesa, Visa, Button
    _itemCtrls = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _itemFades = _itemCtrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutCubic))
        .toList();

    _itemSlides = _itemCtrls
        .map((c) => Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();

    for (int i = 0; i < _itemCtrls.length; i++) {
      Future.delayed(Duration(milliseconds: 150 + i * 100), () {
        if (mounted) _itemCtrls[i].forward();
      });
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _itemCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pageFade,
      child: SlideTransition(
        position: _pageSlide,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(onBack: widget.onBack),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: const AppScrollBehavior(),
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        decelerationRate: ScrollDecelerationRate.fast,
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      children: [
                        FadeTransition(
                          opacity: _itemFades[0],
                          child: SlideTransition(
                            position: _itemSlides[0],
                            child: const _MpesaCard(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeTransition(
                          opacity: _itemFades[1],
                          child: SlideTransition(
                            position: _itemSlides[1],
                            child: const _VisaCard(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: _itemFades[2],
                  child: SlideTransition(
                    position: _itemSlides[2],
                    child: const _AddPaymentButton(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Smooth Scroll Behavior
class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.fast);
}

// Header Pixel-matched
class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.only(right: 16, top: 4, bottom: 4),
              child: Icon(
                Icons.arrow_back,
                size: 28,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Payment Methods',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// M-Pesa Card matching the PDF perfectly
class _MpesaCard extends StatelessWidget {
  const _MpesaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // M-Pesa Logo
          SvgPicture.asset(
            'assets/images/MPESA.svg',
            height: 32,
            alignment: Alignment.centerLeft,
            errorBuilder: (context, error, stackTrace) => const Text(
              'M-PESA',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '+254 712 345 678',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Default',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Visa Card matching the PDF perfectly
class _VisaCard extends StatelessWidget {
  const _VisaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFA5B4FC), width: 1.2), // Soft blue border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visa Logo
          SvgPicture.asset(
            'assets/images/Visa.svg',
            height: 24,
            alignment: Alignment.centerLeft,
            errorBuilder: (context, error, stackTrace) => const Text(
              'VISA',
              style: TextStyle(
                color: Color(0xFF1A1F71),
                fontWeight: FontWeight.w800,
                fontSize: 24,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Visa •••••••••0023',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Expires 17 June 2026',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Use',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Add Payment Method Button
class _AddPaymentButton extends StatelessWidget {
  const _AddPaymentButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor:
                const Color(0xFF3F3CD4), // Deep indigo/blue matching PDF
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Add Payment Method',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
