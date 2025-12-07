import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_live_location_map.dart';

class CustomerLiveTripScreen extends StatefulWidget {
  const CustomerLiveTripScreen({super.key});

  @override
  State<CustomerLiveTripScreen> createState() => _CustomerLiveTripScreenState();
}

class _CustomerLiveTripScreenState extends State<CustomerLiveTripScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _liveTrips = [];

  @override
  void initState() {
    super.initState();
    _loadLiveTrips();
  }

  Future<void> _loadLiveTrips() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Listen for trips in progress for this customer
      _db.child('requests').onValue.listen((event) {
        if (event.snapshot.exists) {
          final trips = <Map<String, dynamic>>[];
          for (final request in event.snapshot.children) {
            final requestData = Map<String, dynamic>.from(request.value as Map);
            if (requestData['customerId'] == user.uid && 
                requestData['status'] == 'in_progress') {
              requestData['requestId'] = request.key;
              trips.add(requestData);
            }
          }
          setState(() {
            _liveTrips = trips;
            _isLoading = false;
          });
        } else {
          setState(() {
            _liveTrips = [];
            _isLoading = false;
          });
        }
      }, onError: (error) {
        print('Error loading live trips: $error');
        setState(() {
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error loading live trips: $e');
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
        title: const Text('Live Trips', style: TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _liveTrips.isEmpty
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
                        'No active trips',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF004d4d),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your trips in progress will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _liveTrips.length,
                  itemBuilder: (context, index) {
                    final trip = _liveTrips[index];
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
                            // Header
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
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'In Progress',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Trip Details
                            _buildDetailRow('Load Type', _getLoadTypeLabel(trip['loadType'], t)),
                            _buildDetailRow('Weight', '${trip['weight']} ${trip['weightUnit']}'),
                            _buildDetailRow('Vehicle Type', trip['vehicleType'] ?? 'N/A'),
                            if (trip['pickupDate'] != null && trip['pickupDate'] != 'N/A')
                              _buildDetailRow('Pickup Date', trip['pickupDate']),
                            _buildDetailRow('Pickup Time', trip['pickupTime'] ?? 'N/A'),
                            _buildDetailRow('Fare', 'Rs ${trip['finalFare'] ?? trip['offerFare']}'),
                            
                            // Location Info
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
                                          'Pickup',
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
                                          'Destination',
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
                            ],
                            
                            const SizedBox(height: 16),
                            
                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.phone, color: Colors.white, size: 18),
                                    label: const Text('Call Driver', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _callDriver(trip['acceptedDriverId']),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.location_on, color: Colors.white, size: 18),
                                    label: const Text('View Live', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DriverLiveLocationMap(
                                            requestId: trip['requestId'],
                                            driverId: trip['acceptedDriverId'],
                                            pickupLocation: trip['pickupLocation'] ?? '',
                                            destinationLocation: trip['destinationLocation'] ?? '',
                                            loadName: trip['loadName'] ?? 'Trip',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
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
}

