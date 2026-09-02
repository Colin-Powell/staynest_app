import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/api_client.dart';
import 'package:property_app/services/uploads.dart';
import 'package:property_app/services/image_upload_service.dart';
import 'package:property_app/services/verification_api.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

// ==========================================
// 1. CORE DATA
// ==========================================
class VerificationSession {
  File? idPhotoFront;
  File? idPhotoBack;
  File? selfie;
  File? proofOfAddress;
  File? utilityBill;
  File? leaseAgreement;
  File? propertyPhotos;

  String? idPhotoFrontUrl;
  String? idPhotoBackUrl;
  String? selfieUrl;
  String? proofOfAddressUrl;
  String? utilityBillUrl;
  String? leaseAgreementUrl;
  String? propertyPhotosUrl;

  Map<String, String> adminRejections = {};

  double get progress {
    int completed = 0;
    if (idPhotoFront != null) completed++;
    if (idPhotoBack != null) completed++;
    if (selfie != null) completed++;
    return completed / 3; // Only ID + selfie are required for KYC approval
  }

  Map<String, dynamic> toDocumentsMap() => {
        if (idPhotoFrontUrl != null) 'id_photo_front': idPhotoFrontUrl,
        if (idPhotoBackUrl != null) 'id_photo_back': idPhotoBackUrl,
        if (selfieUrl != null) 'selfie': selfieUrl,
      };
}

class LandlordVerificationEntry extends StatelessWidget {
  const LandlordVerificationEntry({super.key});
  @override
  Widget build(BuildContext context) => const VerificationCenter();
}

// ==========================================
// 2. BASE PAGE: Verification Center
// ==========================================
class VerificationCenter extends StatefulWidget {
  const VerificationCenter({super.key});
  @override
  State<VerificationCenter> createState() => _VerificationCenterState();
}

class _VerificationCenterState extends State<VerificationCenter> {
  final VerificationSession _session = VerificationSession();

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isEmailVerified) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(PhosphorIconsRegular.caretLeft,
                color: _dark, size: 24),
          ),
          title: Text('Verify Email First',
              style: GoogleFonts.poppins(
                  color: _dark, fontWeight: FontWeight.w700, fontSize: 20)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsRegular.shieldSlash,
                    size: 64, color: _grey),
                const SizedBox(height: 16),
                Text(
                  'Please complete OTP email verification before starting landlord KYC.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 16, color: _grey),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                    text: 'Verify Now',
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/otp')),
              ],
            ),
          ),
        ),
      );
    }

    if (!AppSession.isLandlord) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(PhosphorIconsRegular.caretLeft,
                color: _dark, size: 24),
          ),
          title: Text('Access Denied',
              style: GoogleFonts.poppins(
                  color: _dark, fontWeight: FontWeight.w700, fontSize: 20)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsRegular.shieldSlash,
                    size: 64, color: _grey),
                const SizedBox(height: 16),
                Text(
                  'Verification center is available for landlords only.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 16, color: _grey),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                    text: 'Go Back', onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(PhosphorIconsRegular.caretLeft,
              color: _dark, size: 28),
        ),
        title: Text('Verification Center',
            style: GoogleFonts.poppins(
                color: _dark,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: -0.5)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: _green.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsFill.shieldCheck,
                          size: 80, color: _green),
                    ),
                    const SizedBox(height: 24),
                    Text(
                        'Complete verification to build trust with\ntenants and unlock premium features.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 15, color: _grey, height: 1.5)),
                    const SizedBox(height: 48),
                    _buildFeature(PhosphorIconsFill.sealCheck, 'Verified Badge',
                        'Show tenants you are trustworthy'),
                    _buildFeature(PhosphorIconsFill.eye, 'Higher Visibility',
                        'Get featured in more searches'),
                    _buildFeature(
                        PhosphorIconsFill.lightning,
                        'Faster Bookings',
                        'Verified landlords get more bookings'),
                    _buildFeature(PhosphorIconsFill.lockKey, 'Secure Platform',
                        'We protect you and your tenants'),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surface,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, -4))
                ],
                border: Border(top: BorderSide(color: _grey.withOpacity(0.1))),
              ),
              child: Column(
                children: [
                  PrimaryButton(
                      text: 'Start Verification',
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => VerificationRequirementHub(
                                  session: _session)))),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      try {
                        final status =
                            await VerificationApi.getVerificationStatus();
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VerificationStatusView(
                              statusData: status ?? {'status': 'not_started'},
                            ),
                          ),
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VerificationStatusView(
                              statusData: {'status': 'not_started'},
                            ),
                          ),
                        );
                      }
                    },
                    child: Text('Check Existing Status',
                        style: GoogleFonts.poppins(
                            color: _green,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, size: 28, color: _green),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
              ]))
        ],
      ),
    );
  }
}

