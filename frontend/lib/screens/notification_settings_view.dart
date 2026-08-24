import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsView extends StatefulWidget {
  const NotificationSettingsView({super.key});

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
    setState(() {
      _enableAllNotifications = prefs.getBool('enableAllNotifications') ?? true;
      _enableChatNotifications =
          prefs.getBool('enableChatNotifications') ?? true;
      _enableBookingUpdates = prefs.getBool('enableBookingUpdates') ?? true;
      _enablePromotions = prefs.getBool('enablePromotions') ?? false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    // If global notifications are disabled, unsubscribe from all topics
    if (key == 'enableAllNotifications' && !value) {
      await FCMService.instance.unsubscribeFromTopic('promotions');
      await FCMService.instance.unsubscribeFromTopic('updates');
    }
    
    // Apply FCM topic subscriptions based on settings
    if (key == 'enablePromotions') {
      if (value) {
        FCMService.instance.subscribeToTopic('promotions');
      } else {
        FCMService.instance.unsubscribeFromTopic('promotions');
      }
    }
    // Add more topic logic here for other notification types if applicable
  }

  Widget _buildToggleTile(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.gray900)),
      subtitle: Text(subtitle,
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.gray500)),
      value: value,
      onChanged: onChanged,
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
            (bool newValue) {
              setState(() => _enableAllNotifications = newValue);
              _saveSetting('enableAllNotifications', newValue);
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
            (bool newValue) {
              setState(() => _enablePromotions = newValue);
              _saveSetting('enablePromotions', newValue);
            },
          ),
        ],
      ),
    );
  }
}
