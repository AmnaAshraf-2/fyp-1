import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'customer_accepted_offer.dart';
import 'waiting_for_response.dart';

class UpcomingBookingsScreen extends StatefulWidget {
  const UpcomingBookingsScreen({super.key});

  @override
  State<UpcomingBookingsScreen> createState() => _UpcomingBookingsScreenState();
}

class _UpcomingBookingsScreenState extends State<UpcomingBookingsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingBookings = [];
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _loadUpcomingBookings();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUpcomingBookings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Set a timeout for Firebase operations
      final timeout = Duration(seconds: 10);
      
      // Listen for changes in requests where customer is the current user and status is accepted
      _subscription = _db.child('requests').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          final requests = <Map<String, dynamic>>[];
          for (final request in event.snapshot.children) {
            final requestData = Map<String, dynamic>.from(request.value as Map);
            if (requestData['customerId'] == user.uid && 
                (requestData['status'] == 'accepted' || requestData['status'] == 'in_progress')) {
              requestData['requestId'] = request.key;
              requests.add(requestData);
            }
          }
          setState(() {
            _upcomingBookings = requests;
            _isLoading = false;
          });
        } else {
          setState(() {
            _upcomingBookings = [];
            _isLoading = false;
          });
        }
      }, onError: (error) {
        print('Error loading upcoming bookings: $error');
        setState(() {
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error loading upcoming bookings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _callDriver(String driverId) async {
    try {
      final driverSnapshot = await _db.child('users/$driverId').get();
      if (driverSnapshot.exists) {
        final driverData = Map<String, dynamic>.from(driverSnapshot.value as Map);
        final phoneNumber = driverData['phone']?.toString();
        
        if (phoneNumber != null) {
          final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
          if (await canLaunchUrl(phoneUri)) {
            await launchUrl(phoneUri);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot make call to $phoneNumber')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Driver phone number not available')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calling driver: $e')),
      );
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    final t = AppLocalizations.of(context)!;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.cancelRequest),
        content: Text(t.areYouSureCancelRequest),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t.cancelRequest),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update request status to cancelled
        await _db.child('requests/$requestId').update({
          'status': 'cancelled',
          'cancelledBy': 'customer',
          'cancelledAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Remove all offers for this request
        await _db.child('customer_offers/$requestId').remove();

        // Notify driver about cancellation
        final requestSnapshot = await _db.child('requests/$requestId').get();
        if (requestSnapshot.exists) {
          final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
          final driverId = requestData['acceptedDriverId'];
          if (driverId != null) {
            await _db.child('driver_notifications/$driverId').push().set({
              'type': 'request_cancelled',
              'requestId': requestId,
              'message': 'Customer cancelled the request',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.requestCancelled)),
        );

        // Refresh the list
        _loadUpcomingBookings();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _findNewDriver(String requestId) async {
    try {
      // Reset request status to pending
      await _db.child('requests/$requestId').update({
        'status': 'pending',
        'acceptedDriverId': null,
        'acceptedOfferId': null,
        'finalFare': null,
      });

      // Remove all existing offers
      await _db.child('customer_offers/$requestId').remove();

      // Navigate to waiting for response screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingForResponseScreen(requestId: requestId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finding new driver: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(t.upcomingBookings, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading bookings...',
                    style: const TextStyle(color: Color(0xFF004d4d)),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please check your internet connection',
                    style: const TextStyle(
                      color: Color(0xFF004d4d),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : _upcomingBookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.noUpcomingBookings,
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
                  itemCount: _upcomingBookings.length,
                  itemBuilder: (context, index) {
                    final booking = _upcomingBookings[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  booking['loadName'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF004d4d),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: booking['status'] == 'accepted'
                                        ? Colors.orange
                                        : Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    booking['status'] == 'accepted'
                                        ? 'Accepted'
                                        : 'In Progress',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${booking['loadType']} • ${booking['weight']} ${booking['weightUnit']}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF004d4d),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pickup: ${booking['pickupTime'] ?? 'N/A'}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF004d4d),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fare: Rs ${booking['finalFare'] ?? booking['offerFare']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.phone, size: 18),
                                    label: Text(t.callDriver),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _callDriver(booking['acceptedDriverId']),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.cancel, size: 18),
                                    label: Text(t.cancelRequest),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    onPressed: () => _cancelRequest(booking['requestId']),
                                  ),
                                ),
                              ],
                            ),
                            if (booking['status'] == 'accepted') ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.search, size: 18),
                                  label: Text(t.findNewDriver),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blue,
                                  ),
                                  onPressed: () => _findNewDriver(booking['requestId']),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
