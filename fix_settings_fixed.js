const fs = require('fs');

const file = 'frontend/lib/screens/dashboard/landlord_settings_page.dart';
let text = fs.readFileSync(file, 'utf8');

const bankDetailsRegex = /class BankDetailsPage extends StatelessWidget \{[\s\S]*?\/\/ --- 5\. PRIVACY POLICY PAGE ---/m;
const bankDetailsReplacement = `class BankDetailsPage extends StatefulWidget {
  const BankDetailsPage({super.key});

  @override
  State<BankDetailsPage> createState() => _BankDetailsPageState();
}

class _BankDetailsPageState extends State<BankDetailsPage> {
  final _bankNameController = TextEditingController();
  final _holderController = TextEditingController();
  final _accountController = TextEditingController();
  final _routingController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = AppSession.currentUser;
    final bank = user['settings']?['bank_details'] ?? {};
    _bankNameController.text = bank['bank_name'] ?? '';
    _holderController.text = bank['account_holder'] ?? '';
    _accountController.text = bank['account_number'] ?? '';
    _routingController.text = bank['routing_number'] ?? '';
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final repo = RemoteDatabaseRepository();
      final updated = await repo.updateCurrentUser(update: {
        'settings': {
          ...(AppSession.currentUser['settings'] ?? {}),
          'bank_details': {
            'bank_name': _bankNameController.text.trim(),
            'account_holder': _holderController.text.trim(),
            'account_number': _accountController.text.trim(),
            'routing_number': _routingController.text.trim(),
          }
        }
      });
      AppSession.updateCurrentUser(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank details updated')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiResult.mapError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Bank Details',
      bottomNavigationBar: _buildSaveButton(
        context, 
        text: _isSaving ? "Saving..." : "Save Bank Details",
        onPressed: _isSaving ? null : _handleSave,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          children: [
            _GlassContainer(
              padding: const EdgeInsets.all(16),
              opacity: 0.8,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(PhosphorIcons.info(PhosphorIconsStyle.fill),
                        color: const Color(0xFF059669), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'These details will be used to process your rental payouts.',
                      style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF374151)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField('Bank Name',
                controller: _bankNameController,
                hintText: 'e.g. Chase Bank', prefixIcon: PhosphorIcons.bank()),
            _buildTextField('Account Holder Name',
                controller: _holderController,
                hintText: 'Jomison Real Estate'),
            _buildTextField('Account Number', controller: _accountController, hintText: '1234567890'),
            _buildTextField('Routing Number', controller: _routingController, hintText: '098765432'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// --- 5. PRIVACY POLICY PAGE ---`;

text = text.replace(bankDetailsRegex, bankDetailsReplacement);

const notifRegex = /class _NotificationSettingsPageState extends State<NotificationSettingsPage> \{[\s\S]*?Widget _buildSectionHeader/m;
const notifReplacement = `class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool emailNewBooking = true;
  bool emailMessages = true;
  bool pushNewBooking = true;
  bool pushMessages = false;
  bool smsAlerts = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = AppSession.currentUser;
    final notifs = user['settings']?['notifications'] ?? {};
    emailNewBooking = notifs['email_new_booking'] ?? true;
    emailMessages = notifs['email_messages'] ?? true;
    pushNewBooking = notifs['push_new_booking'] ?? true;
    pushMessages = notifs['push_messages'] ?? false;
    smsAlerts = notifs['sms_alerts'] ?? false;
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final repo = RemoteDatabaseRepository();
      final updated = await repo.updateCurrentUser(update: {
        'settings': {
          ...(AppSession.currentUser['settings'] ?? {}),
          'notifications': {
            'email_new_booking': emailNewBooking,
            'email_messages': emailMessages,
            'push_new_booking': pushNewBooking,
            'push_messages': pushMessages,
            'sms_alerts': smsAlerts,
          }
        }
      });
      AppSession.updateCurrentUser(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings updated')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiResult.mapError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: 'Notifications',
      bottomNavigationBar: _buildSaveButton(
        context,
        text: _isSaving ? "Saving..." : "Save Settings",
        onPressed: _isSaving ? null : _handleSave,
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          _buildSectionHeader('Email Notifications'),
          _buildSwitchTile(
              'New Bookings',
              'Get notified when a new booking is made',
              emailNewBooking,
              (v) => setState(() => emailNewBooking = v)),
          _buildSwitchTile(
              'New Messages',
              'Get notified of new tenant messages',
              emailMessages,
              (v) => setState(() => emailMessages = v)),
          const SizedBox(height: 16),
          _buildSectionHeader('Push Notifications'),
          _buildSwitchTile('New Bookings', 'Push alerts for new bookings',
              pushNewBooking, (v) => setState(() => pushNewBooking = v)),
          _buildSwitchTile('New Messages', 'Push alerts for new messages',
              pushMessages, (v) => setState(() => pushMessages = v)),
          const SizedBox(height: 16),
          _buildSectionHeader('SMS Notifications'),
          _buildSwitchTile(
              'Critical Alerts',
              'Important account or booking updates via SMS',
              smsAlerts,
              (v) => setState(() => smsAlerts = v)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader`;

text = text.replace(notifRegex, notifReplacement);
fs.writeFileSync(file, text, 'utf8');
console.log('Fixed landlord_settings_page.dart');
