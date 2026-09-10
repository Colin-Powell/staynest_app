import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/services/wallet_api.dart';

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
    final format = NumberFormat.currency(locale: 'en_KE', symbol: 'KSh ', decimalDigits: 2);
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

  // ─── UI BUILDERS ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: const Icon(PhosphorIconsRegular.caretLeft, color: _dark, size: 28),
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
          // Wallet Card Shimmer
          Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade100,
            child: Container(height: 24, width: 150, color: Colors.white),
          ),
          const SizedBox(height: 24),
          // Transactions Shimmer
          ...List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                    child: Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                          child: Container(width: double.infinity, height: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Shimmer.fromColors(
                          baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                          child: Container(width: 120, height: 12, color: Colors.white),
                        ),
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
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), shape: BoxShape.circle),
              child: const Icon(PhosphorIconsRegular.warningCircle, size: 48, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _dark),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'We couldn\'t load your wallet data.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: _grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _dark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
              child: Text('Try Again', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
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
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Balance',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              Icon(PhosphorIconsRegular.wallet, color: Colors.white.withOpacity(0.7), size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(balanceRaw),
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Trigger withdraw or deposit logic here
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action coming soon')));
                  },
                  icon: const Icon(PhosphorIconsRegular.arrowUpRight, size: 18, color: _dark),
                  label: Text('Withdraw', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _dark)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _dark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(PhosphorIconsRegular.dotsThree, color: Colors.white, size: 24),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> transaction) {
    final type = transaction['type']?.toString() ?? 'unknown';
    final amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
    final isPositive = amount >= 0;
    
    // Determine icon based on simple heuristics
    IconData iconData = PhosphorIconsRegular.arrowsLeftRight;
    if (type.toLowerCase().contains('booking') || type.toLowerCase().contains('rent')) {
      iconData = PhosphorIconsRegular.house;
    } else if (type.toLowerCase().contains('withdraw') || type.toLowerCase().contains('payout')) {
      iconData = PhosphorIconsRegular.bank;
    } else if (type.toLowerCase().contains('refund')) {
      iconData = PhosphorIconsRegular.arrowUUpLeft;
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(transaction['created_at'].toString()),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _grey,
                    fontWeight: FontWeight.w400,
                  ),
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
              color: isPositive ? _green : _dark,
            ),
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
          child: Text(
            'Recent Transactions',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
        ),
        if (_transactions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: _grey.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(PhosphorIconsRegular.receipt, size: 40, color: _grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: _dark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your wallet history will appear here.',
                    style: GoogleFonts.poppins(fontSize: 14, color: _grey),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactions.length,
            itemBuilder: (context, index) {
              return _buildTransactionTile(_transactions[index]);
            },
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
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            padding: EdgeInsets.only(
                              top: 8,
                              bottom: MediaQuery.of(context).padding.bottom + 40,
                            ),
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