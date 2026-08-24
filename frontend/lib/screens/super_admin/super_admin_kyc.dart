import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/super_admin_service.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/utils/responsive_layout.dart';

class SuperAdminKycPage extends StatefulWidget {
  const SuperAdminKycPage({super.key});

  @override
  State<SuperAdminKycPage> createState() => _SuperAdminKycPageState();
}

class _SuperAdminKycPageState extends State<SuperAdminKycPage> {
  final Set<String> _processingIds = <String>{};
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  
  Map<String, dynamic>? _selectedItem;

  @override
  void initState() {
    super.initState();
    _loadKyc();
  }

  Future<void> _loadKyc() async {
    setState(() => _loading = true);
    try {
      final items = await SuperAdminService.fetchKyc(limit: 100);
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

  Future<void> _handleDecision(String id, String status, {String? notes}) async {
    setState(() => _processingIds.add(id));
    try {
      await SuperAdminService.updateKycStatus(id, status: status, adminNotes: notes);
      await _loadKyc();
      if (mounted) {
        if (_selectedItem != null && _selectedItem!['id'].toString() == id) {
          setState(() => _selectedItem = null);
        }
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

  void _showRejectDialog(String id) {
    final _notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject KYC', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            hintText: 'Reason for rejection (sent to landlord)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: const Color(0xFFD1D5DB))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red500),
            onPressed: () {
              Navigator.pop(ctx);
              _handleDecision(id, 'rejected', notes: _notesController.text);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: StayNestColors.outlineLight),
      ),
      child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _items[index];
          final id = item['id']?.toString() ?? '';
          final status = item['status']?.toString() ?? 'submitted';
          final name = item['name']?.toString() ?? 'Unknown user';
          final email = item['email']?.toString() ?? 'No email';
          final date = item['created_at'] != null 
              ? item['created_at'].toString().split('T')[0]
              : '';
              
          final isSelected = _selectedItem?['id'].toString() == id;

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primary.withValues(alpha: 0.05),
            leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(PhosphorIcons.identificationBadge(PhosphorIconsStyle.fill), color: AppColors.primary)),
            title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('$email � $date', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFD1D5DB))),
            trailing: Chip(
                label: Text(status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                backgroundColor: status == 'approved'
                    ? AppColors.greenBg
                    : status == 'rejected'
                        ? AppColors.redBg
                        : StayNestColors.surfaceVariantLight),
            onTap: () {
              setState(() => _selectedItem = item);
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailsPanel() {
    if (_selectedItem == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.fileMagnifyingGlass(PhosphorIconsStyle.light), size: 64, color: const Color(0xFFD1D5DB)),
            const SizedBox(height: 16),
            Text('Select a submission to review', style: GoogleFonts.poppins(color: const Color(0xFFD1D5DB))),
          ],
        ),
      );
    }

    final item = _selectedItem!;
    final id = item['id']?.toString() ?? '';
    final status = item['status']?.toString() ?? 'submitted';
    final name = item['name']?.toString() ?? 'Unknown user';
    final isProcessing = _processingIds.contains(id);
    
    final documents = item['documents'] is Map ? item['documents'] : {};
    final idUrl = documents['id_document_url'];
    final proofUrl = documents['proof_of_address_url'];

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: StayNestColors.outlineLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Reviewing: $name', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedItem = null)),
              ],
            ),
          ),
          
          // Documents
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID Document', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.gray600)),
                  const SizedBox(height: 8),
                  if (idUrl != null)
                    Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: StayNestColors.surfaceVariantLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: StayNestColors.outlineLight),
                        image: DecorationImage(image: NetworkImage(idUrl), fit: BoxFit.contain),
                      ),
                    )
                  else
                    const Text('No ID uploaded.'),
                    
                  const SizedBox(height: 24),
                  
                  Text('Proof of Address / Ownership', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.gray600)),
                  const SizedBox(height: 8),
                  if (proofUrl != null)
                    Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: StayNestColors.surfaceVariantLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: StayNestColors.outlineLight),
                        image: DecorationImage(image: NetworkImage(proofUrl), fit: BoxFit.contain),
                      ),
                    )
                  else
                    const Text('No proof of address uploaded.'),
                ],
              ),
            ),
          ),
          
          // Action Buttons
          if (status == 'submitted')
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: AppColors.red500,
                        side: const BorderSide(color: AppColors.red500),
                      ),
                      onPressed: isProcessing ? null : () => _showRejectDialog(id),
                      child: const Text('Reject KYC'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.green600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isProcessing ? null : () => _handleDecision(id, 'approved'),
                      child: isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Approve KYC'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktopOrLarger(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KYC Verification Queue', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Review landlord documents and approve them to allow listing creation.', style: GoogleFonts.poppins(color: const Color(0xFFD1D5DB))),
                const SizedBox(height: 16),
                // Local Filters
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Filter by name or email...',
                          prefixIcon: const Icon(Icons.search, color: const Color(0xFFD1D5DB)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StayNestColors.outlineLight)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StayNestColors.outlineLight)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        value: 'All',
                        items: ['All', 'Pending', 'Approved', 'Rejected'].map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                        onChanged: (value) {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                Expanded(
                  child: isDesktop 
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: _buildList()),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: StayNestColors.outlineLight),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _buildDetailsPanel(),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _selectedItem == null 
                        ? _buildList() 
                        : _buildDetailsPanel(), // Full screen on mobile
                ),
              ],
            ),
          ),
    );
  }
}
