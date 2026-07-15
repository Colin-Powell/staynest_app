import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/super_admin_service.dart';
import 'package:property_app/theme.dart';

class SuperAdminPropertiesPage extends StatefulWidget {
  const SuperAdminPropertiesPage({super.key});

  @override
  State<SuperAdminPropertiesPage> createState() =>
      _SuperAdminPropertiesPageState();
}

class _SuperAdminPropertiesPageState extends State<SuperAdminPropertiesPage> {
  final Set<String> _processingIds = <String>{};
  List<Map<String, dynamic>> _properties = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() => _loading = true);
    try {
      final properties = await SuperAdminService.fetchProperties();
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
            content: Text(
              status == 'approved'
                  ? 'Property approved successfully.'
                  : 'Property rejected successfully.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update property status: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadProperties,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Property moderation',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray900)),
            const SizedBox(height: 8),
            Text(
                'Approve new listings, review flagged properties, and inspect ownership details.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.gray500)),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator()))
            else if (_properties.isEmpty)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No properties found.')))
            else
              ..._properties.map((property) {
                final id = property['id']?.toString() ?? '';
                final title =
                    property['title']?.toString() ?? 'Untitled property';
                final city = property['city']?.toString() ?? 'Unknown city';
                final price = property['price']?.toString() ?? '0';
                final status =
                    (property['status']?.toString() ?? 'pending_review')
                        .toLowerCase();
                final isProcessing = _processingIds.contains(id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: StayNestColors.outlineLight)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              child: Icon(
                                  PhosphorIcons.buildingApartment(
                                      PhosphorIconsStyle.fill),
                                  color: AppColors.primary)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.gray900)),
                                Text('$city • KSh $price',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.gray500)),
                              ],
                            ),
                          ),
                          Chip(
                              label: Text(status.toUpperCase(),
                                  style: GoogleFonts.poppins(fontSize: 11)),
                              backgroundColor: status == 'approved'
                                  ? AppColors.greenBg
                                  : status == 'rejected'
                                      ? AppColors.redBg
                                      : AppColors.gray50),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: isProcessing || status == 'approved'
                                ? null
                                : () => _handleDecision(id, 'approved'),
                            icon: isProcessing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.check, size: 16),
                            label: const Text('Approve'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.green600,
                              side: const BorderSide(color: AppColors.green600),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: isProcessing || status == 'rejected'
                                ? null
                                : () => _handleDecision(id, 'rejected'),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.red500,
                              side: const BorderSide(color: AppColors.red500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
