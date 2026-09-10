import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/services/wallet_api.dart';
import 'package:property_app/services/landlord_payment_methods_service.dart';
import 'package:property_app/utils/api_result.dart';

// ─── Design System Constants ──────────────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981);
const Color _primary = Color(0xFF3F37C9); // App Accent

class WalletView extends StatefulWidget {
  const WalletView({super.key});

  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  Map<String, dynamic> _walletData = {};
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        WalletApi.getWallet(),
        WalletApi.getTransactions(),
      ]);

      if (mounted) {
        setState(() {
          _walletData = results[0] as Map<String, dynamic>;
          _transactions = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Unable to load wallet data. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(dynamic amount) {
    final val = double.tryParse(amount.toString()) ?? 0.0;
    final format = NumberFormat.currency(
        locale: 'en_KE', symbol: 'KSh ', decimalDigits: 2);
    return format.format(val);
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0 && now.day == date.day) {
        return 'Today, ${DateFormat.jm().format(date)}';
      } else if (diff.inDays == 1 && now.day - 1 == date.day) {
        return 'Yesterday, ${DateFormat.jm().format(date)}';
      }
      return DateFormat('MMM d, yyyy • h:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  // ─── FINTECH ACTIONS & MODALS ───────────────────────────────────────────────

  void _showSuccessModal(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: _green.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(PhosphorIconsFill.checkCircle,
                  color: _green, size: 64),
            ),
            const SizedBox(height: 24),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                    letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: _grey, height: 1.5, fontSize: 14)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    elevation: 0),
                onPressed: () => Navigator.pop(ctx),
                child: Text('Done',
                    style: GoogleFonts.poppins(
                        color: _surface,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showErrorModal(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(PhosphorIconsFill.warningCircle,
                  color: Color(0xFFEF4444), size: 64),
            ),
            const SizedBox(height: 24),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                    letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: _grey, height: 1.5, fontSize: 14)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _dark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    elevation: 0),
                onPressed: () => Navigator.pop(ctx),
                child: Text('Got it',
                    style: GoogleFonts.poppins(
                        color: _surface,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<LandlordPaymentMethod?> _selectMethod(
      {required Set<String> allowedTypes}) async {
    final methods = (await LandlordPaymentMethodsService.getPaymentMethods())
        .where((method) => allowedTypes.contains(method.type))
        .toList();
    if (!mounted) return null;

    if (methods.isEmpty) {
      final result = await showDialog<LandlordPaymentMethod?>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _AddMpesaMethodDialog(
          onSave: (phone) => LandlordPaymentMethodsService.addMpesaMethod(
              phone: phone, isDefault: true),
        ),
      );
      return result;
    }

    return showModalBottomSheet<LandlordPaymentMethod>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Select Payment Method',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
              ),
              ListView.separated(
                shrinkWrap: true,
                itemCount: methods.length,
                separatorBuilder: (_, __) =>
                    Divider(color: _grey.withOpacity(0.1), height: 1),
                itemBuilder: (context, index) {
                  final method = methods[index];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsRegular.wallet,
                          color: _primary, size: 24),
                    ),
                    title: Text(method.displayName,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: _dark,
                            fontSize: 15)),
                    subtitle: Text(method.maskedAccount,
                        style: GoogleFonts.poppins(color: _grey, fontSize: 13)),
                    onTap: () => Navigator.pop(context, method),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<double?> _showAmountSheet(String title,
      {required double minimum}) async {
    String amountText = '';
    var isProcessing = false;

    final amount = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: _grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                        letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('Minimum amount: KSh ${minimum.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
                const SizedBox(height: 32),
                TextField(
                  onChanged: (value) => amountText = value,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(
                      fontSize: 24, fontWeight: FontWeight.w700, color: _dark),
                  decoration: InputDecoration(
                    prefixText: 'KSh ',
                    prefixStyle: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _grey),
                    border: UnderlineInputBorder(
                        borderSide: BorderSide(color: _grey.withOpacity(0.3))),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: _primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            final amount = double.tryParse(amountText.trim());
                            if (amount == null || amount < minimum) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      'Please enter a valid amount (Min: KSh $minimum)')));
                              return;
                            }
                            setSheetState(() => isProcessing = true);
                            FocusScope.of(context).unfocus();
                            if (context.mounted)
                              Navigator.pop(sheetContext, amount);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32)),
                      elevation: 0,
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text('Continue',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
    return amount;
  }

  Future<void> _showTopUpSheet() async {
    final amount = await _showAmountSheet('Top up wallet', minimum: 10);
    if (amount == null || !mounted) return;
    final method = await _selectMethod(allowedTypes: {'mpesa'});
    if (method == null || !mounted) return;
    try {
      await WalletApi.topUp(amount: amount, paymentMethod: method);
      await _loadData();
      if (mounted)
        _showSuccessModal('Top Up Initiated',
            'An M-Pesa prompt has been sent to your phone. Enter your PIN to complete the transaction.');
    } catch (error) {
      if (mounted) _showErrorModal('Top Up Failed', ApiResult.mapError(error));
    }
  }

  Future<void> _showWithdrawSheet() async {
    final amount = await _showAmountSheet('Withdraw funds', minimum: 50);
    if (amount == null || !mounted) return;
    final balance =
        double.tryParse(_walletData['wallet_balance'].toString()) ?? 0;
    if (amount > balance) {
      if (mounted)
        _showErrorModal('Insufficient Funds',
            'You cannot withdraw more than your available balance.');
      return;
    }

    final method =
        await _selectMethod(allowedTypes: {'mpesa', 'bank_transfer'});
    if (method == null) return;
    try {
      await WalletApi.withdraw(amount: amount, paymentMethod: method);
      await _loadData();
      if (mounted)
        _showSuccessModal('Withdrawal Processing',
            'Your withdrawal request has been submitted and is currently being processed.');
    } catch (error) {
      if (mounted)
        _showErrorModal('Withdrawal Failed', ApiResult.mapError(error));
    }
  }

  // ─── UI BUILDERS ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: const Icon(PhosphorIconsRegular.caretLeft,
                color: _dark, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'My Wallet',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _dark,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade100,
            child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24))),
          ),
          const SizedBox(height: 32),
          Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade100,
            child: Container(height: 24, width: 150, color: Colors.white),
          ),
          const SizedBox(height: 24),
          ...List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.grey.shade200,
                    highlightColor: Colors.grey.shade100,
                    child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(
                            baseColor: Colors.grey.shade200,
                            highlightColor: Colors.grey.shade100,
                            child: Container(
                                width: double.infinity,
                                height: 16,
                                color: Colors.white)),
                        const SizedBox(height: 8),
                        Shimmer.fromColors(
                            baseColor: Colors.grey.shade200,
                            highlightColor: Colors.grey.shade100,
                            child: Container(
                                width: 120, height: 12, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2), shape: BoxShape.circle),
              child: const Icon(PhosphorIconsRegular.warningCircle,
                  size: 48, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 24),
            Text('Oops! Something went wrong',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'We couldn\'t load your wallet data.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _dark,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
              ),
              child: Text('Try Again',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    final balanceRaw = _walletData['wallet_balance'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Available Balance',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.7))),
              Icon(PhosphorIconsRegular.wallet,
                  color: Colors.white.withOpacity(0.7), size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(_formatCurrency(balanceRaw),
              style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -1.0)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showWithdrawSheet,
                  icon: const Icon(PhosphorIconsRegular.arrowUpRight,
                      size: 18, color: _dark),
                  label: Text('Withdraw',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: _dark)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _dark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showTopUpSheet,
                  icon: const Icon(PhosphorIconsRegular.plus,
                      size: 18, color: Colors.white),
                  label: Text('Top up',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.45)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> transaction) {
    final type = transaction['type']?.toString() ?? 'unknown';
    final amount =
        double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
    final isPositive = amount >= 0;

    IconData iconData = PhosphorIconsRegular.arrowsLeftRight;
    if (type.toLowerCase().contains('booking') ||
        type.toLowerCase().contains('rent')) {
      iconData = PhosphorIconsRegular.house;
    } else if (type.toLowerCase().contains('withdraw') ||
        type.toLowerCase().contains('payout')) {
      iconData = PhosphorIconsRegular.bank;
    } else if (type.toLowerCase().contains('refund') ||
        type.toLowerCase().contains('topup')) {
      iconData = PhosphorIconsRegular.arrowDownLeft;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _grey.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Icon(iconData, color: _dark, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['description']?.toString() ?? type.toUpperCase(),
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600, color: _dark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(transaction['created_at'].toString()),
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: _grey, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${isPositive ? '+' : ''} KSh ${amount.abs().toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isPositive ? _green : _dark),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Text('Recent Transactions',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
        ),
        if (_transactions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: _grey.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(PhosphorIconsRegular.receipt,
                        size: 40, color: _grey),
                  ),
                  const SizedBox(height: 16),
                  Text('No transactions yet',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _dark)),
                  const SizedBox(height: 4),
                  Text('Your wallet history will appear here.',
                      style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactions.length,
            itemBuilder: (context, index) =>
                _buildTransactionTile(_transactions[index]),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? _buildShimmerLoading()
                  : _hasError
                      ? _buildErrorState()
                      : RefreshIndicator(
                          color: _primary,
                          backgroundColor: _surface,
                          onRefresh: _loadData,
                          child: ListView(
                            physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics()),
                            padding: EdgeInsets.only(
                                top: 8,
                                bottom:
                                    MediaQuery.of(context).padding.bottom + 40),
                            children: [
                              _buildWalletCard(),
                              _buildTransactionsList(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMpesaMethodDialog extends StatefulWidget {
  const _AddMpesaMethodDialog({required this.onSave});

  final Future<LandlordPaymentMethod> Function(String phone) onSave;

  @override
  State<_AddMpesaMethodDialog> createState() => _AddMpesaMethodDialogState();
}

class _AddMpesaMethodDialogState extends State<_AddMpesaMethodDialog> {
  final _phoneController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _phoneController.text.trim();
    if (!LandlordPaymentMethodsService.isValidMpesaPhone(phone)) {
      setState(() => _error = 'Enter a valid Kenyan M-Pesa number.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final method = await widget.onSave(phone);
      if (mounted) Navigator.pop(context, method);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = ApiResult.mapError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Add M-Pesa Method',
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.w700, color: _dark)),
      content: TextField(
        controller: _phoneController,
        enabled: !_isSaving,
        keyboardType: TextInputType.phone,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'M-Pesa number',
          errorText: _error,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
