import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  State<CustomerNotificationsScreen> createState() => _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState extends State<CustomerNotificationsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Listen for changes in customer notifications
      _db.child('customer_notifications/$user.uid').onValue.listen((event) {
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
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _db.child('customer_notifications/${_auth.currentUser!.uid}/$notificationId').update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await _db.child('customer_notifications/${_auth.currentUser!.uid}').remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications cleared')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing notifications: $e')),
      );
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'request_cancelled':
        return Icons.cancel;
      case 'journey_started':
        return Icons.play_arrow;
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
      case 'journey_started':
        return Colors.green;
      case 'offer_accepted':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all, color: Color(0xFF004d4d)),
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
                        'No notifications',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF004d4d),
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
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isRead ? Colors.grey[50] : Colors.white,
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
    if (timestamp == null) return 'Unknown time';
    
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
