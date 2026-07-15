import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/super_admin_service.dart';
import 'package:property_app/theme.dart';

class SuperAdminKycPage extends StatefulWidget {
  const SuperAdminKycPage({super.key});

  @override
  State<SuperAdminKycPage> createState() => _SuperAdminKycPageState();
}

class _SuperAdminKycPageState extends State<SuperAdminKycPage> {
  final Set<String> _processingIds = <String>{};
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadKyc();
  }

  Future<void> _loadKyc() async {
    setState(() => _loading = true);
    try {
      final items = await SuperAdminService.fetchKyc();
      if (mounted) {
        setState(() {
          _items = items;
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
      await SuperAdminService.updateKycStatus(id, status: status);
      await _loadKyc();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'KYC approved successfully.'
                  : 'KYC rejected successfully.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update KYC status: $error')),
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
      onRefresh: _loadKyc,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KYC review queue',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray900)),
            const SizedBox(height: 8),
            Text(
                'Review identity and compliance submissions before they become active.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.gray500)),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator()))
            else if (_items.isEmpty)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No KYC submissions found.')))
            else
              ..._items.map((item) {
                final id = item['id']?.toString() ?? '';
                final status = item['status']?.toString() ?? 'submitted';
                final name = item['name']?.toString() ?? 'Unknown user';
                final email = item['email']?.toString() ?? 'No email';
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
                                  PhosphorIcons.identificationBadge(
                                      PhosphorIconsStyle.fill),
                                  color: AppColors.primary)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.gray900)),
                                Text(email,
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
