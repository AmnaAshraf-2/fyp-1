import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_accepted_offer.dart';
import 'driver_live_trip.dart';
import 'package:logistics_app/screens/users/customer/route_map_view.dart';
import 'package:logistics_app/services/location_tracking_service.dart';

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

        // Stop location tracking if active
        await LocationTrackingService().stopTracking();

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

        // Start location tracking for driver
        final trackingService = LocationTrackingService();
        await trackingService.startTracking(_auth.currentUser!.uid);

        // Notify customer that cargo is now in transit
        final requestSnapshot = await _db.child('requests/$requestId').get();
        if (requestSnapshot.exists) {
          final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
          final customerId = requestData['customerId'];
          if (customerId != null) {
            await _db.child('customer_notifications/$customerId').push().set({
              'type': 'journey_started',
              'requestId': requestId,
              'message': 'Your cargo is now in transit',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journey started successfully')),
        );

        // Navigate to live trip screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DriverLiveTripScreen(),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting journey: $e')),
        );
      }
    }
  }

  String _getLoadTypeLabel(String? loadType, AppLocalizations t) {
    switch (loadType) {
      case 'fragile':
        return t.fragile;
      case 'heavy':
        return t.heavy;
      case 'perishable':
        return t.perishable;
      case 'general':
        return t.generalGoods;
      default:
        return loadType ?? 'N/A';
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF004d4d),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF004d4d),
              ),
            ),
          ),
        ],
      ),
    );
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
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF004d4d), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    trip['loadName'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF004d4d),
                                    ),
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
                            const SizedBox(height: 16),
                            
                            // Trip Details Section
                            _buildDetailRow('Load Type', _getLoadTypeLabel(trip['loadType'], t)),
                            _buildDetailRow('Weight', '${trip['weight']} ${trip['weightUnit']}'),
                            _buildDetailRow('Quantity', '${trip['quantity']} vehicle(s)'),
                            _buildDetailRow('Vehicle Type', trip['vehicleType'] ?? 'N/A'),
                            if (trip['pickupDate'] != null && trip['pickupDate'] != 'N/A')
                              _buildDetailRow('Pickup Date', trip['pickupDate']),
                            _buildDetailRow('Pickup Time', trip['pickupTime'] ?? 'N/A'),
                            _buildDetailRow('Fare', 'Rs ${trip['finalFare'] ?? trip['offerFare']}'),
                            _buildDetailRow('Insurance', trip['isInsured'] == true ? 'Yes' : 'No'),
                            
                            // Location Section
                            if (trip['pickupLocation'] != null && trip['destinationLocation'] != null) ...[
                              const SizedBox(height: 12),
                              const Divider(color: Color(0xFF004d4d)),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.radio_button_checked, color: Colors.green, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Pickup Location',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          trip['pickupLocation'] ?? 'Not specified',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF004d4d),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Column(
                                  children: [
                                    Container(
                                      height: 1,
                                      color: Colors.grey.withOpacity(0.3),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 4),
                                      child: Icon(Icons.arrow_downward, color: Color(0xFF004d4d), size: 20),
                                    ),
                                    Container(
                                      height: 1,
                                      color: Colors.grey.withOpacity(0.3),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.location_on, color: Colors.red, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Destination Location',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          trip['destinationLocation'] ?? 'Not specified',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF004d4d),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.map, color: Color(0xFF004d4d)),
                                  label: const Text('View Route on Map', style: TextStyle(color: Color(0xFF004d4d))),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF004d4d)),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RouteMapView(
                                          pickupLocation: trip['pickupLocation'] ?? '',
                                          destinationLocation: trip['destinationLocation'] ?? '',
                                          loadName: trip['loadName'],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            
                            // Contact Information
                            if (trip['senderPhone'] != null || trip['receiverPhone'] != null) ...[
                              const SizedBox(height: 12),
                              const Divider(color: Color(0xFF004d4d)),
                              const SizedBox(height: 12),
                              if (trip['senderPhone'] != null)
                                _buildDetailRow('Sender Phone', trip['senderPhone']),
                              if (trip['receiverPhone'] != null)
                                _buildDetailRow('Receiver Phone', trip['receiverPhone']),
                            ],
                            
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
                                      side: const BorderSide(color: Colors.red),
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
                            if (trip['status'] == 'in_progress') ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.visibility, size: 18),
                                  label: const Text('View Live Trip'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const DriverLiveTripScreen(),
                                      ),
                                    );
                                  },
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