// ==========================================
// 3. HUB PAGE: Verification Requirements
// ==========================================
class VerificationRequirementHub extends StatefulWidget {
  final VerificationSession session;
  const VerificationRequirementHub({super.key, required this.session});
  @override
  State<VerificationRequirementHub> createState() =>
      _VerificationRequirementHubState();
}

class _VerificationRequirementHubState
    extends State<VerificationRequirementHub> {
  @override
  Widget build(BuildContext context) {
    int idDocs = (widget.session.idPhotoFront != null ? 1 : 0) +
        (widget.session.idPhotoBack != null ? 1 : 0) +
        (widget.session.selfie != null ? 1 : 0);
    String progressStr = '${(widget.session.progress * 100).toInt()}%';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(PhosphorIconsRegular.caretLeft,
              color: _dark, size: 28),
        ),
        toolbarHeight: 80,
        title: Text('Requirements',
            style: GoogleFonts.poppins(
                color: _dark,
                fontWeight: FontWeight.w700,
                fontSize: 24,
                letterSpacing: -0.5)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Complete all mandatory steps below to get your profile verified.',
                        style: GoogleFonts.poppins(color: _grey, fontSize: 15)),
                    const SizedBox(height: 32),
                    VerificationCard(
                      icon: PhosphorIconsRegular.identificationCard,
                      title: 'Identity Verification',
                      subtitle: 'Verify your identity you\'re human',
                      statusText: '$idDocs/3',
                      isComplete: idDocs == 3,
                      hasError: widget.session.adminRejections
                          .containsKey('identity'),
                      errorMessage: widget.session.adminRejections['identity'],
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => VerificationStepFlow(
                                    session: widget.session, initialPage: 0)));
                        setState(() {});
                      },
                    ),
                    const VerificationCard(
                      icon: PhosphorIconsRegular.storefront,
                      title: 'KYC Complete',
                      subtitle: 'Identity and selfie check only',
                      statusText: 'Active',
                      isComplete: true,
                      onTap: null,
                    ),
                    const SizedBox(height: 32),
                    Text('Overall Progress',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: _dark)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                                value: widget.session.progress,
                                backgroundColor: _grey.withOpacity(0.2),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(_green),
                                minHeight: 8),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(progressStr,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700, color: _dark)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SecureWatermark(),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surface,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, -4))
                ],
                border: Border(top: BorderSide(color: _grey.withOpacity(0.1))),
              ),
              child: PrimaryButton(
                  text: 'Continue',
                  enabled: widget.session.progress == 1.0,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              VerificationStepFlow(session: widget.session)))),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. SUB-HUBS WITH FRONT/BACK LOGIC
// ==========================================
class VerificationStepFlow extends StatefulWidget {
  final VerificationSession session;
  final int initialPage;
  const VerificationStepFlow(
      {super.key, required this.session, this.initialPage = 0});
  @override
  State<VerificationStepFlow> createState() => _VerificationStepFlowState();
}

