import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Future<LandlordPaymentMethod?> _enterPhoneNumber() async {
    final phone = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _MpesaPhoneEntrySheet(),
    );
    if (phone == null) return null;

    return LandlordPaymentMethod(
      id: '',
      type: 'mpesa',
      displayName: 'M-Pesa - ${phone.substring(phone.length - 4)}',
      accountNumber: phone,
      isDefault: false,
      lastUsed: '',
      createdAt: '',
    );
  }

  Widget _buildUseAnotherPhoneButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () async {
          final method = await _enterPhoneNumber();
          if (method != null && mounted) Navigator.pop(context, method);
        },
        icon: const Icon(Icons.phone_android_rounded),
        label: const Text('Use another phone number'),
        style: FilledButton.styleFrom(
          backgroundColor: _green,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
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
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Saved payment methods are unavailable. You can still pay with an M-Pesa number.',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildUseAnotherPhoneButton(),
                        ],
                      )
                    else if (_methods.isEmpty)
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No saved M-Pesa number found.',
                              style: GoogleFonts.poppins(color: _grey),
                            ),
                          ),
                          _buildUseAnotherPhoneButton(),
                        ],
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

class _MpesaPhoneEntrySheet extends StatefulWidget {
  const _MpesaPhoneEntrySheet();

  @override
  State<_MpesaPhoneEntrySheet> createState() => _MpesaPhoneEntrySheetState();
}

class _MpesaPhoneEntrySheetState extends State<_MpesaPhoneEntrySheet> {
  late final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Use another M-Pesa number',
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your M-Pesa phone number';
                  }
                  if (!LandlordPaymentMethodsService.isValidMpesaPhone(value)) {
                    return 'Use 07..., 01..., or +254... format';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+254712345678',
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    Navigator.pop(
                      context,
                      LandlordPaymentMethodsService.normalizeMpesaPhone(
                          _controller.text.trim()),
                    );
                  },
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  child: const Text('Continue with this number'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
