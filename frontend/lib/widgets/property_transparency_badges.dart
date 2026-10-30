import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property_app/models/property.dart';

class PropertyTransparencyBadges extends StatelessWidget {
  final Property property;
  final bool compact;
  final bool showUnspecified;

  const PropertyTransparencyBadges({
    super.key,
    required this.property,
    this.compact = false,
    this.showUnspecified = true,
  });

  @override
  Widget build(BuildContext context) {
    final management = _managementBadge();
    final fee = _viewingFeeBadge();
    final badges = [
      if (management != null) management,
      if (fee != null) fee,
    ];
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: badges,
    );
  }

  Widget? _managementBadge() {
    final managementType = property.agent.isAgent &&
            {'landlord', 'unspecified'}.contains(property.managementType)
        ? 'agent'
        : property.managementType;
    final (
      String label,
      IconData icon,
      String? imageAsset,
      Color foreground,
      Color background,
      String description
    )? data = switch (managementType) {
      'landlord' => (
          'Landlord managed',
          Icons.home_work_outlined,
          'assets/images/landlord_owned.gif',
          const Color(0xFF167447),
          const Color(0xFFEAF7EF),
          'The landlord manages this property and tenant inquiries.',
        ),
      'agent' => (
          'Agent managed',
          Icons.business_center_outlined,
          null,
          const Color(0xFF176B87),
          const Color(0xFFEAF6FA),
          'An assigned property agent manages this listing.',
        ),
      'staynest' => (
          'StayNest managed',
          Icons.shield_outlined,
          'assets/images/staynest_owned.gif',
          const Color(0xFF176D50),
          const Color(0xFFE7F5EE),
          'This property is directly managed by StayNest.',
        ),
      _ => showUnspecified
          ? (
              'Management not specified',
              Icons.help_outline_rounded,
              null,
              const Color(0xFF596273),
              const Color(0xFFF3F4F6),
              'The property manager has not been specified.',
            )
          : null,
    };
    if (data == null) return null;
    return _badge(data.$1, data.$2, data.$3, data.$4, data.$5, data.$6);
  }

  Widget? _viewingFeeBadge() {
    final (
      String label,
      IconData icon,
      String? imageAsset,
      Color foreground,
      Color background,
      String description
    )? data = switch (property.viewingFeeType) {
      'free' => (
          'Free viewing',
          Icons.check_circle_outline_rounded,
          'assets/images/free.gif',
          const Color(0xFF167447),
          const Color(0xFFEAF7EF),
          'No viewing fee is charged for visiting this property.',
        ),
      'paid' when property.viewingFeeAmount != null => (
          'Viewing fee: KSh ${NumberFormat('#,##0.##').format(property.viewingFeeAmount)}',
          Icons.account_balance_wallet_outlined,
          'assets/images/fee.gif',
          const Color(0xFF9A5A00),
          const Color(0xFFFFF3D9),
          'Viewing fee collected by ${property.viewingFeeCollector ?? 'the property manager'}.${property.viewingFeeNotes?.isNotEmpty == true ? ' ${property.viewingFeeNotes}' : ''}',
        ),
      'paid' => (
          'Viewing fee details unavailable',
          Icons.help_outline_rounded,
          'assets/images/fee.gif',
          const Color(0xFF596273),
          const Color(0xFFF3F4F6),
          'A viewing fee is required, but the amount has not been provided.',
        ),
      _ => showUnspecified
          ? (
              'Viewing fee not specified',
              Icons.help_outline_rounded,
              null,
              const Color(0xFF596273),
              const Color(0xFFF3F4F6),
              'The viewing fee has not been specified. Confirm with the manager before visiting.',
            )
          : null,
    };
    if (data == null) return null;
    return _badge(
      data.$1,
      data.$2,
      data.$3,
      data.$4,
      data.$5,
      data.$6,
    );
  }

  Widget _badge(
    String label,
    IconData icon,
    String? imageAsset,
    Color foreground,
    Color background,
    String description,
  ) {
    return Tooltip(
      message: description,
      child: Container(
        constraints: const BoxConstraints(minHeight: 26),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageAsset != null)
              Image.asset(
                imageAsset,
                width: compact ? 14 : 18,
                height: compact ? 14 : 18,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              )
            else
              Icon(icon, size: compact ? 12 : 14, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