class _VerificationStepFlowState extends State<VerificationStepFlow> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialPage);
  late int _currentPage;
  bool _isSubmitting = false;
  final String _idempotencyKey = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _identityComplete =>
      widget.session.idPhotoFront != null &&
      widget.session.idPhotoBack != null &&
      widget.session.selfie != null;
  bool get _allPagesComplete => _identityComplete;

  Future<void> _goNext() async {
    if (_isSubmitting) return;

    if (!_allPagesComplete) {
      ModalUtils.showError(context, 'Incomplete Step',
          'Please upload all required identity documents before continuing.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'documents': widget.session.toDocumentsMap(),
        'property': {},
      };
      final resp = await VerificationApi.submitVerification(
        payload,
        idempotencyKey: _idempotencyKey,
      );
      final data = resp['data'] ?? resp;
      final nextStatus =
          (data['status'] ?? 'submitted').toString().toLowerCase();
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (nextStatus == 'submitted' ||
            nextStatus == 'under_review' ||
            nextStatus == 'pending_review') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Verification submitted. Dashboard actions unlock after admin approval.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF059669),
            ),
          );
          Navigator.pushNamedAndRemoveUntil(
              context, '/portal', (route) => false);
          return;
        }
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => VerificationStatusView(
                    statusData: data ?? {'status': 'not_started'})));
      }
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      final message = e is ApiException && e.message.isNotEmpty
          ? e.message
          : 'Something went wrong while submitting your documents. Please try again later.';
      if (mounted) {
        ModalUtils.showError(context, 'Submission Failed', message);
      }
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic);
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _handleUpload(
      File file, String type, Function(String url) onSuccess) async {
    final progress = ValueNotifier<double>(0.0);
    final task = UploadsService.uploadFileWithProgress(
        file, (p) => progress.value = p,
        idempotencyKey: '${_idempotencyKey}_$type');

    ModalUtils.showProgress(context, progress,
        message: 'Uploading securely...', onCancel: () => task.cancel());

    try {
      final url = await task.future;
      onSuccess(url);
      if (mounted) Navigator.pop(context);
      ModalUtils.showSuccess(context, 'Document uploaded successfully!',
          autoClose: const Duration(milliseconds: 1200));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (e is UploadCancelledException) {
        ModalUtils.showError(context, 'Cancelled', 'The upload was cancelled.');
      } else {
        ModalUtils.showError(context, 'Upload Failed',
            'We couldn\'t upload your document. Please check your connection.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
            onTap: _goBack,
            child: const Icon(PhosphorIconsRegular.caretLeft,
                color: _dark, size: 28)),
        title: Text(
            _currentPage == 0
                ? 'Identity Verification'
                : 'Property Verification',
            style: GoogleFonts.poppins(
                color: _dark, fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Step ${_currentPage + 1} of 2',
                      style: GoogleFonts.poppins(
                          color: _grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text('${(widget.session.progress * 100).toInt()}% complete',
                      style: GoogleFonts.poppins(
                          color: _green,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [_buildIdentityPage()],
              ),
            ),
            const SecureWatermark(),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: _surface,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, -4))
                  ],
                  border:
                      Border(top: BorderSide(color: _grey.withOpacity(0.1)))),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                        child: OutlinedButton(
                            onPressed: _goBack,
                            style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: _green, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(32)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16)),
                            child: Text('Back',
                                style: GoogleFonts.poppins(
                                    color: _green,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)))),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                      flex: 2,
                      child: PrimaryButton(
                          text: _isSubmitting
                              ? 'Submitting...'
                              : (_currentPage == 0
                                  ? 'Continue'
                                  : 'Submit Verification'),
                          enabled: !_isSubmitting,
                          onPressed: _goNext)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityPage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload Your Identity documents',
              style: GoogleFonts.poppins(color: _grey, fontSize: 15)),
          const SizedBox(height: 32),
          VerificationCard(
            icon: PhosphorIconsRegular.identificationCard,
            title: 'National ID (Front)',
            subtitle: 'Clear photo of the front',
            isComplete: widget.session.idPhotoFront != null,
            statusText:
                widget.session.idPhotoFront != null ? 'Approved' : 'Upload',
            hasError:
                widget.session.adminRejections.containsKey('idPhotoFront'),
            errorMessage: widget.session.adminRejections['idPhotoFront'],
            previewWidget: widget.session.idPhotoFront != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(widget.session.idPhotoFront!,
                        width: 72, height: 72, fit: BoxFit.cover),
                  )
                : null,
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DocumentCapture(
                            title: 'National ID (Front)',
                            subtitle: 'Ensure all edges are visible',
                            onFileCaptured: (file) async {
                              widget.session.idPhotoFront = file;
                              widget.session.adminRejections
                                  .remove('idPhotoFront');
                              setState(() {});
                              await _handleUpload(
                                  file,
                                  'idPhotoFront',
                                  (url) =>
                                      widget.session.idPhotoFrontUrl = url);
                            },
                          )));
            },
          ),
          VerificationCard(
            icon: PhosphorIconsRegular.identificationCard,
            title: 'National ID (Back)',
            subtitle: 'Clear photo of the back',
            isComplete: widget.session.idPhotoBack != null,
            statusText:
                widget.session.idPhotoBack != null ? 'Approved' : 'Upload',
            hasError: widget.session.adminRejections.containsKey('idPhotoBack'),
            errorMessage: widget.session.adminRejections['idPhotoBack'],
            previewWidget: widget.session.idPhotoBack != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(widget.session.idPhotoBack!,
                        width: 72, height: 72, fit: BoxFit.cover),
                  )
                : null,
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DocumentCapture(
                            title: 'National ID (Back)',
                            subtitle: 'Ensure barcode/MRZ is readable',
                            onFileCaptured: (file) async {
                              widget.session.idPhotoBack = file;
                              widget.session.adminRejections
                                  .remove('idPhotoBack');
                              setState(() {});
                              await _handleUpload(file, 'idPhotoBack',
                                  (url) => widget.session.idPhotoBackUrl = url);
                            },
                          )));
            },
          ),
          VerificationCard(
            icon: PhosphorIconsRegular.userFocus,
            title: 'Selfie with ID',
            subtitle: 'Live face verification',
            isComplete: widget.session.selfie != null,
            statusText: widget.session.selfie != null ? 'Approved' : 'Capture',
            hasError: widget.session.adminRejections.containsKey('selfie'),
            errorMessage: widget.session.adminRejections['selfie'],
            previewWidget: widget.session.selfie != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(widget.session.selfie!,
                        width: 72, height: 72, fit: BoxFit.cover),
                  )
                : null,
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SelfieCaptureScreen(
                            onFileCaptured: (file) async {
                              widget.session.selfie = file;
                              widget.session.adminRejections.remove('selfie');
                              setState(() {});
                              await _handleUpload(file, 'selfie',
                                  (url) => widget.session.selfieUrl = url);
                            },
                          )));
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. CAPTURE SCREENS WITH CROPPER
// ==========================================
class DocumentCapture extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<void> Function(File file) onFileCaptured;

  const DocumentCapture(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.onFileCaptured});

  @override
  State<DocumentCapture> createState() => _DocumentCaptureState();
}

