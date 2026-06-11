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
  final _formKey = GlobalKey<FormState>();
  final _budgetMin = TextEditingController();
  final _budgetMax = TextEditingController();
  String _status = 'student';
  int _household = 1;
  bool _pets = false;
  final List<String> _preferredCategories = [];
  final _preferredCities = TextEditingController();
  bool _optIn = true;
  bool _consentGiven = false;
  bool _isSaving = false;

  final _repo = RemoteDatabaseRepository();

  final List<String> _categories = ['Apertments', 'Bedsitter', 'Single Room'];

  @override
  void dispose() {
    _budgetMin.dispose();
    _budgetMax.dispose();
    _preferredCities.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final profile = {
      'budget_min':
          _budgetMin.text.isNotEmpty ? num.tryParse(_budgetMin.text) : null,
      'budget_max':
          _budgetMax.text.isNotEmpty ? num.tryParse(_budgetMax.text) : null,
      'status': _status,
      'household_size': _household,
      'pets': _pets,
      'preferred_categories': _preferredCategories,
      'preferred_cities': _preferredCities.text.isNotEmpty
          ? _preferredCities.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
          : [],
      'opt_in_personalized': _optIn,
      'consent_given': _consentGiven,
      'consent_at': _consentGiven ? DateTime.now().toIso8601String() : null,
      'data_retention_days': 365,
    };

    if (_optIn && !_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Please provide consent to enable personalized recommendations.')));
      setState(() => _isSaving = false);
      return;
    }

    try {
      final res = await _repo.saveTenantProfile(profile);
      if (res != null) {
        // Fetch the fresh, full user object to ensure we have the correct 
        // verification status before checking it for navigation.
        final fullUser = await _repo.loadCurrentUser();
        AppSession.updateCurrentUser(fullUser);
        
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Preferences saved.')));
      }
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save preferences.')));
    }

    setState(() => _isSaving = false);
    // Only show OTP screen for unverified users (registrations).
    if (AppSession.currentUserVerified == true) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/otp');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tell us a bit about you')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Budget (KES)',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _budgetMin,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Min'))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextFormField(
                        controller: _budgetMax,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Max'))),
              ]),
              const SizedBox(height: 16),
              Text('Status',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                  initialValue: _status,
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(
                        value: 'employed', child: Text('Employed')),
                    DropdownMenuItem(
                        value: 'self-employed', child: Text('Self-employed')),
                    DropdownMenuItem(
                        value: 'unemployed', child: Text('Unemployed')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'student')),
              const SizedBox(height: 16),
              Text('Household size',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                IconButton(
                    onPressed: () => setState(
                        () => _household = (_household - 1).clamp(1, 99)),
                    icon: const Icon(Icons.remove)),
                Text('$_household', style: GoogleFonts.poppins(fontSize: 16)),
                IconButton(
                    onPressed: () => setState(
                        () => _household = (_household + 1).clamp(1, 99)),
                    icon: const Icon(Icons.add)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                const Text('Pets'),
                const SizedBox(width: 12),
                Switch(
                    value: _pets, onChanged: (v) => setState(() => _pets = v)),
              ]),
              const SizedBox(height: 16),
              Text('Preferred categories',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Wrap(
                  spacing: 8,
                  children: _categories.map((c) {
                    final active = _preferredCategories.contains(c);
                    return ChoiceChip(
                        label: Text(c),
                        selected: active,
                        onSelected: (s) => setState(() {
                              if (s) {
                                _preferredCategories.add(c);
                              } else {
                                _preferredCategories.remove(c);
                              }
                            }));
                  }).toList()),
              const SizedBox(height: 16),
              Text('Preferred cities (comma separated)',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _preferredCities,
                  decoration: const InputDecoration(
                      hintText: 'e.g., Nairobi, Mombasa')),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Personalized recommendations',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Switch(
                    value: _optIn,
                    onChanged: (v) => setState(() => _optIn = v)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Checkbox(
                    value: _consentGiven,
                    onChanged: (v) =>
                        setState(() => _consentGiven = v ?? false)),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/privacy'),
                    child: Text(
                      'I have read and agree to the Privacy & Data Retention Policy',
                      style: GoogleFonts.poppins(
                          fontSize: 13, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const CircularProgressIndicator()
                          : const Text('Save & Continue'))),
            ],
          ),
        ),
      ),
    );
  }
}
