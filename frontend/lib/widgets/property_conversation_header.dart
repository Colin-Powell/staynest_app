import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/message_service.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/screens/property/property_details.dart';

class PropertyConversationHeader extends StatelessWidget {
  final PropertyConversationContext property;

  const PropertyConversationHeader({
    super.key,
    required this.property,
  });

  Future<void> _viewProperty(BuildContext context) async {
    final current =
        await PropertyService.instance.fetchPropertyById(property.id);
    if (!context.mounted) return;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This property is no longer available.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertyDetails(property: current),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availability = property.availabilityStatus?.trim();
    final availabilityLabel = availability == null || availability.isEmpty
        ? null
        : availability
            .replaceAll('_', ' ')
            .split(' ')
            .map((part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    final managementLabel = switch (property.managementType) {
      'landlord' => 'Landlord managed',
      'agent' => 'Agent managed',
      'staynest' => 'StayNest managed',
      _ => 'Management not specified',
    };
    final feeLabel = switch (property.viewingFeeType) {
      'free' => 'Free viewing',
      'paid' when property.viewingFeeAmount != null =>
        'Viewing fee KSh ${NumberFormat('#,##0.##').format(property.viewingFeeAmount)}',
      'paid' => 'Viewing fee amount unavailable',
      _ => 'Viewing fee not specified',
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(8),
        ),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(8),
        ),
        child: SizedBox(
          height: 100,
          child: Row(
            children: [
              SizedBox(
                width: 76,
                height: 100,
                child: property.imageUrl == null || property.imageUrl!.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFE2E8F0),
                        child: Icon(PhosphorIconsRegular.house,
                            color: Color(0xFF64748B)),
                      )
                    : Image.network(
                        property.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFE2E8F0),
                          child: Icon(PhosphorIconsRegular.house,
                              color: Color(0xFF64748B)),
                        ),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        property.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF172033),
                        ),
                      ),
                      if (property.location.isNotEmpty)
                        Text(
                          property.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        children: [
                          if (property.price != null && property.price! > 0)
                            Text(
                              'Ksh ${property.price}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF172033),
                              ),
                            ),
                          if (availabilityLabel != null)
                            Text(
                              availabilityLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          Text(
                            managementLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          Tooltip(
                            message: property.viewingFeeNotes?.isNotEmpty ==
                                    true
                                ? '${_feeCollectorLabel(property.viewingFeeCollector)} collects this fee. ${property.viewingFeeNotes}'
                                : 'Fee collected independently by ${_feeCollectorLabel(property.viewingFeeCollector)}.',
                            child: Text(
                              feeLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _viewProperty(context),
                icon: const Icon(PhosphorIconsRegular.arrowSquareOut, size: 15),
                label: const Text('View'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _feeCollectorLabel(String? collector) => switch (collector) {
        'agent' => 'The assigned agent',
        'landlord' => 'The landlord',
        'staynest' => 'StayNest',
        _ => 'The property manager',
      };
}
