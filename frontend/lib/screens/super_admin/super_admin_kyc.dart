import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/super_admin_service.dart';
import 'package:property_app/session/app_session.dart';
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
  String _searchQuery = '';
  String _filterStatus = 'Pending';

  Map<String, dynamic>? _selectedItem;

  static const List<String> _rejectionReasons = [
    'Blurry / Unreadable Document',
    'Document Expired',
    'Name Mismatch (Profile vs ID)',
    'Face Mismatch (Selfie vs ID)',
    'Unsupported Document Type',
    'Suspected Fraud / Forgery',
    'Other'
  ];

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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleDecision(String id, String status,
      {String? notes}) async {
    setState(() => _processingIds.add(id));
    try {
      await SuperAdminService.updateKycStatus(id,
          status: status, adminNotes: notes);
      await _loadKyc();
      if (mounted) {
        if (_selectedItem != null && _selectedItem!['id'].toString() == id) {
          setState(() => _selectedItem = null);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(status == 'approved' ? 'KYC Approved.' : 'KYC Rejected.'),
            backgroundColor: AppColors.gray900,
            behavior: SnackBarBehavior.floating,
            shape:
                const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: AppColors.gray900,
            behavior: SnackBarBehavior.floating,
            shape:
                const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(id));
    }
  }

  void _showRejectDialog(String id) {
    String selectedReason = _rejectionReasons.first;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text('Reject Document',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.gray900)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select rejection reason:',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray700)),
                  const SizedBox(height: 12),
                  ..._rejectionReasons.map((reason) => RadioListTile<String>(
                        title: Text(reason,
                            style: GoogleFonts.inter(
                                fontSize: 14, color: AppColors.gray900)),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: AppColors.gray900,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (val) =>
                            setDialogState(() => selectedReason = val!),
                      )),
                  const SizedBox(height: 16),
                  Text('Additional Notes:',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    cursorColor: AppColors.gray900,
                    decoration: InputDecoration(
                      hintText: 'Notes for the user...',
                      hintStyle: GoogleFonts.inter(
                          color: AppColors.gray400, fontSize: 13),
                      border: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide:
                              BorderSide(color: StayNestColors.outlineLight)),
                      focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: AppColors.gray900)),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gray600,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final formattedNotes =
                    "$selectedReason: ${notesController.text.trim()}";
                _handleDecision(id, 'rejected', notes: formattedNotes);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gray900,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Confirm Rejection'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktopOrLarger(context);

    final pendingCount = _items
        .where((i) =>
            (i['status']?.toString() ?? 'submitted').toLowerCase() ==
            'submitted')
        .length;
    final filteredItems = _items.where((item) {
      final type =
          (item['name']?.toString() ?? item['user_id']?.toString() ?? '')
              .toLowerCase();
      final status = (item['status']?.toString() ?? 'submitted').toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesSearch = type.contains(q) ||
          (item['email']?.toString() ?? '').toLowerCase().contains(q);
      final matchesStatus = _filterStatus == 'All' ||
          (_filterStatus == 'Pending' && status == 'submitted') ||
          status == _filterStatus.toLowerCase();
      return matchesSearch && matchesStatus;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KYC Verification',
                          style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gray900,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Text('Review identity documents.',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.gray500)),
                    ],
                  ),
                  if (pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: AppColors.gray100,
                          border:
                              Border.all(color: StayNestColors.outlineLight)),
                      child: Text('$pendingCount Pending',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gray900)),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // SEARCH & FILTERS
              Row(
                children: [
                  Expanded(
                    flex: isDesktop ? 0 : 1,
                    child: Container(
                      width: isDesktop ? 320 : null,
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          border:
                              Border.all(color: StayNestColors.outlineLight)),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        cursorColor: AppColors.gray900,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.gray900),
                        decoration: InputDecoration(
                          hintText: 'Search records...',
                          hintStyle: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.gray400),
                          prefixIcon: Icon(PhosphorIcons.magnifyingGlass(),
                              size: 18, color: AppColors.gray500),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: StayNestColors.outlineLight)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterStatus,
                        icon: Icon(PhosphorIcons.caretDown(),
                            size: 16, color: AppColors.gray500),
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.gray900),
                        items: ['All', 'Pending', 'Approved', 'Rejected']
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _filterStatus = val!),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // WORKSPACE
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: StayNestColors.outlineLight)),
            child: isDesktop
                ? Row(
                    children: [
                      SizedBox(width: 350, child: _buildList(filteredItems)),
                      const VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: StayNestColors.outlineLight),
                      Expanded(child: _buildDetailPane(isMobile: false)),
                    ],
                  )
                : _selectedItem == null
                    ? _buildList(filteredItems)
                    : _buildDetailPane(isMobile: true),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // LIST VIEW COMPONENT
  Widget _buildList(List<Map<String, dynamic>> filteredItems) {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gray900));
    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/illustrations/empty.svg', height: 120),
            const SizedBox(height: 16),
            Text('No documents found',
                style: GoogleFonts.inter(
                    color: AppColors.gray500, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: filteredItems.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: StayNestColors.outlineLight),
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final id = item['id']?.toString() ?? '';
        final status =
            (item['status']?.toString() ?? 'submitted').toLowerCase();
        final isSelected =
            _selectedItem != null && _selectedItem!['id'].toString() == id;

        // ONLY colors allowed are indicator statuses
        Color statusColor;
        IconData statusIcon;
        if (status == 'approved') {
          statusColor = AppColors.green600;
          statusIcon = PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
        } else if (status == 'rejected') {
          statusColor = StayNestColors.error;
          statusIcon = PhosphorIcons.xCircle(PhosphorIconsStyle.fill);
        } else {
          statusColor = Colors.orange;
          statusIcon = PhosphorIcons.clock(PhosphorIconsStyle.fill);
        }

        return InkWell(
          onTap: () => setState(() => _selectedItem = item),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.gray50 : Colors.white,
              // Grey selection border (No blue)
              border: Border(
                  left: BorderSide(
                      color:
                          isSelected ? AppColors.gray900 : Colors.transparent,
                      width: 4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User #${item['user_id'] ?? 'Unknown'}',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gray900)),
                      const SizedBox(height: 4),
                      Text('Submitted Document',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.gray500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // DETAIL PANE COMPONENT
  Widget _buildDetailPane({required bool isMobile}) {
    if (_selectedItem == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/illustrations/empty.svg', height: 160),
            const SizedBox(height: 24),
            Text('Select a document from the queue',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray500)),
          ],
        ),
      );
    }

    final item = _selectedItem!;
    final id = item['id'].toString();
    final documents = item['documents'] is Map
        ? Map<String, dynamic>.from(item['documents'])
        : <String, dynamic>{};
    final documentEntries = documents.entries
        .where((entry) =>
            entry.value is String && (entry.value as String).isNotEmpty)
        .toList();
    final status = (item['status']?.toString() ?? 'submitted').toLowerCase();
    final isProcessing = _processingIds.contains(id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Detail Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: StayNestColors.outlineLight)),
              color: Colors.white),
          child: Row(
            children: [
              if (isMobile) ...[
                IconButton(
                    icon: Icon(PhosphorIcons.arrowLeft(),
                        color: AppColors.gray900),
                    onPressed: () => setState(() => _selectedItem = null)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Document Details',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray900)),
                    Text('User ID: ${item['user_id']}',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.gray500)),
                  ],
                ),
              ),
              if (!isMobile)
                IconButton(
                    icon: Icon(PhosphorIcons.x(), color: AppColors.gray400),
                    onPressed: () => setState(() => _selectedItem = null)),
            ],
          ),
        ),

        // Document Gallery
        Expanded(
          child: Container(
            color: AppColors.gray50,
            child: documentEntries.isEmpty
                ? Center(
                    child: Text('No images provided.',
                        style: GoogleFonts.inter(color: AppColors.gray500)))
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: documentEntries.length,
                    itemBuilder: (context, index) {
                      final entry = documentEntries[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        // Sharp corners for image cards
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border:
                                Border.all(color: StayNestColors.outlineLight)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(PhosphorIcons.scan(),
                                    size: 18, color: AppColors.gray500),
                                const SizedBox(width: 8),
                                Text(
                                    entry.key
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.gray700)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Image.network(
                              '${AppSession.apiBaseUrl}${entry.value}',
                              headers: AppSession.apiToken != null
                                  ? {
                                      'Authorization':
                                          'Bearer ${AppSession.apiToken!}'
                                    }
                                  : null,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                height: 200,
                                color: AppColors.gray100,
                                child: Center(
                                    child: Text('Image unavailable',
                                        style: GoogleFonts.inter(
                                            color: AppColors.gray400))),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),

        // Action Footer (Strictly Grey/Black styling)
        if (status == 'submitted')
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(color: StayNestColors.outlineLight))),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        isProcessing ? null : () => _showRejectDialog(id),
                    icon: Icon(PhosphorIcons.x(), size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gray900,
                      side:
                          const BorderSide(color: StayNestColors.outlineLight),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      // Sharp corner for buttons
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => _handleDecision(id, 'approved'),
                    icon: isProcessing
                        ? const SizedBox.shrink()
                        : Icon(PhosphorIcons.check(), size: 18),
                    label: isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gray900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(color: StayNestColors.outlineLight))),
            child: Text('This document was ${status.toUpperCase()}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: AppColors.gray500)),
          )
      ],
    );
  }
}
