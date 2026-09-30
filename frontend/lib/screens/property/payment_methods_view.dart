import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:property_app/utils/responsive_modal_sheet.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:property_app/session/app_session.dart';

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
      vsync: this, duration: const Duration(milliseconds: 500));
  late final Animation<double> _pageFade =
      CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic);
  late final Animation<Offset> _pageSlide =
      Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
          .animate(_pageFade);

  // Mutable list of payment methods
  final List<Map<String, dynamic>> _methods = [];

  @override
  void initState() {
    super.initState();
    _pageCtrl.forward();
    _initMethods();
  }

  void _initMethods() {
    final phone = AppSession.displayPhone;
    // Start with M-Pesa if phone is available
    if (phone.isNotEmpty) {
      _methods.add({'type': 'mpesa', 'number': phone, 'isDefault': true});
    } else {
      _methods.add(
          {'type': 'mpesa', 'number': '+254 7XX XXX XXX', 'isDefault': true});
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _setDefault(int index) {
    setState(() {
      for (int i = 0; i < _methods.length; i++) {
        _methods[i]['isDefault'] = (i == index);
      }
    });
  }

  void _removeMethod(int index) {
    if (_methods[index]['isDefault'] == true && _methods.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Cannot remove default payment method. Set another as default first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove payment method?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'This will remove the ${_methods[index]['type'] == 'mpesa' ? 'M-Pesa' : 'card'} ending in ...${_methods[index]['number'].toString().substring(_methods[index]['number'].toString().length - 4)}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _methods.removeAt(index));
            },
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  void _showAddSheet() {
    final phoneCtrl = TextEditingController();
    showResponsiveModalSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('Add M-Pesa Number',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827))),
            const SizedBox(height: 20),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))
              ],
              decoration: InputDecoration(
                labelText: 'Phone number (e.g. +254712345678)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.phone_android_rounded),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  final number = phoneCtrl.text.trim();
                  if (number.length < 9) return;
                  Navigator.pop(ctx);
                  setState(() => _methods.add(
                      {'type': 'mpesa', 'number': number, 'isDefault': false}));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('M-Pesa number added'),
                        behavior: SnackBarBehavior.floating),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3F3CD4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Add Number',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
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
                  child: _methods.isEmpty
                      ? const Center(
                          child: Text('No payment methods yet.',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 16)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          itemCount: _methods.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (_, i) {
                            final m = _methods[i];
                            return _PaymentCard(
                              type: m['type'] as String,
                              number: m['number'] as String,
                              isDefault: m['isDefault'] as bool,
                              onSetDefault: () => _setDefault(i),
                              onRemove: () => _removeMethod(i),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, 8, 20, MediaQuery.of(context).padding.bottom + 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: _showAddSheet,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Payment Method',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F3CD4),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
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
              child: Icon(Icons.arrow_back, size: 28, color: Color(0xFF111827)),
            ),
          ),
          const Expanded(
            child: Text('Payment Methods',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5)),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final String type;
  final String number;
  final bool isDefault;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;

  const _PaymentCard({
    required this.type,
    required this.number,
    required this.isDefault,
    required this.onSetDefault,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isMpesa = type == 'mpesa';
    final borderColor =
        isMpesa ? const Color(0xFF4CAF50) : const Color(0xFFA5B4FC);
    final logoColor =
        isMpesa ? const Color(0xFF4CAF50) : const Color(0xFF1A1F71);
    final defaultColor =
        isMpesa ? const Color(0xFF22C55E) : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              isMpesa
                  ? SvgPicture.asset('assets/images/MPESA.svg',
                      height: 28,
                      errorBuilder: (_, __, ___) => Text('M-PESA',
                          style: TextStyle(
                              color: logoColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)))
                  : Text('VISA',
                      style: TextStyle(
                          color: logoColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          fontStyle: FontStyle.italic)),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF9CA3AF)),
                onSelected: (v) {
                  if (v == 'default') onSetDefault();
                  if (v == 'remove') onRemove();
                },
                itemBuilder: (_) => [
                  if (!isDefault)
                    const PopupMenuItem(
                        value: 'default', child: Text('Set as Default')),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove',
                        style: TextStyle(color: Color(0xFFEF4444))),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(number,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280))),
              if (isDefault)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: defaultColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Default',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
