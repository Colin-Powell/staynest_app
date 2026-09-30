import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/services/wallet_api.dart';
import 'package:property_app/theme.dart';

const Color _textDark = StayNestColors.textPrimaryLight;
const Color _textLight = StayNestColors.textSecondaryLight;
const Color _dividerColor = StayNestColors.divider;
const Color _primary = StayNestColors.primary;
const Color _pageBackground = StayNestColors.surfaceVariantLight;
const double _maxWebWidth = 1120.0;

class PropertyPaymentPage extends StatefulWidget {
  final Property property;
  final DateTime checkIn;
  final DateTime checkOut;
  final String selectedTime;
  final String? notes;
  final String idempotencyKey;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onComplete;

  const PropertyPaymentPage({
    super.key,
    required this.property,
    required this.checkIn,
    required this.checkOut,
    required this.selectedTime,
    this.notes,
    required this.idempotencyKey,
    this.embedded = false,
    this.onBack,
    this.onComplete,
  });

  @override
  State<PropertyPaymentPage> createState() => _PropertyPaymentPageState();
}

class _PropertyPaymentPageState extends State<PropertyPaymentPage> {
  static const int _viewingFee = 500;
  bool _processing = false;
  bool _loadingWallet = true;
  String? _walletError;
  double _walletBalance = 0;

  int get _total => _viewingFee;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await WalletApi.getWallet();
      if (!mounted) return;
      final balance = wallet['wallet_balance'];
      setState(() {
        _walletBalance = balance is num
            ? balance.toDouble()
            : double.tryParse(balance?.toString() ?? '') ?? 0;
        _loadingWallet = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingWallet = false;
          _walletError = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _confirmPayment() async {
    if (_processing || _loadingWallet || _walletBalance < _total) return;
    setState(() => _processing = true);
    try {
      await BookingService.createAndPayFromWallet(
        propertyId: widget.property.id,
        checkIn: widget.checkIn,
        checkOut: widget.checkOut,
        notes: widget.notes,
        idempotencyKey: widget.idempotencyKey,
      );
      if (mounted) {
        if (widget.onComplete != null) {
          widget.onComplete!();
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: StayNestColors.error,
        ),
      );
    }
  }

  Future<void> _openWallet() async {
    await Navigator.pushNamed(context, '/wallet');
    if (mounted) await _loadWallet();
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          if (isDesktop) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWebWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPageHeading(),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 55, child: _buildWalletSection()),
                          const SizedBox(width: 32),
                          Expanded(flex: 45, child: _buildSummaryCard()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPageHeading(),
                      const SizedBox(height: 24),
                      _buildSummaryCard(),
                      const SizedBox(height: 24),
                      _buildWalletSection(),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  14 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(top: BorderSide(color: _dividerColor)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: _buildConfirmButton(),
              ),
            ],
          );
        },
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: _pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded,
                color: _textDark, size: 22),
          ),
        ),
        title: Text(
          'Payment',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
      ),
      body: content,
    );
  }

  Widget _buildPageHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.embedded && widget.onBack != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to booking'),
            ),
          ),
        Text(
          'Complete your booking',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your payment is held securely in escrow while the host reviews your request.',
          style:
              GoogleFonts.poppins(fontSize: 14, color: _textLight, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildWalletSection() {
    final hasEnoughFunds = _walletBalance >= _total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: StayNestColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  PhosphorIconsRegular.wallet,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'StayNest wallet',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                    Text(
                      'Payment held in booking escrow',
                      style:
                          GoogleFonts.poppins(fontSize: 12, color: _textLight),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle,
                  color: StayNestColors.success, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: _dividerColor),
          const SizedBox(height: 16),
          if (_walletError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFC2410C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'We could not initialise your wallet session.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: const Color(0xFF9A3412)),
                    ),
                  ),
                  TextButton(
                      onPressed: _loadWallet, child: const Text('Retry')),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Wallet balance',
                  style: GoogleFonts.poppins(fontSize: 14, color: _textLight)),
              if (_loadingWallet)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  'Ksh ${_walletBalance.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
            ],
          ),
          if (!_loadingWallet && !hasEnoughFunds) ...[
            const SizedBox(height: 14),
            Text(
              'Add Ksh ${(_total - _walletBalance).toStringAsFixed(2)} to continue.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: StayNestColors.error),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openWallet,
              icon: const Icon(PhosphorIconsRegular.deviceMobile, size: 18),
              label: const Text('Add funds with M-Pesa'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StayNestColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: _primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your payment stays in escrow until the booking is completed. If the host declines or the booking is cancelled, the wallet payment is refunded.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _textDark,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _processing || _loadingWallet || _walletBalance < _total
              ? null
              : _confirmPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: _processing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  _loadingWallet
                      ? 'Checking wallet...'
                      : 'Pay Ksh ${_total.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  // ─── RIGHT COLUMN: SUMMARY CARD ────────────────────────────────────────────

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tiny Image + Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.property.image.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.property.image,
                        width: 104,
                        height: 104,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: _pageBackground),
                        errorWidget: (_, __, ___) => Container(
                          color: _pageBackground,
                          child: const Icon(PhosphorIconsRegular.house,
                              color: _textLight),
                        ),
                      )
                    : Container(width: 104, height: 104, color: _dividerColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.property.category.isNotEmpty
                          ? widget.property.category
                          : 'Entire home',
                      style:
                          GoogleFonts.poppins(fontSize: 12, color: _textLight),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.property.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _textDark,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(PhosphorIconsFill.star,
                            size: 12, color: _textDark),
                        const SizedBox(width: 4),
                        Text(
                          widget.property.rating > 0
                              ? widget.property.rating.toStringAsFixed(2)
                              : 'New',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _textDark),
                        ),
                        if (widget.property.reviews > 0) ...[
                          Text(' (${widget.property.reviews})',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: _textLight)),
                        ]
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildPriceRow(
            'Viewing date',
            '${DateFormat('MMM d').format(widget.checkIn)} - ${DateFormat('MMM d, yyyy').format(widget.checkOut)}',
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: _dividerColor),
          const SizedBox(height: 24),

          // Price Details Section
          Text(
            'Price details',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 16),
          _buildPriceRow(
            'Viewing booking fee',
            'Ksh ${_viewingFee.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 10),
          Text(
            'Monthly rent is arranged separately with the landlord.',
            style: GoogleFonts.poppins(fontSize: 12, color: _textLight),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: _dividerColor),
          const SizedBox(height: 18),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total due now',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
              Text(
                'Ksh ${_total.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: _textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
