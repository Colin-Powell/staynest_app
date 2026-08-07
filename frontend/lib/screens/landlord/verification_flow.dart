// lib/screens/verification_center.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/mdi.dart';

import 'package:property_app/session/app_session.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/services/uploads.dart';
import 'package:property_app/services/verification_api.dart';

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
    if (proofOfAddress != null) completed++;
    if (utilityBill != null) completed++;
    if (leaseAgreement != null) completed++;
    if (propertyPhotos != null) completed++;
    return completed / 7;
  }

  Map<String, dynamic> toDocumentsMap() => {
        if (idPhotoFrontUrl != null) 'id_photo_front': idPhotoFrontUrl,
        if (idPhotoBackUrl != null) 'id_photo_back': idPhotoBackUrl,
        if (selfieUrl != null) 'selfie': selfieUrl,
        if (proofOfAddressUrl != null) 'proof_of_address': proofOfAddressUrl,
        if (utilityBillUrl != null) 'utility_bill': utilityBillUrl,
        if (leaseAgreementUrl != null) 'lease_agreement': leaseAgreementUrl,
        if (propertyPhotosUrl != null) 'property_photos': propertyPhotosUrl,
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
    if (!AppSession.isLandlord) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.gray900),
          title: Text('Access Denied',
              style: GoogleFonts.poppins(
                  color: AppColors.gray900,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Verification center is available for landlords only.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: AppColors.gray700,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
        title: Text('Verification Center',
            style: GoogleFonts.poppins(
                color: AppColors.gray900,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Iconify(Mdi.shield_check,
                        size: 120, color: AppColors.primary),
                    const SizedBox(height: 24),
                    Text(
                        'Complete verification to build trust with\ntenants and get higher visibility',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: AppColors.gray500,
                            height: 1.4)),
                    const SizedBox(height: 48),
                    _buildFeature(
                        PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                        'Verified Badge',
                        'Show tenants you are trustworthy'),
                    _buildFeature(PhosphorIcons.eye(PhosphorIconsStyle.fill),
                        'Higher Visibility', 'Get featured in more searches'),
                    _buildFeature(
                        PhosphorIcons.lightning(PhosphorIconsStyle.fill),
                        'Faster Bookings',
                        'Verified landlords get more bookings'),
                    _buildFeature(
                        PhosphorIcons.lockKey(PhosphorIconsStyle.fill),
                        'Secure Platform',
                        'We protect you and your tenants'),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
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
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VerificationStatusView(
                                statusData: {'status': 'submitted'}))),
                    child: Text('View Verification Status',
                        style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/portal'),
                    child: Text('Skip for now (Admin Approval Required)',
                        style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontSize: 14,
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
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        children: [
          Icon(icon, size: 36, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray900)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.gray500)),
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
    int propDocs = widget.session.utilityBill != null ? 1 : 0;
    String progressStr = '${(widget.session.progress * 100).toInt()}%';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
        toolbarHeight: 100,
        title: Text('Verification\nRequirement',
            style: GoogleFonts.poppins(
                color: AppColors.gray900,
                fontWeight: FontWeight.bold,
                fontSize: 24,
                height: 1.2)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Complete all steps to get verified',
                        style: GoogleFonts.poppins(
                            color: AppColors.gray500, fontSize: 16)),
                    const SizedBox(height: 32),
                    VerificationCard(
                      icon: PhosphorIcons.identificationCard(),
                      iconColor:
                          idDocs == 3 ? AppColors.green600 : AppColors.primary,
                      title: 'Identity Verification',
                      subtitle: 'Verify your identity you\'re human',
                      statusText: '$idDocs/3',
                      statusColor: idDocs == 3
                          ? AppColors.green600
                          : StayNestColors.warning,
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
                    VerificationCard(
                      icon: PhosphorIcons.buildings(),
                      iconColor: propDocs >= 1
                          ? AppColors.green600
                          : StayNestColors.warning,
                      title: 'Property Verification',
                      subtitle: 'Prove property ownership',
                      statusText: '$propDocs/3',
                      statusColor: propDocs >= 1
                          ? AppColors.green600
                          : StayNestColors.warning,
                      hasError: widget.session.adminRejections
                          .containsKey('property'),
                      errorMessage: widget.session.adminRejections['property'],
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => VerificationStepFlow(
                                    session: widget.session, initialPage: 1)));
                        setState(() {});
                      },
                    ),
                    VerificationCard(
                      icon: PhosphorIcons.storefront(),
                      iconColor: AppColors.gray400,
                      title: 'Business Verification',
                      subtitle: 'Verify your business details',
                      statusText: '0/2',
                      statusColor: AppColors.gray400,
                    ),
                    const SizedBox(height: 32),
                    Text('Overall Progress',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.gray900)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: LinearProgressIndicator(
                                value: widget.session.progress,
                                backgroundColor: StayNestColors.outlineLight,
                                color: AppColors.primary,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4))),
                        const SizedBox(width: 16),
                        Text(progressStr,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                color: AppColors.gray900)),
                      ],
                    ),
                    const SizedBox(height: 40),
                    PrimaryButton(
                        text: 'Start Verification',
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => VerificationStepFlow(
                                    session: widget.session)))),
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
      widget.session.selfie != null &&
      widget.session.proofOfAddress != null;
  bool get _propertyComplete =>
      widget.session.utilityBill != null &&
      widget.session.propertyPhotos != null;
  bool get _allPagesComplete => _identityComplete && _propertyComplete;

  Future<void> _goNext() async {
    if (_currentPage == 0) {
      if (!_identityComplete) {
        ModalUtils.showError(context, 'Incomplete Step',
            'Please upload all required identity documents before continuing.');
        return;
      }
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.ease);
      return;
    }

    if (!_allPagesComplete) {
      ModalUtils.showError(context, 'Complete All Pages',
          'Finish the required property verification steps before review.');
      return;
    }

    try {
      final payload = {
        'documents': widget.session.toDocumentsMap(),
        'property': {}
      };
      final resp = await VerificationApi.submitVerification(payload);
      final data = resp['data'] ?? resp;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => VerificationStatusView(
                  statusData: data ?? {'status': 'submitted'})));
    } catch (e) {
      ModalUtils.showError(context, 'Submission Failed',
          'Something went wrong while submitting your documents. Please try again later.');
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.ease);
      return;
    }
    Navigator.pop(context);
  }

  // Network Upload Wrapper Function
  Future<void> _handleUpload(
      File file, String type, Function(String url) onSuccess) async {
    final progress = ValueNotifier<double>(0.0);
    final task =
        UploadsService.uploadFileWithProgress(file, (p) => progress.value = p);
    ModalUtils.showProgress(context, progress,
        message: 'Uploading document...', onCancel: () => task.cancel());
    try {
      final url = await task.future;
      onSuccess(url);
      if (mounted) Navigator.pop(context); // close progress dialog
      ModalUtils.showSuccess(context, 'Document uploaded successfully!',
          onOk: () => Navigator.pop(context),
          autoClose: const Duration(milliseconds: 1200));
    } catch (e) {
      if (mounted) Navigator.pop(context); // close progress dialog
      if (e is UploadCancelledException) {
        ModalUtils.showCancelled(context);
      } else {
        ModalUtils.showError(context, 'Upload Failed',
            'We couldn\'t upload your document. Please check your connection and try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
        title: Text(
            _currentPage == 0
                ? 'Identity Verification'
                : 'Property Verification',
            style: GoogleFonts.poppins(
                color: AppColors.gray900,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Step ${_currentPage + 1} of 2',
                      style: GoogleFonts.poppins(
                          color: AppColors.gray500, fontSize: 14)),
                  Text('${(widget.session.progress * 100).toInt()}% complete',
                      style: GoogleFonts.poppins(
                          color: AppColors.gray500, fontSize: 14)),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() {
                  _currentPage = index;
                }),
                children: [_buildIdentityPage(), _buildPropertyPage()],
              ),
            ),
            const SecureWatermark(),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                        child: OutlinedButton(
                            onPressed: _goBack,
                            style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.primary),
                                shape: const RoundedRectangleBorder(
                                    borderRadius: AppRadius.buttonBorderRadius),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16)),
                            child: Text('Back',
                                style: GoogleFonts.poppins(
                                    color: AppColors.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)))),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                      child: PrimaryButton(
                          text: _currentPage == 0
                              ? 'Next'
                              : 'Review Verification',
                          enabled: _currentPage == 0
                              ? _identityComplete
                              : _allPagesComplete,
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload Your Identity documents',
              style:
                  GoogleFonts.poppins(color: AppColors.gray500, fontSize: 16)),
          const SizedBox(height: 32),
          VerificationCard(
            icon: PhosphorIcons.identificationCard(),
            iconColor: widget.session.idPhotoFront != null
                ? AppColors.green600
                : AppColors.gray400,
            title: 'National ID (Front)',
            subtitle: 'Clear photo of the front',
            statusText:
                widget.session.idPhotoFront != null ? 'Approved' : 'Upload',
            statusColor: widget.session.idPhotoFront != null
                ? AppColors.green600
                : AppColors.primary,
            hasError:
                widget.session.adminRejections.containsKey('idPhotoFront'),
            errorMessage: widget.session.adminRejections['idPhotoFront'],
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
            icon: PhosphorIcons.identificationCard(),
            iconColor: widget.session.idPhotoBack != null
                ? AppColors.green600
                : AppColors.gray400,
            title: 'National ID (Back)',
            subtitle: 'Clear photo of the back',
            statusText:
                widget.session.idPhotoBack != null ? 'Approved' : 'Upload',
            statusColor: widget.session.idPhotoBack != null
                ? AppColors.green600
                : AppColors.primary,
            hasError: widget.session.adminRejections.containsKey('idPhotoBack'),
            errorMessage: widget.session.adminRejections['idPhotoBack'],
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
            icon: PhosphorIcons.userFocus(),
            iconColor: widget.session.selfie != null
                ? AppColors.green600
                : AppColors.gray400,
            title: 'Selfie with ID',
            subtitle: 'Live face verification',
            statusText: widget.session.selfie != null ? 'Approved' : 'Pending',
            statusColor: widget.session.selfie != null
                ? AppColors.green600
                : StayNestColors.warning,
            hasError: widget.session.adminRejections.containsKey('selfie'),
            errorMessage: widget.session.adminRejections['selfie'],
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
          VerificationCard(
            icon: PhosphorIcons.mapPin(),
            iconColor: widget.session.proofOfAddress != null
                ? AppColors.green600
                : AppColors.gray400,
            title: 'Proof of address',
            subtitle: 'Utility bill or bank statement',
            statusText:
                widget.session.proofOfAddress != null ? 'Approved' : 'Upload',
            statusColor: widget.session.proofOfAddress != null
                ? AppColors.green600
                : AppColors.primary,
            hasError:
                widget.session.adminRejections.containsKey('proofOfAddress'),
            errorMessage: widget.session.adminRejections['proofOfAddress'],
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DocumentCapture(
                            title: 'Proof of address',
                            subtitle: 'Must be dated within last 3 months',
                            onFileCaptured: (file) async {
                              widget.session.proofOfAddress = file;
                              widget.session.adminRejections
                                  .remove('proofOfAddress');
                              setState(() {});
                              await _handleUpload(
                                  file,
                                  'proofOfAddress',
                                  (url) =>
                                      widget.session.proofOfAddressUrl = url);
                            },
                          )));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload property documents',
              style:
                  GoogleFonts.poppins(color: AppColors.gray500, fontSize: 16)),
          const SizedBox(height: 32),
          VerificationCard(
            icon: PhosphorIcons.fileText(),
            iconColor: AppColors.green600,
            title: 'Title Deed / Ownership',
            subtitle: 'Verified automatically',
            statusText: 'Approved',
            statusColor: AppColors.green600,
            onTap: () {},
          ),
          VerificationCard(
            icon: PhosphorIcons.receipt(),
            iconColor: widget.session.utilityBill != null
                ? AppColors.green600
                : StayNestColors.warning,
            title: 'Utility Bill',
            subtitle: 'Recent utility bill (2 months)',
            statusText:
                widget.session.utilityBill != null ? 'Approved' : 'Pending',
            statusColor: widget.session.utilityBill != null
                ? AppColors.green600
                : StayNestColors.warning,
            hasError: widget.session.adminRejections.containsKey('utilityBill'),
            errorMessage: widget.session.adminRejections['utilityBill'],
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DocumentCapture(
                          title: 'Utility Bill',
                          subtitle: 'Upload clear photo',
                          onFileCaptured: (f) async {
                            widget.session.utilityBill = f;
                            widget.session.adminRejections
                                .remove('utilityBill');
                            setState(() {});
                            await _handleUpload(f, 'utilityBill',
                                (url) => widget.session.utilityBillUrl = url);
                          })));
            },
          ),
          VerificationCard(
            icon: PhosphorIcons.signature(),
            iconColor: widget.session.leaseAgreement != null
                ? AppColors.green600
                : AppColors.gray400,
            title: 'Lease Agreement',
            subtitle: 'If applicable',
            statusText:
                widget.session.leaseAgreement != null ? 'Approved' : 'Upload',
            statusColor: widget.session.leaseAgreement != null
                ? AppColors.green600
                : AppColors.primary,
            hasError:
                widget.session.adminRejections.containsKey('leaseAgreement'),
            errorMessage: widget.session.adminRejections['leaseAgreement'],
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DocumentCapture(
                          title: 'Lease Agreement',
                          subtitle: 'Signed copy required',
                          onFileCaptured: (f) async {
                            widget.session.leaseAgreement = f;
                            widget.session.adminRejections
                                .remove('leaseAgreement');
                            setState(() {});
                            await _handleUpload(
                                f,
                                'leaseAgreement',
                                (url) =>
                                    widget.session.leaseAgreementUrl = url);
                          })));
            },
          ),
          VerificationCard(
            icon: PhosphorIcons.houseLine(),
            iconColor: widget.session.propertyPhotos != null
                ? AppColors.green600
                : AppColors.gray400,
            title: 'Property Photos',
            subtitle: 'Exterior photo of property',
            statusText:
                widget.session.propertyPhotos != null ? 'Approved' : 'Upload',
            statusColor: widget.session.propertyPhotos != null
                ? AppColors.green600
                : AppColors.primary,
            hasError:
                widget.session.adminRejections.containsKey('propertyPhotos'),
            errorMessage: widget.session.adminRejections['propertyPhotos'],
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DocumentCapture(
                          title: 'Property Photos',
                          subtitle: 'Show full facade',
                          onFileCaptured: (f) async {
                            widget.session.propertyPhotos = f;
                            widget.session.adminRejections
                                .remove('propertyPhotos');
                            setState(() {});
                            await _handleUpload(
                                f,
                                'propertyPhotos',
                                (url) =>
                                    widget.session.propertyPhotosUrl = url);
                          })));
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
class DocumentCapture extends StatelessWidget {
  final String title;
  final String subtitle;
  final ValueChanged<File> onFileCaptured;

