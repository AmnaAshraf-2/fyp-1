import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:logistics_app/screens/users/customer/route_map_view.dart';

class PastTripsScreen extends StatefulWidget {
  const PastTripsScreen({super.key});

  @override
  State<PastTripsScreen> createState() => _PastTripsScreenState();
}

class _PastTripsScreenState extends State<PastTripsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pastTrips = [];
  StreamSubscription? _historySubscription;
  StreamSubscription? _requestsSubscription;
  Map<String, Map<String, dynamic>> _tripsMap = {};

  @override
  void initState() {
    super.initState();
    _loadPastTrips();
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  void _updateTripsList() {
    final trips = _tripsMap.values.toList();
    // Sort by completion date (newest first)
    trips.sort((a, b) {
      final aTime = a['completedAt'] ?? a['journeyCompletedAt'] ?? a['timestamp'] ?? 0;
      final bTime = b['completedAt'] ?? b['journeyCompletedAt'] ?? b['timestamp'] ?? 0;
      return bTime.compareTo(aTime);
    });
    if (mounted) {
      setState(() {
        _pastTrips = trips;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPastTrips() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final timeout = Duration(seconds: 10);

      // Listen to driver_history for completed trips
      _historySubscription = _db.child('driver_history/${user.uid}').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          for (final trip in event.snapshot.children) {
            final tripKey = trip.key;
            // Skip if trip key is null
            if (tripKey == null) continue;
            
            final tripData = Map<String, dynamic>.from(trip.value as Map);
            tripData['requestId'] = tripKey;
            tripData['status'] = 'completed';
            // History trips take precedence (they have more complete data)
            _tripsMap[tripKey] = tripData;
          }
        }
        _updateTripsList();
      }, onError: (error) {
        print('Error loading driver history: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });

      // Listen to requests for completed trips that might not be in history yet
      _requestsSubscription = _db.child('requests').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          for (final request in event.snapshot.children) {
            final requestData = Map<String, dynamic>.from(request.value as Map);
            final requestId = request.key;
            
            // Skip if requestId is null
            if (requestId == null) continue;
            
            // Check if this request is completed and assigned to this driver
            if (requestData['acceptedDriverId'] == user.uid && 
                requestData['status'] == 'completed') {
              // Only add if not already in history (to avoid duplicates)
              if (!_tripsMap.containsKey(requestId)) {
                requestData['requestId'] = requestId;
                requestData['status'] = 'completed';
                // Ensure we have completion timestamp
                if (requestData['journeyCompletedAt'] == null && requestData['completedAt'] == null) {
                  requestData['completedAt'] = DateTime.now().millisecondsSinceEpoch;
                }
                _tripsMap[requestId] = requestData;
              }
            }
          }
        }
        _updateTripsList();
      }, onError: (error) {
        print('Error loading requests: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      print('Error loading past trips: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showTripDetails(Map<String, dynamic> trip) {
    final t = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.tripDetails,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF004d4d),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(t.loadName, trip['loadName'] ?? 'N/A'),
                    _buildDetailRow(t.loadType, _getLoadTypeLabel(trip['loadType'], t)),
                    _buildDetailRow(t.weight, '${trip['weight']} ${trip['weightUnit']}'),
                    _buildDetailRow(t.quantity, '${trip['quantity']} vehicle(s)'),
                    _buildDetailRow(t.vehicleType, trip['vehicleType'] ?? 'N/A'),
                    if (trip['pickupDate'] != null && trip['pickupDate'] != 'N/A')
                      _buildDetailRow(t.pickupDate, trip['pickupDate']),
                    _buildDetailRow(t.pickupTime, trip['pickupTime'] ?? 'N/A'),
                    _buildDetailRow('Fare', 'Rs ${trip['finalFare'] ?? trip['offerFare']}'),
                    _buildDetailRow('Insurance', trip['isInsured'] == true ? 'Yes' : 'No'),
                    SizedBox(height: 16),
                    if (trip['pickupLocation'] != null)
                      _buildDetailRow('Pickup Location', trip['pickupLocation']),
                    if (trip['destinationLocation'] != null)
                      _buildDetailRow('Destination', trip['destinationLocation']),
                    if (trip['senderPhone'] != null)
                      _buildDetailRow('Sender Phone', trip['senderPhone']),
                    if (trip['receiverPhone'] != null)
                      _buildDetailRow('Receiver Phone', trip['receiverPhone']),
                    SizedBox(height: 16),
                    if (trip['journeyStartedAt'] != null)
                      _buildDetailRow('Journey Started', _formatTimestamp(trip['journeyStartedAt'])),
                    if (trip['journeyCompletedAt'] != null)
                      _buildDetailRow('Journey Completed', _formatTimestamp(trip['journeyCompletedAt'])),
                    if (trip['pickupLocation'] != null && trip['destinationLocation'] != null) ...[
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.map, color: Colors.white),
                          label: Text('View Route on Map', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
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
                    if (trip['customerId'] != null) ...[
                      SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.phone, color: Colors.white),
                          label: Text('Call Customer', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _callCustomer(trip['customerId']);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
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
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF004d4d),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
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
        title: Text(t.pastTrips, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
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
          : _pastTrips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 70, color: Colors.grey.shade400),
                      SizedBox(height: 10),
                      Text(
                        'No completed trips yet',
                        style: TextStyle(fontSize: 18, color: Color(0xFF004d4d)),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Your completed trip history will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pastTrips.length,
                  itemBuilder: (_, i) {
                    final trip = _pastTrips[i];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Color(0xFF004d4d), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          )
                        ],
                      ),
                      child: InkWell(
                        onTap: () => _showTripDetails(trip),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      trip['loadName'] ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF004d4d),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Completed',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  )
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${_getLoadTypeLabel(trip['loadType'], t)} • ${trip['weight']} ${trip['weightUnit']}',
                                style: TextStyle(color: Color(0xFF004d4d)),
                              ),
                              SizedBox(height: 4),
                              if (trip['pickupLocation'] != null)
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 14, color: Colors.green),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        trip['pickupLocation'],
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              if (trip['destinationLocation'] != null) ...[
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 14, color: Colors.red),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        trip['destinationLocation'],
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              SizedBox(height: 8),
                              if (trip['journeyCompletedAt'] != null)
                                Text(
                                  'Completed: ${_formatTimestamp(trip['journeyCompletedAt'])}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Fare: Rs ${trip['finalFare'] ?? trip['offerFare']}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

