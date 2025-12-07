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
        setState(() => _isLoading = false);
        return;
      }

      final timeout = Duration(seconds: 10);

      _subscription = _db.child('requests').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          final requests = <Map<String, dynamic>>[];
          for (final request in event.snapshot.children) {
            final requestData = Map<String, dynamic>.from(request.value as Map);
            final status = requestData['status'] as String?;
            // Include accepted, dispatched, and in_progress statuses
            // Also include bookings accepted by enterprise (acceptedEnterpriseId) or driver (acceptedDriverId)
            if (requestData['customerId'] == user.uid &&
                (status == 'accepted' || status == 'dispatched' || status == 'in_progress')) {
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
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _callDriver(String driverId) async {
    try {
      final snapshot = await _db.child('users/$driverId').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final phone = data['phone']?.toString();

        if (phone != null) {
          final uri = Uri(scheme: 'tel', path: phone);
          if (await canLaunchUrl(uri)) launchUrl(uri);
        }
      }
    } catch (e) {}
  }

  Future<void> _callEnterprise(String enterpriseId) async {
    try {
      final snapshot = await _db.child('users/$enterpriseId').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final enterpriseDetails = data['enterpriseDetails'] as Map<String, dynamic>?;
        
        // Try to get phone from enterpriseDetails first, then from user data
        final phone = enterpriseDetails?['contactPhone']?.toString() ?? 
                     enterpriseDetails?['cooperateNumber']?.toString() ??
                     data['phone']?.toString() ?? 
                     data['phoneNumber']?.toString();

        if (phone != null && phone.isNotEmpty) {
          final uri = Uri(scheme: 'tel', path: phone);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot make call to $phone')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enterprise contact number not available')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error contacting enterprise: $e')),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
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
        // Get request data to find the accepted driver
        final requestSnapshot = await _db.child('requests/$requestId').get();
        if (requestSnapshot.exists) {
          final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
          final driverId = requestData['acceptedDriverId'];
          
          // Update request status to cancelled
          await _db.child('requests/$requestId').update({
            'status': 'cancelled',
            'cancelledBy': 'customer',
            'cancelledAt': DateTime.now().millisecondsSinceEpoch,
          });

          await _db.child('customer_offers/$requestId').remove();

          // Notify driver about cancellation if there's an accepted driver
          if (driverId != null) {
            await _db.child('driver_notifications/$driverId').push().set({
              'type': 'request_cancelled',
              'requestId': requestId,
              'message': 'Customer cancelled the request',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling request: $e')),
        );
      }
    }
  }

  Future<void> _findNewDriver(String requestId) async {
    await _db.child('requests/$requestId').update({
      'status': 'pending',
      'acceptedDriverId': null,
      'acceptedOfferId': null,
      'finalFare': null,
    });

    await _db.child('customer_offers/$requestId').remove();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => WaitingForResponseScreen(requestId: requestId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(t.upcomingBookings, style: const TextStyle(color: Color(0xFF004d4d))),
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF004d4d)),
                  SizedBox(height: 10),
                  Text("Loading...", style: TextStyle(color: Color(0xFF004d4d))),
                ],
              ),
            )
          : _upcomingBookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 70, color: Colors.grey.shade400),
                      SizedBox(height: 10),
                      Text(t.noUpcomingBookings,
                          style: TextStyle(fontSize: 18, color: Color(0xFF004d4d))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _upcomingBookings.length,
                  itemBuilder: (_, i) {
                    final b = _upcomingBookings[i];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  b['loadName'] ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF004d4d),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: b['status'] == 'accepted' 
                                        ? Colors.orange 
                                        : b['status'] == 'dispatched'
                                            ? Colors.blue
                                            : Colors.green,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    b['status'] == 'accepted' 
                                        ? 'Accepted' 
                                        : b['status'] == 'dispatched'
                                            ? 'Dispatched'
                                            : 'In Progress',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                )
                              ],
                            ),

                            SizedBox(height: 8),
                            Text('${b['loadType']} • ${b['weight']} ${b['weightUnit']}',
                                style: TextStyle(color: Color(0xFF004d4d))),

                            SizedBox(height: 4),
                            Text('Pickup: ${b['pickupTime'] ?? 'N/A'}',
                                style: TextStyle(color: Color(0xFF004d4d))),

                            SizedBox(height: 4),
                            Text('Fare: Rs ${b['finalFare'] ?? b['offerFare']}',
                                style: TextStyle(fontSize: 16, color: Colors.green.shade700)),

                            SizedBox(height: 16),
                            // Contact buttons row
                            if (b['acceptedDriverId'] != null || b['acceptedEnterpriseId'] != null)
                              Row(
                                children: [
                                  // Show call driver button if there's an accepted driver
                                  if (b['acceptedDriverId'] != null)
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: Icon(Icons.phone, size: 18),
                                        label: Text(t.callDriver),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: () => _callDriver(b['acceptedDriverId']),
                                      ),
                                    ),
                                  // Show contact enterprise button if there's an accepted enterprise
                                  if (b['acceptedEnterpriseId'] != null) ...[
                                    if (b['acceptedDriverId'] != null) SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: Icon(Icons.business, size: 18),
                                        label: Text('Contact Enterprise'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: () => _callEnterprise(b['acceptedEnterpriseId']),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            SizedBox(height: b['acceptedDriverId'] != null || b['acceptedEnterpriseId'] != null ? 10 : 0),
                            // Cancel button row
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: Icon(Icons.cancel, size: 18),
                                    label: Text(t.cancelRequest),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () => _cancelRequest(b['requestId']),
                                  ),
                                ),
                              ],
                            ),

                            // Only show find new driver for accepted status (not dispatched or in_progress)
                            if (b['status'] == 'accepted') ...[
                              SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  icon: Icon(Icons.search, size: 18),
                                  label: Text(t.findNewDriver),
                                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                                  onPressed: () => _findNewDriver(b['requestId']),
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
