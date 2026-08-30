import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/models/property_taxonomy.dart';

const Color _tenantPrimary = Color(0xFF3F37C9);
const Color _textDark = Color(0xFF111827);
const Color _textLight = Color(0xFF6B7280);

class AmenitiesView extends StatelessWidget {
  final List<String> amenities;
  final List<String> customFeatures;
  final VoidCallback? onClose;

  const AmenitiesView({
    super.key,
    this.amenities = const [],
    this.customFeatures = const [],
    this.onClose,
  });

  IconData _getIconFor(String iconKey) {
    switch (iconKey) {
      case 'squares_four': return PhosphorIcons.squaresFour();
      case 'columns': return PhosphorIcons.columns();
      case 'arrows_out': return PhosphorIcons.arrowsOut();
      case 'sun': return PhosphorIcons.sun();
      case 'app_window': return PhosphorIcons.appWindow();
      case 'archive_box': return PhosphorIcons.archive();
      case 'door': return PhosphorIcons.door();
      case 'armchair': return PhosphorIcons.armchair();
      case 'couch': return PhosphorIcons.couch();
      case 'buildings': return PhosphorIcons.buildings();
      case 'paint_roller': return PhosphorIcons.paintRoller();
      case 'drop': return PhosphorIcons.drop();
      case 'drop_half_bottom': return PhosphorIcons.dropHalfBottom();
      case 'clock': return PhosphorIcons.clock();
      case 'lightning': return PhosphorIcons.lightning();
      case 'plugs': return PhosphorIcons.plugs();
      case 'lightbulb': return PhosphorIcons.lightbulb();
      case 'wifi_high': return PhosphorIcons.wifiHigh();
      case 'broadcast': return PhosphorIcons.broadcast();
      case 'battery_charging': return PhosphorIcons.batteryCharging();
      case 'sun_dim': return PhosphorIcons.sunDim();
      case 'shield_check': return PhosphorIcons.shieldCheck();
      case 'lock_key': return PhosphorIcons.lockKey();
      case 'wall': return PhosphorIcons.wall();
      case 'user_circle_gear': return PhosphorIcons.userCircleGear();
      case 'moon': return PhosphorIcons.moon();
      case 'camera': return PhosphorIcons.camera();
      case 'lightbulb_filament': return PhosphorIcons.lightbulbFilament();
      case 'student': return PhosphorIcons.student();
      case 'sneaker': return PhosphorIcons.sneaker();
      case 'bus': return PhosphorIcons.bus();
      case 'shopping_cart': return PhosphorIcons.shoppingCart();
      case 'storefront': return PhosphorIcons.storefront();
      case 'road_horizon': return PhosphorIcons.roadHorizon();
      case 'speaker_none': return PhosphorIcons.speakerNone();
      case 'car_profile': return PhosphorIcons.carProfile();
      case 'backpack': return PhosphorIcons.backpack();
      case 'cooking_pot': return PhosphorIcons.cookingPot();
      case 'users': return PhosphorIcons.users();
      case 't_shirt': return PhosphorIcons.tShirt();
      case 'car': return PhosphorIcons.car();
      case 'book_open': return PhosphorIcons.bookOpen();
      case 'engine': return PhosphorIcons.engine();
      case 'elevator': return PhosphorIcons.elevator();
      case 'wheelchair': return PhosphorIcons.wheelchair();
      case 'paw_print': return PhosphorIcons.pawPrint();
      case 'house_line': return PhosphorIcons.houseLine();
      case 'tree': return PhosphorIcons.tree();
      case 'barbell': return PhosphorIcons.barbell();
      case 'swimming_pool': return PhosphorIcons.swimmingPool();
      default: return PhosphorIcons.checkCircle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFeatures = amenities.isNotEmpty || customFeatures.isNotEmpty;

    final categorized = <String, List<PropertyAttribute>>{};
    for (var aId in amenities) {
      final attr = PropertyTaxonomy.getAttributeById(aId);
      if (attr != null) {
        if (!categorized.containsKey(attr.category)) {
          categorized[attr.category] = [];
        }
        categorized[attr.category]!.add(attr);
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onClose ?? () => Navigator.pop(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black.withOpacity(0.1)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textDark, size: 20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('Property Features',
                    style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w800, color: _textDark, letterSpacing: -0.5),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !hasFeatures
                  ? Center(
                      child: Text('No features listed for this property.',
                          style: GoogleFonts.poppins(fontSize: 16, color: _textLight, fontWeight: FontWeight.w500)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 112),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...PropertyTaxonomy.categories.map((cat) {
                            final catAttrs = categorized[cat.id] ?? [];
                            if (catAttrs.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cat.label,
                                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
                                const SizedBox(height: 16),
                                ...catAttrs.map((attr) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      children: [
                                        Icon(_getIconFor(attr.iconKey), color: _tenantPrimary, size: 22),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(attr.label,
                                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: _textDark))),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 24),
                              ],
                            );
                          }),
                          if (customFeatures.isNotEmpty) ...[
                            Text('Additional Features',
                                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
                            const SizedBox(height: 16),
                            ...customFeatures.map((cf) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: _tenantPrimary, size: 22),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(cf,
                                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: _textDark))),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 24),
                          ],
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
