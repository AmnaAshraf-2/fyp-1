import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:async';
import 'package:logistics_app/screens/users/customer/route_map_view.dart';

// Teal color palette
const kTealDark = Color(0xFF004D4D);
const kTeal = Color(0xFF007D7D);
const kTealLight = Color(0xFFB2DFDB);
const kTealBg = Color(0xFFE0F2F1);

class EnterprisePastBookingsScreen extends StatefulWidget {
  const EnterprisePastBookingsScreen({super.key});

  @override
  State<EnterprisePastBookingsScreen> createState() => _EnterprisePastBookingsScreenState();
}

class _EnterprisePastBookingsScreenState extends State<EnterprisePastBookingsScreen> {
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
      final aTime = a['completedAt'] ?? a['journeyCompletedAt'] ?? a['deliveredAt'] ?? a['timestamp'] ?? 0;
      final bTime = b['completedAt'] ?? b['journeyCompletedAt'] ?? b['deliveredAt'] ?? b['timestamp'] ?? 0;
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

      // Listen to enterprise_history for completed bookings
      _historySubscription = _db.child('enterprise_history/${user.uid}').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          for (final booking in event.snapshot.children) {
            final bookingKey = booking.key;
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
        print('Error loading enterprise history: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });

      // Listen to requests for completed bookings that might not be in history yet
      _requestsSubscription = _db.child('requests').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          for (final request in event.snapshot.children) {
            final requestKey = request.key;
            if (requestKey == null) continue;
            
            final requestData = Map<String, dynamic>.from(request.value as Map);
            final acceptedEnterpriseId = requestData['acceptedEnterpriseId'] as String?;
            
            // Check if this request is completed and belongs to this enterprise
            if (acceptedEnterpriseId == user.uid &&
                requestData['status'] == 'completed') {
              requestData['requestId'] = requestKey;
              requestData['status'] = 'completed';
              
              // Only add if not already in history (history takes precedence)
              if (!_bookingsMap.containsKey(requestKey)) {
                if (requestData['journeyCompletedAt'] == null && requestData['completedAt'] == null && requestData['deliveredAt'] == null) {
                  requestData['completedAt'] = DateTime.now().millisecondsSinceEpoch;
                }
                _bookingsMap[requestKey] = requestData;
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a1a), Color(0xFF2d2d2d)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _pastBookings.isEmpty
                  ? _buildEmptyState(t)
                  : _buildBookingsList(t),
        ),
      ),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a1a1a), Color(0xFF2d2d2d)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          t.pastBookings,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.white.withOpacity(.5),
          ),
          const SizedBox(height: 16),
          Text(
            t.noCompletedBookingsYet,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.completedBookingHistoryWillAppearHere,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList(AppLocalizations t) {
    return RefreshIndicator(
      onRefresh: _loadPastBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pastBookings.length,
        itemBuilder: (context, index) {
          final booking = _pastBookings[index];
          return _buildBookingCard(booking, t);
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, AppLocalizations t) {
    final timestamp = booking['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(booking['timestamp'] as int)
        : DateTime.now();
    final completedAt = booking['completedAt'] ?? 
                       booking['journeyCompletedAt'] ?? 
                       booking['deliveredAt'];
    final completedDate = completedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(completedAt as int)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kTeal, kTealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        t.delivered,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Show customer information
            if (booking['customerId'] != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          t.customerInformation,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(t.customerId, booking['customerId'] ?? t.nA),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Booking details
            _buildInfoRow(t.loadName, booking['loadName'] ?? t.nA),
            _buildInfoRow(t.loadType, _getLoadTypeLabel(booking['loadType'], t)),
            _buildInfoRow(t.loadWeight, '${booking['weight']} ${booking['weightUnit']}'),
            _buildInfoRow(t.quantity, '${booking['quantity']}'),
            _buildInfoRow(t.vehicleType, booking['vehicleType'] ?? t.nA),
            _buildInfoRow(t.finalFare, 'Rs. ${booking['finalFare'] ?? booking['offerFare'] ?? t.nA}'),
            _buildInfoRow(t.pickupTime, booking['pickupTime'] ?? t.nA),
            if (completedDate != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(t.deliveredAt, _formatDateTime(completedDate)),
            ],
            // Show assigned drivers and vehicles
            if (booking['assignedResources'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment_ind, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          t.assignedResources,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final assignedResourcesRaw = booking['assignedResources'];
                        if (assignedResourcesRaw == null) {
                          return const SizedBox.shrink();
                        }
                        
                        final List<Map<String, dynamic>> assignments = [];
                        
                        // Handle both Map and List types
                        if (assignedResourcesRaw is Map) {
                          final assignedResources = Map<String, dynamic>.from(assignedResourcesRaw);
                          assignedResources.forEach((key, value) {
                            if (value != null && value is Map) {
                              final assignment = Map<String, dynamic>.from(value);
                              assignment['index'] = key;
                              assignments.add(assignment);
                            }
                          });
                        } else if (assignedResourcesRaw is List) {
                          for (int i = 0; i < assignedResourcesRaw.length; i++) {
                            final value = assignedResourcesRaw[i];
                            if (value != null && value is Map) {
                              final assignment = Map<String, dynamic>.from(value);
                              assignment['index'] = i.toString();
                              assignments.add(assignment);
                            }
                          }
                        }
                        
                        if (assignments.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        
                        // Sort by index if available
                        assignments.sort((a, b) {
                          final indexA = int.tryParse(a['index']?.toString() ?? '0') ?? 0;
                          final indexB = int.tryParse(b['index']?.toString() ?? '0') ?? 0;
                          return indexA.compareTo(indexB);
                        });
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: assignments.asMap().entries.map((entry) {
                            final index = entry.key;
                            final assignment = entry.value;
                            final t = AppLocalizations.of(context)!;
                            final driverName = assignment['driverName'] ?? t.nA;
                            final vehicleInfoRaw = assignment['vehicleInfo'];
                            String vehicleInfo = t.nA;
                            
                            if (vehicleInfoRaw != null && vehicleInfoRaw is Map) {
                              final vehicleData = Map<String, dynamic>.from(vehicleInfoRaw);
                              final makeModel = vehicleData['makeModel'] ?? '';
                              final registration = vehicleData['registrationNumber'] ?? '';
                              vehicleInfo = makeModel.isNotEmpty 
                                ? '$makeModel${registration.isNotEmpty ? ' ($registration)' : ''}'
                                : t.nA;
                            }
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.vehicleNumber('${index + 1}'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildInfoRow(t.driver, driverName),
                                    _buildInfoRow(t.vehicle, vehicleInfo),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            // Show locations if available
            if (booking['pickupLocation'] != null && booking['destinationLocation'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(t.pickupLocation, booking['pickupLocation'] ?? t.nA),
              _buildInfoRow(t.destinationLocation, booking['destinationLocation'] ?? t.nA),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map, color: Colors.white),
                  label: Text(t.viewRouteOnMap, style: const TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                  ),
                  onPressed: () {
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(.9)),
            ),
          ),
        ],
      ),
    );
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
        return loadType ?? t.nA;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final t = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? t.dayAgo : t.daysAgo}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? t.hourAgo : t.hoursAgo}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? t.minuteAgo : t.minutesAgo}';
    } else {
      return t.justNow;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

