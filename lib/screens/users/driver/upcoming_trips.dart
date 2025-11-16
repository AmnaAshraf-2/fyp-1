import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_accepted_offer.dart';

class UpcomingTripsScreen extends StatefulWidget {
  const UpcomingTripsScreen({super.key});

  @override
  State<UpcomingTripsScreen> createState() => _UpcomingTripsScreenState();
}

class _UpcomingTripsScreenState extends State<UpcomingTripsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingTrips = [];

  @override
  void initState() {
    super.initState();
    _loadUpcomingTrips();
  }

  Future<void> _loadUpcomingTrips() async {
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

      // Listen for changes in requests where driver is the accepted driver and status is accepted or in_progress
      _db.child('requests').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          final trips = <Map<String, dynamic>>[];
          for (final request in event.snapshot.children) {
            final requestData = Map<String, dynamic>.from(request.value as Map);
            if (requestData['acceptedDriverId'] == user.uid && 
                (requestData['status'] == 'accepted' || requestData['status'] == 'in_progress')) {
              requestData['requestId'] = request.key;
              trips.add(requestData);
            }
          }
          setState(() {
            _upcomingTrips = trips;
            _isLoading = false;
          });
        } else {
          setState(() {
            _upcomingTrips = [];
            _isLoading = false;
          });
        }
      }, onError: (error) {
        print('Error loading upcoming trips: $error');
        setState(() {
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error loading upcoming trips: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _callCustomer(String customerId) async {
    try {
      final customerSnapshot = await _db.child('users/$customerId').get();
      if (customerSnapshot.exists) {
        final customerData = Map<String, dynamic>.from(customerSnapshot.value as Map);
        final phoneNumber = customerData['phone']?.toString();
        
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
            const SnackBar(content: Text('Customer phone number not available')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calling customer: $e')),
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
          'cancelledBy': 'driver',
          'cancelledAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Remove all offers for this request
        await _db.child('customer_offers/$requestId').remove();

        // Notify customer about cancellation
        final requestSnapshot = await _db.child('requests/$requestId').get();
        if (requestSnapshot.exists) {
          final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
          final customerId = requestData['customerId'];
          if (customerId != null) {
            await _db.child('customer_notifications/$customerId').push().set({
              'type': 'request_cancelled',
              'requestId': requestId,
              'message': 'Driver cancelled the request',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.requestCancelled)),
        );

        // Refresh the list
        _loadUpcomingTrips();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _startJourney(String requestId) async {
    final t = AppLocalizations.of(context)!;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Journey'),
        content: const Text('Are you sure you want to start this journey?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Start Journey'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update request status to in_progress
        await _db.child('requests/$requestId').update({
          'status': 'in_progress',
          'journeyStartedAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Notify customer that journey has started
        final requestSnapshot = await _db.child('requests/$requestId').get();
        if (requestSnapshot.exists) {
          final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
          final customerId = requestData['customerId'];
          if (customerId != null) {
            await _db.child('customer_notifications/$customerId').push().set({
              'type': 'journey_started',
              'requestId': requestId,
              'message': 'Driver has started the journey',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journey started successfully')),
        );

        // Refresh the list
        _loadUpcomingTrips();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting journey: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Upcoming Trips', style: TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _upcomingTrips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_bus,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No upcoming trips',
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
                  itemCount: _upcomingTrips.length,
                  itemBuilder: (context, index) {
                    final trip = _upcomingTrips[index];
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
                                  trip['loadName'] ?? 'N/A',
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
                                    color: trip['status'] == 'accepted'
                                        ? Colors.orange
                                        : Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    trip['status'] == 'accepted'
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
                              '${trip['loadType']} • ${trip['weight']} ${trip['weightUnit']}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF004d4d),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pickup: ${trip['pickupTime'] ?? 'N/A'}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF004d4d),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fare: Rs ${trip['finalFare'] ?? trip['offerFare']}',
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
                                    label: const Text('Call Customer'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _callCustomer(trip['customerId']),
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
                                    onPressed: () => _cancelRequest(trip['requestId']),
                                  ),
                                ),
                              ],
                            ),
                            if (trip['status'] == 'accepted') ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.play_arrow, size: 18),
                                  label: const Text('Start Journey'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _startJourney(trip['requestId']),
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
