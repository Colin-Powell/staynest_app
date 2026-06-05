import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Your project imports
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/services/uploads.dart';

class AddListingFlow extends StatefulWidget {
  const AddListingFlow({super.key});

  @override
  State<AddListingFlow> createState() => _AddListingFlowState();
}

class _AddListingFlowState extends State<AddListingFlow> {
  bool _loadingDraft = true;
  bool _submitting = false;

  final PageController _pageController = PageController();
  int _currentStep = 1;
  final int _totalSteps = 6;

  // Form Keys
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step5Key = GlobalKey<FormState>(); // Pricing Key

  // --- Step 1: Basic Info ---
  String _propertyType = 'Apartment';
  final _title = TextEditingController();
  final _description = TextEditingController();
  int _bedrooms = 1;
  int _bathrooms = 1;

  // --- Step 2: Location ---
  String? _selectedCountry = 'Kenya';
  String? _selectedCity = 'Nairobi';
  final _neighborhood = TextEditingController();
  final _street = TextEditingController();
  final _building = TextEditingController();
  final _zip = TextEditingController();

  final List<String> _countries = [
    'Kenya',
    'Uganda',
    'Tanzania',
    'Rwanda',
    'South Africa'
  ];
  final Map<String, List<String>> _citiesByCountry = {
    'Kenya': ['Nairobi', 'Mombasa', 'Kilifi', 'Nakuru', 'Kisumu', 'Eldoret'],
    'Uganda': ['Kampala', 'Entebbe', 'Jinja', 'Mbarara'],
    'Tanzania': ['Dar es Salaam', 'Dodoma', 'Arusha', 'Zanzibar City'],
    'Rwanda': ['Kigali', 'Musanze', 'Gisenyi'],
    'South Africa': ['Cape Town', 'Johannesburg', 'Durban', 'Pretoria'],
  };

  // --- Step 3: Amenities ---
  final Map<String, bool> _amenities = {};

  final Map<String, IconData> _essentialAmenities = {
    'Wifi': PhosphorIcons.wifiHigh(),
    'Water included': PhosphorIcons.drop(),
    'Electricity included': PhosphorIcons.lightning(),
    'Heating': PhosphorIcons.thermometer(),
    'Air Conditioning': PhosphorIcons.wind(),
    'Hot Water': PhosphorIcons.bathtub(),
  };

  final Map<String, IconData> _additionalAmenities = {
    'Parking': PhosphorIcons.carProfile(),
    'Security': PhosphorIcons.shieldCheck(),
    'CCTV': PhosphorIcons.securityCamera(),
    'Furnished': PhosphorIcons.armchair(),
    'Gym': PhosphorIcons.barbell(),
    'Swimming Pool': PhosphorIcons.swimmingPool(),
    'Elevator': PhosphorIcons.elevator(),
    'Wheelchair Accessible': PhosphorIcons.wheelchair(),
    'Pet Friendly': PhosphorIcons.pawPrint(),
    'Balcony / Patio': PhosphorIcons.treePalm(),
    'Garden': PhosphorIcons.plant(),
    'Backup Generator': PhosphorIcons.batteryCharging(),
    'Laundry / Washer': PhosphorIcons.washingMachine(),
    'Dishwasher': PhosphorIcons.archive(),
  };

  // --- Step 4: Photos ---
  final List<File> _photos = [];

  // --- Step 5: Pricing and Details ---
  final _rentPrice = TextEditingController();
  final _serviceCharges = TextEditingController();
  final _securityDeposit = TextEditingController();
  String _minimumStay = '6 Months';
  DateTime? _availableFrom;

  static const _draftKey = 'listing_draft';

  @override
  void initState() {
    super.initState();
    for (var key in [
      ..._essentialAmenities.keys,
      ..._additionalAmenities.keys
    ]) {
      _amenities[key] = false;
    }
    _loadDraft();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _title.dispose();
    _description.dispose();
    _neighborhood.dispose();
    _street.dispose();
    _building.dispose();
    _zip.dispose();
    _rentPrice.dispose();
    _serviceCharges.dispose();
    _securityDeposit.dispose();
    super.dispose();
  }

  // ==========================================
  // DRAFT & SUBMISSION LOGIC
  // ==========================================
  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _propertyType = data['type'] ?? 'Apartment';
        _title.text = data['title'] ?? '';
        _description.text = data['description'] ?? '';
        _bedrooms = data['bedrooms'] ?? 1;
        _bathrooms = data['bathrooms'] ?? 1;

