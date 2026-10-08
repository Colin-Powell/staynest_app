import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';

// ─── Tenant Design System Constants ───────────────────────────────────────────
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _greyDark = Color(0xFF4B5563);
const Color _surface = Colors.white;
const Color _tenantPrimary = Color(0xFF3F37C9); // Tenant Blue Theme
const Color _divider = Color(0xFFE5E7EB);

class TenantProfileView extends StatefulWidget {
  final VoidCallback onBack;

  const TenantProfileView({super.key, required this.onBack});

  @override
  State<TenantProfileView> createState() => _TenantProfileViewState();
}

class _TenantProfileViewState extends State<TenantProfileView> {
  final _repository = RemoteDatabaseRepository();

  final _preferredName = TextEditingController();
  final _bio = TextEditingController();
  final _institution = TextEditingController();
  final _campus = TextEditingController();
  final _course = TextEditingController();
  final _year = TextEditingController();
  final _graduation = TextEditingController();
  final _budgetMin = TextEditingController();
  final _budgetMax = TextEditingController();
  final _locations = TextEditingController();

  final Set<String> _languages = {};
  final Set<String> _propertyTypes = {};
  final Set<String> _amenities = {};

  String _distance = 'Anywhere';
  String _roomPreference = 'Either';
  String _moveInTiming = 'Just browsing';

  bool _loading = true;
  bool _saving = false;

  static const _propertyTypeOptions = [
    'Bedsitter',
    'Single room',
    'One bedroom',
    'Shared room',
    'Hostel',
    'Studio',
  ];

  static const _amenityOptions = [
    'Reliable water',
    'Electricity included',
    'Wi-Fi',
    'Parking',
    'Secure compound',
    'Furnished',
    'Pet friendly',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final controller in [
      _preferredName,
      _bio,
      _institution,
      _campus,
      _course,
      _year,
      _graduation,
      _budgetMin,
      _budgetMax,
      _locations,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _repository.fetchTenantProfileMe();
      if (profile != null) {
        _preferredName.text = profile['preferred_name']?.toString() ?? '';
        _bio.text = profile['bio']?.toString() ?? '';
        _institution.text = profile['institution']?.toString() ?? '';
        _campus.text = profile['campus']?.toString() ?? '';
        _course.text = profile['course']?.toString() ?? '';
        _year.text = profile['year_of_study']?.toString() ?? '';
        _graduation.text = profile['expected_graduation']?.toString() ?? '';
        _budgetMin.text = profile['budget_min']?.toString() ?? '';
        _budgetMax.text = profile['budget_max']?.toString() ?? '';
        _locations.text = _asStringList(profile['preferred_cities']).join(', ');
        _languages.addAll(_asStringList(profile['languages']));
        _propertyTypes.addAll(_asStringList(profile['preferred_categories']));
        _amenities.addAll(_asStringList(profile['preferred_amenities']));
        _distance = profile['distance_preference']?.toString() ?? _distance;
        _roomPreference =
            profile['room_preference']?.toString() ?? _roomPreference;
        _moveInTiming =
            profile['move_in_preference']?.toString() ?? _moveInTiming;
      }
    } catch (_) {
      // Keep the form usable when an optional profile fetch is unavailable.
    }
    if (mounted) setState(() => _loading = false);
  }

