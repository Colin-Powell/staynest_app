import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/services/super_admin_service.dart';
import 'package:property_app/theme.dart';
import 'package:uuid/uuid.dart';

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
  int? _estimatedRecipients;
  bool _targetLocation = false;
  bool _targetPropertyType = false;
  bool _loadingProperties = true;
  bool _loadingCampaigns = false;
  bool _estimating = false;
  bool _sending = false;
  String? _error;
  String? _pendingIdempotencyKey;

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

  Future<void> _loadProperties({String? search}) async {
    setState(() => _loadingProperties = true);
    try {
      final properties = await SuperAdminService.fetchCampaignProperties(
        search: search,
      );
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
      final title = property['title']?.toString() ?? 'this home';
      final city = property['city']?.toString() ?? '';
      final category = property['category']?.toString() ?? 'property';
      _titleController.text =
          city.isEmpty ? 'Explore your next home' : 'Find a home in $city';
      _bodyController.text =
          'Explore this $category, "$title", on StayNest. View the photos and listing details.';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send promotional campaign?'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PropertyImage(url: property['image_url']?.toString(), size: 96),
              const SizedBox(height: 12),
              Text(property['title']?.toString() ?? 'Selected listing',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  'Status: ${property['status']} / ${property['availability_status']}'),
              const SizedBox(height: 8),
              Text(_titleController.text.trim()),
              const SizedBox(height: 4),
              Text(_bodyController.text.trim()),
              const SizedBox(height: 12),
              Text('Audience: $_audienceSummary'),
              Text(
                  'Estimated opted-in tenant recipients: $_estimatedRecipients'),
              const Text('Category: Promotional property notification'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send campaign'),
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
        const SnackBar(content: Text('Campaign accepted for processing.')),
      );
      await _loadCampaigns();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign could not be submitted.')),
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
        _selectedProperty?['image_valid'] == true &&
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_loadProperties(), _loadCampaigns()]);
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Push campaigns',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray900,
                          )),
                      const SizedBox(height: 20),
                      if (_error != null) ...[
                        _InlineError(message: _error!),
                        const SizedBox(height: 12),
                      ],
                      _CampaignSection(
                        title: '1. Select an approved property',
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: _searchProperties,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'Search title or location',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_selectedProperty != null)
                              _selectedPropertyView(_selectedProperty!)
                            else
                              _propertyResults(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _CampaignSection(
                        title: '2. Compose the message',
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameController,
                              maxLength: 100,
                              decoration: const InputDecoration(
                                labelText: 'Internal campaign name (optional)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            TextField(
                              controller: _titleController,
                              maxLength: 80,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Notification title',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _bodyController,
                              maxLength: 180,
                              minLines: 2,
                              maxLines: 3,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Notification message',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _CampaignSection(
                        title: '3. Choose opted-in tenants',
                        child: Column(
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title:
                                  const Text('All eligible opted-in tenants'),
                              subtitle: const Text(
                                  'Includes tenants with a valid active device token.'),
                              value: !_targetLocation && !_targetPropertyType,
                              onChanged: (_) => setState(() {
                                _targetLocation = false;
                                _targetPropertyType = false;
                                _estimatedRecipients = null;
                              }),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  'Saved location matches ${_selectedProperty?['city'] ?? 'property city'}'),
                              value: _targetLocation,
                              onChanged: _selectedProperty == null
                                  ? null
                                  : (value) => setState(() {
                                        _targetLocation = value ?? false;
                                        _estimatedRecipients = null;
                                      }),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  'Preferred property type matches ${_selectedProperty?['category'] ?? 'property type'}'),
                              value: _targetPropertyType,
                              onChanged: _selectedProperty == null
                                  ? null
                                  : (value) => setState(() {
                                        _targetPropertyType = value ?? false;
                                        _estimatedRecipients = null;
                                      }),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _selectedProperty == null || _estimating
                                        ? null
                                        : _estimateAudience,
                                icon: _estimating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.refresh, size: 18),
                                label: Text(_estimatedRecipients == null
                                    ? 'Estimate audience'
                                    : 'Refresh estimate'),
                              ),
                            ),
                            if (_estimatedRecipients != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Estimated recipients: $_estimatedRecipients',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            for (final note in _audienceNotes)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(note,
                                      style: const TextStyle(
                                          color: AppColors.gray600,
                                          fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _CampaignSection(
                        title: '4. Preview',
                        child: _notificationPreview(),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _canSend ? _confirmAndSend : null,
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send, size: 18),
                          label: Text(
                              _sending ? 'Submitting...' : 'Review and send'),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _campaignHistory(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _propertyResults() {
    if (_loadingProperties) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_properties.isEmpty) {
      return const ListTile(title: Text('No eligible properties found.'));
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _properties.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final property = _properties[index];
          final imageValid = property['image_valid'] == true;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: _PropertyImage(
                url: property['image_url']?.toString(), size: 58),
            title: Text(property['title']?.toString() ?? 'Untitled property',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${property['city'] ?? property['town'] ?? 'Location unavailable'}  ·  ${_currency(property['price'])}\n${property['status']} / ${property['availability_status']}',
              maxLines: 2,
            ),
            trailing: IconButton(
              tooltip: imageValid
                  ? 'Select property'
                  : 'A valid listing image is required',
              onPressed: imageValid ? () => _selectProperty(property) : null,
              icon: const Icon(Icons.arrow_forward),
            ),
          );
        },
      ),
    );
  }

  Widget _selectedPropertyView(Map<String, dynamic> property) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PropertyImage(url: property['image_url']?.toString(), size: 88),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(property['title']?.toString() ?? 'Selected property',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  '${property['city'] ?? property['town'] ?? 'Location unavailable'}  ·  ${_currency(property['price'])}'),
              Text(
                  '${property['status']} / ${property['availability_status']}'),
              TextButton.icon(
                onPressed: () => setState(() {
                  _selectedProperty = null;
                  _estimatedRecipients = null;
                }),
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Choose another'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notificationPreview() {
    final property = _selectedProperty;
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;
    return Container(
      constraints: BoxConstraints(maxWidth: isDesktop ? 480 : double.infinity),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F2),
        border: Border.all(color: StayNestColors.outlineLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.home_work_outlined, size: 18),
              SizedBox(width: 8),
              Expanded(
                  child: Text('StayNest',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              Text('now',
                  style: TextStyle(fontSize: 11, color: AppColors.gray600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              _titleController.text.isEmpty
                  ? 'Notification title'
                  : _titleController.text,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(_bodyController.text.isEmpty
              ? 'Promotional message preview'
              : _bodyController.text),
          if (property != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: 16 / 8,
                child: Image.network(
                  property['image_url']?.toString() ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFFE7EAE5),
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
                '${_currency(property['price'])}  ·  ${property['city'] ?? property['town'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.gray700)),
          ],
          const SizedBox(height: 10),
          const Text(
              'Android and iOS may display this differently; image display depends on device support and network conditions.',
              style: TextStyle(fontSize: 11, color: AppColors.gray600)),
        ],
      ),
    );
  }

  Widget _campaignHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Campaign history',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            IconButton(
              tooltip: 'Refresh campaign history',
              onPressed: _loadCampaigns,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Divider(),
        if (_loadingCampaigns)
          const Center(child: CircularProgressIndicator())
        else if (_campaigns.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No campaigns have been sent.'),
          )
        else
          for (final campaign in _campaigns)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _PropertyImage(
                url: campaign['image_url']?.toString(),
                size: 48,
              ),
              title: Text(campaign['name']?.toString().isNotEmpty == true
                  ? campaign['name'].toString()
                  : campaign['property_title']?.toString() ??
                      'Property campaign'),
              subtitle: Text(
                '${campaign['created_at'] ?? ''}  ·  ${campaign['submitted_count'] ?? 0} submitted  ·  ${campaign['failed_count'] ?? 0} errors  ·  ${campaign['skipped_count'] ?? 0} skipped  ·  ${campaign['opened_count'] ?? 0} opens',
              ),
              trailing: _StatusLabel(
                  status: campaign['status']?.toString() ?? 'queued'),
            ),
      ],
    );
  }
}

class _CampaignSection extends StatelessWidget {
  const _CampaignSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: StayNestColors.outlineLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

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
        child: url == null || url!.isEmpty
            ? const ColoredBox(
                color: Color(0xFFE7EAE5),
                child: Icon(Icons.image_not_supported_outlined),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFE7EAE5),
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
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
      'completed' => const Color(0xFF2E7D32),
      'completed_with_errors' || 'failed' => const Color(0xFFC62828),
      'processing' => const Color(0xFF1565C0),
      _ => const Color(0xFF616161),
    };
    return Text(status.replaceAll('_', ' '),
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600));
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
        color: const Color(0xFFFFF1F0),
        border: Border.all(color: const Color(0xFFE6A5A0)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF9B1C16))),
    );
  }
}