        if (_countries.contains(data['country'])) {
          _selectedCountry = data['country'];
        }
        if (_citiesByCountry[_selectedCountry]?.contains(data['city']) ??
            false) {
          _selectedCity = data['city'];
        }

        _neighborhood.text = data['neighborhood'] ?? '';
        _street.text = data['street'] ?? '';
        _building.text = data['building'] ?? '';

        _rentPrice.text = data['rentPrice'] ?? '';
        _serviceCharges.text = data['serviceCharges'] ?? '';
        _securityDeposit.text = data['securityDeposit'] ?? '';
        _minimumStay = data['minimumStay'] ?? '6 Months';
        if (data['availableFrom'] != null) {
          _availableFrom = DateTime.tryParse(data['availableFrom']);
        }

        final savedAmenities =
            Map<String, dynamic>.from(data['amenities'] ?? {});
        for (final key in _amenities.keys) {
          if (savedAmenities.containsKey(key)) {
            _amenities[key] = savedAmenities[key] == true;
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _loadingDraft = false);
  }

  Future<void> _saveDraft({bool showConfirmation = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _draftKey,
        jsonEncode({
          'type': _propertyType,
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'bedrooms': _bedrooms,
          'bathrooms': _bathrooms,
          'country': _selectedCountry,
          'city': _selectedCity,
          'neighborhood': _neighborhood.text.trim(),
          'street': _street.text.trim(),
          'building': _building.text.trim(),
          'rentPrice': _rentPrice.text.trim(),
          'serviceCharges': _serviceCharges.text.trim(),
          'securityDeposit': _securityDeposit.text.trim(),
          'minimumStay': _minimumStay,
          'availableFrom': _availableFrom?.toIso8601String(),
          'amenities': _amenities,
        }));
    if (mounted && showConfirmation) {
      ModalUtils.showSuccess(context, "Draft Saved!",
          "Your progress has been safely tucked away. You can resume anytime.");
    }
  }

