import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/screens/landlord/verification_flow.dart';
import 'package:property_app/services/verification_api.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/repository/remote_database_repository.dart';

const Color _hostGreen = Color(0xFF10B981);
const Color _hostDark = Color(0xFF111827);
const Color _hostGrey = Color(0xFF6B7280);

class BecomeHostView extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSubmitted;
  final VoidCallback? onSwitchToLandlord;

  const BecomeHostView({
    super.key,
    this.onBack,
    this.onSubmitted,
    this.onSwitchToLandlord,
  });

  @override
  State<BecomeHostView> createState() => _BecomeHostViewState();
}

class _BecomeHostViewState extends State<BecomeHostView> {
  Map<String, dynamic>? _application;
  bool _isLoading = true;
  bool _isStarting = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadApplication();
  }

  Future<void> _loadApplication() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      try {
        final user = await RemoteDatabaseRepository().loadCurrentUser();
        AppSession.updateCurrentUser(user);
        await AppSession.persistSession();
      } catch (_) {
        // Verification status can still be viewed if profile refresh is unavailable.
      }
      final application = await VerificationApi.getVerificationStatus();
      if (!mounted) return;
      setState(() {
        _application = application;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  String get _status =>
      (_application?['status']?.toString() ?? 'not_started').toLowerCase();

  String get _statusLabel => switch (_status) {
        'draft' => 'Draft / Incomplete',
        'submitted' || 'pending_review' => 'Submitted',
        'under_review' || 'manual_review' => 'Under Review',
        'more_info_required' => 'More Information Required',
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        'cancelled' => 'Cancelled',
        _ => 'Not Started',
      };

  String get _statusMessage => switch (_status) {
        'draft' =>
          'Your progress is saved. Continue verification to submit it for review.',
        'submitted' =>
          'Your application has been received and is awaiting review.',
        'pending_review' ||
        'under_review' ||
        'manual_review' =>
          'Our team is reviewing your documents. You can keep using your tenant account while you wait.',
        'more_info_required' => _application?['admin_notes']
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
            ? _application!['admin_notes'].toString()
            : 'The review team needs more information. Update your documents and resubmit.',
        'approved' =>
          'Your host application is approved. Your tenant account and data remain available.',
        'rejected' => _application?['admin_notes']
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
            ? _application!['admin_notes'].toString()
            : 'Your application was not approved. You can review the reason and reapply.',
        'cancelled' =>
          'This application was cancelled. You can start a new application at any time.',
        _ =>
          'Verify your identity and provide proof that you own or are authorized to host the property before listing.',
      };

  String get _primaryAction => switch (_status) {
        'draft' || 'more_info_required' => 'Continue Verification',
        'approved' => 'Switch to Landlord Portal',
        'rejected' || 'cancelled' => 'Reapply',
        'submitted' ||
        'under_review' ||
        'pending_review' ||
        'manual_review' =>
          'View Application Status',
        _ => 'Start Verification',
      };

  bool get _canEdit => ![
        'submitted',
        'under_review',
        'pending_review',
        'manual_review',
        'approved'
      ].contains(_status);

  String _formatDate(dynamic raw) {
    if (raw == null) return 'Not submitted';
    final date = DateTime.tryParse(raw.toString())?.toLocal();
    if (date == null) return 'Not submitted';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _startOrContinue() async {
    if (!AppSession.isEmailVerified) {
      Navigator.pushNamed(context, '/otp');
      return;
    }
    if (_status == 'approved') {
      if (widget.onSwitchToLandlord != null) {
        widget.onSwitchToLandlord!();
      } else if (AppSession.hasLandlordAccess) {
        AppSession.setRole('landlord');
        await AppSession.persistSession();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/landlord', (route) => false);
        }
      }
      return;
    }
    if (!_canEdit) {
      await _loadApplication();
      return;
    }

    setState(() => _isStarting = true);
    try {
      final draft = await VerificationApi.saveDraft({
        'documents': _application?['documents'] is Map
            ? Map<String, dynamic>.from(_application!['documents'] as Map)
            : <String, dynamic>{},
        'property': _application?['property_data'] is Map
            ? Map<String, dynamic>.from(_application!['property_data'] as Map)
            : <String, dynamic>{},
      });
      if (!mounted) return;
      setState(() => _application = draft);
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (flowContext) => VerificationRequirementHub(
            session: VerificationSession.fromApplication(draft),
            onClose: () => Navigator.of(flowContext).pop(),
            onSubmitted: _handleSubmitted,
          ),
        ),
      );
      if (mounted) await _loadApplication();
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unable to open verification. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _handleSubmitted() {
    AppSession.notifyHostApplicationChanged();
    AppSession.setRole('tenant');
    AppSession.persistSession();
    if (widget.onSubmitted != null) {
      widget.onSubmitted!();
      return;
    }
    Navigator.of(context).popUntil(
      (route) => route.settings.name == '/home' || route.isFirst,
    );
  }

  Future<void> _cancelApplication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel host application?'),
        content: const Text(
            'Your saved documents will remain attached to this application.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep application'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel application'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await VerificationApi.cancelApplication();
      await _loadApplication();
      AppSession.notifyHostApplicationChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Unable to cancel this application. Please try again.')),
        );
      }
    }
  }

  Future<void> _dismissDraftReminders() async {
    try {
      await VerificationApi.dismissDraftReminders();
      await _loadApplication();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unable to dismiss reminders right now.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _status == 'approved'
        ? _hostGreen
        : _status == 'rejected'
            ? const Color(0xFFDC2626)
            : const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onBack ?? () => Navigator.maybePop(context),
          icon: const Icon(PhosphorIconsRegular.caretLeft, color: _hostDark),
        ),
        title: Text('Become a Host',
            style: GoogleFonts.poppins(
                color: _hostDark, fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Share your space on StayNest',
                          style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _hostDark)),
                      const SizedBox(height: 8),
                      Text(
                          'Reach people looking for a place to stay, manage requests in one place, and grow your hosting activity.',
                          style: GoogleFonts.poppins(
                              color: _hostGrey, height: 1.5)),
                      const SizedBox(height: 20),
                      const _HostRequirementRow(
                          icon: PhosphorIconsRegular.identificationCard,
                          text:
                              'Verify your identity with a government ID and selfie.'),
                      const SizedBox(height: 12),
                      const _HostRequirementRow(
                          icon: PhosphorIconsRegular.houseLine,
                          text:
                              'Provide a lease, title, or written owner authorization.'),
                      const SizedBox(height: 12),
                      const _HostRequirementRow(
                          icon: PhosphorIconsRegular.shieldCheck,
                          text:
                              'StayNest reviews your application before landlord features are enabled.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(color: _hostGreen),
                  ))
                else if (_hasError)
                  TextButton.icon(
                    onPressed: _loadApplication,
                    icon: const Icon(Icons.refresh),
                    label:
                        const Text('Could not load application status. Retry'),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Application status',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      color: _hostDark)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_statusLabel,
                                  style: GoogleFonts.poppins(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(_statusMessage,
                            style: GoogleFonts.poppins(
                                color: _hostGrey, height: 1.45)),
                        if (_application != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Submitted: ${_formatDate(_application!['submitted_at'])}',
                            style: GoogleFonts.poppins(
                                color: _hostGrey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isStarting ? null : _startOrContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: _hostGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isStarting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_primaryAction,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (_application != null &&
                      [
                        'draft',
                        'submitted',
                        'under_review',
                        'pending_review',
                        'manual_review',
                        'more_info_required'
                      ].contains(_status)) ...[
                    const SizedBox(height: 6),
                    TextButton(
                        onPressed: _cancelApplication,
                        child: const Text('Cancel application')),
                  ],
                  if (_status == 'draft')
                    TextButton(
                      onPressed: _dismissDraftReminders,
                      child: const Text('Dismiss completion reminders'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HostRequirementRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HostRequirementRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _hostGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(
                    color: _hostDark, fontSize: 13, height: 1.4)),
          ),
        ],
      );
}
