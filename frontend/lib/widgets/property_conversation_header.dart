import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              width: 64,
              height: 64,
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
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () => _viewProperty(context),
            icon: const Icon(PhosphorIconsRegular.arrowSquareOut, size: 15),
            label: const Text('View'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              textStyle: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