class _DocumentCaptureState extends State<DocumentCapture> {
  File? _previewFile;
  bool _isUploading = false;

  Future<void> _captureDocument(
      BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null) return;

      final sourcePath = picked.path;
      var finalFile = File(sourcePath);

      if (source == ImageSource.gallery) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: sourcePath,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Adjust Document',
              toolbarColor: _dark,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(title: 'Adjust Document'),
          ],
        );
        if (croppedFile != null) {
          finalFile = File(croppedFile.path);
        }
      }

      final compressedFile =
          await ImageUploadService.compressImageFile(finalFile);
      if (!mounted) return;

      setState(() {
        _previewFile = compressedFile;
        _isUploading = true;
      });

      await widget.onFileCaptured(compressedFile);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _isUploading = false);
        ModalUtils.showError(context, 'Process Error',
            "We couldn't prepare your photo. Please try again.");
      }
    }
  }

  Future<void> _chooseSource(BuildContext context) async {
    if (!context.mounted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose document source',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(PhosphorIconsRegular.camera),
                title: Text('Use phone camera',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(PhosphorIconsRegular.imageSquare),
                title: Text('Upload from gallery',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      await _captureDocument(context, source);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(PhosphorIconsRegular.caretLeft,
                color: _dark, size: 28)),
        title: Text('Upload Document',
            style: GoogleFonts.poppins(
                color: _dark, fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text(widget.subtitle,
                        style: GoogleFonts.poppins(color: _grey, fontSize: 15)),
                    const SizedBox(height: 32),
                    if (_previewFile != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _grey.withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(_previewFile!,
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (_isUploading)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _green,
                                    ),
                                  ),
                                if (_isUploading) const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isUploading
                                        ? 'Uploading securely...'
                                        : 'Preview ready',
                                    style: GoogleFonts.poppins(
                                      color: _isUploading ? _green : _dark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    GestureDetector(
                      onTap: () => _chooseSource(context),
                      child: CustomPaint(
                        painter:
                            DashedRectPainter(color: _grey.withOpacity(0.5)),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 64),
                          decoration: BoxDecoration(
                              color: _green.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: _green.withOpacity(0.1),
                                    shape: BoxShape.circle),
                                child: const Icon(
                                    PhosphorIconsRegular.cloudArrowUp,
                                    size: 48,
                                    color: _green),
                              ),
                              const SizedBox(height: 24),
                              Text('Tap to choose a source',
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _dark)),
                              const SizedBox(height: 8),
                              Text('Camera or gallery upload (auto-compressed)',
                                  style: GoogleFonts.poppins(
                                      color: _grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SecureWatermark(),
          ],
        ),
      ),
    );
  }
}

class SelfieCaptureScreen extends StatefulWidget {
  final Future<void> Function(File file) onFileCaptured;
  const SelfieCaptureScreen({super.key, required this.onFileCaptured});
  @override
  State<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen> {
  File? _capturedImage;
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _initializingCamera = false;
  bool _isUploading = false;

  Future<void> _takeSelfie() async {
    try {
      XFile? xfile;
      if (_cameraReady &&
          _cameraController != null &&
          _cameraController!.value.isInitialized) {
        xfile = await _cameraController!.takePicture();
      } else {
        xfile = await ImagePicker().pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.front);
      }
      if (xfile == null) return;

      final imageFile = File(xfile.path);
      if (!await imageFile.exists()) throw Exception();

      final compressedFile =
          await ImageUploadService.compressImageFile(imageFile);

      setState(() {
        _capturedImage = compressedFile;
        _isUploading = true;
      });
      await widget.onFileCaptured(_capturedImage!);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isUploading = false);
      ModalUtils.showError(context, 'Capture Error',
          "Failed to capture selfie. Please try again.");
    }
  }

  Future<void> _initCamera() async {
    if (_initializingCamera) return;
    _initializingCamera = true;
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.isNotEmpty ? cameras.first : throw Exception());
      _cameraController =
          CameraController(front, ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
    } catch (_) {
      setState(() => _cameraReady = false);
    } finally {
      _initializingCamera = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(PhosphorIconsRegular.caretLeft,
                color: _dark, size: 28)),
        title: Text('Selfie Verification',
            style: GoogleFonts.poppins(
                color: _dark, fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Take a clear selfie',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text('Position your face inside the frame',
                        style: GoogleFonts.poppins(color: _grey, fontSize: 15)),
                    const SizedBox(height: 48),
                    Container(
                      height: 320,
                      width: 320,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _green, width: 4),
                          color: _grey.withOpacity(0.1)),
                      clipBehavior: Clip.hardEdge,
                      child: _capturedImage != null
                          ? Image.file(_capturedImage!, fit: BoxFit.cover)
                          : (_cameraReady && _cameraController != null
                              ? CameraPreview(_cameraController!)
                              : const Center(
                                  child: Icon(PhosphorIconsRegular.userFocus,
                                      size: 80, color: _grey))),
                    ),
                    if (_isUploading) ...[
                      const SizedBox(height: 24),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _green,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Uploading selfie securely...',
                        style: GoogleFonts.poppins(
                          color: _green,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(24),
                child: PrimaryButton(
                    text: _isUploading ? 'Uploading...' : 'Capture Selfie',
                    onPressed: _isUploading ? () {} : _takeSelfie,
                    enabled: !_isUploading))
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. STATUS VIEWS
// ==========================================
class VerificationStatusView extends StatelessWidget {
  final Map<String, dynamic> statusData;
  const VerificationStatusView({super.key, required this.statusData});

  @override
  Widget build(BuildContext context) {
    final status =
        statusData['status']?.toString().toLowerCase() ?? 'not_started';

    if (status == 'approved') {
      AppSession.currentRole = 'landlord';
      AppSession.currentUserVerified = true;
      if (statusData['user'] is Map<String, dynamic>) {
        AppSession.updateCurrentUser(statusData['user']);
      }
      return const _SuccessScreen();
    } else if (status == 'rejected' || status == 'action_required') {
      return _RejectedScreen(rejections: statusData['reasons'] ?? []);
    } else if (status == 'not_started') {
      return _NotStartedScreen();
    }
    return _ReviewScreen(statusData: statusData);
  }
}

class _NotStartedScreen extends StatelessWidget {
  const _NotStartedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsFill.shieldCheck,
                  size: 72,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Verification not started',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You have no active landlord KYC yet. Start the verification process to unlock dashboard access and listings.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: _grey,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                text: 'Start Verification',
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VerificationRequirementHub(
                      session: VerificationSession(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RejectedScreen extends StatelessWidget {
  final List<dynamic> rejections;
  const _RejectedScreen({required this.rejections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2), shape: BoxShape.circle),
                  child: const Icon(PhosphorIconsFill.warningCircle,
                      size: 80, color: Color(0xFFEF4444))),
              const SizedBox(height: 32),
              Text('Action Required',
                  style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      letterSpacing: -0.5)),
              const SizedBox(height: 16),
              Text(
                  'We couldn\'t verify your account. Please fix the following issues and resubmit.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: _grey, fontSize: 15, height: 1.5)),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFCA5A5).withOpacity(0.5))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin Notes:',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF991B1B))),
                    const SizedBox(height: 16),
                    ...(rejections.isEmpty
                            ? ['Certain documents were unclear or missing.']
                            : rejections)
                        .map((msg) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ',
                                        style: TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)),
                                    Expanded(
                                        child: Text(msg.toString(),
                                            style: GoogleFonts.poppins(
                                                color: const Color(0xFF991B1B),
                                                fontSize: 14))),
                                  ]),
                            )),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(
                  text: 'Fix & Resubmit',
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewScreen extends StatelessWidget {
  final Map<String, dynamic> statusData;
  const _ReviewScreen({required this.statusData});

  @override
  Widget build(BuildContext context) {
    final rawStatus =
        statusData['status']?.toString().toLowerCase() ?? 'submitted';
    final status = rawStatus == 'pending_review' ? 'under_review' : rawStatus;

    final bool submittedComplete = status == 'submitted' ? false : true;
    final bool underReviewCurrent = status == 'under_review';
    final bool underReviewComplete =
        status == 'under_review' || status == 'submitted';

    final String heading = status == 'submitted'
        ? 'Verification received'
        : 'Verification in progress';
    final String subheading = status == 'submitted'
        ? 'We have received your documents and are preparing them for review.'
        : 'Your application is currently being reviewed by the admin team.';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Verification Review',
            style: GoogleFonts.poppins(
                color: _dark, fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading,
                        style: GoogleFonts.poppins(color: _grey, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(subheading,
                        style: GoogleFonts.poppins(color: _grey, fontSize: 14)),
                    const SizedBox(height: 48),
                    _buildTimelineStep('Submitted', 'Information received',
                        submittedComplete, status == 'submitted'),
                    _buildTimelineStep(
                        'Under Review',
                        'Admin team is checking your documents',
                        underReviewComplete,
                        underReviewCurrent),
                    _buildTimelineStep(
                        'Approved', 'Pending final sign-off', false, false,
                        isLast: true),
                    const SizedBox(height: 64),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _grey.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]),
                      child: Column(
                        children: [
                          const Icon(PhosphorIconsRegular.clock,
                              size: 32, color: _green),
                          const SizedBox(height: 16),
                          Text('Current stage',
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _dark)),
                          const SizedBox(height: 8),
                          Text(
                              status == 'submitted'
                                  ? 'Waiting for admin review.'
                                  : 'Your documents are currently under review.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  color: _grey, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(24),
                child: PrimaryButton(
                    text: 'Go to Dashboard',
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context, '/portal', (route) => false))),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(
      String title, String subtitle, bool isCompleted, bool isCurrent,
      {bool isLast = false}) {
    final Color color =
        isCompleted || isCurrent ? _green : _grey.withOpacity(0.3);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted || isCurrent ? color : Colors.transparent,
                  border: Border.all(color: color, width: 2)),
              child: isCompleted || isCurrent
                  ? const Icon(PhosphorIconsBold.check,
                      size: 14, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                  width: 2,
                  height: 50,
                  color: isCompleted && !isCurrent
                      ? color
                      : _grey.withOpacity(0.2)),
          ],
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? _dark : (isCompleted ? _dark : _grey))),
            const SizedBox(height: 4),
            Text(subtitle,
                style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
          ],
        )
      ],
    );
  }
}

