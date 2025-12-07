import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'route_map_view.dart';
import 'rate_driver_screen.dart';

class PastBookingsScreen extends StatefulWidget {
  const PastBookingsScreen({super.key});

  @override
  State<PastBookingsScreen> createState() => _PastBookingsScreenState();
}

class _PastBookingsScreenState extends State<PastBookingsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pastBookings = [];
  StreamSubscription? _historySubscription;
  StreamSubscription? _requestsSubscription;
  Map<String, Map<String, dynamic>> _bookingsMap = {};

  @override
  void initState() {
    super.initState();
    _loadPastBookings();
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  void _updateBookingsList() {
    final bookings = _bookingsMap.values.toList();
    // Sort by completion date (newest first)
    bookings.sort((a, b) {
      final aTime = a['completedAt'] ?? a['journeyCompletedAt'] ?? a['timestamp'] ?? 0;
      final bTime = b['completedAt'] ?? b['journeyCompletedAt'] ?? b['timestamp'] ?? 0;
      return bTime.compareTo(aTime);
    });
    if (mounted) {
      setState(() {
        _pastBookings = bookings;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPastBookings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final timeout = Duration(seconds: 10);

      // Listen to customer_history for completed bookings
      _historySubscription = _db.child('customer_history/${user.uid}').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          for (final booking in event.snapshot.children) {
            final bookingKey = booking.key;
            // Skip if booking key is null
            if (bookingKey == null) continue;
            
            final bookingData = Map<String, dynamic>.from(booking.value as Map);
            bookingData['requestId'] = bookingKey;
            bookingData['status'] = 'completed';
            // History bookings take precedence (they have more complete data)
            _bookingsMap[bookingKey] = bookingData;
          }
        }
        _updateBookingsList();
      }, onError: (error) {
        print('Error loading customer history: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });

      // Listen to requests for completed bookings that might not be in history yet
      _requestsSubscription = _db.child('requests').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          for (final request in event.snapshot.children) {
            final requestData = Map<String, dynamic>.from(request.value as Map);
            final requestId = request.key;
            
            // Skip if requestId is null
            if (requestId == null) continue;
            
            // Check if this request is completed and belongs to this customer
            if (requestData['customerId'] == user.uid && 
                requestData['status'] == 'completed') {
              // Only add if not already in history (to avoid duplicates)
              if (!_bookingsMap.containsKey(requestId)) {
                requestData['requestId'] = requestId;
                requestData['status'] = 'completed';
                // Ensure we have completion timestamp
                if (requestData['journeyCompletedAt'] == null && requestData['completedAt'] == null) {
                  requestData['completedAt'] = DateTime.now().millisecondsSinceEpoch;
                }
                _bookingsMap[requestId] = requestData;
              }
            }
          }
        }
        _updateBookingsList();
      }, onError: (error) {
        print('Error loading requests: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      print('Error loading past bookings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
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

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showBookingDetails(Map<String, dynamic> booking) {
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
                    _buildDetailRow(t.loadName, booking['loadName'] ?? 'N/A'),
                    _buildDetailRow(t.loadType, _getLoadTypeLabel(booking['loadType'], t)),
                    _buildDetailRow(t.weight, '${booking['weight']} ${booking['weightUnit']}'),
                    _buildDetailRow(t.quantity, '${booking['quantity']} vehicle(s)'),
                    _buildDetailRow(t.vehicleType, booking['vehicleType'] ?? 'N/A'),
                    if (booking['pickupDate'] != null && booking['pickupDate'] != 'N/A')
                      _buildDetailRow(t.pickupDate, booking['pickupDate']),
                    _buildDetailRow(t.pickupTime, booking['pickupTime'] ?? 'N/A'),
                    _buildDetailRow('Fare', 'Rs ${booking['finalFare'] ?? booking['offerFare']}'),
                    _buildDetailRow('Insurance', booking['isInsured'] == true ? 'Yes' : 'No'),
                    SizedBox(height: 16),
                    if (booking['pickupLocation'] != null)
                      _buildDetailRow('Pickup Location', booking['pickupLocation']),
                    if (booking['destinationLocation'] != null)
                      _buildDetailRow('Destination', booking['destinationLocation']),
                    SizedBox(height: 16),
                    if (booking['journeyStartedAt'] != null)
                      _buildDetailRow('Journey Started', _formatTimestamp(booking['journeyStartedAt'])),
                    if (booking['journeyCompletedAt'] != null)
                      _buildDetailRow('Journey Completed', _formatTimestamp(booking['journeyCompletedAt'])),
                    // Rating section
                    if (booking['driverId'] != null || booking['acceptedDriverId'] != null) ...[
                      SizedBox(height: 20),
                      FutureBuilder<bool>(
                        future: _checkIfRated(booking['requestId'] ?? ''),
                        builder: (context, snapshot) {
                          final isRated = snapshot.data ?? false;
                          final driverId = booking['driverId'] ?? booking['acceptedDriverId'];
                          
                          if (!isRated && driverId != null) {
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.star, color: Colors.white),
                                label: Text('Rate Driver', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  // Load driver name
                                  String? driverName;
                                  try {
                                    final driverSnapshot = await _db.child('users/$driverId').get();
                                    if (driverSnapshot.exists) {
                                      final driverData = Map<String, dynamic>.from(
                                        driverSnapshot.value as Map
                                      );
                                      driverName = driverData['name'] ?? driverData['fullName'];
                                    }
                                  } catch (e) {
                                    print('Error loading driver name: $e');
                                  }
                                  
                                  Navigator.pop(context);
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RateDriverScreen(
                                        requestId: booking['requestId'] ?? '',
                                        driverId: driverId,
                                        driverName: driverName,
                                      ),
                                    ),
                                  );
                                  
                                  if (result == true && mounted) {
                                    // Refresh bookings
                                    _loadPastBookings();
                                  }
                                },
                              ),
                            );
                          } else if (isRated && booking['rating'] != null) {
                            final int rating = (booking['rating'] as num).round();
                            return Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber.shade700),
                                  SizedBox(width: 8),
                                  Text(
                                    'Rated: ${'★' * rating}${'☆' * (5 - rating)}',
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return SizedBox.shrink();
                        },
                      ),
                    ],
                    if (booking['pickupLocation'] != null && booking['destinationLocation'] != null) ...[
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
                                  pickupLocation: booking['pickupLocation'] ?? '',
                                  destinationLocation: booking['destinationLocation'] ?? '',
                                  loadName: booking['loadName'],
                                ),
                              ),
                            );
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

  Future<bool> _checkIfRated(String requestId) async {
    if (requestId.isEmpty) return false;
    try {
      final requestSnapshot = await _db.child('requests/$requestId').get();
      if (requestSnapshot.exists) {
        final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
        return requestData['isRated'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking rating status: $e');
      return false;
    }
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
      backgroundColor: const Color(0xFFF5F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(t.bookingHistory, style: const TextStyle(color: Color(0xFF004d4d))),
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
          : _pastBookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 70, color: Colors.grey.shade400),
                      SizedBox(height: 10),
                      Text(
                        'No completed bookings yet',
                        style: TextStyle(fontSize: 18, color: Color(0xFF004d4d)),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Your completed delivery history will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pastBookings.length,
                  itemBuilder: (_, i) {
                    final booking = _pastBookings[i];

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
                      child: InkWell(
                        onTap: () => _showBookingDetails(booking),
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
                                      booking['loadName'] ?? 'N/A',
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
                                '${_getLoadTypeLabel(booking['loadType'], t)} • ${booking['weight']} ${booking['weightUnit']}',
                                style: TextStyle(color: Color(0xFF004d4d)),
                              ),
                              SizedBox(height: 4),
                              if (booking['journeyCompletedAt'] != null)
                                Text(
                                  'Completed: ${_formatTimestamp(booking['journeyCompletedAt'])}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Fare: Rs ${booking['finalFare'] ?? booking['offerFare']}',
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

