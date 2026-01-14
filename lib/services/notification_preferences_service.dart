import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage user notification preferences
class NotificationPreferencesService {
  static const String _keyPrefix = 'notification_preferences_';
  
  /// Default preferences - all enabled by default
  static const Map<String, bool> _defaultPreferences = {
    'email': true,
    'sms': true,
    'inApp': true,
  };

  /// Get notification preferences for the current user
  static Future<Map<String, bool>> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      // Return defaults if no user
      return Map<String, bool>.from(_defaultPreferences);
    }
    
    final userId = user.uid;
    final emailKey = '$_keyPrefix${userId}_email';
    final smsKey = '$_keyPrefix${userId}_sms';
    final inAppKey = '$_keyPrefix${userId}_inApp';
    
    return {
      'email': prefs.getBool(emailKey) ?? _defaultPreferences['email']!,
      'sms': prefs.getBool(smsKey) ?? _defaultPreferences['sms']!,
      'inApp': prefs.getBool(inAppKey) ?? _defaultPreferences['inApp']!,
    };
  }

  /// Save notification preferences for the current user
  static Future<void> savePreferences({
    required bool email,
    required bool sms,
    required bool inApp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      throw Exception('User must be logged in to save preferences');
    }
    
    final userId = user.uid;
    await prefs.setBool('$_keyPrefix${userId}_email', email);
    await prefs.setBool('$_keyPrefix${userId}_sms', sms);
    await prefs.setBool('$_keyPrefix${userId}_inApp', inApp);
  }

  /// Check if a specific notification type is enabled
  static Future<bool> isEnabled(String type) async {
    final preferences = await getPreferences();
    return preferences[type.toLowerCase()] ?? false;
  }

  /// Check if email notifications are enabled
  static Future<bool> isEmailEnabled() async {
    return await isEnabled('email');
  }

  /// Check if SMS notifications are enabled
  static Future<bool> isSmsEnabled() async {
    return await isEnabled('sms');
  }

  /// Check if in-app notifications are enabled
  static Future<bool> isInAppEnabled() async {
    return await isEnabled('inApp');
  }
}













