import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logistics_app/screens/users/customer/route_map_view.dart';
import 'package:logistics_app/services/location_tracking_service.dart';

class DriverLiveTripScreen extends StatefulWidget {
  const DriverLiveTripScreen({super.key});

  @override
  State<DriverLiveTripScreen> createState() => _DriverLiveTripScreenState();
}

class _DriverLiveTripScreenState extends State<DriverLiveTripScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _liveTrip;

  @override
  void initState() {
    super.initState();
    _loadLiveTrip();
    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    final user = _auth.currentUser;
    if (user != null) {
      final trackingService = LocationTrackingService();
      await trackingService.startTracking(user.uid);
    }
  }

  @override
  void dispose() {
    // Stop location tracking when screen is disposed
    final user = _auth.currentUser;
    if (user != null) {
      LocationTrackingService().stopTracking();
    }
    super.dispose();
  }

  Future<void> _loadLiveTrip() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Listen for active trip (status = in_progress)
      _db.child('requests').onValue.listen((event) {
        if (event.snapshot.exists) {
          for (final request in event.snapshot.children) {
            final requestData = Map<String, dynamic>.from(request.value as Map);
            if (requestData['acceptedDriverId'] == user.uid && 
                requestData['status'] == 'in_progress') {
              requestData['requestId'] = request.key;
              setState(() {
                _liveTrip = requestData;
                _isLoading = false;
              });
              return;
            }
          }
          // No active trip found
          setState(() {
            _liveTrip = null;
            _isLoading = false;
          });
        } else {
          setState(() {
            _liveTrip = null;
            _isLoading = false;
          });
        }
      }, onError: (error) {
        print('Error loading live trip: $error');
        setState(() {
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error loading live trip: $e');
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

  Future<void> _completeJourney(String requestId) async {
    final t = AppLocalizations.of(context)!;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.completeJourney),
        content: Text(t.areYouSureCompleteJourney),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(t.completeJourney),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Get the full request data before updating
        final requestSnapshot = await _db.child('requests/$requestId').get();
        if (!requestSnapshot.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Request not found')),
          );
          return;
        }

        final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
        final customerId = requestData['customerId'];
        final driverId = _auth.currentUser?.uid;
        final journeyCompletedAt = DateTime.now().millisecondsSinceEpoch;

        // Update request status to completed
        await _db.child('requests/$requestId').update({
          'status': 'completed',
          'journeyCompletedAt': journeyCompletedAt,
        });

        // Prepare delivery history data
        final deliveryHistory = {
          'requestId': requestId,
          'loadName': requestData['loadName'],
          'loadType': requestData['loadType'],
          'weight': requestData['weight'],
          'weightUnit': requestData['weightUnit'],
          'quantity': requestData['quantity'],
          'pickupDate': requestData['pickupDate'],
          'pickupTime': requestData['pickupTime'],
          'offerFare': requestData['offerFare'],
          'finalFare': requestData['finalFare'] ?? requestData['offerFare'],
          'isInsured': requestData['isInsured'],
          'vehicleType': requestData['vehicleType'],
          'pickupLocation': requestData['pickupLocation'],
          'destinationLocation': requestData['destinationLocation'],
          'senderPhone': requestData['senderPhone'],
          'receiverPhone': requestData['receiverPhone'],
          'status': 'completed',
          'journeyStartedAt': requestData['journeyStartedAt'],
          'journeyCompletedAt': journeyCompletedAt,
          'timestamp': requestData['timestamp'],
          'completedAt': journeyCompletedAt,
        };

        // Add customer and driver IDs to history
        if (customerId != null) {
          deliveryHistory['customerId'] = customerId;
        }
        if (driverId != null) {
          deliveryHistory['driverId'] = driverId;
          deliveryHistory['acceptedDriverId'] = driverId;
        }

        // Save to customer history
        if (customerId != null) {
          await _db.child('customer_history/$customerId').child(requestId).set(deliveryHistory);
        }

        // Save to driver history
        if (driverId != null) {
          await _db.child('driver_history/$driverId').child(requestId).set(deliveryHistory);
        }

        // Notify customer that journey is completed
        if (customerId != null) {
          await _db.child('customer_notifications/$customerId').push().set({
            'type': 'journey_completed',
            'requestId': requestId,
            'driverId': driverId,
            'message': 'Your cargo has been delivered successfully',
            'timestamp': journeyCompletedAt,
          });
        }

        // Stop location tracking
        await LocationTrackingService().stopTracking();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.journeyCompletedSuccessfully)),
        );

        // Navigate back or refresh
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.errorCompletingJourney}: $e')),
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(t.liveTrip, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _liveTrip == null
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
                        'No active trip',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF004d4d),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a journey from Upcoming Trips',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green, width: 2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_bus, color: Colors.green, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Journey In Progress',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  if (_liveTrip!['journeyStartedAt'] != null)
                                    Text(
                                      'Started: ${_formatTimestamp(_liveTrip!['journeyStartedAt'])}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Trip Details Card
                      Card(
                        color: Colors.white,
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
                              Text(
                                t.tripDetails,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF004d4d),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow(t.loadName, _liveTrip!['loadName'] ?? 'N/A'),
                              _buildDetailRow(t.loadType, _getLoadTypeLabel(_liveTrip!['loadType'], t)),
                              _buildDetailRow(t.weight, '${_liveTrip!['weight']} ${_liveTrip!['weightUnit']}'),
                              _buildDetailRow(t.quantity, '${_liveTrip!['quantity']} vehicle(s)'),
                              _buildDetailRow(t.vehicleType, _liveTrip!['vehicleType'] ?? 'N/A'),
                              if (_liveTrip!['pickupDate'] != null && _liveTrip!['pickupDate'] != 'N/A')
                                _buildDetailRow(t.pickupDate, _liveTrip!['pickupDate']),
                              _buildDetailRow(t.pickupTime, _liveTrip!['pickupTime'] ?? 'N/A'),
                              _buildDetailRow('Fare', 'Rs ${_liveTrip!['finalFare'] ?? _liveTrip!['offerFare']}'),
                              _buildDetailRow('Insurance', _liveTrip!['isInsured'] == true ? 'Yes' : 'No'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Location Card
                      if (_liveTrip!['pickupLocation'] != null && _liveTrip!['destinationLocation'] != null)
                        Card(
                          color: Colors.white,
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
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Color(0xFF004d4d), size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      t.routeInformation,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF004d4d),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Pickup Location
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
                                          Text(
                                            'Pickup Location',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _liveTrip!['pickupLocation'] ?? 'Not specified',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFF004d4d),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Arrow
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
                                const SizedBox(height: 20),
                                // Destination Location
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
                                          Text(
                                            'Destination Location',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _liveTrip!['destinationLocation'] ?? 'Not specified',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFF004d4d),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.directions, color: Colors.white),
                                    label: const Text('View Directions on Map', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RouteMapView(
                                            pickupLocation: _liveTrip!['pickupLocation'] ?? '',
                                            destinationLocation: _liveTrip!['destinationLocation'] ?? '',
                                            loadName: _liveTrip!['loadName'],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Contact Information
                      Card(
                        color: Colors.white,
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
                              Text(
                                'Contact Information',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF004d4d),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_liveTrip!['senderPhone'] != null)
                                _buildDetailRow('Sender Phone', _liveTrip!['senderPhone']),
                              if (_liveTrip!['receiverPhone'] != null)
                                _buildDetailRow('Receiver Phone', _liveTrip!['receiverPhone']),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.phone, color: Colors.white),
                                  label: const Text('Call Customer', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _callCustomer(_liveTrip!['customerId']),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Complete Journey Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, color: Colors.white, size: 24),
                          label: const Text(
                            'Complete Journey',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _completeJourney(_liveTrip!['requestId']),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

