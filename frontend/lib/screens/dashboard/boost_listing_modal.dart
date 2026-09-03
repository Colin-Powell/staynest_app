import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/properties_api.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

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
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              'Successfully boosted your listing!', 
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)
            ),
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
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? _green.withOpacity(0.04) : _surface,
          border: Border.all(
            color: isSelected ? _green : _grey.withOpacity(0.15),
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? _green : _grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : _grey, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name, 
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, 
                      fontSize: 16, 
                      color: _dark
                    )
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$days Days • +$boost Visibility', 
                    style: GoogleFonts.poppins(
                      color: _grey, 
                      fontSize: 13,
                      fontWeight: FontWeight.w500
                    )
                  ),
                ],
              ),
            ),
            Text(
              price, 
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800, 
                fontSize: 16, 
                color: isSelected ? _green : _dark,
                letterSpacing: -0.5,
              )
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)), // Deeper pill-like curve
      ),
      padding: const EdgeInsets.all(24).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Drag Handle ───
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: _grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ─── Header ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Boost Your Listing', 
                style: GoogleFonts.poppins(
                  fontSize: 22, 
                  fontWeight: FontWeight.w700, 
                  color: _dark,
                  letterSpacing: -0.5,
                )
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(PhosphorIconsRegular.x, color: _dark, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Increase your visibility and engagement score in search results and recommendations.',
            style: GoogleFonts.poppins(fontSize: 14, color: _grey, height: 1.5),
          ),
          const SizedBox(height: 32),

          // ─── Packages ───
          _buildPackageCard('basic', 'Basic Boost', '7', '50', 'Ksh 1,500', PhosphorIconsFill.rocketLaunch),
          _buildPackageCard('premium', 'Premium Boost', '14', '150', 'Ksh 2,500', PhosphorIconsFill.fire),
          _buildPackageCard('elite', 'Elite Boost', '30', '500', 'Ksh 5,000', PhosphorIconsFill.crown),

          // ─── Error Message ───
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.warningCircle, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!, 
                      style: GoogleFonts.poppins(color: const Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w500)
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ─── Action Button ───
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleBoost,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                disabledBackgroundColor: _grey.withOpacity(0.2),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)), // Modern Pill
              ),
              child: _isProcessing
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      'Confirm Payment', 
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)
                    ),
            ),
          ),
        ],
      ),
    );
  }
}