  const DocumentCapture(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.onFileCaptured});

  Future<void> _pickAndCropImage(BuildContext context) async {
    const int maxBytes = 5 * 1024 * 1024;
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      final fileSize = await picked.length();
      if (fileSize > maxBytes) {
        ModalUtils.showError(
            context, 'File Too Large', 'Selected file exceeds the 5MB limit.');
        return;
      }

      File? finalFile;
      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: picked.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Adjust Document',
              toolbarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
              aspectRatioPresets: [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9
              ],
            ),
            IOSUiSettings(
              title: 'Adjust Document',
              aspectRatioPresets: [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9
              ],
            ),
          ],
        );
        if (croppedFile != null) {
          finalFile = File(croppedFile.path);
        } else {
          return;
        }
      } catch (_) {
        finalFile = File(picked.path);
      }

      onFileCaptured(finalFile);
      if (!context.mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ModalUtils.showError(context, 'Process Error',
          "We couldn't prepare your photo. Please try again or select a different image.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
        title: Text('Upload Document',
            style: GoogleFonts.poppins(
                color: AppColors.gray900,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gray900)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: GoogleFonts.poppins(
                            color: AppColors.gray500, fontSize: 16)),
                    const SizedBox(height: 40),
                    CustomPaint(
                      painter:
                          DashedRectPainter(color: StayNestColors.outlineLight),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.02)),
                        child: Column(
                          children: [
                            Icon(PhosphorIcons.cloudArrowUp(),
                                size: 64, color: AppColors.gray400),
                            const SizedBox(height: 16),
                            Text('Drag and drop or',
                                style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.gray900)),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () => _pickAndCropImage(context),
                              style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.primary),
                                  shape: const RoundedRectangleBorder(
                                      borderRadius:
                                          AppRadius.buttonBorderRadius),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 12)),
                              child: Text('Choose File',
                                  style: GoogleFonts.poppins(
                                      color: AppColors.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 16),
                            Text('JPG or PNG. Max size 5MB',
                                style: GoogleFonts.poppins(
                                    color: AppColors.gray400, fontSize: 14)),
                          ],
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
  final ValueChanged<File> onFileCaptured;
  const SelfieCaptureScreen({super.key, required this.onFileCaptured});
  @override
  State<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen> {
  File? _capturedImage;
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _initializingCamera = false;

  Future<void> _takeSelfie() async {
    const int maxBytes = 5 * 1024 * 1024;
    try {
      XFile? xfile;
      if (_cameraReady &&
          _cameraController != null &&
          _cameraController!.value.isInitialized) {
        xfile = await _cameraController!.takePicture();
      } else {
        xfile = await ImagePicker().pickImage(
            source: ImageSource.camera,
            imageQuality: 70,
            preferredCameraDevice: CameraDevice.front);
      }
      if (xfile == null) return;

      final fileSize = await xfile.length();
      if (fileSize > maxBytes) {
        ModalUtils.showError(context, 'File Too Large',
            'Selfie exceeds the 5MB limit. Please retake a smaller image.');
        return;
      }

      final imageFile = File(xfile.path);
      if (!await imageFile.exists()) {
        ModalUtils.showError(
            context, 'Capture Error', 'Unable to access the selfie file.');
        return;
      }

      setState(() {
        _capturedImage = imageFile;
      });
      widget.onFileCaptured(_capturedImage!);
      if (!mounted) return;
      Navigator.pop(context); // Close the capture screen
    } catch (e) {
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
          orElse: () => cameras.isNotEmpty
              ? cameras.first
              : throw Exception('No cameras available'));
      _cameraController =
          CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
      });
    } catch (_) {
      setState(() {
        _cameraReady = false;
      });
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
        title: Text('Selfie Verification',
            style: GoogleFonts.poppins(
                color: AppColors.gray900,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Take a selfie',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gray900)),
                    const SizedBox(height: 4),
                    Text('Position your face in the frame',
                        style: GoogleFonts.poppins(
                            color: AppColors.gray500, fontSize: 16)),
                    const SizedBox(height: 40),
                    Center(
                      child: Container(
                        height: 320,
                        width: 320,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gray400.withValues(alpha: 0.3)),
                        clipBehavior: Clip.hardEdge,
                        child: _capturedImage != null
                            ? Image.file(_capturedImage!, fit: BoxFit.cover)
                            : (_cameraReady && _cameraController != null
                                ? CameraPreview(_cameraController!)
                                : Center(
                                    child: Icon(
                                        PhosphorIcons.userFocus(
                                            PhosphorIconsStyle.light),
                                        size: 100,
                                        color: AppColors.gray500))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: PrimaryButton(
                    text: 'Capture Selfie', onPressed: _takeSelfie))
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. STATUS VIEWS & NEW REJECTED SCREEN
// ==========================================
class VerificationStatusView extends StatelessWidget {
  final Map<String, dynamic> statusData;
  const VerificationStatusView({super.key, required this.statusData});

  @override
  Widget build(BuildContext context) {
    final status =
        statusData['status']?.toString().toLowerCase() ?? 'submitted';

    if (status == 'approved') {
      AppSession.currentRole = 'landlord';
      AppSession.currentUserVerified = true;
      if (statusData['user'] is Map<String, dynamic>) {
        AppSession.updateCurrentUser(statusData['user']);
      }
      return const _SuccessScreen();
    } else if (status == 'rejected' || status == 'action_required') {
      return _RejectedScreen(rejections: statusData['reasons'] ?? []);
    }
    return const _ReviewScreen();
  }
}

class _RejectedScreen extends StatelessWidget {
  final List<dynamic> rejections;
  const _RejectedScreen({required this.rejections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                        size: 120, color: StayNestColors.error),
                    const SizedBox(height: 24),
                    Text('Action Required',
                        style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gray900)),
                    const SizedBox(height: 16),
                    Text(
                        'We couldn\'t verify your account. Please fix the following issues and resubmit.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            color: AppColors.gray500,
                            fontSize: 16,
                            height: 1.5)),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                          color: StayNestColors.errorLight,
                          borderRadius: AppRadius.cardBorderRadius,
                          border: Border.all(
                              color:
                                  StayNestColors.error.withValues(alpha: 0.3))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Notes:',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: StayNestColors.error)),
                          const SizedBox(height: 12),
                          ...(rejections.isEmpty
                                  ? [
                                      'Certain documents were unclear or missing.'
                                    ]
                                  : rejections)
                              .map((msg) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ',
                                            style: TextStyle(
                                                color: StayNestColors.error,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                        Expanded(
                                            child: Text(msg.toString(),
                                                style: GoogleFonts.poppins(
                                                    color: StayNestColors.error,
                                                    fontSize: 14))),
                                      ],
                                    ),
                                  )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: PrimaryButton(
                    text: 'Fix & Resubmit',
                    onPressed: () => Navigator.pop(context)))
          ],
        ),
      ),
    );
  }
}

