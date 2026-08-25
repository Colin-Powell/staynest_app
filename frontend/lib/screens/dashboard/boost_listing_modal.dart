import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/services/properties_api.dart';

class BoostListingModal extends StatefulWidget {
  final String propertyId;

  const BoostListingModal({super.key, required this.propertyId});

  static Future<bool?> show(BuildContext context, String propertyId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BoostListingModal(propertyId: propertyId),
    );
  }

  @override
  State<BoostListingModal> createState() => _BoostListingModalState();
}

class _BoostListingModalState extends State<BoostListingModal> {
  String _selectedPackage = 'basic';
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _handleBoost() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Simulate payment delay
      await Future.delayed(const Duration(seconds: 2));
      await PropertiesApi.boostProperty(widget.propertyId, _selectedPackage);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.green600,
            content: Text('Successfully boosted your listing!', style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Failed to apply boost. Please try again.';
        });
      }
    }
  }

  Widget _buildPackageCard(String id, String name, String days, String boost, String price, IconData icon) {
    final isSelected = _selectedPackage == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPackage = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? StayNestColors.primary.withOpacity(0.05) : Colors.white,
          border: Border.all(
            color: isSelected ? StayNestColors.primary : StayNestColors.outlineLight,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? StayNestColors.primary : AppColors.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : AppColors.gray500, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('$days Days • +$boost Visibility', style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13)),
                ],
              ),
            ),
            Text(price, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: StayNestColors.primary)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Boost Your Listing', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.gray900)),
              IconButton(
                icon: Icon(PhosphorIcons.x(), color: AppColors.gray500),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Increase your visibility and engagement score in search results and recommendations.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.gray500)),
          const SizedBox(height: 24),

          _buildPackageCard('basic', 'Basic Boost', '7', '50', 'KSh 1,500', PhosphorIcons.rocketLaunch()),
          _buildPackageCard('premium', 'Premium Boost', '14', '150', 'KSh 2,500', PhosphorIcons.fire()),
          _buildPackageCard('elite', 'Elite Boost', '30', '500', 'KSh 5,000', PhosphorIcons.crown()),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!, style: GoogleFonts.inter(color: StayNestColors.error, fontSize: 14)),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleBoost,
              style: ElevatedButton.styleFrom(
                backgroundColor: StayNestColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Confirm Payment', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
