import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/services/fcm_service.dart';
import 'package:property_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsView extends StatefulWidget {
  final VoidCallback? onBack;

  const NotificationSettingsView({super.key, this.onBack});

  @override
  State<NotificationSettingsView> createState() =>
      _NotificationSettingsViewState();
}

class _NotificationSettingsViewState extends State<NotificationSettingsView> {
  bool _enableAllNotifications = true;
  bool _enableChatNotifications = true;
  bool _enableBookingUpdates = true;
  bool _enablePromotions = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> serverSettings = {};
    try {
      serverSettings = await AuthService.instance.fetchNotificationSettings();
    } catch (_) {
      // Local settings remain available if the account API cannot be reached.
    }
    if (!mounted) return;
    setState(() {
      _enableAllNotifications = serverSettings['push'] is bool
          ? serverSettings['push'] as bool
          : prefs.getBool('enableAllNotifications') ?? true;
      _enableChatNotifications =
          prefs.getBool('enableChatNotifications') ?? true;
      _enableBookingUpdates = prefs.getBool('enableBookingUpdates') ?? true;
      _enablePromotions = serverSettings['promotional_push'] is bool
          ? serverSettings['promotional_push'] as bool
          : prefs.getBool('enablePromotions') ?? false;
    });
  }

  Future<bool> _saveSetting(String key, bool value) async {
    try {
      if (key == 'enableAllNotifications') {
        await AuthService.instance.updateNotificationSettings({
          'push': value,
          if (!value) 'promotional_push': false,
        });
        if (!value) {
          try {
            await FCMService.instance.unsubscribeFromTopic('promotions');
            await FCMService.instance.unsubscribeFromTopic('updates');
          } catch (_) {}
        }
      } else if (key == 'enablePromotions') {
        await AuthService.instance.updateNotificationSettings({
          'promotional_push': value && _enableAllNotifications,
        });
        if (!value) {
          try {
            await FCMService.instance.unsubscribeFromTopic('promotions');
          } catch (_) {}
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
      return true;
    } catch (_) {
      return false;
    }
  }

  Widget _buildToggleTile(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged,
      {bool enabled = true}) {
    return SwitchListTile(
      title: Text(title,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.gray900)),
      subtitle: Text(subtitle,
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.gray500)),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
        leading: widget.onBack == null
            ? null
            : IconButton(
                tooltip: 'Back to profile',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: Text('Notification Settings',
            style: GoogleFonts.poppins(
                color: AppColors.gray900,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ),
      body: ListView(
        children: [
          _buildToggleTile(
            'Enable All Notifications',
            'Receive all types of alerts and updates.',
            _enableAllNotifications,
            (bool newValue) async {
              final previousAll = _enableAllNotifications;
              final previousPromotions = _enablePromotions;
              setState(() {
                _enableAllNotifications = newValue;
                if (!newValue) _enablePromotions = false;
              });
              final saved =
                  await _saveSetting('enableAllNotifications', newValue);
              if (!mounted) return;
              if (!saved) {
                setState(() {
                  _enableAllNotifications = previousAll;
                  _enablePromotions = previousPromotions;
                });
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Notification preference could not be saved.')),
                );
              }
            },
          ),
          _buildToggleTile(
            'Chat Messages',
            'Get alerts for new messages from landlords/tenants.',
            _enableChatNotifications,
            (bool newValue) {
              setState(() => _enableChatNotifications = newValue);
              _saveSetting('enableChatNotifications', newValue);
            },
          ),
          _buildToggleTile(
            'Booking Updates',
            'Receive status changes for your bookings.',
            _enableBookingUpdates,
            (bool newValue) {
              setState(() => _enableBookingUpdates = newValue);
              _saveSetting('enableBookingUpdates', newValue);
            },
          ),
          _buildToggleTile(
            'Promotional Offers',
            'Get updates on special deals and new features.',
            _enablePromotions,
            (bool newValue) async {
              final previous = _enablePromotions;
              setState(() => _enablePromotions = newValue);
              final saved = await _saveSetting('enablePromotions', newValue);
              if (!mounted) return;
              if (!saved) {
                setState(() => _enablePromotions = previous);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Promotional preference could not be saved.')),
                );
              }
            },
            enabled: _enableAllNotifications,
          ),
        ],
      ),
    );
  }
}
