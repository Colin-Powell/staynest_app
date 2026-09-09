import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/landlord_payment_methods_service.dart';

// ─── Design System Constants ─────────────────────────────────────────
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981);

class PaymentMethodSelector extends StatefulWidget {
  final String propertyId;
  final String packageType;
  final int amount;
  final String description;

  const PaymentMethodSelector({
    super.key,
    required this.propertyId,
    required this.packageType,
    required this.amount,
    required this.description,
  });

  static Future<LandlordPaymentMethod?> show(
    BuildContext context, {
    required String propertyId,
    required String packageType,
    required int amount,
    required String description,
  }) {
    return showModalBottomSheet<LandlordPaymentMethod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentMethodSelector(
        propertyId: propertyId,
        packageType: packageType,
        amount: amount,
        description: description,
      ),
    );
  }

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  List<LandlordPaymentMethod> _methods = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final methods = await LandlordPaymentMethodsService.getPaymentMethods();
      if (mounted) {
        setState(() {
          _methods = methods.where((method) => method.type == 'mpesa').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load payment methods';
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildMethodCard(LandlordPaymentMethod method) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, method),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _grey.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Method icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  method.type == 'mpesa'
                      ? Icons.phone_android_rounded
                      : method.type == 'bank_transfer'
                          ? Icons.account_balance_rounded
                          : Icons.credit_card_rounded,
                  color: _green,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Method details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        method.typeLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _dark,
                        ),
                      ),
                      if (method.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Default',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _green,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    method.type == 'mpesa'
                        ? method.maskedAccount
                        : '${method.bankName} - ${method.maskedAccount}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: _grey.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return GestureDetector(
      onTap: () {}, // Prevent dismissal
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 20,
                  bottom: mediaQuery.viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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

                    // Header
                    Text(
                      'Choose Payment Method',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ksh ${widget.amount} for ${widget.description}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Methods or loading/error
                    if (_isLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(_green),
                          ),
                        ),
                      )
                    else if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIcons.warningCircle(),
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_methods.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                PhosphorIcons.warning(),
                                color: _grey,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No payment methods found',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: _grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add a payment method to proceed',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: _grey.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _methods.map(_buildMethodCard).toList(),
                      ),

                    const SizedBox(height: 12),

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _grey.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                    ),
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
