import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/services/notification_preferences_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  bool _emailEnabled = true;
  bool _smsEnabled = true;
  bool _inAppEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      final preferences = await NotificationPreferencesService.getPreferences();
      setState(() {
        _emailEnabled = preferences['email'] ?? true;
        _smsEnabled = preferences['sms'] ?? true;
        _inAppEnabled = preferences['inApp'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.errorLoadingPreferences} $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      await NotificationPreferencesService.savePreferences(
        email: _emailEnabled,
        sms: _smsEnabled,
        inApp: _inAppEnabled,
      );
      
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.preferencesSaved),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.errorSavingPreferences}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.notificationPreferences),
        backgroundColor: const Color(0xFF004d4d),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            loc.notificationPreferencesDesc,
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email Notifications
                  _buildPreferenceCard(
                    icon: Icons.email,
                    iconColor: Colors.red,
                    title: loc.emailNotifications,
                    description: loc.emailNotificationsDesc,
                    value: _emailEnabled,
                    onChanged: (value) {
                      setState(() => _emailEnabled = value);
                      _savePreferences();
                    },
                  ),
                  const SizedBox(height: 16),

                  // SMS Notifications
                  _buildPreferenceCard(
                    icon: Icons.sms,
                    iconColor: Colors.green,
                    title: loc.smsNotifications,
                    description: loc.smsNotificationsDesc,
                    value: _smsEnabled,
                    onChanged: (value) {
                      setState(() => _smsEnabled = value);
                      _savePreferences();
                    },
                  ),
                  const SizedBox(height: 16),

                  // In-App Notifications
                  _buildPreferenceCard(
                    icon: Icons.notifications,
                    iconColor: Colors.orange,
                    title: loc.inAppNotifications,
                    description: loc.inAppNotificationsDesc,
                    value: _inAppEnabled,
                    onChanged: (value) {
                      setState(() => _inAppEnabled = value);
                      _savePreferences();
                    },
                  ),
                  const SizedBox(height: 24),

                  // Save Button (optional, since we auto-save)
                  if (_isSaving)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPreferenceCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF004d4d),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // Switch
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF004d4d),
            ),
          ],
        ),
      ),
    );
  }
}



