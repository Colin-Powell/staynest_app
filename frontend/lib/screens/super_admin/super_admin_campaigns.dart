import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:property_app/services/super_admin_service.dart';
import 'package:property_app/widgets/property_image.dart';

// ─── Google Analytics / Firebase Design System Constants ──────────────────────
const Color _bg = Color(0xFFF3F4F6); // Soft GA background
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF6B7280);
const Color _greyLight = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _divider = Color(0xFFE5E7EB);
const Color _primaryBlue = Color(0xFF1A73E8); // Google Blue
const Color _successGreen = Color(0xFF1E8E3E); // Google Green

class SuperAdminCampaignsPage extends StatefulWidget {
  const SuperAdminCampaignsPage({super.key});

  @override
  State<SuperAdminCampaignsPage> createState() =>
      _SuperAdminCampaignsPageState();
}

class _SuperAdminCampaignsPageState extends State<SuperAdminCampaignsPage> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  Timer? _searchTimer;
  Timer? _progressTimer;

  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _campaigns = [];
  Map<String, dynamic>? _selectedProperty;

  List<String> _audienceNotes = [];
  Map<String, int> _audienceDiagnostics = {};
  int? _estimatedRecipients;
  bool _targetLocation = false;
  bool _targetPropertyType = false;

  bool _loadingProperties = true;
  bool _loadingCampaigns = false;
  bool _estimating = false;
  bool _sending = false;
  String? _error;
  String? _pendingIdempotencyKey;

  // Firebase-style stepper state
  int _currentStep = 0;

  Map<String, bool> get _audience => {
        'location': _targetLocation,
        'propertyType': _targetPropertyType,
      };

  String get _audienceSummary {
    final filters = <String>['Opted-in tenants'];
    if (_targetLocation) {
      filters.add(
          'saved city: ${_selectedProperty?['city'] ?? 'selected property'}');
    }
    if (_targetPropertyType) {
      filters.add(
          'preferred type: ${_selectedProperty?['category'] ?? 'selected property'}');
    }
    return filters.join(' + ');
  }

  @override
  void initState() {
    super.initState();
    _loadProperties();
    _loadCampaigns();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted &&
          !_loadingCampaigns &&
          _campaigns.any((campaign) =>
              campaign['status'] == 'queued' ||
              campaign['status'] == 'processing')) {
        _loadCampaigns();
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _progressTimer?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  // ─── Logic Methods (Preserved completely) ───────────────────────────────────

  Future<void> _loadProperties({String? search}) async {
    setState(() => _loadingProperties = true);
    try {
      final properties =
          await SuperAdminService.fetchCampaignProperties(search: search);
      if (mounted) setState(() => _properties = properties);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not load eligible properties.');
      }
    } finally {
      if (mounted) setState(() => _loadingProperties = false);
    }
  }

  Future<void> _loadCampaigns() async {
    if (_loadingCampaigns) return;
    setState(() => _loadingCampaigns = true);
    try {
      final campaigns = await SuperAdminService.fetchPushCampaigns();
      if (mounted) setState(() => _campaigns = campaigns);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load campaign history.');
    } finally {
      if (mounted) setState(() => _loadingCampaigns = false);
    }
  }

  void _searchProperties(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _loadProperties(search: value.trim());
    });
  }

  Future<void> _selectProperty(Map<String, dynamic> property) async {
    setState(() {
      _selectedProperty = property;
      _estimatedRecipients = null;
      _audienceNotes = [];
      _audienceDiagnostics = {};
      final title = property['title']?.toString() ?? 'this home';
      final city = property['city']?.toString() ?? '';
      final category = property['category']?.toString() ?? 'property';
      _titleController.text =
          city.isEmpty ? 'Explore your next home' : 'Find a home in $city';
      _bodyController.text =
          'Explore this $category, "$title", on StayNest. View the photos and listing details.';

      // Auto-advance to Compose Step
      _currentStep = 1;
    });
    await _estimateAudience();
  }

  Future<void> _estimateAudience() async {
    final property = _selectedProperty;
    if (property == null) return;
    setState(() => _estimating = true);
    try {
      final estimate = await SuperAdminService.estimatePushCampaignAudience(
        propertyId: property['id'].toString(),
        audience: _audience,
      );
      if (!mounted) return;
      setState(() {
        _estimatedRecipients =
            int.tryParse('${estimate['estimatedRecipients']}') ?? 0;
        _audienceNotes = (estimate['notes'] as List<dynamic>? ?? [])
            .map((note) => note.toString())
            .toList();
        final diagnostics = estimate['diagnostics'];
        _audienceDiagnostics = diagnostics is Map
            ? diagnostics.map((key, value) => MapEntry(
                  key.toString(),
                  int.tryParse('$value') ?? 0,
                ))
            : {};
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _estimatedRecipients = null;
          _error = 'Audience estimate failed. Review the selection and retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  Future<void> _confirmAndSend() async {
    final property = _selectedProperty;
    if (property == null || !_canSend) return;

    // Quick confirmation modal
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Send Campaign?',
            style:
                GoogleFonts.inter(fontWeight: FontWeight.w700, color: _dark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This push notification will be sent to approximately $_estimatedRecipients tenants.',
              style: GoogleFonts.inter(color: _grey),
            ),
            const SizedBox(height: 8),
            Text('Property: ${property['title'] ?? 'Selected listing'}'),
            Text('Audience: $_audienceSummary'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: _dark, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue, elevation: 0),
            child: Text('Send Campaign',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _sending = true);
    try {
      await SuperAdminService.sendPushCampaign(
        propertyId: property['id'].toString(),
        name: _nameController.text,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        audience: _audience,
        idempotencyKey: _pendingIdempotencyKey ??= const Uuid().v4(),
      );
      _pendingIdempotencyKey = null;
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Campaign processing initiated.',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: _dark,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _currentStep = 0; // Reset
        _selectedProperty = null;
      });
      await _loadCampaigns();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Campaign submission failed.',
                  style: GoogleFonts.inter(color: Colors.white)),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool get _canSend {
    return !_sending &&
        !_estimating &&
        _selectedProperty != null &&
        (_estimatedRecipients ?? 0) > 0 &&
        _titleController.text.trim().isNotEmpty &&
        _titleController.text.trim().length <= 80 &&
        _bodyController.text.trim().isNotEmpty &&
        _bodyController.text.trim().length <= 180;
  }

  String _currency(dynamic amount) {
    final value =
        amount is num ? amount.toDouble() : double.tryParse('$amount');
    return value == null
        ? 'Price unavailable'
        : 'KSh ${value.toStringAsFixed(0)}';
  }

  // ─── UI Layouts ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _primaryBlue,
          onRefresh: () async {
            await Future.wait([_loadProperties(), _loadCampaigns()]);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: _primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(PhosphorIconsFill.megaphone,
                                  color: _primaryBlue, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Push Campaigns',
                              style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: _dark,
                                  letterSpacing: -0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        if (_error != null) ...[
                          _InlineError(message: _error!),
                          const SizedBox(height: 24),
                        ],

                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  children: [
                                    _buildFirebaseStepper(),
                                    const SizedBox(height: 48),
                                    _buildCampaignHistory(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 48),
                              Expanded(
                                flex: 4,
                                child: _buildStickyPreviewPanel(),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildFirebaseStepper(),
                              const SizedBox(height: 32),
                              _buildMobilePreviewPanel(),
                              const SizedBox(height: 48),
                              _buildCampaignHistory(),
                            ],
                          ),

                        const SizedBox(height: 64),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Firebase Style Stepper ──────────────────────────────────────────────────

  Widget _buildFirebaseStepper() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildStep(
            index: 0,
            title: 'Property Selection',
            isCompleted: _selectedProperty != null && _currentStep > 0,
            isActive: _currentStep == 0,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select an approved property to promote.',
                    style: GoogleFonts.inter(color: _grey, fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: _searchProperties,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                        color: _grey, size: 20),
                    hintText: 'Search title or location',
                    hintStyle: GoogleFonts.inter(color: _grey, fontSize: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _divider)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _divider)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: _primaryBlue, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedProperty != null)
                  _selectedPropertyView(_selectedProperty!)
                else
                  _propertyResults(),
              ],
            ),
          ),
          const Divider(height: 1, color: _divider),
          _buildStep(
            index: 1,
            title: 'Compose Message',
            isCompleted: _titleController.text.isNotEmpty &&
                _bodyController.text.isNotEmpty &&
                _currentStep > 1,
            isActive: _currentStep == 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Draft the push notification content.',
                    style: GoogleFonts.inter(color: _grey, fontSize: 13)),
                const SizedBox(height: 16),
                _buildInputField(
                    label: 'Campaign Name (Internal)',
                    controller: _nameController,
                    hint: 'e.g. Summer Promo - Nairobi'),
                _buildInputField(
                    label: 'Notification Title',
                    controller: _titleController,
                    maxLength: 80,
                    onChanged: (_) => setState(() {})),
                _buildInputField(
                    label: 'Notification Body',
                    controller: _bodyController,
                    maxLength: 180,
                    maxLines: 3,
                    onChanged: (_) => setState(() {})),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (_titleController.text.isNotEmpty &&
                          _bodyController.text.isNotEmpty)
                      ? () => setState(() => _currentStep = 2)
                      : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16)),
                  child: Text('Next',
                      style: GoogleFonts.inter(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                )
              ],
            ),
          ),
          const Divider(height: 1, color: _divider),
          _buildStep(
            index: 2,
            title: 'Target Audience',
            isCompleted: _estimatedRecipients != null && _currentStep > 2,
            isActive: _currentStep == 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select the user segments to receive this campaign.',
                    style: GoogleFonts.inter(color: _grey, fontSize: 13)),
                const SizedBox(height: 16),
                _buildTargetCheckbox(
                    'All eligible opted-in tenants',
                    'Includes tenants with a valid active device token.',
                    !_targetLocation && !_targetPropertyType, (v) {
                  setState(() {
                    _targetLocation = false;
                    _targetPropertyType = false;
                    _estimatedRecipients = null;
                  });
                }),
                _buildTargetCheckbox(
                    'Location matches ${_selectedProperty?['city'] ?? 'property city'}',
                    'Targets users looking in this area.',
                    _targetLocation,
                    _selectedProperty == null
                        ? null
                        : (v) {
                            setState(() {
                              _targetLocation = v ?? false;
                              _estimatedRecipients = null;
                            });
                          }),
                _buildTargetCheckbox(
                    'Preference matches ${_selectedProperty?['category'] ?? 'property type'}',
                    'Targets users seeking this property type.',
                    _targetPropertyType,
                    _selectedProperty == null
                        ? null
                        : (v) {
                            setState(() {
                              _targetPropertyType = v ?? false;
                              _estimatedRecipients = null;
                            });
                          }),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _selectedProperty == null || _estimating
                      ? null
                      : _estimateAudience,
                  icon: _estimating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _primaryBlue))
                      : const Icon(PhosphorIconsRegular.users, size: 18),
                  label: Text(_estimatedRecipients == null
                      ? 'Calculate Audience'
                      : 'Recalculate'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryBlue,
                      side: const BorderSide(color: _divider),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14)),
                ),
                if (_estimatedRecipients != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _primaryBlue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsFill.info,
                            color: _primaryBlue, size: 20),
                        const SizedBox(width: 12),
                        Text(
                            'Estimated delivery to $_estimatedRecipients users.',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: _primaryBlue,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEligibilityFunnel(),
                ],
                for (final note in _audienceNotes)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('• $note',
                        style: GoogleFonts.inter(color: _grey, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityFunnel() {
    const steps = <(String, String)>[
      ('Tenant accounts', 'eligible_tenants'),
      ('With active FCM token', 'tenants_with_token'),
      ('OS permission granted', 'tenants_with_permission'),
      ('Promotional opt-in', 'promotional_opt_ins'),
      ('Push enabled', 'eligible_before_targeting'),
    ];
    return Column(
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(step.$1,
                      style: GoogleFonts.inter(fontSize: 11, color: _grey)),
                ),
                Text('${_audienceDiagnostics[step.$2] ?? 0}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            children: [
              Expanded(
                child: Text('Match selected filters',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
              ),
              Text('$_estimatedRecipients',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _dark)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(
      {required int index,
      required String title,
      required bool isCompleted,
      required bool isActive,
      required Widget content}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
            left: BorderSide(
                color: isActive ? _primaryBlue : Colors.transparent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _currentStep = index),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? _successGreen
                          : (isActive ? _primaryBlue : _greyLight),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : Text('${index + 1}',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: isActive || isCompleted
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isActive || isCompleted ? _dark : _grey),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState:
                isActive ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(left: 60, right: 24, bottom: 24),
              child: content,
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
      {required String label,
      required TextEditingController controller,
      int maxLines = 1,
      int? maxLength,
      String? hint,
      Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            onChanged: onChanged,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: _grey, fontSize: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _primaryBlue, width: 2)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCheckbox(
      String title, String subtitle, bool value, Function(bool?)? onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: onChanged,
                  activeColor: _primaryBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _dark)),
                    Text(subtitle,
                        style: GoogleFonts.inter(fontSize: 12, color: _grey)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ─── Property Selection ──────────────────────────────────────────────────────

  Widget _propertyResults() {
    if (_loadingProperties) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: _primaryBlue)),
      );
    }
    if (_properties.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No eligible properties found.',
            style: GoogleFonts.inter(color: _grey)),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
          border: Border.all(color: _divider),
          borderRadius: BorderRadius.circular(8)),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _properties.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: _divider),
        itemBuilder: (context, index) {
          final property = _properties[index];
          return ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: _PropertyImage(
                url: property['image_url']?.toString(), size: 48),
            title: Text(property['title']?.toString() ?? 'Untitled property',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${property['city'] ?? property['town'] ?? 'Location unavailable'}  ·  ${_currency(property['price'])}\n${property['status']} / ${property['availability_status']}',
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 11, color: _grey),
            ),
            trailing: IconButton(
              tooltip: property['image_valid'] == true
                  ? 'Select property'
                  : 'Select property; image unavailable',
              onPressed: () => _selectProperty(property),
              icon: const Icon(PhosphorIconsRegular.checkCircle,
                  color: _primaryBlue),
            ),
          );
        },
      ),
    );
  }

  Widget _selectedPropertyView(Map<String, dynamic> property) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _divider),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PropertyImage(url: property['image_url']?.toString(), size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(property['title']?.toString() ?? 'Selected property',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: _dark,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                    '${property['city'] ?? property['town'] ?? 'Location unavailable'}  ·  ${_currency(property['price'])}',
                    style: GoogleFonts.inter(fontSize: 12, color: _grey)),
                Text(
                    '${property['status']} / ${property['availability_status']}',
                    style: GoogleFonts.inter(fontSize: 12, color: _grey)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() {
                    _selectedProperty = null;
                    _estimatedRecipients = null;
                  }),
                  child: Text('Change Property',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Live Phone Preview ──────────────────────────────────────────────────────

  Widget _buildStickyPreviewPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Device Preview',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w600, color: _dark)),
          const SizedBox(height: 8),
          Text('How it looks on user devices',
              style: GoogleFonts.inter(fontSize: 13, color: _grey)),
          const SizedBox(height: 32),

          // Phone Mockup Frame
          Container(
            width: 280,
            height: 560,
            decoration: BoxDecoration(
              color: Colors.black, // Phone bezel
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 10))
              ],
              border: Border.all(color: const Color(0xFFE5E7EB), width: 6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                children: [
                  // Mock Wallpaper
                  Positioned.fill(
                    child: Image.network(
                      'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=2564&auto=format&fit=crop',
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Mock Status Bar
                  Positioned(
                    top: 12,
                    left: 24,
                    right: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('9:41',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const Row(
                          children: [
                            Icon(PhosphorIconsFill.cellSignalFull,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Icon(PhosphorIconsFill.wifiHigh,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Icon(PhosphorIconsFill.batteryFull,
                                color: Colors.white, size: 16),
                          ],
                        )
                      ],
                    ),
                  ),
                  // Notification Bubble
                  Positioned(
                    top: 60,
                    left: 12,
                    right: 12,
                    child: _notificationPreviewBubble(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _canSend ? _confirmAndSend : null,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(PhosphorIconsFill.paperPlaneRight, size: 18),
              label: Text(_sending ? 'Sending...' : 'Review & Send',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _grey.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMobilePreviewPanel() {
    return _buildStickyPreviewPanel(); // Reuse same layout, it constraints itself
  }

  Widget _notificationPreviewBubble() {
    final property = _selectedProperty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Color(0xFF3F37C9),
                    shape: BoxShape.circle), // StayNest Blue Logo mock
                child: const Icon(PhosphorIconsFill.house,
                    color: Colors.white, size: 10),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('STAYNEST',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _greyLight,
                          letterSpacing: 0.5))),
              Text('now',
                  style: GoogleFonts.inter(fontSize: 11, color: _greyLight)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _titleController.text.isEmpty
                ? 'Notification title'
                : _titleController.text,
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: _dark),
          ),
          const SizedBox(height: 2),
          Text(
            _bodyController.text.isEmpty
                ? 'Promotional message preview'
                : _bodyController.text,
            style: GoogleFonts.inter(fontSize: 13, color: _dark),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (property != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: buildPropertyImage(
                    property['image_url']?.toString() ?? '',
                    fit: BoxFit.cover),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Campaign History Data Table ─────────────────────────────────────────────

  Widget _buildCampaignHistory() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Campaign History',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
                IconButton(
                  tooltip: 'Refresh history',
                  icon: const Icon(PhosphorIconsRegular.arrowsClockwise,
                      size: 20),
                  onPressed: _loadCampaigns,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _divider),
          if (_loadingCampaigns)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: CircularProgressIndicator(color: _primaryBlue)))
          else if (_campaigns.isEmpty)
            Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                    child: Text('No campaigns have been sent.',
                        style: GoogleFonts.inter(color: _grey))))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _campaigns.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: _divider),
              itemBuilder: (context, index) {
                final campaign = _campaigns[index];
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _PropertyImage(
                        url: campaign['image_url']?.toString() ??
                            campaign['current_image_url']?.toString(),
                        size: 48,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              campaign['name']?.toString().isNotEmpty == true
                                  ? campaign['name'].toString()
                                  : campaign['property_title']?.toString() ??
                                      'Property campaign',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _dark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${campaign['created_at'] ?? ''} • ${campaign['submitted_count'] ?? 0} sent • ${campaign['opened_count'] ?? 0} opens',
                              style:
                                  GoogleFonts.inter(fontSize: 12, color: _grey),
                            ),
                          ],
                        ),
                      ),
                      _StatusLabel(
                          status: campaign['status']?.toString() ?? 'queued'),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─── Shared Components ───────────────────────────────────────────────────────

class _PropertyImage extends StatelessWidget {
  const _PropertyImage({required this.url, required this.size});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        dimension: size,
        child: buildPropertyImage(url ?? '',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorPlaceholder: Container(
                color: _divider,
                child:
                    const Icon(PhosphorIconsRegular.image, color: _greyLight))),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'completed' => _successGreen,
      'completed_with_errors' || 'failed' => const Color(0xFFC62828),
      'processing' => _primaryBlue,
      _ => _greyLight,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: const Color(0xFFFCA5A5)),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(PhosphorIconsFill.warningCircle,
              color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: GoogleFonts.inter(
                      color: const Color(0xFF991B1B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
