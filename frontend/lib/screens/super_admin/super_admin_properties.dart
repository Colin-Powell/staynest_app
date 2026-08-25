import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:property_app/services/super_admin_service.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/widgets/property_image.dart';

class SuperAdminPropertiesPage extends StatefulWidget {
  const SuperAdminPropertiesPage({super.key});

  @override
  State<SuperAdminPropertiesPage> createState() =>
      _SuperAdminPropertiesPageState();
}

class _SuperAdminPropertiesPageState extends State<SuperAdminPropertiesPage> {
  final Set<String> _processingIds = <String>{};
  List<Map<String, dynamic>> _properties = [];
  String _searchQuery = '';
  String _statusFilter = 'pending_review';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() => _loading = true);
    try {
      final properties = await SuperAdminService.fetchProperties(status: _statusFilter);
      if (mounted) {
        setState(() {
          _properties = properties;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleDecision(String id, String status) async {
    setState(() => _processingIds.add(id));
    try {
      await SuperAdminService.updatePropertyStatus(id, status: status);
      await _loadProperties();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.gray900,
            content: Text(
              status == 'approved'
                  ? 'Property approved successfully.'
                  : 'Property rejected successfully.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.gray900,
            content: Text(
              'Unable to update property status: $error',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(id));
      }
    }
  }


  Widget _buildTab(String label, String value) {
    final isActive = _statusFilter == value;
    return InkWell(
      onTap: () {
        if (_statusFilter != value) {
          setState(() {
            _statusFilter = value;
          });
          _loadProperties();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.gray900 : Colors.white,
          border: Border.all(color: isActive ? AppColors.gray900 : StayNestColors.outlineLight),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
            color: isActive ? Colors.white : AppColors.gray600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _properties.where((prop) {
      final title = (prop['title']?.toString() ?? '').toLowerCase();
      final city = (prop['city']?.toString() ?? '').toLowerCase();
      final address = (prop['address']?.toString() ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || city.contains(q) || address.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Property Moderation',
                      style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray900,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text('Review full listing metadata and manage inventory.',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.gray500)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildTab('Pending', 'pending_review'),
                      const SizedBox(width: 8),
                      _buildTab('Approved', 'approved'),
                      const SizedBox(width: 8),
                      _buildTab('Rejected', 'rejected'),
                    ],
                  ),
                ],
              ),
              Container(
                width: 320,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: StayNestColors.outlineLight),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style:
                      GoogleFonts.inter(fontSize: 13, color: AppColors.gray900),
                  decoration: InputDecoration(
                    hintText: 'Search title, city, or address...',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.gray400),
                    prefixIcon: Icon(PhosphorIcons.magnifyingGlass(),
                        size: 16, color: AppColors.gray500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gray900))
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset('assets/illustrations/empty.svg',
                              height: 120),
                          const SizedBox(height: 16),
                          Text('No properties found',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gray900)),
                          const SizedBox(height: 4),
                          Text('There are no listings matching your criteria.',
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: AppColors.gray500)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildPropertyCard(filtered[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    final id = property['id']?.toString() ?? '';
    final title = property['title']?.toString() ?? 'Untitled property';
    final address = property['address']?.toString() ?? 'Unknown address';
    final city = property['city']?.toString() ?? 'Unknown city';
    final description =
        property['description']?.toString() ?? 'No description provided.';

    // Listing Flow specific metadata
    final category = property['category']?.toString() ?? 'Unknown Type';
    final beds = property['bedrooms']?.toString() ?? '-';
    final baths = property['bathrooms']?.toString() ?? '-';
    final price = property['price']?.toString() ?? '0';
    final imageCount = property['image_count']?.toString() ?? '0';
    final bookingCount = property['booking_count']?.toString() ?? '0';
    final totalRevenue = property['total_revenue']?.toString() ?? '0';
    final landlordName = property['landlord_name']?.toString() ?? 'Unknown';
    final landlordEmail = property['landlord_email']?.toString() ?? 'N/A';

    // Amenities list parsing
    final amenitiesList = (property['amenities'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final amenitiesDisplay = amenitiesList.isEmpty
        ? 'None listed'
        : amenitiesList.take(4).join(' • ') +
            (amenitiesList.length > 4
                ? ' (+${amenitiesList.length - 4} more)'
                : '');

    // Image parsing
    final images = property['images'] as List<dynamic>? ?? [];
    final imageUrl = (images.isNotEmpty
            ? images.first.toString()
            : property['image_url']?.toString()) ??
        '';

    final status =
        (property['status']?.toString() ?? 'pending_review').toLowerCase();
    final isProcessing = _processingIds.contains(id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: StayNestColors.outlineLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Image Thumbnail
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                border: Border.all(color: StayNestColors.outlineLight),
              ),
              child: imageUrl.isNotEmpty
                  ? buildPropertyImage(imageUrl, fit: BoxFit.cover)
                  : Center(
                      child: Icon(PhosphorIcons.image(),
                          size: 32, color: AppColors.gray400),
                    ),
            ),
            const SizedBox(width: 24),

            // Property Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Title & Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.gray900)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(PhosphorIcons.mapPin(),
                                    size: 14, color: AppColors.gray500),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text('$address, $city',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppColors.gray500)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: StayNestColors.outlineLight),
                  const SizedBox(height: 16),

                  // Metadata Grid (Extracted from Listing Flow fields)
                  Wrap(
                    spacing: 32,
                    runSpacing: 16,
                    children: [
                      _buildMetaItem('Rent Price', 'KSh $price /mo'),
                      _buildMetaItem(
                          'Layout', '$category • $beds Bed • $baths Bath'),
                      _buildMetaItem('Images', imageCount),
                      _buildMetaItem('Bookings', bookingCount),
                      _buildMetaItem('Revenue', 'KSh $totalRevenue'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Text Details
                  _buildTextRow('Amenities:', amenitiesDisplay),
                  const SizedBox(height: 6),
                  _buildTextRow('Description:', description, maxLines: 2),
                  const SizedBox(height: 6),
                  _buildTextRow('Landlord:', '$landlordName • $landlordEmail'),

                  // Action Buttons (Only if pending)
                  if (status == 'pending_review') ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isProcessing
                              ? null
                              : () => _handleDecision(id, 'rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.gray900,
                            side: BorderSide(color: AppColors.gray400),
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                          ),
                          child: const Text('Reject Listing'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isProcessing
                              ? null
                              : () => _handleDecision(id, 'approved'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gray900,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Approve Listing'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.gray500,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gray900)),
      ],
    );
  }

  Widget _buildTextRow(String label, String content, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray700)),
        ),
        Expanded(
          child: Text(content,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.gray500, height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    String label = 'PENDING';
    Color textColor = AppColors.gray700;
    Color bgColor = AppColors.gray100;
    Color borderColor = AppColors.gray400;

    if (status == 'approved') {
      label = 'APPROVED';
      textColor = AppColors.gray900;
      bgColor = Colors.white;
      borderColor = AppColors.gray900;
    } else if (status == 'rejected') {
      label = 'REJECTED';
      textColor = AppColors.gray500;
      bgColor = AppColors.gray50;
      borderColor = AppColors.gray400;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}
