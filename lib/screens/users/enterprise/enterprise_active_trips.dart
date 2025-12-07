import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/screens/users/customer/route_map_view.dart';

// Teal color palette
const kTealDark = Color(0xFF004D4D);
const kTeal = Color(0xFF007D7D);
const kTealLight = Color(0xFFB2DFDB);
const kTealBg = Color(0xFFE0F2F1);

class EnterpriseActiveTripsScreen extends StatefulWidget {
  const EnterpriseActiveTripsScreen({super.key});

  @override
  State<EnterpriseActiveTripsScreen> createState() => _EnterpriseActiveTripsScreenState();
}

class _EnterpriseActiveTripsScreenState extends State<EnterpriseActiveTripsScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeTrips = [];

  @override
  void initState() {
    super.initState();
    _loadActiveTrips();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Listen for changes to requests in real-time
    _db.child('requests').onValue.listen((event) {
      if (mounted) {
        _loadActiveTrips();
      }
    });
  }

  Future<void> _loadActiveTrips() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // Get all driver IDs for this enterprise
      final driversSnapshot = await _db.child('users/${user.uid}/drivers').get();
      Set<String> driverIds = {};
      if (driversSnapshot.exists) {
        for (final driver in driversSnapshot.children) {
          final driverId = driver.key;
          if (driverId != null) {
            driverIds.add(driverId);
          }
        }
      }

      // Load all requests
      final requestsSnapshot = await _db.child('requests').get();
      _activeTrips.clear();
      
      // Use a Set to track unique request IDs to prevent duplicates
      final Set<String> addedRequestIds = {};

      if (requestsSnapshot.exists) {
        for (final request in requestsSnapshot.children) {
          final requestId = request.key;
          if (requestId == null) continue;
          
          // Skip if this request ID has already been added
          if (addedRequestIds.contains(requestId)) {
            continue;
          }
          
          final requestData = Map<String, dynamic>.from(request.value as Map);
          final status = requestData['status'] as String?;
          final acceptedEnterpriseId = requestData['acceptedEnterpriseId'] as String?;
          final acceptedDriverId = requestData['acceptedDriverId'] as String?;

          // Check if this request is dispatched or in_progress by this enterprise or one of its drivers
          if ((status == 'dispatched' || status == 'in_progress') && 
              (acceptedEnterpriseId == user.uid || 
               (acceptedDriverId != null && driverIds.contains(acceptedDriverId)))) {
            requestData['requestId'] = requestId;
            requestData['acceptedDriverId'] = acceptedDriverId;
            
            // Load additional details from the accepted offer
            final acceptedOfferId = requestData['acceptedOfferId'] as String?;
            if (acceptedOfferId != null) {
              try {
                final offerSnapshot = await _db.child('customer_offers/${request.key}/$acceptedOfferId').get();
                if (offerSnapshot.exists) {
                  final offerData = Map<String, dynamic>.from(offerSnapshot.value as Map);
                  requestData['acceptedOfferData'] = offerData;
                  requestData['acceptedAt'] = offerData['timestamp'] ?? requestData['timestamp'];
                }
              } catch (e) {
                print('🔍 DEBUG: Error loading offer details: $e');
              }
            }
            
            // Load customer information if available
            final customerId = requestData['customerId'] as String?;
            if (customerId != null) {
              try {
                final customerSnapshot = await _db.child('users/$customerId').get();
                if (customerSnapshot.exists) {
                  final customerData = Map<String, dynamic>.from(customerSnapshot.value as Map);
                  requestData['customerName'] = customerData['full_name'] ?? 
                                                customerData['name'] ?? 
                                                customerData['companyName'] ?? 
                                                'Customer';
                  requestData['customerPhone'] = customerData['phone'] ?? customerData['phoneNumber'];
                  requestData['customerEmail'] = customerData['email'];
                }
              } catch (e) {
                print('🔍 DEBUG: Error loading customer details: $e');
              }
            }
            
            // Load driver information if it was accepted by a driver
            if (acceptedDriverId != null && driverIds.contains(acceptedDriverId)) {
              try {
                final driverSnapshot = await _db.child('users/$acceptedDriverId').get();
                if (driverSnapshot.exists) {
                  final driverData = Map<String, dynamic>.from(driverSnapshot.value as Map);
                  requestData['driverName'] = driverData['full_name'] ?? 
                                             driverData['name'] ?? 
                                             'Driver';
                  requestData['driverPhone'] = driverData['phone'] ?? driverData['phoneNumber'];
                  requestData['driverVehicle'] = driverData['vehicleInfo'];
                }
              } catch (e) {
                print('🔍 DEBUG: Error loading driver details: $e');
              }
            }
            
            // Load assigned drivers and vehicles information if assigned
            final assignedResourcesRaw = requestData['assignedResources'];
            if (assignedResourcesRaw != null) {
              try {
                Map<String, dynamic> assignedResources = {};
                
                // Handle both Map and List types
                if (assignedResourcesRaw is Map) {
                  assignedResources = Map<String, dynamic>.from(assignedResourcesRaw);
                } else if (assignedResourcesRaw is List) {
                  // Convert list to map with index as key
                  for (int i = 0; i < assignedResourcesRaw.length; i++) {
                    final item = assignedResourcesRaw[i];
                    if (item != null && item is Map) {
                      assignedResources[i.toString()] = Map<String, dynamic>.from(item);
                    }
                  }
                }
                
                if (assignedResources.isNotEmpty) {
                  final Map<String, dynamic> loadedResources = {};
                  
                  for (final entry in assignedResources.entries) {
                    final index = entry.key;
                    final assignmentRaw = entry.value;
                    
                    if (assignmentRaw == null || assignmentRaw is! Map) continue;
                    
                    final assignment = Map<String, dynamic>.from(assignmentRaw);
                    final driverId = assignment['driverId'] as String?;
                    final vehicleId = assignment['vehicleId'] as String?;
                    
                    final Map<String, dynamic> loadedAssignment = {};
                    
                    // Load driver details
                    if (driverId != null) {
                      final driverSnapshot = await _db.child('users/${user.uid}/drivers/$driverId').get();
                      if (driverSnapshot.exists) {
                        final driverData = Map<String, dynamic>.from(driverSnapshot.value as Map);
                        loadedAssignment['driverId'] = driverId;
                        loadedAssignment['driverName'] = driverData['name'] ?? 
                                                         driverData['fullName'] ?? 
                                                         'Driver';
                        loadedAssignment['driverPhone'] = driverData['phone'] ?? 
                                                          driverData['phoneNumber'];
                      }
                    }
                    
                    // Load vehicle details
                    if (vehicleId != null) {
                      final vehicleSnapshot = await _db.child('users/${user.uid}/vehicles/$vehicleId').get();
                      if (vehicleSnapshot.exists) {
                        final vehicleData = Map<String, dynamic>.from(vehicleSnapshot.value as Map);
                        loadedAssignment['vehicleId'] = vehicleId;
                        loadedAssignment['vehicleInfo'] = vehicleData;
                      }
                    }
                    
                    if (loadedAssignment.isNotEmpty) {
                      loadedResources[index] = loadedAssignment;
                    }
                  }
                  
                  if (loadedResources.isNotEmpty) {
                    requestData['assignedResources'] = loadedResources;
                  }
                }
              } catch (e) {
                print('🔍 DEBUG: Error loading assigned resources: $e');
              }
            }
            
            // Add to list and mark as added
            _activeTrips.add(requestData);
            addedRequestIds.add(requestId);
          }
        }
      }

      // Remove any duplicates based on requestId (additional safeguard)
      final Map<String, Map<String, dynamic>> uniqueTrips = {};
      for (final trip in _activeTrips) {
        final requestId = trip['requestId'] as String?;
        if (requestId != null) {
          // Keep the first occurrence of each requestId
          if (!uniqueTrips.containsKey(requestId)) {
            uniqueTrips[requestId] = trip;
          }
        }
      }
      _activeTrips = uniqueTrips.values.toList();

      // Sort by timestamp (newest first)
      _activeTrips.sort((a, b) {
        final timestampA = a['timestamp'] as int? ?? 0;
        final timestampB = b['timestamp'] as int? ?? 0;
        return timestampB.compareTo(timestampA);
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('🔍 DEBUG: Error loading active trips: $e');
      setState(() {
        _isLoading = false;
      });
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
              : _activeTrips.isEmpty
                  ? _buildEmptyState(t)
                  : _buildTripsList(t),
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
          'Active Trips',
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
            Icons.local_shipping,
            size: 80,
            color: Colors.white.withOpacity(.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Trips',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dispatched bookings will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsList(AppLocalizations t) {
    return RefreshIndicator(
      onRefresh: _loadActiveTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activeTrips.length,
        itemBuilder: (context, index) {
          final trip = _activeTrips[index];
          return _buildTripCard(trip, t);
        },
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip, AppLocalizations t) {
    final timestamp = trip['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(trip['timestamp'] as int)
        : DateTime.now();
    final dispatchedAt = trip['dispatchedAt'] != null
        ? (trip['dispatchedAt'] is int 
            ? DateTime.fromMillisecondsSinceEpoch(trip['dispatchedAt'] as int)
            : null)
        : null;
    final status = trip['status'] as String? ?? 'dispatched';
    final isInProgress = status == 'in_progress';

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
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
                    color: isInProgress ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isInProgress ? Colors.blue : Colors.green, 
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isInProgress ? Icons.directions_car : Icons.local_shipping, 
                        color: isInProgress ? Colors.blue : Colors.green, 
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isInProgress ? 'In Progress' : 'Dispatched',
                        style: TextStyle(
                          color: isInProgress ? Colors.blue : Colors.green,
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
            if (trip['customerName'] != null) ...[
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
                          'Customer Information',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Name', trip['customerName'] ?? 'N/A'),
                    if (trip['customerPhone'] != null)
                      _buildInfoRow('Phone', trip['customerPhone']),
                    if (trip['customerEmail'] != null)
                      _buildInfoRow('Email', trip['customerEmail']),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Load details
            _buildInfoRow(t.loadName, trip['loadName'] ?? 'N/A'),
            _buildInfoRow(t.loadType, _getLoadTypeLabel(trip['loadType'], t)),
            _buildInfoRow(t.loadWeight, '${trip['weight']} ${trip['weightUnit']}'),
            _buildInfoRow(t.quantity, '${trip['quantity']}'),
            _buildInfoRow(t.vehicleType, trip['vehicleType'] ?? 'N/A'),
            _buildInfoRow(t.finalFare, 'Rs. ${trip['finalFare'] ?? trip['offerFare'] ?? 'N/A'}'),
            _buildInfoRow(t.pickupTime, trip['pickupTime'] ?? 'N/A'),
            if (dispatchedAt != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Dispatched At', _formatDateTime(dispatchedAt)),
            ],
            // Show assigned drivers and vehicles
            if (trip['assignedResources'] != null) ...[
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
                          'Assigned Resources',
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
                        final assignedResourcesRaw = trip['assignedResources'];
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
                            final driverName = assignment['driverName'] ?? 'N/A';
                            final vehicleInfoRaw = assignment['vehicleInfo'];
                            String vehicleInfo = 'N/A';
                            
                            if (vehicleInfoRaw != null && vehicleInfoRaw is Map) {
                              final vehicleData = Map<String, dynamic>.from(vehicleInfoRaw);
                              final makeModel = vehicleData['makeModel'] ?? '';
                              final registration = vehicleData['registrationNumber'] ?? '';
                              vehicleInfo = makeModel.isNotEmpty 
                                ? '$makeModel${registration.isNotEmpty ? ' ($registration)' : ''}'
                                : 'N/A';
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
                                      'Vehicle ${index + 1}:',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildInfoRow('Driver', driverName),
                                    _buildInfoRow('Vehicle', vehicleInfo),
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
            if (trip['pickupLocation'] != null && trip['destinationLocation'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(t.pickupLocation, trip['pickupLocation'] ?? 'N/A'),
              _buildInfoRow(t.destinationLocation, trip['destinationLocation'] ?? 'N/A'),
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
            // Mark as delivered button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text(
                  'Mark as Delivered',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => _markAsDelivered(trip),
              ),
            ),
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
        return loadType ?? 'N/A';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _markAsDelivered(Map<String, dynamic> trip) async {
    final requestId = trip['requestId'] as String?;
    
    if (requestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Request ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.green.shade800, width: 1),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade800),
            const SizedBox(width: 8),
            Text(
              'Mark as Delivered',
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure this booking has been delivered? The customer will be notified.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark as Delivered'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get the full request data
      final requestSnapshot = await _db.child('requests/$requestId').get();
      if (!requestSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
      final customerId = requestData['customerId'] as String?;
      final deliveredAt = DateTime.now().millisecondsSinceEpoch;

      // Update request status to completed
      await _db.child('requests/$requestId').update({
        'status': 'completed',
        'deliveredAt': deliveredAt,
        'deliveredBy': user.uid,
        'journeyCompletedAt': deliveredAt,
        'completedAt': deliveredAt,
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
        'dispatchedAt': requestData['dispatchedAt'],
        'journeyStartedAt': requestData['journeyStartedAt'],
        'deliveredAt': deliveredAt,
        'journeyCompletedAt': deliveredAt,
        'timestamp': requestData['timestamp'],
        'completedAt': deliveredAt,
        'acceptedEnterpriseId': requestData['acceptedEnterpriseId'],
        'assignedResources': requestData['assignedResources'],
      };

      // Add customer and enterprise IDs to history
      if (customerId != null) {
        deliveryHistory['customerId'] = customerId;
      }
      deliveryHistory['enterpriseId'] = user.uid;

      // Save to customer history
      if (customerId != null) {
        await _db.child('customer_history/$customerId').child(requestId).set(deliveryHistory);
      }

      // Save to enterprise history
      await _db.child('enterprise_history/${user.uid}').child(requestId).set(deliveryHistory);

      // Save to driver history for each assigned driver
      final assignedResourcesRaw = requestData['assignedResources'];
      if (assignedResourcesRaw != null) {
        Map<String, dynamic> assignedResources = {};
        
        if (assignedResourcesRaw is Map) {
          assignedResources = Map<String, dynamic>.from(assignedResourcesRaw);
        } else if (assignedResourcesRaw is List) {
          for (int i = 0; i < assignedResourcesRaw.length; i++) {
            final item = assignedResourcesRaw[i];
            if (item != null && item is Map) {
              assignedResources[i.toString()] = Map<String, dynamic>.from(item);
            }
          }
        }
        
        for (final assignment in assignedResources.values) {
          if (assignment is Map) {
            final assignmentData = Map<String, dynamic>.from(assignment);
            final driverId = assignmentData['driverId'] as String?;
            if (driverId != null) {
              try {
                // Create driver-specific history entry
                final driverHistory = Map<String, dynamic>.from(deliveryHistory);
                driverHistory['driverId'] = driverId;
                driverHistory['acceptedDriverId'] = driverId;
                await _db.child('driver_history/$driverId').child(requestId).set(driverHistory);
              } catch (e) {
                print('Error saving driver history for $driverId: $e');
              }
            }
          }
        }
      }

      // Notify customer that delivery is completed
      if (customerId != null) {
        final loadName = requestData['loadName'] as String? ?? 'your cargo';
        await _db.child('customer_notifications/$customerId').push().set({
          'type': 'journey_completed',
          'requestId': requestId,
          'message': 'Your booking for "$loadName" has been delivered',
          'timestamp': deliveredAt,
          'isRead': false,
          'enterpriseId': user.uid, // Include enterpriseId for rating
        });
      }

      // Notify assigned drivers if any
      if (assignedResourcesRaw != null) {
        Map<String, dynamic> assignedResources = {};
        
        if (assignedResourcesRaw is Map) {
          assignedResources = Map<String, dynamic>.from(assignedResourcesRaw);
        } else if (assignedResourcesRaw is List) {
          for (int i = 0; i < assignedResourcesRaw.length; i++) {
            final item = assignedResourcesRaw[i];
            if (item != null && item is Map) {
              assignedResources[i.toString()] = Map<String, dynamic>.from(item);
            }
          }
        }
        
        for (final assignment in assignedResources.values) {
          if (assignment is Map) {
            final assignmentData = Map<String, dynamic>.from(assignment);
            final driverId = assignmentData['driverId'] as String?;
            if (driverId != null) {
              try {
                await _db.child('driver_notifications/$driverId').push().set({
                  'type': 'journey_completed',
                  'requestId': requestId,
                  'message': 'Delivery completed for assigned booking',
                  'timestamp': deliveredAt,
                  'isRead': false,
                });
              } catch (e) {
                print('Error notifying driver $driverId: $e');
              }
            }
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking marked as delivered successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload active trips to remove the delivered one
      await _loadActiveTrips();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking as delivered: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

