import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/services/landlord_payment_methods_service.dart';
import 'dart:async';

// ─── Design System Constants ─────────────────────────────────────────
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord
const Color _orange = Color(0xFFF97316); // Orange for M-Pesa

class MpesaPaymentModal extends StatefulWidget {
  final String propertyId;
  final String packageType;
  final int amount;
  final String description;
  final LandlordPaymentMethod? paymentMethod;
  final Function(bool success)? onComplete;

  const MpesaPaymentModal({
    super.key,
    required this.propertyId,
    required this.packageType,
    required this.amount,
    required this.description,
    this.paymentMethod,
    this.onComplete,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String propertyId,
    required String packageType,
    required int amount,
    required String description,
    LandlordPaymentMethod? paymentMethod,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: MpesaPaymentModal(
          propertyId: propertyId,
          packageType: packageType,
          amount: amount,
          description: description,
          paymentMethod: paymentMethod,
        ),
      ),
    );
  }

  @override
  State<MpesaPaymentModal> createState() => _MpesaPaymentModalState();
}

class _MpesaPaymentModalState extends State<MpesaPaymentModal> {
  String _step = 'phone'; // phone | confirming | pending | success | error
  String _phone = '';
  bool _useAnotherPhone = false;
  String? _errorMessage;
  String? _successMessage;
  String? _checkoutRequestId;
  Timer? _statusCheckTimer;
  bool _isProcessing = false;

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    final phone = (!_useAnotherPhone && widget.paymentMethod != null)
        ? widget.paymentMethod!.accountNumber
        : _phone;

    if (!LandlordPaymentMethodsService.isValidMpesaPhone(phone)) {
      setState(() => _errorMessage = 'Please enter a valid phone number');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _step = 'confirming';
    });

    try {
      // Format phone number
      String formattedPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '254' + formattedPhone.substring(1);
      } else if (!formattedPhone.startsWith('254')) {
        formattedPhone = '254' + formattedPhone;
      }

      // Call backend to initiate STKPush
      final response = await PropertiesApi.initiatePayment(
        propertyId: widget.propertyId,
        packageType: widget.packageType,
        phone: formattedPhone,
      );

      if (!mounted) return;

      setState(() {
        _checkoutRequestId = response['checkoutRequestId'];
        _step = 'pending';
        _isProcessing = false;
      });

      // Start polling for payment status
      _startStatusCheck();

      // Show M-Pesa prompt info
      _showMpesaPrompt();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = 'error';
        _errorMessage = 'Failed to initiate payment. Please try again.';
        _isProcessing = false;
      });
      debugPrint('Payment error: $e');
    }
  }

  void _startStatusCheck() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _checkoutRequestId == null) {
        timer.cancel();
        return;
      }

      try {
        // Check payment status (this endpoint needs to be added to the backend)
        // For now, we'll rely on the callback mechanism
      } catch (e) {
        debugPrint('Status check error: $e');
      }
    });

    // Auto-cancel after 2 minutes
    Timer(const Duration(minutes: 2), () {
      _statusCheckTimer?.cancel();
      if (mounted && _step == 'pending') {
        setState(() {
          _step = 'error';
          _errorMessage = 'Payment request expired. Please try again.';
        });
      }
    });
  }

  void _showMpesaPrompt() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('M-Pesa Prompt Sent'),
        content: const Text(
          'A payment prompt has been sent to your phone. '
          'Enter your M-Pesa PIN on your phone to complete the payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleSuccess() {
    _statusCheckTimer?.cancel();
    setState(() {
      _step = 'success';
      _successMessage = 'Payment successful! Your boost is now active.';
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onComplete?.call(true);
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return GestureDetector(
      onTap: () {}, // Prevent dismissal on outside tap
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: Colors.black.withOpacity(_step == 'pending' ? 0.5 : 0.3),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: _step == 'pending' ? 0.35 : 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 20,
                  bottom: mediaQuery.viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_step == 'phone') ...[
                      Text(
                        'Pay with M-Pesa',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${widget.description}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Amount display
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Amount to pay',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: _grey,
                              ),
                            ),
                            Text(
                              'Ksh ${widget.amount}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (widget.paymentMethod == null || _useAnotherPhone)
                        TextFormField(
                          onChanged: (val) => setState(() => _phone = val),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+ ]')),
                          ],
                          decoration: InputDecoration(
                            hintText: '0701 234 567 (or 254701234567)',
                            hintStyle: GoogleFonts.poppins(
                              color: _grey.withOpacity(0.6),
                            ),
                            prefixIcon: Icon(
                              PhosphorIcons.phone(),
                              color: _grey.withOpacity(0.6),
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _grey.withOpacity(0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _grey.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _green,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _dark,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _grey.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_android_rounded,
                                  color: _green),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'M-Pesa ${widget.paymentMethod!.maskedAccount}',
                                  style: GoogleFonts.poppins(
                                      color: _dark,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (widget.paymentMethod != null && !_useAnotherPhone)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(() {
                              _useAnotherPhone = true;
                              _phone = '';
                              _errorMessage = null;
                            }),
                            child: const Text('Use another phone number'),
                          ),
                        ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.warningCircle(),
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Pay button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              _isProcessing ? null : () => _initiatePayment(),
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            disabledBackgroundColor: _grey.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isProcessing
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                )
                              : Text(
                                  'Pay Ksh ${widget.amount}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Text(
                        'Powered by M-Pesa',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _grey,
                        ),
                      ),
                    ] else if (_step == 'pending') ...[
                      // Loading state
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation(_orange),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Processing Payment',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _dark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Enter your M-Pesa PIN on your phone\nto complete this payment',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: _grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: _grey),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _dark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_step == 'success') ...[
                      // Success state
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: _green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                PhosphorIcons.checkCircle(
                                    PhosphorIconsStyle.fill),
                                color: _green,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Payment Successful!',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _dark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your listing boost is now active',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: _grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_step == 'error') ...[
                      // Error state
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Payment Failed',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _dark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage ?? 'An error occurred',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: _grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _green,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Try Again',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
