import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:property_app/utils/responsive_modal_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Your project imports
import 'package:property_app/repository/http_json_client.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/image_upload_service.dart';
import 'package:property_app/services/verification_api.dart';
import 'package:property_app/utils/api_result.dart';
import 'package:property_app/utils/geocoding.dart';
import 'package:property_app/services/property_service.dart';
import 'package:property_app/services/uploads.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/models/property_taxonomy.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const _bg = Color(0xFFFAFAFA);
const _dark = Color(0xFF111827);
const _grey = Color(0xFF9CA3AF);
const _greyLight = Color(0xFFF3F4F6);
const _green = Color(0xFF10B981); // Emerald Green for Landlord Theme
const _surface = Colors.white;

String? _joinLocationParts(Iterable<String?> values) {
  final parts = <String>[];
  for (final value in values) {
    if (value != null && value.isNotEmpty && !parts.contains(value)) {
      parts.add(value);
    }
  }
  return parts.isEmpty ? null : parts.join(', ');
}

class PickedPhoto {
  final XFile? file;
  String? url;
  double progress;
  bool isUploading;
  String? error;

  PickedPhoto(
    this.file, {
    this.url,
    this.progress = 0.0,
    this.isUploading = false,
    this.error,
  });
}

class PickedVideo {
  final XFile? file;
  String? url;
  bool isUploading;
  double progress;

  PickedVideo(this.file,
      {this.url, this.isUploading = false, this.progress = 0.0});
}

class AddListingFlow extends StatefulWidget {
  final Map<String, dynamic>? property;

  const AddListingFlow({super.key, this.property});

  bool get isEditing => property?['id'] != null;

  @override
  State<AddListingFlow> createState() => _AddListingFlowState();
}

class _AddListingFlowState extends State<AddListingFlow> {
  bool _loadingDraft = true;
  bool _submitting = false;
  bool _isUploadingImages = false;
  double _uploadProgress = 0.0;
  final List<UploadProgress> _imageUploadStatus = [];

  final PageController _pageController = PageController();
  int _currentStep = 1;
  final int _totalSteps = 6;

  // Form Keys
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step5Key = GlobalKey<FormState>();

  // --- Step 1: Basic Info ---
  String _propertyType = 'Apartment';
  final _title = TextEditingController();
  final _description = TextEditingController();
  int _bedrooms = 1;
  int _bathrooms = 1;

  // --- Step 2: Location ---
  final String _selectedCountry = 'Kenya';
  String? _selectedCity;
  final _neighborhood = TextEditingController();
  final _locationSearch = TextEditingController();
  Timer? _locationSearchTimer;
  int _locationSearchRequest = 0;
  List<GeocodingSuggestion> _locationSuggestions = [];
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedLocationLabel;
  GeocodingSuggestion? _selectedLocation;
  double? _locationBiasLatitude;
  double? _locationBiasLongitude;

  // --- Step 3: Amenities ---
  final Set<String> _selectedAttributes = {};
  final List<String> _customFeatures = [];
  final TextEditingController _customFeatureController =
      TextEditingController();

  // --- Step 4: Photos & Video ---
  final List<PickedPhoto> _pickedPhotos = [];
  PickedVideo? _pickedVideo;
  VideoPlayerController? _videoThumbnailController;

  // --- Step 5: Pricing and Details ---
  final _rentPrice = TextEditingController();
  final _serviceCharges = TextEditingController();
  final _securityDeposit = TextEditingController();
  String _minimumStay = '6 Months';
  DateTime? _availableFrom;

  String? _draftId;
  Future<void> _draftSaveQueue = Future<void>.value();
  Timer? _draftSaveTimer;
  bool _draftAutosaveEnabled = false;
  bool _draftDirty = false;