class _ReviewScreen extends StatelessWidget {
  const _ReviewScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Verification Review',
            style: GoogleFonts.poppins(
                color: AppColors.gray900,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Review your information',
                        style: GoogleFonts.poppins(
                            color: AppColors.gray500, fontSize: 16)),
                    const SizedBox(height: 32),
                    _buildTimelineStep('Submitted', 'May 17, 2026 10:30AM',
                        true, false, AppColors.green600),
                    _buildTimelineStep('Under Review', 'May 17, 2026 11:45 AM',
                        false, true, AppColors.primary),
                    _buildTimelineStep('Manual Review', 'Pending', false, false,
                        AppColors.gray400),
                    _buildTimelineStep(
                        'Approved', 'Pending', false, false, AppColors.gray400,
                        isLast: true),
                    const SizedBox(height: 40),
                    Text('Estimated Completion',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gray900)),
                    const SizedBox(height: 8),
                    Text('1-2 business days',
                        style: GoogleFonts.poppins(
                            color: AppColors.gray500, fontSize: 16)),
                    const SizedBox(height: 40),
                    Center(
                        child: Text(
                            'You\'ll receive a notification once your verification is\ncomplete',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                color: AppColors.gray500,
                                fontSize: 14,
                                height: 1.5))),
                  ],
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: PrimaryButton(
                    text: 'Continue to Portal',
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context, '/portal', (route) => false))),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(String title, String subtitle, bool isCompleted,
      bool isCurrent, Color color,
      {bool isLast = false}) {
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
                  ? Icon(PhosphorIcons.check(),
                      size: 14, color: AppColors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                  width: 2,
                  height: 60,
                  color: isCompleted && !isCurrent
                      ? color
                      : StayNestColors.outlineLight),
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
                    color: AppColors.gray900)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.gray500)),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text('Verification Status',
              style: GoogleFonts.poppins(
                  color: AppColors.gray900,
                  fontWeight: FontWeight.bold,
                  fontSize: 20))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                        size: 120, color: AppColors.green600),
                    const SizedBox(height: 24),
                    Text('You\'re Verified!',
                        style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gray900)),
                    const SizedBox(height: 16),
                    Text(
                        'Congratulations! Your account has been\nsuccessfully verified',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            color: AppColors.gray500,
                            fontSize: 16,
                            height: 1.5)),
                    const SizedBox(height: 48),
                    _buildFeature(
                        PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                        'Verified Badge',
                        'Your profile is now verified',
                        AppColors.green600),
                    _buildFeature(
                        PhosphorIcons.headset(PhosphorIconsStyle.fill),
                        'Priority Support',
                        'Get priority customer support',
                        AppColors.primary),
                    _buildFeature(
                        PhosphorIcons.eye(PhosphorIconsStyle.fill),
                        'Higher Visibility',
                        'Verified landlords get more bookings',
                        AppColors.primary),
                  ],
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: PrimaryButton(
                    text: 'Go to Dashboard',
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst)))
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(
      IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray900)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.gray500)),
              ]))
        ],
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
          backgroundColor: enabled ? AppColors.primary : AppColors.gray400,
          shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.buttonBorderRadius),
          elevation: 0,
        ),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white)),
      ),
    );
  }
}

class VerificationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String statusText;
  final Color statusColor;
  final VoidCallback? onTap;
  final bool hasError;
  final String? errorMessage;

  const VerificationCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.statusColor,
    this.onTap,
    this.hasError = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final activeIconColor = hasError ? StayNestColors.error : iconColor;
    final activeBorderColor =
        hasError ? StayNestColors.error : StayNestColors.outlineLight;
    final activeBgColor =
        hasError ? StayNestColors.errorLight : AppColors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.base),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
            color: activeBgColor,
            borderRadius: AppRadius.cardBorderRadius,
            border: Border.all(color: activeBorderColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: activeIconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: activeIconColor, size: 32)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: hasError
                                  ? StayNestColors.error
                                  : AppColors.gray900)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: hasError
                                  ? StayNestColors.error
                                  : AppColors.gray500)),
                    ],
                  ),
                ),
                Text(hasError ? 'Retry' : statusText,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: hasError ? StayNestColors.error : statusColor)),
              ],
            ),
            if (hasError && errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.warning(),
                        size: 16, color: StayNestColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(errorMessage!,
                            style: GoogleFonts.poppins(
                                color: StayNestColors.error,
                                fontSize: 13,
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.squaresFour(),
              size: 16, color: AppColors.gray500.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text('All information is secure and encrypted',
              style:
                  GoogleFonts.poppins(color: AppColors.gray500, fontSize: 13)),
        ],
      ),
    );
  }
}

