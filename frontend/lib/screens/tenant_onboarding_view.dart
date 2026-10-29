import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'package:property_app/services/user_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/utils/geocoding.dart';

class TenantOnboardingView extends StatefulWidget {
  const TenantOnboardingView({super.key});

  @override
  State<TenantOnboardingView> createState() => _TenantOnboardingViewState();
}

class _TenantOnboardingViewState extends State<TenantOnboardingView> {
  static const _green = Color(0xFF167447);
  static const _ink = Color(0xFF17312A);
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
      final missingPreferences =
          preferences is Map && preferences['missingFields'] is List
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
      for (final field in const [
        'preferredLocation',
        'budgetRange',
        'propertyType',
      ]) {
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
      ? value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList()
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
          setState(
              () => _errorMessage = 'Enter your name to save this detail.');
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
        if (minimum == null ||
            maximum == null ||
            minimum < 0 ||
            maximum <= 0 ||
            maximum < minimum) {
          setState(() => _errorMessage = 'Enter a valid minimum and maximum.');
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
        return _savePreferences(
            {'preferred_categories': _propertyTypes.toList()});
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
      setState(
          () => _errorMessage ??= 'Could not save this detail. Try again.');
      return;
    }
    _completedFields.add(_currentStep);
    unawaited(AnalyticsService.logEvent('profile_field_completed', {
      'field': _currentStep,
    }));
    _advance();
  }

  void _skip() {
    setState(() => _errorMessage = null);
    unawaited(AnalyticsService.logEvent('preference_step_skipped', {
      'field': _currentStep,
    }));
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
        'preferredLocation' =>
          'Choose an area so nearby homes are easier to find.',
        'budgetRange' =>
          'Set a range to focus on homes within your price range.',
        'propertyType' =>
          'Choose home types to bring the most relevant listings forward.',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final total = _steps.length;
    final progress = _success || total == 0 ? 1.0 : _stepIndex / total;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F8F3),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (!_success && _stepIndex > 0) {
              setState(() => _stepIndex--);
            } else {
              Navigator.maybePop(context);
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _green))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E9E1)),
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
        Text('LET’S GET STARTED',
            style: GoogleFonts.poppins(
                color: _green, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Let’s find a place that fits you.',
            style: GoogleFonts.poppins(
                color: _ink, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(_benefitFor(step),
            style: GoogleFonts.poppins(
                color: const Color(0xFF5E6E65), fontSize: 14, height: 1.5)),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            color: _green,
            backgroundColor: const Color(0xFFE4ECE5),
          ),
        ),
        const SizedBox(height: 7),
        Text('Step ${_stepIndex + 1} of $total',
            style: GoogleFonts.poppins(
                color: const Color(0xFF69786F), fontSize: 12)),
        const SizedBox(height: 22),
        Text(_titleFor(step),
            style: GoogleFonts.poppins(
                color: _ink, fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        _buildStepInput(step),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(_errorMessage!,
              style: GoogleFonts.poppins(
                  color: const Color(0xFFB42318), fontSize: 13)),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _continue,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save and continue'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
                onPressed: _saving ? null : _skip,
                child: const Text('Skip for now')),
          ],
        ),
      ],
    );
  }

  Widget _buildStepInput(String step) {
    if (step == 'name') {
      return TextField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        maxLength: 120,
        decoration: const InputDecoration(
          labelText: 'Full name',
          border: OutlineInputBorder(),
        ),
      );
    }
    if (step == 'preferredLocation') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _locationController,
            onChanged: _searchLocations,
            decoration: const InputDecoration(
              labelText: 'Search for a town or area',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          if (_locationSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E9E1)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _locationSuggestions.take(5).map((suggestion) {
                  return ListTile(
                    dense: true,
                    leading:
                        const Icon(Icons.location_on_outlined, color: _green),
                    title: Text(suggestion.displayName, maxLines: 2),
                    onTap: () => _addLocation(suggestion),
                  );
                }).toList(),
              ),
            ),
          if (_locations.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _locations
                  .map((location) => InputChip(
                        label: Text(location),
                        onDeleted: () =>
                            setState(() => _locations.remove(location)),
                      ))
                  .toList(),
            ),
          ],
          if (_locationController.text.trim().length >= 3 &&
              _locationSuggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No areas found. Check your connection or try another search.',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF69786F), fontSize: 12),
              ),
            ),
        ],
      );
    }
    if (step == 'budgetRange') {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _minimumController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Minimum (KSh / month)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _maximumController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Maximum (KSh / month)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _types.map((type) {
        final selected = _propertyTypes.contains(type);
        return FilterChip(
          label: Text(type),
          selected: selected,
          onSelected: (value) => setState(() {
            value ? _propertyTypes.add(type) : _propertyTypes.remove(type);
          }),
          selectedColor: const Color(0xFFDCEFE2),
          checkmarkColor: _green,
        );
      }).toList(),
    );
  }

  Widget _buildSuccess() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: _green, size: 38),
          const SizedBox(height: 16),
          Text("You're all set!",
              style: GoogleFonts.poppins(
                  color: _ink, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            _completedFields.isEmpty
                ? 'You can add housing preferences anytime from your profile.'
                : 'Your details are saved. You can update preferences anytime from your profile.',
            style: GoogleFonts.poppins(
                color: const Color(0xFF5E6E65), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.maybePop(context),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Back to browsing'),
            ),
          ),
        ],
      );

  Widget _buildLoadError() => Column(
        children: [
          const Icon(Icons.wifi_off, color: Color(0xFF69786F), size: 36),
          const SizedBox(height: 12),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _errorMessage = null;
              });
              unawaited(_load());
            },
            child: const Text('Try again'),
          ),
        ],
      );
}