  List<String> _asStringList(dynamic value) => value is List
      ? value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList()
      : const [];

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await _repository.saveTenantProfile({
      'preferred_name': _preferredName.text.trim().isEmpty
          ? null
          : _preferredName.text.trim(),
      'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      'languages': _languages.toList(),
      'institution': _institution.text.trim(),
      'campus': _campus.text.trim(),
      'course': _course.text.trim(),
      'year_of_study': _year.text.trim(),
      'expected_graduation': int.tryParse(_graduation.text.trim()),
      'budget_min': double.tryParse(_budgetMin.text.trim()),
      'budget_max': double.tryParse(_budgetMax.text.trim()),
      'preferred_categories': _propertyTypes.toList(),
      'preferred_cities': _locations.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      'preferred_amenities': _amenities.toList(),
      'distance_preference': _distance,
      'room_preference': _roomPreference,
      'move_in_preference': _moveInTiming,
      'opt_in_personalized': true,
    });

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Could not save profile.'
              : 'Profile updated successfully.',
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor:
            result == null ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── UI BUILDERS ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface, // Pure white background
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: widget.onBack,
          behavior: HitTestBehavior.opaque,
          child: const Icon(PhosphorIconsRegular.caretLeft,
              color: _dark, size: 28),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: _dark,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _tenantPrimary))
                  : Text(
                      'Save',
                      style: GoogleFonts.poppins(
                        color: _tenantPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _divider, height: 1.0),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _tenantPrimary))
          : Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 800), // Desktop responsive
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 48),
                    _buildSectionHeader('About you',
                        'Share a bit about yourself with potential hosts.'),
                    _field('Preferred Name', _preferredName,
                        hint: 'What should we call you?'),
                    _field('Bio', _bio,
                        maxLines: 4,
                        hint:
                            'I am a 3rd-year engineering student looking for a quiet place...'),
                    _buildMultiSelect(
                        'Languages you speak',
                        ['English', 'Swahili', 'French', 'Sign Language'],
                        _languages),
                    _buildSectionDivider(),
                    _buildSectionHeader('Education',
                        'Help landlords understand your student status.'),
                    _field('Institution', _institution,
                        hint: 'e.g. University of Nairobi'),
                    _field('Campus', _campus, hint: 'e.g. Main Campus'),
                    _field('Course of Study', _course,
                        hint: 'e.g. BSc. Computer Science'),
                    Row(
                      children: [
                        Expanded(
                            child: _field('Year of Study', _year,
                                keyboardType: TextInputType.number,
                                hint: 'e.g. 3')),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _field('Graduation Year', _graduation,
                                keyboardType: TextInputType.number,
                                hint: 'e.g. 2025')),
                      ],
                    ),
                    _buildSectionDivider(),
                    _buildSectionHeader('Housing Preferences',
                        'Tell us what you are looking for in your next stay.'),
                    _buildMultiSelect(
                        'Property Types', _propertyTypeOptions, _propertyTypes),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _field('Min Budget', _budgetMin,
                                keyboardType: TextInputType.number,
                                prefix: 'Ksh ')),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _field('Max Budget', _budgetMax,
                                keyboardType: TextInputType.number,
                                prefix: 'Ksh ')),
                      ],
                    ),
                    _field('Preferred Locations', _locations,
                        hint: 'e.g. Kisimani, Kilifi'),
                    _buildDropdown(
                        'Distance from campus',
                        _distance,
                        ['< 500 m', '< 1 km', '< 2 km', 'Anywhere'],
                        (value) => setState(() => _distance = value!)),
                    _buildDropdown(
                        'Room Setup',
                        _roomPreference,
                        ['Private room', 'Shared room', 'Either'],
                        (value) => setState(() => _roomPreference = value!)),
                    _buildDropdown(
                        'Looking to move',
                        _moveInTiming,
                        [
                          'Immediately',
                          'Within 1 month',
                          '1-3 months',
                          'Just browsing'
                        ],
                        (value) => setState(() => _moveInTiming = value!)),
                    const SizedBox(height: 8),
                    _buildMultiSelect(
                        'Must-have Amenities', _amenityOptions, _amenities),
                    _buildSectionDivider(),
                    _buildSectionHeader('Account & Security',
                        'Manage your verification and contact details.'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(PhosphorIconsRegular.shieldCheck,
                          color: _dark, size: 28),
                      title: Text(
                        'Contact & Verification',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: _dark,
                            fontSize: 16),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Email, phone, and identity verification are managed separately in your account settings.',
                          style: GoogleFonts.poppins(
                              color: _greyDark, fontSize: 14, height: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Divider(color: _divider, height: 1, thickness: 1),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _dark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: _greyDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Stack(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _divider, width: 1.5),
              ),
              child: ClipOval(
                child: AppSession.buildAvatar(
                  AppSession.displayAvatar,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _divider),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: const Icon(PhosphorIconsRegular.camera,
                    size: 16, color: _dark),
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _preferredName.text.isEmpty
                    ? AppSession.displayName
                    : _preferredName.text,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _institution.text.isEmpty ? 'Student' : _institution.text,
                style: GoogleFonts.poppins(color: _greyDark, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    AppSession.currentUserVerified
                        ? PhosphorIconsFill.sealCheck
                        : PhosphorIconsRegular.warningCircle,
                    color: AppSession.currentUserVerified
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppSession.currentUserVerified
                        ? 'Verified Account'
                        : 'Action Required',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppSession.currentUserVerified
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller,
      {int maxLines = 1,
      TextInputType? keyboardType,
      String? hint,
      String? prefix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: _dark),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(
                fontSize: 15, color: _dark, fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                  color: _grey, fontSize: 15, fontWeight: FontWeight.w400),
              prefixText: prefix,
              prefixStyle: GoogleFonts.poppins(
                  color: _dark, fontSize: 15, fontWeight: FontWeight.w500),
              filled: false,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _tenantPrimary, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelect(
      String label, List<String> options, Set<String> selected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: _dark),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              return GestureDetector(
                onTap: () => setState(() => isSelected
                    ? selected.remove(option)
                    : selected.add(option)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _tenantPrimary.withOpacity(0.08)
                        : _surface,
                    border: Border.all(
                      color: isSelected ? _tenantPrimary : _divider,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    option,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? _tenantPrimary : _dark,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: _dark),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: options.contains(value) ? value : options.first,
            icon: const Icon(PhosphorIconsRegular.caretDown,
                color: _grey, size: 20),
            style: GoogleFonts.poppins(
                fontSize: 15, color: _dark, fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              filled: false,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _tenantPrimary, width: 1.5)),
            ),
            items: options
                .map((option) =>
                    DropdownMenuItem(value: option, child: Text(option)))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