class ModalUtils {
  static void showSuccess(BuildContext context, String message,
      {required VoidCallback onOk, Duration? autoClose}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.dialogBorderRadius),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                color: AppColors.green600, size: 64),
            const SizedBox(height: 16),
            Text('Success',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray900)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: AppColors.gray500)),
            const SizedBox(height: 24),
            PrimaryButton(
                text: 'OK',
                onPressed: () {
                  Navigator.pop(ctx);
                  onOk();
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
          try {
            onOk();
          } catch (_) {}
        }
      });
    }
  }

  static void showCancelled(BuildContext context, {String? message}) {
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
                color: AppColors.gray400, size: 64),
            const SizedBox(height: 16),
            Text('Upload Cancelled',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray900)),
            const SizedBox(height: 8),
            Text(message ?? 'The upload was cancelled.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: AppColors.gray500)),
            const SizedBox(height: 24),
            PrimaryButton(text: 'OK', onPressed: () => Navigator.pop(ctx)),
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
                color: StayNestColors.error, size: 64),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray900)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: AppColors.gray500)),
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
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.dialogBorderRadius),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (c, val, _) =>
                    CircularProgressIndicator(value: val.clamp(0.0, 1.0))),
            const SizedBox(height: 16),
            ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (c, val, _) => Text('${(val * 100).toInt()}%')),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: AppColors.gray500))
            ],
            const SizedBox(height: 12),
            if (onCancel != null)
              TextButton(
                  onPressed: () {
                    try {
                      onCancel();
                    } catch (_) {}
                    Navigator.pop(ctx);
                  },
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(color: AppColors.primary)))
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
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      canvas.drawLine(Offset(startX, size.height),
          Offset(startX + dashWidth, size.height), paint);
      startX += dashWidth + dashSpace;
    }
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), paint);
      canvas.drawLine(Offset(size.width, startY),
          Offset(size.width, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
