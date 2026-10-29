import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'package:property_app/services/user_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/utils/geocoding.dart';

// ─── Tenant Design System Constants ───────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _tenantPrimary = Color(0xFF3F37C9); // Tenant Blue Theme

class TenantOnboardingView extends StatefulWidget {
  const TenantOnboardingView({super.key});

  @override
  State<TenantOnboardingView> createState() => _TenantOnboardingViewState();
}

class _TenantOnboardingViewState extends State<TenantOnboardingView> {
  static const _types = [
    'Bedsitter',
    'Single room',
    'One bedroom',
    'Shared room',
    'Hostel',
    'Studio',
  ];

  final _repository = RemoteDatabaseRepository();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _minimumController = TextEditingController();
  final _maximumController = TextEditingController();
  final Set<String> _locations = {};
  final Set<String> _propertyTypes = {};
  final List<String> _steps = [];
  final Set<String> _completedFields = {};

  Timer? _locationTimer;
  List<GeocodingSuggestion> _locationSuggestions = [];
  bool _loading = true;
  bool _saving = false;
  bool _success = false;
  String? _errorMessage;
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _nameController.dispose();
    _locationController.dispose();
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _repository.fetchProfileCompletion(),
        _repository.fetchTenantProfileMe(),
      ]);
      final completion = values[0] as Map<String, dynamic>?;
      final profile = values[1] as Map<String, dynamic>?;
      
      final personal = completion?['profile'];
      final preferences = completion?['preferences'];
      final missingPersonal = personal is Map &&
          personal['missingFields'] is List &&
          (personal['missingFields'] as List).contains('name');
      final missingPreferences = preferences is Map && preferences['missingFields'] is List
              ? (preferences['missingFields'] as List).cast<String>()
              : <String>[];
              
      if (personal is Map && (personal['completedFields'] as num? ?? 0) > 0) {
        _completedFields.add('name');
      }
      
      _completedFields.addAll(
        const ['preferredLocation', 'budgetRange', 'propertyType']
            .where((field) => !missingPreferences.contains(field)),
      );

      if (missingPersonal) {
        _steps.add('name');
        _nameController.text = AppSession.currentUserName ?? '';
      }
      
      for (final field in const ['preferredLocation', 'budgetRange', 'propertyType']) {
        if (missingPreferences.contains(field)) _steps.add(field);
      }
      
      if (profile != null) {
        _locations.addAll(_stringList(profile['preferred_cities']));
        _propertyTypes.addAll(_stringList(profile['preferred_categories']));
        _minimumController.text = profile['budget_min']?.toString() ?? '';
        _maximumController.text = profile['budget_max']?.toString() ?? '';
      }
      _success = _steps.isEmpty;
    } catch (_) {
      _errorMessage = 'Could not load your saved preferences. Try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<String> _stringList(dynamic value) => value is List
      ? value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList()
      : const [];

  String get _currentStep => _steps[_stepIndex];

  void _searchLocations(String value) {
    _locationTimer?.cancel();
    if (value.trim().length < 3) {
      setState(() => _locationSuggestions = []);
      return;
    }
    _locationTimer = Timer(const Duration(milliseconds: 350), () async {
      final suggestions = await searchAddressSuggestions(value.trim());
      if (!mounted) return;
      setState(() => _locationSuggestions = suggestions);
    });
  }

  void _addLocation(GeocodingSuggestion suggestion) {
    final area = suggestion.town ??
        suggestion.neighborhood ??
        suggestion.county ??
        suggestion.displayName.split(',').first.trim();
    if (area.trim().isEmpty) return;
    setState(() {
      _locations.add(area.trim());
      _locationController.clear();
      _locationSuggestions = [];
      _errorMessage = null;
    });
  }

  Future<bool> _saveCurrentStep() async {
    switch (_currentStep) {
      case 'name':
        final name = _nameController.text.trim();
        if (name.isEmpty || name.length > 120) {
          setState(() => _errorMessage = 'Enter your name to save this detail.');
          return false;
        }
        final saved = await UserService.updateProfile({'name': name});
        if (saved) AppSession.currentUserName = name;
        return saved;
      case 'preferredLocation':
        if (_locations.isEmpty) {
          setState(() => _errorMessage = 'Choose at least one suggested area.');
          return false;
        }
        return _savePreferences({'preferred_cities': _locations.toList()});
      case 'budgetRange':
        final minimum = double.tryParse(_minimumController.text.trim());
        final maximum = double.tryParse(_maximumController.text.trim());
        if (minimum == null || maximum == null || minimum < 0 || maximum <= 0 || maximum < minimum) {
          setState(() => _errorMessage = 'Enter a valid minimum and maximum budget.');
          return false;
        }
        return _savePreferences({
          'budget_min': minimum,
          'budget_max': maximum,
        });
      case 'propertyType':
        if (_propertyTypes.isEmpty) {
          setState(() => _errorMessage = 'Choose at least one home type.');
          return false;
        }
        return _savePreferences({'preferred_categories': _propertyTypes.toList()});
      default:
        return false;
    }
  }

  Future<bool> _savePreferences(Map<String, dynamic> values) async {
    final result = await _repository.saveTenantProfile({
      ...values,
      'opt_in_personalized': true,
      'consent_given': true,
      'consent_at': DateTime.now().toUtc().toIso8601String(),
    });
    return result != null;
  }

  Future<void> _continue() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    bool saved;
    try {
      saved = await _saveCurrentStep();
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      setState(() => _errorMessage ??= 'Could not save this detail. Try again.');
      return;
    }
    _completedFields.add(_currentStep);
    unawaited(AnalyticsService.logEvent('profile_field_completed', {'field': _currentStep}));
    _advance();
  }

  void _skip() {
    setState(() => _errorMessage = null);
    unawaited(AnalyticsService.logEvent('preference_step_skipped', {'field': _currentStep}));
    _advance();
  }

  void _advance() {
    setState(() {
      if (_stepIndex + 1 >= _steps.length) {
        _success = true;
        if (_completedFields.isNotEmpty) {
          unawaited(AnalyticsService.logEvent('profile_completion_finished'));
        }
      } else {
        _stepIndex++;
      }
    });
  }

  String _titleFor(String step) => switch (step) {
        'name' => 'What should we call you?',
        'preferredLocation' => 'Where would you like to live?',
        'budgetRange' => 'What fits your monthly budget?',
        'propertyType' => 'What kind of place are you looking for?',
        _ => 'Your preferences',
      };

  String _benefitFor(String step) => switch (step) {
        'name' => 'Your name makes your account feel more personal.',
        'preferredLocation' => 'Choose an area so nearby homes are easier to find.',
        'budgetRange' => 'Set a range to focus on homes within your price range.',
        'propertyType' => 'Choose home types to bring the most relevant listings forward.',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final total = _steps.length;
    final progress = _success || total == 0 ? 1.0 : _stepIndex / total;
    
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (!_success && _stepIndex > 0) {
              setState(() => _stepIndex--);
            } else {
              Navigator.maybePop(context);
            }
          },
          icon: const Icon(PhosphorIconsRegular.caretLeft, color: _dark, size: 28),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _tenantPrimary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: _errorMessage != null && _steps.isEmpty && !_success
                        ? _buildLoadError()
                        : _success
                            ? _buildSuccess()
                            : _buildStep(progress, total),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStep(double progress, int total) {
    final step = _currentStep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LET’S GET STARTED',
          style: GoogleFonts.poppins(color: _tenantPrimary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)
        ),
        const SizedBox(height: 8),
        Text(
          'Let’s find a place that fits you.',
          style: GoogleFonts.poppins(color: _dark, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5)
        ),
        const SizedBox(height: 12),
        Text(
          _benefitFor(step),
          style: GoogleFonts.poppins(color: _grey, fontSize: 15, height: 1.5)
        ),
        const SizedBox(height: 32),
        
        // Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: _tenantPrimary,
            backgroundColor: _grey.withOpacity(0.15),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Step ${_stepIndex + 1} of $total',
          style: GoogleFonts.poppins(color: _grey, fontSize: 13, fontWeight: FontWeight.w500)
        ),
        
        const SizedBox(height: 40),
        
        Text(
          _titleFor(step),
          style: GoogleFonts.poppins(color: _dark, fontSize: 18, fontWeight: FontWeight.w600)
        ),
        const SizedBox(height: 24),
        
        _buildStepInput(step),
        
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(PhosphorIconsRegular.warningCircle, color: Color(0xFFEF4444), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_errorMessage!, style: GoogleFonts.poppins(color: const Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w500))),
            ],
          ),
        ],
        
        const SizedBox(height: 48),
        
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tenantPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)), // Pill shape
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text('Save and continue', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _saving ? null : _skip,
              child: Text('Skip for now', style: GoogleFonts.poppins(color: _grey, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepInput(String step) {
    if (step == 'name') {
      return TextFormField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        maxLength: 120,
        style: GoogleFonts.poppins(fontSize: 15, color: _dark, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Enter your full name',
          hintStyle: GoogleFonts.poppins(color: _grey, fontSize: 15),
          filled: true,
          fillColor: _bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _tenantPrimary, width: 1.5)),
        ),
      );
    }
    if (step == 'preferredLocation') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _locationController,
            onChanged: _searchLocations,
            style: GoogleFonts.poppins(fontSize: 15, color: _dark, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Search for a town or area',
              hintStyle: GoogleFonts.poppins(color: _grey, fontSize: 15),
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: _grey),
              filled: true,
              fillColor: _bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _tenantPrimary, width: 1.5)),
            ),
          ),
          if (_locationSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _grey.withOpacity(0.2)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _locationSuggestions.take(5).length,
                separatorBuilder: (_, __) => Divider(height: 1, color: _grey.withOpacity(0.1)),
                itemBuilder: (context, index) {
                  final suggestion = _locationSuggestions[index];
                  return ListTile(
                    leading: const Icon(PhosphorIconsRegular.mapPin, color: _tenantPrimary, size: 20),
                    title: Text(suggestion.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 14, color: _dark)),
                    onTap: () => _addLocation(suggestion),
                  );
                },
              ),
            ),
          if (_locations.isNotEmpty) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _locations.map((location) => Container(
                padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: _tenantPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _tenantPrimary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(location, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _tenantPrimary)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _locations.remove(location)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: _tenantPrimary.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(PhosphorIconsRegular.x, size: 12, color: _tenantPrimary),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ],
          if (_locationController.text.trim().length >= 3 && _locationSuggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'No areas found. Check your connection or try another search.',
                style: GoogleFonts.poppins(color: _grey, fontSize: 13),
              ),
            ),
        ],
      );
    }
    if (step == 'budgetRange') {
      return Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _minimumController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(fontSize: 15, color: _dark, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Minimum (KSh / mo)',
                labelStyle: GoogleFonts.poppins(color: _grey, fontSize: 13),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _tenantPrimary, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _maximumController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(fontSize: 15, color: _dark, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Maximum (KSh / mo)',
                labelStyle: GoogleFonts.poppins(color: _grey, fontSize: 13),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _grey.withOpacity(0.2))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _tenantPrimary, width: 1.5)),
              ),
            ),
          ),
        ],
      );
    }
    
    // Property Type
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _types.map((type) {
        final isSelected = _propertyTypes.contains(type);
        return GestureDetector(
          onTap: () {
            setState(() {
              isSelected ? _propertyTypes.remove(type) : _propertyTypes.add(type);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? _tenantPrimary.withOpacity(0.08) : _surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? _tenantPrimary : _grey.withOpacity(0.2),
                width: isSelected ? 2.0 : 1.5,
              ),
            ),
            child: Text(
              type,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? _tenantPrimary : _dark,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSuccess() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(PhosphorIconsFill.checkCircle, color: Color(0xFF10B981), size: 64),
          ),
          const SizedBox(height: 32),
          Text(
            "You're all set!",
            style: GoogleFonts.poppins(color: _dark, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5)
          ),
          const SizedBox(height: 12),
          Text(
            _completedFields.isEmpty
                ? 'You can add housing preferences anytime from your profile.'
                : 'Your details are saved. You can update preferences anytime from your profile.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: _grey, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.maybePop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _tenantPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                elevation: 0,
              ),
              child: Text('Back to browsing', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );

  Widget _buildLoadError() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), shape: BoxShape.circle),
            child: const Icon(PhosphorIconsRegular.wifiSlash, color: Color(0xFFEF4444), size: 48),
          ),
          const SizedBox(height: 24),
          Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: _dark)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _errorMessage = null;
                });
                unawaited(_load());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _dark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                elevation: 0,
              ),
              child: Text('Try again', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
}