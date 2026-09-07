// START OF FILE
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';

class TenantSurveyView extends StatefulWidget {
  const TenantSurveyView({super.key});

  @override
  State<TenantSurveyView> createState() => _TenantSurveyViewState();
}

class _TenantSurveyViewState extends State<TenantSurveyView> {
  // Theme Colors
  static const Color _primary = Color(0xFF3F37C9); // Tenant Blue
  static const Color _dark = Color(0xFF111827);
  static const Color _grey = Color(0xFF9CA3AF);
  static const Color _lightGrey = Color(0xFFF3F4F6);

  // Selection States
  String? _selectedStatus;
  String? _selectedHousehold;
  String? _selectedPets;
  String? _selectedBudgetTier;
  final List<String> _preferredCategories = [];
  final List<String> _preferredCities = [];

  bool _consentGiven = false;
  bool _isSaving = false;
  bool _hasError = false;

  final _repo = RemoteDatabaseRepository();

  // Datasets for Pills
  final List<String> _statusOptions = ['Student', 'Employed', 'Self-employed', 'Unemployed'];
  final List<String> _householdOptions = ['1', '2', '3', '4', '5+'];
  final List<String> _petOptions = ['Yes', 'No'];
  
  final List<String> _categories = ['Apartment', 'Bedsitter', 'Single Room', 'Studio', 'Villa'];
  final List<String> _availableCities = ['Kilifi', 'Mombasa', 'Nairobi', 'Nakuru', 'Kwale'];
  final List<Map<String, String>> _budgetTiers = [
    {'id': 'budget', 'label': 'Budget (< 10k)'},
    {'id': 'mid', 'label': 'Mid-Tier (10k - 25k)'},
    {'id': 'premium', 'label': 'Premium (25k+)'},
  ];

  // Validation Check for button activation
  bool get _isFormValid {
    return _selectedBudgetTier != null &&
           _preferredCategories.isNotEmpty &&
           _preferredCities.isNotEmpty &&
           _consentGiven;
  }