  RemoteDatabaseRepository _buildRepo() {
    return RemoteDatabaseRepository(apiClient: HttpJsonClient());
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadDraft().then((_) {
      if (mounted) _enableDraftAutosave();
    }));
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    if (_draftDirty) unawaited(_queueDraftSave());
    _pageController.dispose();
    _title.dispose();
    _description.dispose();
    _neighborhood.dispose();
    _locationSearch.dispose();
    _locationSearchTimer?.cancel();
    _rentPrice.dispose();
    _serviceCharges.dispose();
    _securityDeposit.dispose();
    _videoThumbnailController?.dispose();
    super.dispose();
  }

  void _enableDraftAutosave() {
    if (widget.property != null) return;
    _draftAutosaveEnabled = true;
    for (final controller in [
      _title,
      _description,
      _neighborhood,
      _locationSearch,
      _customFeatureController,
      _rentPrice,
      _serviceCharges,
      _securityDeposit,
    ]) {
      controller.addListener(_scheduleDraftSave);
    }
  }

  void _scheduleDraftSave() {
    if (!_draftAutosaveEnabled) return;
    _draftDirty = true;
    unawaited(PropertyService.instance
        .cacheDraftLocally(_buildDraftPayload(), draftId: _draftId));
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 450), () {
      _draftSaveTimer = null;
      unawaited(_queueDraftSave());
    });
  }

  // ==========================================
  // DRAFT & SUBMISSION LOGIC
  // ==========================================
  Future<void> _loadDraft() async {
    final existing = widget.property;
    if (existing != null && existing.isNotEmpty) {
      _title.text = existing['title']?.toString() ?? '';
      _description.text = existing['description']?.toString() ?? '';
      _propertyType = existing['category']?.toString() ?? _propertyType;
      _bedrooms = (existing['bedrooms'] as num?)?.toInt() ?? _bedrooms;
      _bathrooms = (existing['bathrooms'] as num?)?.toInt() ?? _bathrooms;
      _selectedCity = existing['city']?.toString() ?? _selectedCity;
      _neighborhood.text = existing['address']?.toString() ?? '';
      _locationSearch.text = existing['address']?.toString() ?? '';
      _rentPrice.text = existing['price']?.toString() ?? '';
      _serviceCharges.text = existing['service_charges']?.toString() ?? '';
      _securityDeposit.text = existing['security_deposit']?.toString() ?? '';
      _minimumStay = existing['minimum_stay']?.toString() ?? _minimumStay;
      _availableFrom =
          DateTime.tryParse(existing['available_from']?.toString() ?? '');
      _selectedLatitude = (existing['lat'] as num?)?.toDouble();
      _selectedLongitude = (existing['lng'] as num?)?.toDouble();
      _locationBiasLatitude = _selectedLatitude;
      _locationBiasLongitude = _selectedLongitude;
      _selectedLocationLabel = _locationSearch.text;
      if (_selectedLatitude != null && _selectedLongitude != null) {
        _selectedLocation = (
          locationId: null,
          type: null,
          aliases: const [],
          displayName: _locationSearch.text,
          secondaryName: _joinLocationParts([
            existing['road']?.toString(),
            existing['neighborhood']?.toString(),
            existing['town']?.toString(),
            existing['county']?.toString(),
          ]),
          lat: _selectedLatitude!,
          lng: _selectedLongitude!,
          country: existing['country']?.toString() ?? _selectedCountry,
          county: existing['county']?.toString(),
          subCounty: existing['sub_county']?.toString(),
          ward: existing['ward']?.toString(),
          town: existing['town']?.toString(),
          neighborhood: existing['neighborhood']?.toString(),
          estateOrVillage: existing['estate_village']?.toString(),
          road: existing['road']?.toString(),
          landmark: existing['landmark']?.toString(),
        );
      }

      final existingImages = existing['images'];
      if (existingImages is List) {
        for (final image in existingImages) {
          final url = image?.toString();
          if (url != null && url.isNotEmpty) {
            _pickedPhotos.add(PickedPhoto(null, url: url, progress: 1.0));
          }
        }
      } else if (existing['image_url'] != null) {
        _pickedPhotos.add(PickedPhoto(null,
            url: existing['image_url'].toString(), progress: 1.0));
      }

      final existingVideo = existing['video_url']?.toString();
      if (existingVideo != null && existingVideo.isNotEmpty) {
        _pickedVideo = PickedVideo(null, url: existingVideo);
        // Load thumbnail for existing video
        _videoThumbnailController =
            VideoPlayerController.networkUrl(Uri.parse(existingVideo))
              ..initialize().then((_) {
                if (mounted) setState(() {});
              });
      }

      final existingAmenities = existing['amenities'];
      if (existingAmenities is List) {
        for (final amenity in existingAmenities) {
          final str = amenity.toString();
          if (str.startsWith('custom:')) {
            _customFeatures.add(str.substring(7));
          } else {
            final mapped = PropertyTaxonomy.mapLegacyLabel(str);
            final attr = PropertyTaxonomy.getAttributeById(mapped);
            if (attr != null) _selectedAttributes.add(attr.id);
          }
        }
      }
      if (mounted) setState(() => _loadingDraft = false);
      return;
    }

    try {
      final drafts = await PropertyService.instance.getDrafts();
      if (drafts.isNotEmpty) {
        final data = drafts.first;
        _draftId = data['id']?.toString();
        _propertyType = data['category'] ?? 'Apartment';
        _title.text = data['title'] ?? '';
        _description.text = data['description'] ?? '';
        _bedrooms = data['bedrooms'] ?? 1;
        _bathrooms = data['bathrooms'] ?? 1;
        _selectedCity = data['city'] ?? 'Kenya';
        _neighborhood.text = data['address'] ?? '';
        _locationSearch.text = data['address'] ?? '';
        if (data['lat'] != null) {
          _selectedLatitude = (data['lat'] as num).toDouble();
        }
        if (data['lng'] != null) {
          _selectedLongitude = (data['lng'] as num).toDouble();
        }
        if (_selectedLatitude != null && _selectedLongitude != null) {
          _locationBiasLatitude = _selectedLatitude;
          _locationBiasLongitude = _selectedLongitude;
          _selectedLocation = (
            locationId: null,
            type: null,
            aliases: const [],
            displayName: _locationSearch.text,
            secondaryName: _joinLocationParts([
              data['road']?.toString(),
              data['neighborhood']?.toString(),
              data['town']?.toString(),
              data['county']?.toString(),
            ]),
            lat: _selectedLatitude!,
            lng: _selectedLongitude!,
            country: data['country']?.toString() ?? _selectedCountry,
            county: data['county']?.toString(),
            subCounty: data['sub_county']?.toString(),
            ward: data['ward']?.toString(),
            town: data['town']?.toString(),
            neighborhood: data['neighborhood']?.toString(),
            estateOrVillage: data['estate_village']?.toString(),
            road: data['road']?.toString(),
            landmark: data['landmark']?.toString(),
          );
        }
        _rentPrice.text = data['price']?.toString() ?? '';
        _serviceCharges.text = data['service_charges']?.toString() ?? '';
        _securityDeposit.text = data['security_deposit']?.toString() ?? '';
        _minimumStay = data['minimum_stay']?.toString() ?? _minimumStay;
        _availableFrom =
            DateTime.tryParse(data['available_from']?.toString() ?? '');
        _customFeatureController.text =
            data['custom_feature_input']?.toString() ?? '';
        final draftPhotos = data['photos'];
        if (draftPhotos is List) {
          for (final photo in draftPhotos) {
            final url = photo?.toString();
            if (url != null && url.isNotEmpty) {
              _pickedPhotos.add(PickedPhoto(null, url: url, progress: 1.0));
            }
          }
        }
        final draftVideo = data['video_url']?.toString();
        if (draftVideo != null && draftVideo.isNotEmpty) {
          _pickedVideo = PickedVideo(null, url: draftVideo);
        }
        if (data['amenities'] is List) {
          for (final a in (data['amenities'] as List)) {
            final str = a.toString();
            if (str.startsWith('custom:')) {
              _customFeatures.add(str.substring(7));
            } else {
              final mapped = PropertyTaxonomy.mapLegacyLabel(str);
              final attr = PropertyTaxonomy.getAttributeById(mapped);
              if (attr != null) _selectedAttributes.add(attr.id);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load backend draft: $e');
    }
    if (mounted) setState(() => _loadingDraft = false);
  }

  Future<void> _saveDraft({bool showConfirmation = true}) async {
    var savedRemotely = true;
    try {
      final payload = _buildDraftPayload();
      final data =
          await PropertyService.instance.saveDraft(payload, draftId: _draftId);
      if (data['id'] != null) _draftId = data['id'].toString();
    } catch (e) {
      savedRemotely = false;
      debugPrint('Failed to save draft $e');
    }
    if (mounted && showConfirmation) {
      ModalUtils.showSuccess(
        context,
        savedRemotely ? "Draft Saved!" : "Draft Saved Offline",
        savedRemotely
            ? "Your progress has been safely tucked away. You can resume anytime."
            : "Your progress is stored on this device and will be available here until it syncs online.",
      );
    }
  }

  Map<String, dynamic> _buildDraftPayload() {
    return {
      'category': _propertyType,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'city': _selectedCity,
      'address': _neighborhood.text.trim().isNotEmpty
          ? _neighborhood.text.trim()
          : _locationSearch.text.trim(),
      'country': _selectedLocation?.country ?? _selectedCountry,
      'county': _selectedLocation?.county,
      'sub_county': _selectedLocation?.subCounty,
      'ward': _selectedLocation?.ward,
      'town': _selectedLocation?.town,
      'neighborhood': _selectedLocation?.neighborhood,
      'estate_village': _selectedLocation?.estateOrVillage,
      'road': _selectedLocation?.road,
      'landmark': _selectedLocation?.landmark,
      'lat': _selectedLatitude,
      'lng': _selectedLongitude,
      'price': _rentPrice.text.trim().isEmpty ? null : _rentPrice.text.trim(),
      'service_charges': _serviceCharges.text.trim().isEmpty
          ? null
          : _serviceCharges.text.trim(),
      'security_deposit': _securityDeposit.text.trim().isEmpty
          ? null
          : _securityDeposit.text.trim(),
      'minimum_stay': _minimumStay,
      'available_from': _availableFrom?.toIso8601String().split('T').first,
      'custom_feature_input': _customFeatureController.text,
      'area': (_bedrooms * 35).clamp(30, 500),
      'photos': _pickedPhotos
          .where((photo) => photo.url != null && photo.url!.isNotEmpty)
          .map((photo) => photo.url)
          .toList(),
      'video_url': _pickedVideo?.url,
      'amenities': [
        ..._selectedAttributes,
        ..._customFeatures.map((c) => 'custom:$c')
      ],
    };
  }

  Future<void> _queueDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = null;
    _draftDirty = false;
    _draftSaveQueue = _draftSaveQueue.then((_) async {
      await _saveDraft(showConfirmation: false);
    });
    return _draftSaveQueue;
  }

  void _searchLocations(String value) {
    _locationSearchTimer?.cancel();
    final request = ++_locationSearchRequest;
    if (_selectedLocationLabel != value.trim()) {
      _selectedLatitude = null;
      _selectedLongitude = null;
    }
    if (value.trim().length < 3) {
      setState(() => _locationSuggestions = []);
      return;
    }

    _locationSearchTimer = Timer(const Duration(milliseconds: 450), () async {
      final suggestions = await searchAddressSuggestions(
        value.trim(),
        nearLat: _locationBiasLatitude,
        nearLng: _locationBiasLongitude,
      );
      if (!mounted || request != _locationSearchRequest) return;
      setState(() => _locationSuggestions = suggestions);
    });
  }

  void _selectLocation(GeocodingSuggestion suggestion) {
    setState(() {
      _locationSearch.text = suggestion.displayName;
      _locationSearch.selection =
          TextSelection.collapsed(offset: _locationSearch.text.length);
      _selectedLatitude = suggestion.lat;
      _selectedLongitude = suggestion.lng;
      _locationBiasLatitude = suggestion.lat;
      _locationBiasLongitude = suggestion.lng;
      _selectedLocation = suggestion;
      _selectedCity = suggestion.town ?? suggestion.county ?? _selectedCountry;
      _selectedLocationLabel = suggestion.displayName.trim();
      _neighborhood.text = suggestion.displayName.split(',').first.trim();
      _locationSuggestions = [];
    });
  }

  Future<void> _uploadPickedPhoto(PickedPhoto photo) async {
    final pickedFile = photo.file;
    if (pickedFile == null) return;

    setState(() {
      photo.isUploading = true;
      photo.progress = 0.0;
      photo.error = null;
    });

    try {
      final compressed =
          await ImageUploadService.compressPickedImage(pickedFile);
      final task =
          UploadsService.uploadXFileWithProgress(compressed, (progress) {
        if (!mounted) return;
        setState(() => photo.progress = progress);
      });
      final url = await task.future;
      if (mounted) {
        setState(() {
          photo.url = url;
          photo.isUploading = false;
          photo.progress = 1.0;
        });
        await _queueDraftSave();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          photo.error = e.toString();
          photo.isUploading = false;
        });
      }
    }
  }

  Future<void> _pickPropertyVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final controller = kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(picked.path))
        : VideoPlayerController.file(File(picked.path));

    try {
      await controller.initialize();
      if (controller.value.duration > const Duration(seconds: 30)) {
        if (mounted) {
          ModalUtils.showError(context, 'Video Too Long',
              'Choose a property video that is 30 seconds or shorter.');
        }
        await controller.dispose();
        return;
      }

      setState(() {
        _videoThumbnailController?.dispose();
        _videoThumbnailController = controller;
        _pickedVideo = PickedVideo(picked, isUploading: true, progress: 0.0);
      });

      final task = UploadsService.uploadXFileWithProgress(picked, (progress) {
        if (mounted) {
          setState(() {
            _pickedVideo?.progress = progress;
          });
        }
      });

      final url = await task.future;
      if (mounted) {
        setState(() {
          _pickedVideo?.url = url;
          _pickedVideo?.isUploading = false;
          _pickedVideo?.progress = 1.0;
        });
        await _queueDraftSave();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pickedVideo = null;
          _scheduleDraftSave();
        });
        ModalUtils.showError(context, 'Video Upload Failed',
            'We could not process that video. Please try another clip.');
      }
      await controller.dispose();
    }
  }

  Future<void> _publishListing() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    Map<String, dynamic>? verificationStatus;
    try {
      verificationStatus = await VerificationApi.getVerificationStatus();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ModalUtils.showError(
          context, 'Verification Check Failed', ApiResult.mapError(error));
      return;
    }
    final normalizedStatus =
        verificationStatus?['status']?.toString().toLowerCase() ??
            'not_started';
    final isApproved = normalizedStatus == 'approved';

    if (!isApproved || AppSession.currentUserVerified != true) {
      await _saveDraft(showConfirmation: false);
      if (!mounted) return;
      setState(() => _submitting = false);
      _showVerificationDialog();
      return;
    }

    if (_pickedPhotos.isEmpty) {
      setState(() => _submitting = false);
      ModalUtils.showError(context, "Photos Required",
          "Please add at least one photo of your amazing property.");
      return;
    }

    if (AppSession.apiToken == null) {
      setState(() => _submitting = false);
      ModalUtils.showError(context, "Session Expired",
          "Please log out and log back in, then try again.");
      return;
    }

    setState(() {
      _isUploadingImages = true;
      _uploadProgress = 1.0;
    });

    try {
      if (_pickedPhotos.any((p) => p.isUploading)) {
        throw Exception('Please wait for all photos to finish uploading.');
      }
      if (_pickedPhotos.any((p) => p.error != null)) {
        throw Exception(
            'Some photos failed to upload. Please remove them or try again.');
      }
      if (_pickedVideo?.isUploading == true) {
        throw Exception('Please wait for the video to finish uploading.');
      }

      final uploadedUrls = _pickedPhotos.map((p) => p.url!).toList();
      if (uploadedUrls.isEmpty) throw Exception('No photos uploaded');

      final resolvedAddress = _locationSearch.text.trim();
      final location = _selectedLocation;
      final derivedCity = location?.town ??
          location?.county ??
          _selectedCity ??
          _selectedCountry;

      if (_selectedLatitude == null || _selectedLongitude == null) {
        throw Exception(
            'Select a location from the address suggestions before publishing.');
      }
      final selectedAmenities = [
        ..._selectedAttributes,
        ..._customFeatures.map((c) => 'custom:$c')
      ];
      final estimatedArea = (_bedrooms * 35).clamp(30, 500);

      final repo = _buildRepo();
      final Map<String, dynamic> propertyPayload = {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'category': _propertyType,
        'city': derivedCity,
        'address': resolvedAddress,
        'country': location?.country ?? _selectedCountry,
        'county': location?.county,
        'sub_county': location?.subCounty,
        'ward': location?.ward,
        'town': location?.town,
        'neighborhood': location?.neighborhood,
        'estate_village': location?.estateOrVillage,
        'road': location?.road,
        'landmark': location?.landmark,
        'price': _rentPrice.text.trim(),
        'bedrooms': _bedrooms,
        'bathrooms': _bathrooms,
        'area': estimatedArea,
        'service_charges': _serviceCharges.text.trim().isEmpty
            ? null
            : _serviceCharges.text.trim(),
        'security_deposit': _securityDeposit.text.trim().isEmpty
            ? null
            : _securityDeposit.text.trim(),
        'minimum_stay': _minimumStay,
        'available_from': _availableFrom?.toIso8601String().split('T').first,
        'image_url': uploadedUrls.first,
        'images': uploadedUrls,
        'video_url': _pickedVideo?.url,
        'amenities': selectedAmenities,
        'lat': _selectedLatitude,
        'lng': _selectedLongitude,
      };

      final existingPropertyId = widget.property?['id']?.toString();
      if (existingPropertyId != null && existingPropertyId.isNotEmpty) {
        await repo.updatePropertyFromListing(
            propertyId: existingPropertyId, listingPayload: propertyPayload);
      } else {
        await repo.createPropertyFromListing(listingPayload: propertyPayload);
      }

      if (_draftId != null) {
        try {
          await PropertyService.instance.deleteDraft(_draftId!);
          _draftId = null;
        } catch (_) {}
      }

      if (!mounted) return;
      ModalUtils.showSuccess(
        context,
        widget.isEditing ? "Listing Updated" : "Hooray! Listing Published",
        widget.isEditing
            ? "Your property details were updated successfully."
            : "Your property is now live and ready to be discovered.",
        onOk: () {
          Navigator.pop(context);
          Navigator.pop(context, true);
        },
      );
    } catch (e) {
      if (mounted) {
        ModalUtils.showError(
            context, "Oops! We hit a snag", ApiResult.mapError(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _isUploadingImages = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsFill.lockKey,
                color: Color(0xFFF59E0B), size: 64),
            const SizedBox(height: 16),
            Text('Verification Required',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 8),
            Text(
                'To keep our community safe, we require all landlords to be verified before their listings go live. We\'ve saved your draft!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: _grey, height: 1.5, fontSize: 14)),
            const SizedBox(height: 24),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Edit Draft',
                  style: GoogleFonts.poppins(
                      color: _grey, fontWeight: FontWeight.w600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/verification_center');
            },
            child: Text('Verify Now',
                style: GoogleFonts.poppins(
                    color: _surface, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // NAVIGATION
  // ==========================================
  void _nextStep() {
    if (_currentStep == 1 && !(_step1Key.currentState?.validate() ?? false)) {
      return;
    }
    if (_currentStep == 2 && !(_step2Key.currentState?.validate() ?? false)) {
      return;
    }
    if (_currentStep == 4 && _pickedPhotos.isEmpty) {
      ModalUtils.showError(context, "Photos Required",
          "Let's show off your property! Please upload at least one photo.");
      return;
    }
    if (_currentStep == 5 && !(_step5Key.currentState?.validate() ?? false)) {
      return;
    }

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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _green,
            onPrimary: Colors.white,
            onSurface: _dark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _availableFrom = picked);
      _scheduleDraftSave();
    }
  }

  // ==========================================
  // MAIN BUILDER
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (_loadingDraft) {
      return const Scaffold(
          backgroundColor: _bg,
          body: Center(child: CircularProgressIndicator(color: _green)));
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: _previousStep,
          behavior: HitTestBehavior.opaque,
          child: const Icon(PhosphorIconsRegular.caretLeft,
              size: 24, color: _dark),
        ),
        title: _currentStep < _totalSteps
            ? Text('Add New Listing',
                style: GoogleFonts.poppins(
                    color: _dark, fontWeight: FontWeight.w700, fontSize: 20))
            : null,
        centerTitle: true,
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_totalSteps - 1, (index) {
          final stepNum = index + 1;
          final isActive = stepNum == _currentStep;
          final isPast = stepNum < _currentStep;

          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isPast ? _green : _surface,
              border: isActive || isPast
                  ? null
                  : Border.all(color: _grey.withOpacity(0.3)),
            ),
            child: Center(
              child: isPast
                  ? const Icon(PhosphorIconsBold.check,
                      color: _surface, size: 16)
                  : Text(stepNum.toString(),
                      style: GoogleFonts.poppins(
                          color: isActive ? _surface : _grey,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Basic Information',
                style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                    letterSpacing: -0.5)),
            const SizedBox(height: 24),
            _buildLabel('Property Type'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildPropertyTypeChip(
                    'Apartment', 'assets/images/apartments.webp'),
                _buildPropertyTypeChip(
                    'Bedsitter', 'assets/images/bedsitter.webp'),
                _buildPropertyTypeChip(
                    'Single Room', 'assets/images/singleroom.webp'),
                _buildPropertyTypeChip(
                    'One Bedroom', 'assets/images/onebedroom.webp'),
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
                                _scheduleDraftSave();
                              }),
                          () => setState(() {
                                _bedrooms++;
                                _scheduleDraftSave();
                              }),
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
                                _scheduleDraftSave();
                              }),
                          () => setState(() {
                                _bathrooms++;
                                _scheduleDraftSave();
                              }),
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
  void _openLocationPickerSheet() {
    showResponsiveModalSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocationPickerSheet(
        onLocationSelected: (locationStr, lat, lng, location) {
          setState(() {
            _locationSearch.text = locationStr;
            _selectedLatitude = lat;
            _selectedLongitude = lng;
            _locationBiasLatitude = lat;
            _locationBiasLongitude = lng;
            _selectedLocation = location;
            _selectedCity =
                location?.town ?? location?.county ?? _selectedCountry;
            _selectedLocationLabel = locationStr;
            _neighborhood.text = locationStr.split(',').first.trim();
            _locationSuggestions = [];
          });
        },
      ),
    );
  }

  Widget _buildStep2Location() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location & Address',
                style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                    letterSpacing: -0.5)),
            const SizedBox(height: 32),
            _buildLabel('Search exact location'),
            TextFormField(
              controller: _locationSearch,
              onChanged: _searchLocations,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.poppins(
                  color: _dark, fontWeight: FontWeight.w500, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Start typing an address or landmark',
                hintStyle: GoogleFonts.poppins(
                    color: _grey, fontWeight: FontWeight.w400, fontSize: 14),
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                    color: _grey, size: 20),
                suffixIcon: _selectedLatitude != null
                    ? const Icon(PhosphorIconsFill.checkCircle,
                        color: _green, size: 20)
                    : null,
                filled: true,
                fillColor: _surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _grey.withOpacity(0.2))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _grey.withOpacity(0.2))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _green)),
              ),
            ),
            if (_locationSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: _locationSuggestions.map((suggestion) {
                    return ListTile(
                      leading: Icon(_locationTypeIcon(suggestion.type),
                          color: _green, size: 20),
                      title: Text(suggestion.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              GoogleFonts.poppins(fontSize: 14, color: _dark)),
                      subtitle: suggestion.secondaryName == null &&
                              suggestion.type == null
                          ? null
                          : Text(
                              [
                                if (suggestion.secondaryName != null)
                                  suggestion.secondaryName!,
                                if (suggestion.type != null)
                                  _locationTypeLabel(suggestion.type!),
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: _grey)),
                      onTap: () => _selectLocation(suggestion),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _openLocationPickerSheet,
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.crosshair,
                      color: _green, size: 20),
                  const SizedBox(width: 8),
                  Text('Use my current location',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _green)),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _grey.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset('assets/images/mapsheet.webp',
                          width: 90,
                          height: 100,
                          fit: BoxFit.contain), // Fixed Image Fit
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(PhosphorIconsRegular.info,
                                  color: _green, size: 18),
                              const SizedBox(width: 8),
                              Text('Location Setup',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: _dark,
                                      fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                              'Search for the exact location or use your current location. The address will auto-fill.',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: _grey, height: 1.4)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            _buildNextButton('Next: Amenities', _nextStep),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  IconData _locationTypeIcon(String? type) {
    switch (type) {
      case 'hospital':
        return PhosphorIconsRegular.hospital;
      case 'campus':
      case 'school':
        return PhosphorIconsRegular.graduationCap;
      case 'neighborhood':
      case 'estate':
      case 'village':
        return PhosphorIconsRegular.buildings;
      case 'road':
        return PhosphorIconsRegular.mapPin;
      default:
        return PhosphorIconsRegular.mapPin;
    }
  }

  String _locationTypeLabel(String type) => switch (type) {
        'shoppingCentre' => 'Shopping centre',
        'subCounty' => 'Sub-county',
        _ => type[0].toUpperCase() + type.substring(1),
      };

  // ==========================================
  // STEP 3: Amenities
  // ==========================================
  Widget _buildStep3Amenities() {
    final popular =
        PropertyTaxonomy.getPopularAttributes(propertyType: _propertyType);
    final allAttrs =
        PropertyTaxonomy.getAttributesForPropertyType(_propertyType);
    final categorized = <String, List<PropertyAttribute>>{};

    for (var attr in allAttrs) {
      if (!categorized.containsKey(attr.category)) {
        categorized[attr.category] = [];
      }
      categorized[attr.category]!.add(attr);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Property Features',
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(
              'Select the features, utilities and services available at this property.',
              style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
          const SizedBox(height: 32),
          if (popular.isNotEmpty) ...[
            Text('Popular for students',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600, color: _dark)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: popular.map((p) => _buildFeatureChip(p)).toList(),
            ),
            const SizedBox(height: 32),
            Container(height: 1, color: _grey.withOpacity(0.2)),
            const SizedBox(height: 24),
          ],
          ...PropertyTaxonomy.categories.map((cat) {
            final catAttrs = categorized[cat.id] ?? [];
            if (catAttrs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.label,
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: catAttrs.map((p) => _buildFeatureChip(p)).toList(),
                ),
                const SizedBox(height: 32),
              ],
            );
          }),
          Text('Custom Features',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600, color: _dark)),
          const SizedBox(height: 16),
          ..._customFeatures.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsFill.checkCircle,
                        color: _green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            Text(c, style: GoogleFonts.poppins(fontSize: 14))),
                    IconButton(
                      icon: const Icon(PhosphorIconsRegular.x,
                          size: 16, color: _grey),
                      onPressed: () => setState(() {
                        _customFeatures.remove(c);
                        _scheduleDraftSave();
                      }),
                    ),
                  ],
                ),
              )),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customFeatureController,
                  decoration: InputDecoration(
                    hintText: 'Add another feature...',
                    hintStyle: GoogleFonts.poppins(color: _grey, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: _surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: _grey.withOpacity(0.2))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: _grey.withOpacity(0.2))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _green)),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      setState(() {
                        _customFeatures.add(v.trim());
                        _customFeatureController.clear();
                        _scheduleDraftSave();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(PhosphorIconsFill.plusCircle,
                    color: _green, size: 40),
                onPressed: () {
                  if (_customFeatureController.text.trim().isNotEmpty) {
                    setState(() {
                      _customFeatures.add(_customFeatureController.text.trim());
                      _customFeatureController.clear();
                      _scheduleDraftSave();
                    });
                  }
                },
              )
            ],
          ),
          const SizedBox(height: 48),
          _buildNextButton('Next: Photos', _nextStep),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(PropertyAttribute attr) {
    final isSelected = _selectedAttributes.contains(attr.id);
    return FilterChip(
      selected: isSelected,
      label: Text(attr.label),
      labelStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: isSelected ? Colors.white : _dark,
        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
      ),
      selectedColor: _green,
      backgroundColor: Colors.white,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? _green : _grey.withOpacity(0.3)),
      ),
      onSelected: (val) {
        setState(() {
          if (val) {
            _selectedAttributes.add(attr.id);
          } else {
            _selectedAttributes.remove(attr.id);
          }
          _scheduleDraftSave();
        });
      },
    );
  }

  // ==========================================
  // STEP 4: Photos & Video
  // ==========================================
  Widget _buildStep4Photos() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Photos',
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('Upload high-quality photos of your property',
              style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1),
            itemCount: _pickedPhotos.length + 1,
            itemBuilder: (context, index) {
              if (index == _pickedPhotos.length) {
                return GestureDetector(
                  onTap: () async {
                    final picked =
                        await ImagePicker().pickMultiImage(imageQuality: 75);
                    if (picked.isNotEmpty) {
                      for (final x in picked) {
                        final photo = PickedPhoto(x);
                        setState(() => _pickedPhotos.add(photo));
                        _uploadPickedPhoto(photo);
                      }
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _grey.withOpacity(0.3),
                          style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(PhosphorIconsRegular.plus,
                            size: 32, color: _green),
                        const SizedBox(height: 12),
                        Text('Add Photo',
                            style: GoogleFonts.poppins(
                                color: _green,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                );
              }
              final photo = _pickedPhotos[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: photo.url != null
                        ? buildPropertyImage(photo.url!, fit: BoxFit.cover)
                        : photo.file == null
                            ? const SizedBox.shrink()
                            : kIsWeb
                                ? Image.network(photo.file!.path,
                                    fit: BoxFit.cover)
                                : Image.file(File(photo.file!.path),
                                    fit: BoxFit.cover),
                  ),
                  if (photo.isUploading)
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20)),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: photo.progress > 0 ? photo.progress : null,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  if (photo.error != null)
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20)),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: photo.error!,
                              child: const Icon(
                                PhosphorIconsRegular.warningCircle,
                                color: Colors.redAccent,
                                size: 32,
                              ),
                            ),
                            TextButton(
                              onPressed: () => _uploadPickedPhoto(photo),
                              child: const Text('Retry upload'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _pickedPhotos.removeAt(index);
                        _scheduleDraftSave();
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: _surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4)
                            ]),
                        child: const Icon(PhosphorIconsRegular.x,
                            size: 14, color: _dark),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text('Property Video (optional)',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 16, color: _dark)),
          const SizedBox(height: 4),
          Text('Upload a quick 30s tour to get 3x more views.',
              style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
          const SizedBox(height: 16),

          // ─── NEW REFACTORED VIDEO UPLOAD UI ───
          if (_pickedVideo != null) ...[
            Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Stack(fit: StackFit.expand, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _videoThumbnailController != null &&
                            _videoThumbnailController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio:
                                _videoThumbnailController!.value.aspectRatio,
                            child: VideoPlayer(_videoThumbnailController!))
                        : Container(color: _grey.withOpacity(0.1)),
                  ),
                  if (_pickedVideo!.isUploading)
                    Container(
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20)),
                        child: Center(
                            child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                                value: _pickedVideo!.progress,
                                color: Colors.white),
                            const SizedBox(height: 12),
                            Text(
                                '${(_pickedVideo!.progress * 100).toStringAsFixed(0)}%',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ))),
                  if (!_pickedVideo!.isUploading)
                    Center(
                        child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsFill.play,
                          color: Colors.white, size: 28),
                    )),
                  if (!_pickedVideo!.isUploading)
                    Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                            onTap: () {
                              _videoThumbnailController?.dispose();
                              _videoThumbnailController = null;
                              setState(() {
                                _pickedVideo = null;
                                _scheduleDraftSave();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(PhosphorIconsRegular.x,
                                  size: 14, color: Colors.black),
                            )))
                ]))
          ] else ...[
            GestureDetector(
                onTap: _pickPropertyVideo,
                child: Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: _surface,
                        border: Border.all(
                            color: _grey.withOpacity(0.3),
                            style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(20)),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(PhosphorIconsRegular.videoCamera,
                              size: 36, color: _green),
                          const SizedBox(height: 12),
                          Text('Add property video',
                              style: GoogleFonts.poppins(
                                  color: _green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ])))
          ],

          const SizedBox(height: 32),
          Text('Tips',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 16, color: _dark)),
          const SizedBox(height: 12),
          Text(
              '• Include a picture of the living room, bedroom, and kitchen.\n• Shoot in landscape mode with good natural lighting.',
              style:
                  GoogleFonts.poppins(color: _grey, height: 1.6, fontSize: 14)),
          const SizedBox(height: 48),
          _buildNextButton('Next: Pricing & Details', _nextStep),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 5: Pricing and Details
  // ==========================================
  Widget _buildStep5Pricing() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _step5Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pricing and Details',
                style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                    letterSpacing: -0.5)),
            const SizedBox(height: 24),
            _buildLabel('Rent Price'),
            _buildPricingField(_rentPrice, '12000', '/month'),
            const SizedBox(height: 20),
            _buildLabel('Service Charges (Ksh.)'),
            _buildPricingField(_serviceCharges, '1500', '/month'),
            const SizedBox(height: 20),
            _buildLabel('Security Deposit (Ksh.)'),
            _buildPricingField(_securityDeposit, '12000', '/month'),
            const SizedBox(height: 20),
            _buildLabel('Minimum Stay'),
            _buildDropdown(
              value: _minimumStay,
              items: ['1 Month', '3 Months', '6 Months', '1 Year'],
              hint: 'Select Minimum Stay',
              onChanged: (val) => setState(() {
                _minimumStay = val ?? '6 Months';
                _scheduleDraftSave();
              }),
            ),
            const SizedBox(height: 20),
            _buildLabel('Available From'),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: _surface,
                  border: Border.all(color: _grey.withOpacity(0.2)),
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
                          color: _availableFrom != null ? _dark : _grey,
                          fontWeight: FontWeight.w500,
                          fontSize: 14),
                    ),
                    const Icon(PhosphorIconsRegular.calendarBlank,
                        color: _grey, size: 20),
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
          color: _dark, fontWeight: FontWeight.w500, fontSize: 14),
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.poppins(
            color: _grey, fontWeight: FontWeight.w400, fontSize: 14),
        suffixIcon: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(suffix,
                  style: GoogleFonts.poppins(color: _grey, fontSize: 14)),
            ),
          ],
        ),
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _grey.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _grey.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _green)),
      ),
    );
  }

  // ==========================================
  // STEP 6: Review & Publish
  // ==========================================
  Widget _buildStep6Review() {
    final selectedAmenities = [
      ..._selectedAttributes
          .map((id) => PropertyTaxonomy.getAttributeById(id)?.label ?? id),
      ..._customFeatures
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & Publish',
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('Review your listing details',
              style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
          const SizedBox(height: 32),

          // Preview Card
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(24)),
                  child: _pickedPhotos.isNotEmpty
                      ? (_pickedPhotos.first.url != null
                          ? buildPropertyImage(_pickedPhotos.first.url!,
                              width: 120,
                              height: double.infinity,
                              fit: BoxFit.cover)
                          : _pickedPhotos.first.file == null
                              ? Container(color: _greyLight)
                              : kIsWeb
                                  ? Image.network(
                                      _pickedPhotos.first.file!.path,
                                      width: 120,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_pickedPhotos.first.file!.path),
                                      width: 120,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ))
                      : Container(
                          width: 120,
                          color: _greyLight,
                          child: const Icon(PhosphorIconsRegular.image,
                              color: _grey)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 16.0),
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
                                color: _dark)),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(PhosphorIconsRegular.mapPin,
                              size: 14, color: _grey),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(
                                  '${_neighborhood.text.isEmpty ? 'Area' : _neighborhood.text}, ${_selectedCity ?? 'City'}',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                      color: _grey, fontSize: 13))),
                        ]),
                        const Spacer(),
                        RichText(
                          text: TextSpan(children: [
                            TextSpan(
                                text:
                                    'Ksh. ${_rentPrice.text.isEmpty ? '0' : _rentPrice.text}',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _dark)),
                            TextSpan(
                                text: ' /mo',
                                style: GoogleFonts.poppins(
                                    color: _grey, fontSize: 13)),
                          ]),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 40),
          if (_isUploadingImages ||
              _imageUploadStatus.isNotEmpty ||
              _pickedVideo?.isUploading == true) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(PhosphorIconsRegular.cloudArrowUp,
                          color: _green, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                _uploadProgress < 1.0 ||
                                        _pickedVideo?.isUploading == true
                                    ? 'Optimizing & Uploading...'
                                    : 'Upload Complete',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _dark)),
                            const SizedBox(height: 2),
                            Text(
                                '${(_uploadProgress * 100).toStringAsFixed(0)}% • ${_imageUploadStatus.length} media files',
                                style: GoogleFonts.poppins(
                                    color: _grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value:
                          (_uploadProgress + (_pickedVideo?.progress ?? 1.0)) /
                              2.0, // Blended progress
                      minHeight: 8,
                      backgroundColor: _greyLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(_green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          Text('Details',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 20),
          _buildReviewRow('Property Type', _propertyType),
          _buildReviewRow('Bedrooms', _bedrooms.toString()),
          _buildReviewRow('Bathrooms', _bathrooms.toString()),
          _buildReviewRow('Furnished',
              _selectedAttributes.contains('furnished') ? 'Yes' : 'No'),

          Divider(color: _grey.withOpacity(0.2), height: 40),

          Text('Pricing',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 20),
          _buildReviewRow('Rent Price', 'Ksh. ${_rentPrice.text} /month'),
          _buildReviewRow(
              'Service Charges', 'Ksh. ${_serviceCharges.text} /month'),
          _buildReviewRow('Security Deposit', 'Ksh. ${_securityDeposit.text}'),
          _buildReviewRow('Minimum Stay', _minimumStay),
          _buildReviewRow(
              'Available From',
              _availableFrom != null
                  ? _formatDate(_availableFrom!)
                  : 'Immediate'),

          Divider(color: _grey.withOpacity(0.2), height: 40),

          Text('Amenities',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: selectedAmenities.map((label) {
              return _buildAmenityPill(label, PhosphorIconsRegular.check);
            }).toList()
              ..addAll([
                if (selectedAmenities.isEmpty)
                  Text('No features selected.',
                      style: GoogleFonts.poppins(
                          color: _grey,
                          fontStyle: FontStyle.italic,
                          fontSize: 14))
              ]),
          ),

          const SizedBox(height: 32),
          Text('Description',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 16),
          Text(
              _description.text.isEmpty
                  ? 'No description provided.'
                  : _description.text,
              style:
                  GoogleFonts.poppins(color: _grey, height: 1.6, fontSize: 14)),

          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _saveDraft(showConfirmation: true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: _green, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                  ),
                  child: Text('Save Draft',
                      style: GoogleFonts.poppins(
                          color: _green,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _publishListing,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: _surface, strokeWidth: 2))
                      : Text('Publish',
                          style: GoogleFonts.poppins(
                              color: _surface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
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
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  color: _grey, fontWeight: FontWeight.w500, fontSize: 14)),
          Text(value,
              style: GoogleFonts.poppins(
                  color: _dark, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildAmenityPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _dark, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500, color: _dark)),
        ],
      ),
    );
  }

  // ==========================================
  // UTILITY BUILDERS
  // ==========================================
  Widget _buildPropertyTypeChip(String label, String imagePath) {
    bool isSelected = _propertyType == label;
    return GestureDetector(
      onTap: () => setState(() {
        _propertyType = label;
        _scheduleDraftSave();
      }),
      child: Container(
        padding: const EdgeInsets.only(left: 6, right: 16, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? _green : _grey.withOpacity(0.2),
            width: isSelected ? 2.0 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                    image: AssetImage(imagePath), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    color: isSelected ? _green : _dark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCounter(VoidCallback onDec, VoidCallback onInc, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
              onTap: onDec,
              child: const Icon(PhosphorIconsRegular.minus,
                  color: _grey, size: 20)),
          Text(value.toString(),
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 14, color: _dark)),
          GestureDetector(
              onTap: onInc,
              child: const Icon(PhosphorIconsRegular.plus,
                  color: _dark, size: 20)),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600, color: _dark)),
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
          color: _dark, fontWeight: FontWeight.w500, fontSize: 14),
      validator: (value) =>
          (required && (value == null || value.trim().isEmpty))
              ? 'Required'
              : null,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.poppins(
            color: _grey, fontWeight: FontWeight.w400, fontSize: 14),
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _grey.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _grey.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _green)),
      ),
    );
  }

  Widget _buildDropdown(
      {required String? value,
      required List<String> items,
      required String hint,
      required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      icon: const Icon(PhosphorIconsRegular.caretDown, color: _grey),
      items: items
          .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e,
                  style: GoogleFonts.poppins(
                      color: _dark,
                      fontWeight: FontWeight.w500,
                      fontSize: 14))))
          .toList(),
      onChanged: onChanged,
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _grey.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _grey.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _green)),
      ),
    );
  }

  Widget _buildNextButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(text,
            style: GoogleFonts.poppins(
                color: _surface, fontWeight: FontWeight.w600, fontSize: 16)),
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
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsFill.checkCircle, color: _green, size: 64),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: _grey, height: 1.5, fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    elevation: 0),
                onPressed: onOk ?? () => Navigator.pop(ctx),
                child: Text('Awesome!',
                    style: GoogleFonts.poppins(
                        color: _surface, fontWeight: FontWeight.w600)),
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
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsFill.warningCircle,
                color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: _grey, height: 1.5, fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _dark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    elevation: 0),
                onPressed: () => Navigator.pop(ctx),
                child: Text('Got it',
                    style: GoogleFonts.poppins(
                        color: _surface, fontWeight: FontWeight.w600)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  final void Function(
          String address, double lat, double lng, GeocodingSuggestion? location)
      onLocationSelected;
  const _LocationPickerSheet({required this.onLocationSelected});

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  bool _isLoading = true;
  String? _locationName;
  double? _lat;
  double? _lng;
  String? _error;
  GeocodingSuggestion? _location;
  bool _isResolvingTap = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final location =
          await reverseGeocodeSuggestion(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
          _locationName = location?.displayName ??
              '${position.latitude}, ${position.longitude}';
          _location = location;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectMapPoint(LatLng point) async {
    setState(() => _isResolvingTap = true);
    final location =
        await reverseGeocodeSuggestion(point.latitude, point.longitude);
    if (!mounted) return;
    setState(() {
      _lat = point.latitude;
      _lng = point.longitude;
      _location = location;
      _locationName = location?.displayName ??
          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      _isResolvingTap = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('Confirm Location',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
            ),
            if (_lat != null && _lng != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 220,
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(_lat!, _lng!),
                            initialZoom: 15,
                            onTap: (_, point) => _selectMapPoint(point),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.staynest.property_app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_lat!, _lng!),
                                  width: 44,
                                  height: 44,
                                  child: const Icon(PhosphorIconsFill.mapPin,
                                      color: _green, size: 42),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_isResolvingTap)
                          const ColoredBox(
                            color: Color(0x66FFFFFF),
                            child: Center(
                                child:
                                    CircularProgressIndicator(color: _green)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _isLoading
                  ? Column(
                      children: [
                        const CircularProgressIndicator(color: _green),
                        const SizedBox(height: 16),
                        Text('Detecting your location...',
                            style: GoogleFonts.poppins(
                                color: _grey, fontSize: 14)),
                      ],
                    )
                  : _error != null
                      ? Text('Error: $_error',
                          style: GoogleFonts.poppins(color: Colors.redAccent))
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: _greyLight,
                              borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              const Icon(PhosphorIconsRegular.mapPin,
                                  color: _green, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_locationName ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: _dark)),
                                  if (_location?.secondaryName != null) ...[
                                    const SizedBox(height: 3),
                                    Text(_location!.secondaryName!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                            fontSize: 12, color: _grey)),
                                  ],
                                ],
                              )),
                            ],
                          ),
                        ),
            ),
            Container(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
              width: double.infinity,
              height: 76,
              child: ElevatedButton(
                onPressed: (_isLoading || _error != null)
                    ? null
                    : () {
                        widget.onLocationSelected(
                            _locationName!, _lat!, _lng!, _location);
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: _grey.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32)),
                  elevation: 0,
                ),
                child: Text('Use this location',
                    style: GoogleFonts.poppins(
                        color: _surface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
