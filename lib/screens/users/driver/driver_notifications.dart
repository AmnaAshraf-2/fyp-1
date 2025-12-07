import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DriverNotificationsScreen extends StatefulWidget {
  const DriverNotificationsScreen({super.key});

  @override
  State<DriverNotificationsScreen> createState() => _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends State<DriverNotificationsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<DatabaseEvent>? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  void _loadNotifications() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Set up real-time listener for driver notifications
      _notificationsSubscription = _db
          .child('driver_notifications/${user.uid}')
          .onValue
          .listen(
        (event) {
          if (mounted) {
            if (event.snapshot.exists) {
              final notifications = <Map<String, dynamic>>[];
              for (final notification in event.snapshot.children) {
                final notificationData = Map<String, dynamic>.from(notification.value as Map);
                notificationData['notificationId'] = notification.key;
                notifications.add(notificationData);
              }
              // Sort by timestamp (newest first)
              notifications.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
              setState(() {
                _notifications = notifications;
                _isLoading = false;
              });
            } else {
              setState(() {
                _notifications = [];
                _isLoading = false;
              });
            }
          }
        },
        onError: (error) {
          print('Error listening to notifications: $error');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _db.child('driver_notifications/${_auth.currentUser!.uid}/$notificationId').update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    final t = AppLocalizations.of(context)!;
    try {
      await _db.child('driver_notifications/${_auth.currentUser!.uid}').remove();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.allNotificationsCleared)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.errorClearingNotifications}: $e')),
      );
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'request_cancelled':
        return Icons.cancel;
      case 'new_offer':
        return Icons.local_offer;
      case 'offer_accepted':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'request_cancelled':
        return Colors.red;
      case 'new_offer':
        return Colors.orange;
      case 'offer_accepted':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.notifications, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF004d4d), // Dark teal color
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all, color: Colors.white),
              onPressed: _clearAllNotifications,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.noNotifications,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final isRead = notification['isRead'] == true;
                    
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getNotificationColor(notification['type']).withOpacity(0.1),
                          child: Icon(
                            _getNotificationIcon(notification['type']),
                            color: _getNotificationColor(notification['type']),
                          ),
                        ),
                        title: Text(
                          notification['message'] ?? 'Notification',
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            color: const Color(0xFF004d4d),
                          ),
                        ),
                        subtitle: Text(
                          _formatTimestamp(notification['timestamp']),
                          style: const TextStyle(
                            color: Color(0xFF004d4d),
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          if (!isRead) {
                            _markAsRead(notification['notificationId']);
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }

  String _formatTimestamp(int? timestamp) {
    final t = AppLocalizations.of(context)!;
    if (timestamp == null) return t.unknownTime;
    
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? t.dayAgo : t.daysAgo}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? t.hourAgo : t.hoursAgo}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? t.minuteAgo : t.minutesAgo}';
    } else {
      return t.justNow;
    }
  }
}