class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: _green.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(PhosphorIconsFill.shieldCheck,
                      size: 80, color: _green)),
              const SizedBox(height: 32),
              Text('You\'re Verified!',
                  style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      letterSpacing: -0.5)),
              const SizedBox(height: 16),
              Text(
                  'Congratulations! Your account has been\nsuccessfully verified and upgraded.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: _grey, fontSize: 15, height: 1.5)),
              const Spacer(),
              PrimaryButton(
                  text: 'Back to Login',
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false))
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 7. SHARED COMPONENTS
// ==========================================
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool enabled;
  const PrimaryButton(
      {super.key,
      required this.text,
      required this.onPressed,
      this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          disabledBackgroundColor: _grey.withOpacity(0.2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32)), // Modern pill shape
          elevation: 0,
        ),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.white : _grey)),
      ),
    );
  }
}

class VerificationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String statusText;
  final bool isComplete;
  final VoidCallback? onTap;
  final bool hasError;
  final String? errorMessage;
  final Widget? previewWidget;

  const VerificationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.isComplete,
    this.onTap,
    this.hasError = false,
    this.errorMessage,
    this.previewWidget,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        hasError ? const Color(0xFFEF4444) : (isComplete ? _green : _dark);
    final borderColor = hasError
        ? const Color(0xFFFCA5A5)
        : (isComplete ? _green.withOpacity(0.5) : _grey.withOpacity(0.1));
    final bgColor = hasError ? const Color(0xFFFEF2F2) : _surface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: Icon(icon, color: statusColor, size: 24)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color:
                                  hasError ? const Color(0xFF991B1B) : _dark)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color:
                                  hasError ? const Color(0xFFEF4444) : _grey)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(hasError ? 'Retry' : statusText,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
              ],
            ),
            if (previewWidget != null) ...[
              const SizedBox(height: 16),
              previewWidget!,
            ],
            if (hasError && errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(PhosphorIconsRegular.warningCircle,
                        size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(errorMessage!,
                            style: GoogleFonts.poppins(
                                color: const Color(0xFF991B1B),
                                fontSize: 12,
                                fontWeight: FontWeight.w500))),
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

class SecureWatermark extends StatelessWidget {
  const SecureWatermark({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(PhosphorIconsRegular.lockKey, size: 16, color: _grey),
          const SizedBox(width: 8),
          Text('All information is secure and encrypted',
              style: GoogleFonts.poppins(
                  color: _grey, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class ModalUtils {
  static void showSuccess(BuildContext context, String message,
      {VoidCallback? onOk, Duration? autoClose}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsFill.checkCircle, color: _green, size: 64),
            const SizedBox(height: 16),
            Text('Success',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: _grey)),
            const SizedBox(height: 24),
            PrimaryButton(
                text: 'OK',
                onPressed: () {
                  Navigator.pop(ctx);
                  if (onOk != null) onOk();
                }),
          ],
        ),
      ),
    );
    if (autoClose != null) {
      Future.delayed(autoClose, () {
        if (Navigator.canPop(context)) {
          try {
            Navigator.pop(context);
          } catch (_) {}
          if (onOk != null)
            try {
              onOk();
            } catch (_) {}
        }
      });
    }
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
                color: Color(0xFFEF4444), size: 64),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: _grey)),
            const SizedBox(height: 24),
            PrimaryButton(text: 'Dismiss', onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  static void showProgress(BuildContext context, ValueNotifier<double> progress,
      {String? message, VoidCallback? onCancel}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (c, val, _) => CircularProgressIndicator(
                    value: val.clamp(0.0, 1.0), color: _green)),
            const SizedBox(height: 24),
            ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (c, val, _) => Text('${(val * 100).toInt()}%',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 18))),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: _grey))
            ],
            const SizedBox(height: 24),
            if (onCancel != null)
              TextButton(
                  onPressed: () {
                    try {
                      onCancel();
                    } catch (_) {}
                    Navigator.pop(ctx);
                  },
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(
                          color: _dark, fontWeight: FontWeight.w600)))
          ],
        ),
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  DashedRectPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 8, dashSpace = 6, startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(20));

    // Simplistic dash implementation for rectangle bounds
    Path path = Path()..addRRect(rrect);
    Path dashPath = Path();
    for (final measurePath in path.computeMetrics()) {
      double distance = 0;
      while (distance < measurePath.length) {
        dashPath.addPath(
            measurePath.extractPath(distance, distance + dashWidth),
            Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