  Future<void> _publishListing() async {
    if (AppSession.currentUserVerified != true) {
      await _saveDraft(showConfirmation: false);
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.white,
          shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.dialogBorderRadius),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.lockKey(PhosphorIconsStyle.fill),
                  color: StayNestColors.warning, size: 64),
              const SizedBox(height: 16),
              Text('Verification Required',
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray900)),
              const SizedBox(height: 8),
              Text(
                  'To keep our community safe, we require all landlords to be verified before their listings go live. We\'ve saved your draft!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: AppColors.gray500, height: 1.5)),
              const SizedBox(height: 24),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Edit Draft',
                    style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonBorderRadius)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/verification_center');
              },
              child: Text('Verify Now',
                  style: GoogleFonts.poppins(
                      color: AppColors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      return;
    }

    if (_photos.isEmpty) {
      ModalUtils.showError(context, "Photos Required",
          "Please add at least one photo of your amazing property.");
      return;
    }

    setState(() => _submitting = true);
    try {
      // 1) Upload photos to get public URLs
      final uploadedUrls = <String>[];
      for (final photo in _photos) {
        final url = await UploadsService.uploadFile(photo);

        uploadedUrls.add(url);
      }
      if (uploadedUrls.isEmpty) {
        throw Exception('No photos uploaded');
      }

      // 2) Create the property immediately so it appears in landlord listings
      final repo = RemoteDatabaseRepository();
      final propertyPayload = {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        // backend stores category in `properties.category`.
        'category': _propertyType,
        'city': _selectedCity,
        // backend requires price, bedrooms, bathrooms, area
        'price': _rentPrice.text.trim(),
        'bedrooms': _bedrooms,
        'bathrooms': _bathrooms,
        // UI does not capture area; use 1 as a safe default.
        'area': 1,
        'image_url': uploadedUrls.first,
        'lat': null,
        'lng': null,
      };

      await repo.createPropertyFromListing(propertyPayload);

      // 3) Also submit verification record (used by admin flow)
      final propertyVerificationPayload = {
        ...propertyPayload,
        'service_charges': _serviceCharges.text.trim(),
        'security_deposit': _securityDeposit.text.trim(),
        'minimum_stay': _minimumStay,
        'available_from': _availableFrom?.toIso8601String(),
        'amenities':
            _amenities.entries.where((e) => e.value).map((e) => e.key).toList(),
        'location': '${_neighborhood.text}, $_selectedCity',
        'type': _propertyType,
        'photos': uploadedUrls,
      };

      final documents = {'photos': uploadedUrls};
      final resp =
          await repo.submitVerification(documents, propertyVerificationPayload);
      if (resp == null) throw Exception('Server returned null');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);

      if (!mounted) return;
      ModalUtils.showSuccess(context, "Hooray! Listing Published",
          "Your property is now live and ready to be discovered by amazing tenants.",
          onOk: () {
        Navigator.pop(context);
        Navigator.pop(context);
      });
    } catch (e) {
      if (mounted)
        ModalUtils.showError(context, "Oops! We hit a snag",
            "Something went wrong while trying to publish your listing. Please try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ==========================================
  // NAVIGATION
  // ==========================================
  void _nextStep() {
    if (_currentStep == 1 && !(_step1Key.currentState?.validate() ?? false))
      return;
    if (_currentStep == 2 && !(_step2Key.currentState?.validate() ?? false))
      return;
    if (_currentStep == 4 && _photos.isEmpty) {
      ModalUtils.showError(context, "Photos Required",
          "Let's show off your property! Please upload at least one photo to continue.");
      return;
    }
    // Final Validation exactly at step 5 before going to step 6 (Review)
    if (_currentStep == 5 && !(_step5Key.currentState?.validate() ?? false))
      return;

    if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic);
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic);
    } else {
      Navigator.pop(context);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableFrom ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.gray900,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _availableFrom = picked);
    }
  }

  // ==========================================
  // MAIN BUILDER
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (_loadingDraft)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: GestureDetector(
          onTap: _previousStep,
          behavior: HitTestBehavior.opaque,
          child:
              const Icon(Icons.arrow_back, size: 28, color: AppColors.gray900),
        ),
        title: _currentStep < _totalSteps
            ? Text('Add New Listing',
                style: GoogleFonts.poppins(
                    color: AppColors.gray900,
                    fontWeight: FontWeight.bold,
                    fontSize: 24))
            : null,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentStep < _totalSteps) _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1BasicInfo(),
                  _buildStep2Location(),
                  _buildStep3Amenities(),
                  _buildStep4Photos(),
                  _buildStep5Pricing(),
                  _buildStep6Review(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 8, AppSpacing.xl, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_totalSteps - 1, (index) {
          final stepNum = index + 1;
          final isActive = stepNum == _currentStep;
          return Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppColors.primary : AppColors.white,
              border: isActive
                  ? null
                  : Border.all(color: StayNestColors.outlineLight),
            ),
            child: Center(
              child: Text(
                stepNum.toString(),
                style: GoogleFonts.poppins(
                    color: isActive ? AppColors.white : AppColors.gray900,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==========================================
  // STEP 1: Basic Information
  // ==========================================
  Widget _buildStep1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Basic Information',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: AppColors.gray900)),
            const SizedBox(height: 24),
            Text('Property Type',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.gray900)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildPropertyTypeChip('Apartment', PhosphorIcons.buildings()),
                _buildPropertyTypeChip('Room', PhosphorIcons.door()),
                _buildPropertyTypeChip('Home', PhosphorIcons.house()),
                _buildPropertyTypeChip('Studio', PhosphorIcons.armchair()),
              ],
            ),
            const SizedBox(height: 32),
            _buildLabel('Property Title'),
            _buildTextField(_title, 'Modern 2-Bedroom Apartment'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _buildLabel('Bedrooms'),
                      _buildCounter(
                          () => setState(() {
                                if (_bedrooms > 0) _bedrooms--;
                              }),
                          () => setState(() => _bedrooms++),
                          _bedrooms),
                    ])),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _buildLabel('Bathrooms'),
                      _buildCounter(
                          () => setState(() {
                                if (_bathrooms > 0) _bathrooms--;
                              }),
                          () => setState(() => _bathrooms++),
                          _bathrooms),
                    ])),
              ],
            ),
            const SizedBox(height: 24),
            _buildLabel('Description'),
            _buildTextField(_description,
                'A modern and spacious 2-bedroom apartment\nin a secure compound and amenities',
                maxLines: 5),
            const SizedBox(height: 48),
            _buildNextButton('Next: Location', _nextStep),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 2: Location & Address
  // ==========================================
  Widget _buildStep2Location() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location & Address',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: AppColors.gray900)),
            const SizedBox(height: 24),
            _buildLabel('Country'),
            _buildDropdown(
              value: _selectedCountry,
              items: _countries,
              hint: 'Select Country',
              onChanged: (val) {
                setState(() {
                  _selectedCountry = val;
                  _selectedCity = _citiesByCountry[val]?.first;
                });
              },
            ),
            const SizedBox(height: 20),
            _buildLabel('City'),
            _buildDropdown(
              value: _selectedCity,
              items: _citiesByCountry[_selectedCountry] ?? [],
              hint: 'Select City',
              onChanged: (val) => setState(() => _selectedCity = val),
            ),
            const SizedBox(height: 20),
            _buildLabel('Area / Neighborhood'),
            _buildTextField(_neighborhood, 'Kilimani'),
            const SizedBox(height: 20),
            _buildLabel('Street Address'),
            _buildTextField(_street, 'Kindaruma Road'),
            const SizedBox(height: 20),
            _buildLabel('Building (Optional)'),
            _buildTextField(_building, 'Sunset Apartments', required: false),
            const SizedBox(height: 20),
            _buildLabel('Zip / Postal Code (Optional)'),
            _buildTextField(_zip, '00100',
                required: false, keyboardType: TextInputType.number),
            const SizedBox(height: 48),
            _buildNextButton('Next: Amenities', _nextStep),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 3: Amenities
  // ==========================================
  Widget _buildStep3Amenities() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amenities',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.gray900)),
          const SizedBox(height: 4),
          Text('Select all that applies',
              style:
                  GoogleFonts.poppins(fontSize: 14, color: AppColors.gray400)),
          const SizedBox(height: 32),
          Text('Essential',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.gray900)),
          const SizedBox(height: 20),
          ..._essentialAmenities.entries
              .map((e) => _buildCheckbox(e.key, e.value)),
          const SizedBox(height: 24),
          Text('Additional',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.gray900)),
          const SizedBox(height: 20),
          ..._additionalAmenities.entries
              .map((e) => _buildCheckbox(e.key, e.value)),
          const SizedBox(height: 48),
          _buildNextButton('Next: Photos', _nextStep),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCheckbox(String label, IconData icon) {
    bool isChecked = _amenities[label] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: GestureDetector(
        onTap: () => setState(() => _amenities[label] = !isChecked),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.gray900),
            const SizedBox(width: 16),
            Expanded(
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: AppColors.gray900,
                        fontWeight: FontWeight.w500))),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked ? AppColors.green600 : AppColors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: isChecked
                        ? AppColors.green600
                        : StayNestColors.outlineLight,
                    width: 1.5),
              ),
              child: isChecked
                  ? Icon(PhosphorIcons.check(PhosphorIconsStyle.bold),
                      size: 14, color: AppColors.white)
                  : null,
            )
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 4: Photos
  // ==========================================
  Widget _buildStep4Photos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Photos',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.gray900)),
          const SizedBox(height: 4),
          Text('Upload high-quality photos of your property',
              style:
                  GoogleFonts.poppins(fontSize: 14, color: AppColors.gray400)),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1),
            itemCount: _photos.length + 1,
            itemBuilder: (context, index) {
              if (index == _photos.length) {
                return GestureDetector(
                  onTap: () async {
                    final picked =
                        await ImagePicker().pickMultiImage(imageQuality: 75);
                    if (picked.isNotEmpty)
                      setState(() =>
                          _photos.addAll(picked.map((x) => File(x.path))));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: StayNestColors.outlineLight)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.plus(),
                            size: 36, color: AppColors.primary),
                        const SizedBox(height: 12),
                        Text('Add Photo',
                            style: GoogleFonts.poppins(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 16)),
                      ],
                    ),
                  ),
                );
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_photos[index], fit: BoxFit.cover)),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _photos.removeAt(index)),
                      child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18)),
                    ),
                  )
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text('Tips',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.gray900)),
          const SizedBox(height: 16),
          Text(
              '• Include a picture of the living room, bedroom, and kitchen.\n• Shoot in landscape mode with good natural lighting.',
              style: GoogleFonts.poppins(
                  color: AppColors.gray500, height: 1.6, fontSize: 14)),
          const SizedBox(height: 48),
          _buildNextButton('Next: Pricing & Details', _nextStep),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 5: Pricing and Details (NEW)
  // ==========================================
  Widget _buildStep5Pricing() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Form(
        key: _step5Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pricing and Details',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: AppColors.gray900)),
            const SizedBox(height: 24),
            _buildLabel('Rent Price'),
            _buildPricingField(_rentPrice, '12000', '/month'),
            const SizedBox(height: 20),
            _buildLabel('Service Charges (KES)'),
            _buildPricingField(_serviceCharges, '1500', '/month'),
            const SizedBox(height: 20),
            _buildLabel('Security Deposit (KES)'),
            _buildPricingField(_securityDeposit, '12000', '/month'),
            const SizedBox(height: 20),
            _buildLabel('Minimum Stay'),
            _buildDropdown(
              value: _minimumStay,
              items: ['1 Month', '3 Months', '6 Months', '1 Year'],
              hint: 'Select Minimum Stay',
              onChanged: (val) =>
                  setState(() => _minimumStay = val ?? '6 Months'),
            ),
            const SizedBox(height: 20),
            _buildLabel('Available From'),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: StayNestColors.outlineLight),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _availableFrom != null
                          ? _formatDate(_availableFrom!)
                          : 'Select Date',
                      style: GoogleFonts.poppins(
                        color: _availableFrom != null
                            ? AppColors.gray900
                            : AppColors.gray400,
                        fontWeight: _availableFrom != null
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    Icon(PhosphorIcons.calendarBlank(),
                        color: AppColors.gray400, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            _buildNextButton('Next: Review', _nextStep),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingField(
      TextEditingController controller, String hint, String suffix) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: GoogleFonts.poppins(
          color: AppColors.gray900, fontWeight: FontWeight.w600, fontSize: 16),
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.poppins(
            color: AppColors.gray400, fontWeight: FontWeight.w600),
        suffixIcon: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(suffix,
                  style: GoogleFonts.poppins(
                      color: AppColors.gray400, fontSize: 14)),
            ),
          ],
        ),
        filled: false,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: StayNestColors.outlineLight)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: StayNestColors.outlineLight)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary)),
      ),
    );
  }

  // ==========================================
  // STEP 6: Review & Publish
  // ==========================================
  Widget _buildStep6Review() {
    List<MapEntry<String, bool>> selectedAmenities =
        _amenities.entries.where((e) => e.value).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & Publish',
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray900)),
          const SizedBox(height: 4),
          Text('Review your listing details',
              style:
                  GoogleFonts.poppins(fontSize: 14, color: AppColors.gray400)),
          const SizedBox(height: 32),

          // Preview Card
          Container(
            height: 120,
            decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: StayNestColors.outlineLight)),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(24)),
                  child: _photos.isNotEmpty
                      ? Image.file(_photos.first,
                          width: 120, height: 120, fit: BoxFit.cover)
                      : Container(
                          width: 120,
                          height: 120,
                          color: StayNestColors.surfaceVariantLight,
                          child: const Icon(Icons.image)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_title.text.isEmpty ? 'Untitled' : _title.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.gray900)),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                              size: 14, color: AppColors.gray400),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(
                                  '${_neighborhood.text.isEmpty ? 'Area' : _neighborhood.text}, ${_selectedCity ?? 'City'}',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                      color: AppColors.gray400, fontSize: 13))),
                        ]),
                        const Spacer(),
                        RichText(
                            text: TextSpan(children: [
                          TextSpan(
                              text:
                                  'Kes. ${_rentPrice.text.isEmpty ? '0' : _rentPrice.text}',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.gray900)),
                          TextSpan(
                              text: ' /month',
                              style: GoogleFonts.poppins(
                                  color: AppColors.gray400, fontSize: 14)),
                        ]))
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 40),
          Text('Details',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.gray900)),
          const SizedBox(height: 24),
          _buildReviewRow('Property Type', _propertyType),
          _buildReviewRow('Bedrooms', _bedrooms.toString()),
          _buildReviewRow('Bathrooms', _bathrooms.toString()),
          _buildReviewRow(
              'Furnished', _amenities['Furnished'] == true ? 'Yes' : 'No'),

          const Divider(color: StayNestColors.outlineLight, height: 40),

          Text('Pricing',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.gray900)),
          const SizedBox(height: 24),
          _buildReviewRow('Rent Price', 'Kes. ${_rentPrice.text} /month'),
          _buildReviewRow(
              'Service Charges', 'Kes. ${_serviceCharges.text} /month'),
          _buildReviewRow('Security Deposit', 'Kes. ${_securityDeposit.text}'),
          _buildReviewRow('Minimum Stay', _minimumStay),
          _buildReviewRow(
              'Available From',
              _availableFrom != null
                  ? _formatDate(_availableFrom!)
                  : 'Immediate'),

          const Divider(color: StayNestColors.outlineLight, height: 40),

          Text('Amenities',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.gray900)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: selectedAmenities.map((e) {
              IconData icon = _essentialAmenities[e.key] ??
                  _additionalAmenities[e.key] ??
                  PhosphorIcons.check();
              return _buildAmenityPill(e.key, icon);
            }).toList()
              ..addAll([
                if (selectedAmenities.isEmpty)
                  Text('No amenities selected.',
                      style: GoogleFonts.poppins(
                          color: AppColors.gray400,
                          fontStyle: FontStyle.italic))
              ]),
          ),

          const SizedBox(height: 32),
          Text('Description',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.gray900)),
          const SizedBox(height: 16),
          Text(
              _description.text.isEmpty
                  ? 'No description provided.'
                  : _description.text,
              style: GoogleFonts.poppins(
                  color: AppColors.gray500, height: 1.6, fontSize: 14)),

          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _saveDraft(showConfirmation: true),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: Text('Save Draft',
                      style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _publishListing,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0),
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2))
                      : Text('Publish',
                          style: GoogleFonts.poppins(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  color: AppColors.gray500,
                  fontWeight: FontWeight.w500,
                  fontSize: 14)),
          Text(value,
              style: GoogleFonts.poppins(
                  color: AppColors.gray900,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildAmenityPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4, right: 14),
      decoration: BoxDecoration(
          border: Border.all(color: StayNestColors.outlineLight),
          borderRadius: BorderRadius.circular(24),
          color: AppColors.white),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: StayNestColors.primaryLight, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primary, size: 16)),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray900)),
        ],
      ),
    );
  }

  // ==========================================
  // UTILITY BUILDERS
  // ==========================================
  Widget _buildPropertyTypeChip(String label, IconData icon) {
    bool isSelected = _propertyType == label;
    return GestureDetector(
      onTap: () => setState(() => _propertyType = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.gray50,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : StayNestColors.outlineLight)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: isSelected ? AppColors.white : AppColors.gray500),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    color: isSelected ? AppColors.white : AppColors.gray500,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildCounter(VoidCallback onDec, VoidCallback onInc, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: StayNestColors.outlineLight),
          borderRadius: AppRadius.inputBorderRadius),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
              onTap: onDec,
              child: Icon(PhosphorIcons.minus(),
                  color: AppColors.gray500, size: 20)),
          Text(value.toString(),
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          GestureDetector(
              onTap: onInc,
              child: Icon(PhosphorIcons.plus(),
                  color: AppColors.gray900, size: 20)),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: AppColors.gray900)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {int maxLines = 1,
      TextInputType keyboardType = TextInputType.text,
      bool required = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(
          color: AppColors.gray900, fontWeight: FontWeight.w500),
      validator: (value) =>
          (required && (value == null || value.trim().isEmpty))
              ? 'Required'
              : null,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.poppins(
            color: AppColors.gray400, fontWeight: FontWeight.w500),
        filled: false,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: StayNestColors.outlineLight)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: StayNestColors.outlineLight)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary)),
      ),
    );
  }

  Widget _buildDropdown(
      {required String? value,
      required List<String> items,
      required String hint,
      required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      icon: Icon(PhosphorIcons.caretDown(), color: AppColors.gray900),
      items: items
          .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e,
                  style: GoogleFonts.poppins(
                      color: AppColors.gray900, fontWeight: FontWeight.w500))))
          .toList(),
      onChanged: onChanged,
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: false,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: StayNestColors.outlineLight)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: StayNestColors.outlineLight)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary)),
      ),
    );
  }

  Widget _buildNextButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0),
        onPressed: onPressed,
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: AppColors.white)),
      ),
    );
  }
}

// ==========================================
// MODAL UTILITIES
// ==========================================
class ModalUtils {
  static void showSuccess(BuildContext context, String title, String message,
      {VoidCallback? onOk}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.dialogBorderRadius),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                color: AppColors.green600, size: 72),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray900)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.poppins(color: AppColors.gray500, height: 1.5)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonBorderRadius),
                    elevation: 0),
                onPressed: onOk ?? () => Navigator.pop(ctx),
                child: Text('Awesome!',
                    style: GoogleFonts.poppins(
                        color: AppColors.white, fontWeight: FontWeight.w600)),
              ),
            )
          ],
        ),
      ),
    );
  }

  static void showError(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.dialogBorderRadius),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                color: StayNestColors.error, size: 72),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray900)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.poppins(color: AppColors.gray500, height: 1.5)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gray900,
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonBorderRadius),
                    elevation: 0),
                onPressed: () => Navigator.pop(ctx),
                child: Text('Got it',
                    style: GoogleFonts.poppins(
                        color: AppColors.white, fontWeight: FontWeight.w600)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