  Future<void> _submit() async {
    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select your budget, property types, cities, and accept the privacy policy.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    _hasError = false;

    int householdSize = int.tryParse((_selectedHousehold ?? '1').replaceAll('+', '')) ?? 1;

    int? budgetMin;
    int? budgetMax;
    if (_selectedBudgetTier == 'budget') {
      budgetMax = 10000;
    } else if (_selectedBudgetTier == 'mid') {
      budgetMin = 10000;
      budgetMax = 25000;
    } else if (_selectedBudgetTier == 'premium') {
      budgetMin = 25000;
    }

    final profile = {
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'status': (_selectedStatus ?? 'student').toLowerCase(),
      'household_size': householdSize,
      'pets': _selectedPets == 'Yes',
      'preferred_categories': _preferredCategories,
      'preferred_cities': _preferredCities,
      'opt_in_personalized': true,
      'consent_given': _consentGiven,
      'consent_at': _consentGiven ? DateTime.now().toIso8601String() : null,
      'data_retention_days': 365,
    };

    try {
      final res = await _repo.saveTenantProfile(profile);
      if (res != null) {
        try {
          // Attempt to sync the updated user profile
          final fullUser = await _repo.loadCurrentUser();
          AppSession.updateCurrentUser(fullUser);
        } catch (e) {
          debugPrint('TenantSurveyView: Failed to sync user data: $e');
        }

        if (!mounted) return;
        setState(() => _isSaving = false);

        if (AppSession.currentUserVerified == true) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/otp');
        }
      } else {
        throw Exception('Failed to save profile');
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences. Please try again.',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ─── Main Scrollable Content ───
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 180), // Massive bottom padding to clear the floating footer
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Big Header
                  Text(
                    'Customize your stay',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: _dark,
                      letterSpacing: -1.0,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select your preferences below to get better property recommendations tailored just for you.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: _grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ─── Sections ───
                  _buildSection(
                    title: 'Monthly Rent Budget',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.start,
                      children: _budgetTiers.map((tier) {
                        final active = _selectedBudgetTier == tier['id'];
                        return _TikTokPill(
                          label: tier['label']!,
                          isActive: active,
                          onTap: () => setState(() => _selectedBudgetTier = tier['id']),
                        );
                      }).toList(),
                    ),
                  ),

                  _buildSection(
                    title: 'Preferred Property Types',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _categories.map((c) {
                        final active = _preferredCategories.contains(c);
                        return _TikTokPill(
                          label: c,
                          isActive: active,
                          onTap: () {
                            setState(() {
                              active ? _preferredCategories.remove(c) : _preferredCategories.add(c);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  _buildSection(
                    title: 'Target Locations',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _availableCities.map((city) {
                        final active = _preferredCities.contains(city);
                        return _TikTokPill(
                          label: city,
                          isActive: active,
                          onTap: () {
                            setState(() {
                              active ? _preferredCities.remove(city) : _preferredCities.add(city);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  _buildSection(
                    title: 'Your Status',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _statusOptions.map((status) {
                        final active = _selectedStatus == status;
                        return _TikTokPill(
                          label: status,
                          isActive: active,
                          onTap: () => setState(() => _selectedStatus = status),
                        );
                      }).toList(),
                    ),
                  ),

                  _buildSection(
                    title: 'Household Size',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _householdOptions.map((size) {
                        final active = _selectedHousehold == size;
                        return _TikTokPill(
                          label: size == '1' ? '1 Person' : '$size People',
                          isActive: active,
                          onTap: () => setState(() => _selectedHousehold = size),
                        );
                      }).toList(),
                    ),
                  ),

                  _buildSection(
                    title: 'Do you have pets?',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _petOptions.map((option) {
                        final active = _selectedPets == option;
                        return _TikTokPill(
                          label: option,
                          isActive: active,
                          onTap: () => setState(() => _selectedPets = option),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Floating Footer with Gradient Fade ───
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 32, 24, MediaQuery.of(context).padding.bottom + 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.9),
                    Colors.white,
                    Colors.white,
                  ],
                  stops: const [0.0, 0.2, 0.5, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Privacy Checkbox
                  GestureDetector(
                    onTap: () => setState(() => _consentGiven = !_consentGiven),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _consentGiven ? _primary : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _consentGiven ? _primary : _grey.withOpacity(0.5), width: 2),
                          ),
                          child: _consentGiven ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'I have read and agree to the Privacy Policy.',
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _dark),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/privacy'),
                                child: Text(
                                  'Read Policy',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: _primary, decoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Smart Action Button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _isFormValid ? _primary : _lightGrey,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _isFormValid
                          ? [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]
                          : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isFormValid && !_isSaving ? _submit : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: _isSaving
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text(
                                  _hasError ? 'Try Again' : 'Explore Stays',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _isFormValid ? Colors.white : _grey,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Playful Bouncy Sparkle Pill ──────────────────────────────────────────────

class _TikTokPill extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TikTokPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_TikTokPill> createState() => _TikTokPillState();
}

class _TikTokPillState extends State<_TikTokPill> with TickerProviderStateMixin {
  // 1. Controller for the tap down press effect
  late final AnimationController _tapController;
  late final Animation<double> _tapScale;

  // 2. Controller for the glorious bouncy selection & sparkle
  late final AnimationController _selectController;
  late final Animation<double> _bounceScale;
  late final Animation<double> _sparkleScale;
  late final Animation<double> _sparkleRotate;

  @override
  void initState() {
    super.initState();
    
    // Tap Down Animation
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _tapScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );

    // Bouncy Selection Animation
    _selectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Sequence: Shrink quickly -> Pop out big -> Settle elastically
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.90).chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.15).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
    ]).animate(_selectController);

    // Sparkle Icon Animation
    _sparkleScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
    ]).animate(_selectController);

    // A little spin to the sparkle
    _sparkleRotate = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(parent: _selectController, curve: Curves.easeOutCubic),
    );

    if (widget.isActive) {
      _selectController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_TikTokPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _selectController.forward(from: 0.0);
    } else if (!widget.isActive && oldWidget.isActive) {
      _selectController.reverse();
    }
  }

  @override
  void dispose() {
    _tapController.dispose();
    _selectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _tapController.forward(),
      onTapUp: (_) {
        _tapController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _tapController.reverse(),
      child: ScaleTransition(
        scale: _tapScale, // Tap depression
        child: ScaleTransition(
          scale: _bounceScale, // Magic Bounce
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: widget.isActive ? const Color(0xFF3F37C9) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isActive ? const Color(0xFF3F37C9) : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: widget.isActive
                  ? [BoxShadow(color: const Color(0xFF3F37C9).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w600,
                    color: widget.isActive ? Colors.white : const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}