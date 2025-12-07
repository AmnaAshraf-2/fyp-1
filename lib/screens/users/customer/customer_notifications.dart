import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/screens/users/customer/upcoming_bookings.dart';

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

      // Set up real-time listener for customer notifications
      _notificationsSubscription = _db
          .child('customer_notifications/${user.uid}')
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
      case 'journey_completed':
        return Icons.check_circle_outline;
      case 'offer_accepted':
        return Icons.check_circle;
      case 'resources_assigned':
        return Icons.assignment_ind;
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
      case 'journey_completed':
        return Colors.teal;
      case 'offer_accepted':
        return Colors.blue;
      case 'resources_assigned':
        return Colors.orange;
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
                    return _buildNotificationCard(notification, t);
                  },
                ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, AppLocalizations t) {
    final isRead = notification['isRead'] == true;
    final requestId = notification['requestId'] as String?;
    
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead ? Colors.grey.shade300 : _getNotificationColor(notification['type']).withOpacity(0.3),
          width: isRead ? 1 : 2,
        ),
      ),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: requestId != null ? _loadRequestAndDriverData(requestId) : Future.value(null),
        builder: (context, snapshot) {
          final requestData = snapshot.data?['request'] as Map<String, dynamic>?;
          final driverData = snapshot.data?['driver'] as Map<String, dynamic>?;
          final enterpriseData = snapshot.data?['enterprise'] as Map<String, dynamic>?;
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          
          return ExpansionTile(
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
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              _formatTimestamp(notification['timestamp']),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            trailing: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
            onExpansionChanged: (expanded) async {
              if (expanded && !isRead) {
                await _markAsRead(notification['notificationId']);
              }
            },
            children: [
              if (requestData != null) ...[
                // Cargo Details Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_shipping, color: Colors.teal.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Cargo Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Load Name', requestData['loadName'] ?? 'N/A'),
                      _buildDetailRow('Load Type', requestData['loadType'] ?? 'N/A'),
                      _buildDetailRow(
                        'Weight',
                        '${requestData['weight'] ?? 'N/A'} ${requestData['weightUnit'] ?? ''}',
                      ),
                      _buildDetailRow('Vehicle Type', requestData['vehicleType'] ?? 'N/A'),
                      _buildDetailRow('Quantity', '${requestData['quantity'] ?? 'N/A'}'),
                      if (requestData['pickupLocation'] != null && requestData['pickupLocation'] != 'N/A')
                        _buildDetailRow('Pickup', requestData['pickupLocation']),
                      if (requestData['destinationLocation'] != null && requestData['destinationLocation'] != 'N/A')
                        _buildDetailRow('Destination', requestData['destinationLocation']),
                      if (requestData['pickupDate'] != null && requestData['pickupDate'] != 'N/A')
                        _buildDetailRow('Pickup Date', requestData['pickupDate']),
                      if (requestData['pickupTime'] != null && requestData['pickupTime'] != 'N/A')
                        _buildDetailRow('Pickup Time', requestData['pickupTime']),
                      _buildDetailRow('Fare', 'Rs. ${requestData['offerFare'] ?? requestData['finalFare'] ?? 'N/A'}'),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
              
              // Driver/Enterprise Details Section
              if (driverData != null || enterpriseData != null) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            enterpriseData != null ? Icons.business : Icons.person,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            enterpriseData != null ? 'Enterprise Details' : 'Driver Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (driverData != null) ...[
                        _buildDetailRow('Name', driverData['name'] ?? driverData['fullName'] ?? 'N/A'),
                        _buildDetailRow('Phone', driverData['phone'] ?? driverData['phoneNumber'] ?? 'N/A'),
                        if (driverData['vehicleInfo'] != null) ...[
                          Builder(
                            builder: (context) {
                              final vehicleInfo = driverData['vehicleInfo'] as Map?;
                              if (vehicleInfo != null) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow('Vehicle', vehicleInfo['type'] ?? 'N/A'),
                                    if (vehicleInfo['plateNumber'] != null)
                                      _buildDetailRow('Plate Number', vehicleInfo['plateNumber']),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ],
                      if (enterpriseData != null) ...[
                        _buildDetailRow('Name', enterpriseData['name'] ?? enterpriseData['enterpriseName'] ?? 'N/A'),
                        _buildDetailRow('Phone', enterpriseData['phone'] ?? enterpriseData['phoneNumber'] ?? 'N/A'),
                        if (enterpriseData['email'] != null)
                          _buildDetailRow('Email', enterpriseData['email']),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
              
              // Action Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: Text(
                      notification['type'] == 'offer_accepted' || 
                      notification['type'] == 'journey_started' || 
                      notification['type'] == 'journey_completed'
                          ? 'View Booking'
                          : 'View Details',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      final type = notification['type'];
                      if (type == 'offer_accepted' || type == 'journey_started' || type == 'journey_completed') {
                        if (requestId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UpcomingBookingsScreen(),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadRequestAndDriverData(String requestId) async {
    try {
      // Load request data
      final requestSnapshot = await _db.child('requests/$requestId').get();
      if (!requestSnapshot.exists) return null;
      
      final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
      Map<String, dynamic>? driverData;
      Map<String, dynamic>? enterpriseData;
      
      // Load driver data if acceptedDriverId exists
      final driverId = requestData['acceptedDriverId'] as String?;
      if (driverId != null) {
        final driverSnapshot = await _db.child('users/$driverId').get();
        if (driverSnapshot.exists) {
          driverData = Map<String, dynamic>.from(driverSnapshot.value as Map);
        }
      }
      
      // Load enterprise data if acceptedEnterpriseId exists
      final enterpriseId = requestData['acceptedEnterpriseId'] as String?;
      if (enterpriseId != null) {
        final enterpriseSnapshot = await _db.child('users/$enterpriseId').get();
        if (enterpriseSnapshot.exists) {
          enterpriseData = Map<String, dynamic>.from(enterpriseSnapshot.value as Map);
        }
      }
      
      return {
        'request': requestData,
        'driver': driverData,
        'enterprise': enterpriseData,
      };
    } catch (e) {
      print('Error loading request and driver data: $e');
      return null;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF004d4d),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
