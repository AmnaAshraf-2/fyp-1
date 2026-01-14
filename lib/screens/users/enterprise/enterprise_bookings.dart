import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/screens/users/customer/route_map_view.dart';
import 'package:logistics_app/services/vehicle_provider.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_drivers_live_location_map.dart';

// Teal color palette
const kTealDark = Color(0xFF004D4D);
const kTeal = Color(0xFF007D7D);
const kTealLight = Color(0xFFB2DFDB);
const kTealBg = Color(0xFFE0F2F1);

class EnterpriseBookingsScreen extends StatefulWidget {
  const EnterpriseBookingsScreen({super.key});

  @override
  State<EnterpriseBookingsScreen> createState() => _EnterpriseBookingsScreenState();
}

class _EnterpriseBookingsScreenState extends State<EnterpriseBookingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();
  final VehicleProvider _vehicleProvider = VehicleProvider();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _acceptedBookings = [];
  List<VehicleModel> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadAcceptedBookings();
    _setupRealtimeListener();
  }

  Future<void> _loadVehicles() async {
    try {
      final vehicles = await _vehicleProvider.loadVehicles();
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Convert vehicle type (could be nameKey or localized name) to nameKey
  String? _getVehicleNameKey(String vehicleType) {
    // First, check if it's already a nameKey
    for (VehicleModel vehicle in _vehicles) {
      if (vehicle.nameKey == vehicleType) {
        return vehicle.nameKey;
      }
    }
    // If not, check if it matches any localized name
    for (VehicleModel vehicle in _vehicles) {
      if (vehicle.getName('en') == vehicleType ||
          vehicle.getName('ur') == vehicleType ||
          vehicle.getName('ps') == vehicleType) {
        return vehicle.nameKey;
      }
    }
    return null;
  }

  /// Check if two vehicle types match (handles both nameKey and localized names)
  bool _vehicleTypesMatch(String vehicleType1, String vehicleType2) {
    // Direct match
    if (vehicleType1 == vehicleType2) return true;
    
    // Convert both to nameKey and compare
    String? nameKey1 = _getVehicleNameKey(vehicleType1);
    String? nameKey2 = _getVehicleNameKey(vehicleType2);
    
    if (nameKey1 != null && nameKey2 != null) {
      return nameKey1 == nameKey2;
    }
    
    // If one or both couldn't be converted, fall back to direct comparison
    return vehicleType1 == vehicleType2;
  }

  void _setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Listen for changes to requests in real-time
    _db.child('requests').onValue.listen((event) {
      if (mounted) {
        _loadAcceptedBookings();
      }
    });
  }

  Future<void> _loadAcceptedBookings() async {
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
      _acceptedBookings.clear();
      
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

          // Check if this request is accepted by this enterprise or one of its drivers
          if (status == 'accepted' && 
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
                  // Add offer details to request data
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
                  final t = AppLocalizations.of(context)!;
                  requestData['customerName'] = customerData['full_name'] ?? 
                                                customerData['name'] ?? 
                                                customerData['companyName'] ?? 
                                                t.customer;
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
                  final t = AppLocalizations.of(context)!;
                  requestData['driverName'] = driverData['full_name'] ?? 
                                             driverData['name'] ?? 
                                             t.driver;
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
                    
                    // Start with all existing assignment data to preserve status, driverAuthUid, respondedAt, etc.
                    final Map<String, dynamic> loadedAssignment = Map<String, dynamic>.from(assignment);
                    
                    // Load driver details (update/add but don't replace existing data)
                    if (driverId != null) {
                      final driverSnapshot = await _db.child('users/${user.uid}/drivers/$driverId').get();
                      if (driverSnapshot.exists) {
                        final driverData = Map<String, dynamic>.from(driverSnapshot.value as Map);
                        loadedAssignment['driverId'] = driverId;
                        final t = AppLocalizations.of(context)!;
                        loadedAssignment['driverName'] = driverData['name'] ?? 
                                                         driverData['fullName'] ?? 
                                                         t.driver;
                        loadedAssignment['driverPhone'] = driverData['phone'] ?? 
                                                          driverData['phoneNumber'];
                      }
                    }
                    
                    // Load vehicle details (update/add but don't replace existing data)
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
            _acceptedBookings.add(requestData);
            addedRequestIds.add(requestId);
          }
        }
      }

      // Remove any duplicates based on requestId (additional safeguard)
      final Map<String, Map<String, dynamic>> uniqueBookings = {};
      for (final booking in _acceptedBookings) {
        final requestId = booking['requestId'] as String?;
        if (requestId != null) {
          // Keep the first occurrence of each requestId
          if (!uniqueBookings.containsKey(requestId)) {
            uniqueBookings[requestId] = booking;
          }
        }
      }
      _acceptedBookings = uniqueBookings.values.toList();

      // Sort by timestamp (newest first)
      _acceptedBookings.sort((a, b) {
        final timestampA = a['timestamp'] as int? ?? 0;
        final timestampB = b['timestamp'] as int? ?? 0;
        return timestampB.compareTo(timestampA);
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('🔍 DEBUG: Error loading accepted bookings: $e');
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
              : _acceptedBookings.isEmpty
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
          t.bookings,
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
            Icons.assignment_turned_in,
            size: 80,
            color: Colors.white.withOpacity(.5),
          ),
          const SizedBox(height: 16),
          Text(
            t.noBookings,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.acceptedOffersWillAppearHere,
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
      onRefresh: _loadAcceptedBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _acceptedBookings.length,
        itemBuilder: (context, index) {
          final booking = _acceptedBookings[index];
          return _buildBookingCard(booking, t);
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, AppLocalizations t) {
    final timestamp = booking['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(booking['timestamp'] as int)
        : DateTime.now();
    final acceptedAt = booking['acceptedAt'] != null
        ? (booking['acceptedAt'] is int 
            ? DateTime.fromMillisecondsSinceEpoch(booking['acceptedAt'] as int)
            : null)
        : null;

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
                        t.accepted,
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
            if (booking['customerName'] != null) ...[
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
                    _buildInfoRow(t.firstName, booking['customerName'] ?? t.nA),
                    if (booking['customerPhone'] != null)
                      _buildInfoRow(t.phoneNumber, booking['customerPhone']),
                    if (booking['customerEmail'] != null)
                      _buildInfoRow(t.email, booking['customerEmail']),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Show driver information if accepted by driver
            if (booking['driverName'] != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.drive_eta, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          t.assignedDriver,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(t.firstName, booking['driverName'] ?? t.nA),
                    if (booking['driverPhone'] != null)
                      _buildInfoRow(t.phoneNumber, booking['driverPhone']),
                    if (booking['driverVehicle'] != null)
                      Builder(
                        builder: (context) {
                          final vehicleInfoRaw = booking['driverVehicle'];
                          if (vehicleInfoRaw == null) {
                            return const SizedBox.shrink();
                          }
                          // Convert LinkedMap to Map<String, dynamic>
                          final vehicleInfo = Map<String, dynamic>.from(vehicleInfoRaw as Map);
                          final make = vehicleInfo['make']?.toString() ?? '';
                          final model = vehicleInfo['model']?.toString() ?? '';
                          final vehicleName = '$make $model'.trim();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (vehicleName.isNotEmpty)
                                _buildInfoRow(t.vehicle, vehicleName),
                              if (vehicleInfo['plateNumber'] != null)
                                _buildInfoRow(t.plate, vehicleInfo['plateNumber'].toString()),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Load details
            _buildInfoRow(t.loadName, booking['loadName'] ?? t.nA),
            _buildInfoRow(t.loadType, _getLoadTypeLabel(booking['loadType'], t)),
            _buildInfoRow(t.loadWeight, '${booking['weight']} ${booking['weightUnit']}'),
            _buildInfoRow(t.quantity, '${booking['quantity']}'),
            _buildInfoRow(t.vehicleType, booking['vehicleType'] ?? t.nA),
            _buildInfoRow(t.finalFare, 'Rs. ${booking['finalFare'] ?? booking['offerFare'] ?? t.nA}'),
            _buildInfoRow(t.pickupTime, booking['pickupTime'] ?? t.nA),
            _buildInfoRow(t.insurance, booking['isInsured'] == true ? t.yes : t.no),
            // Show offer details if available
            if (booking['acceptedOfferData'] != null) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final offerDataRaw = booking['acceptedOfferData'];
                  if (offerDataRaw == null) return const SizedBox.shrink();
                  // Convert LinkedMap to Map<String, dynamic>
                  final offerData = Map<String, dynamic>.from(offerDataRaw as Map);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (offerData['offerType'] != null)
                        _buildInfoRow(t.offerType, offerData['offerType'] == 'counter' ? t.counterOffer : t.acceptance),
                      if (offerData['originalFare'] != null)
                        _buildInfoRow(t.originalFare, 'Rs. ${offerData['originalFare']}'),
                    ],
                  );
                },
              ),
            ],
            if (acceptedAt != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(t.acceptedAt, _formatDateTime(acceptedAt)),
            ],
            // Show assigned drivers and vehicles if already assigned
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
                          // Handle if it's stored as a list
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
                            
                            final assignmentStatus = assignment['status'] as String? ?? 'pending';
                            final isPending = assignmentStatus == 'pending';
                            final isAccepted = assignmentStatus == 'accepted';
                            final isRejected = assignmentStatus == 'rejected';
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isPending
                                        ? Colors.orange.withOpacity(0.5)
                                        : isAccepted
                                            ? Colors.green.withOpacity(0.5)
                                            : Colors.red.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${t.vehicle} ${index + 1}:',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isPending
                                                ? Colors.orange
                                                : isAccepted
                                                    ? Colors.green
                                                    : Colors.red,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            isPending
                                                ? t.pending
                                                : isAccepted
                                                    ? t.accepted
                                                    : t.rejected,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ],
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
            // Assign/Edit drivers and vehicles button
            Builder(
              builder: (context) {
                final quantity = booking['quantity'] as int? ?? 1;
                final assignedResourcesRaw = booking['assignedResources'];
                
                // Handle both Map and List types
                Map<String, dynamic> assignedResourcesMap = {};
                if (assignedResourcesRaw != null) {
                  if (assignedResourcesRaw is Map) {
                    assignedResourcesMap = Map<String, dynamic>.from(assignedResourcesRaw);
                  } else if (assignedResourcesRaw is List) {
                    // Convert List to Map with index as key
                    for (int i = 0; i < assignedResourcesRaw.length; i++) {
                      final item = assignedResourcesRaw[i];
                      if (item != null && item is Map) {
                        assignedResourcesMap[i.toString()] = Map<String, dynamic>.from(item);
                      }
                    }
                  }
                }
                
                final assignedCount = assignedResourcesMap.length;
                
                // Calculate assignment statuses
                int pendingCount = 0;
                int acceptedCount = 0;
                int rejectedCount = 0;
                int journeyStartedCount = 0;
                
                for (final assignment in assignedResourcesMap.values) {
                  if (assignment is Map) {
                    final status = assignment['status'] as String? ?? 'pending';
                    if (status == 'pending') {
                      pendingCount++;
                    } else if (status == 'accepted') {
                      acceptedCount++;
                      // Check if journey has started
                      if (assignment['journeyStarted'] == true) {
                        journeyStartedCount++;
                      }
                    } else if (status == 'rejected') {
                      rejectedCount++;
                    }
                  }
                }
                
                final allAccepted = assignedCount == quantity && acceptedCount == quantity && rejectedCount == 0;
                final hasRejected = rejectedCount > 0;
                final hasJourneyStarted = journeyStartedCount > 0;
                
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    // Show warning if there are rejected assignments
                    if (hasRejected) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$rejectedCount driver${rejectedCount > 1 ? 's' : ''} ${t.rejected} the assignment. Please assign another driver${rejectedCount > 1 ? 's' : ''}.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Show notify customer button only when all have accepted
                    if (allAccepted && assignedCount > 0) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.notifications_active, color: Colors.white),
                          label: Text(
                            t.notifyCustomer,
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => _askToNotifyCustomer(
                            booking['requestId'] as String,
                            booking['customerId'] as String? ?? '',
                            acceptedCount,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (assignedCount < quantity)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.assignment, color: Colors.white),
                          label: Text(
                            assignedCount == 0 
                                ? t.assignDriversVehiclesRequired(quantity.toString())
                                : t.completeAssignmentRemaining((quantity - assignedCount).toString()),
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => _showAssignDriverVehicleDialog(booking),
                        ),
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              label: Text(
                                t.editAssignment,
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () => _showAssignDriverVehicleDialog(booking, isEdit: true),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Dispatch button - only show if status is 'accepted' and all drivers have accepted their assignments
                          if ((booking['status'] == 'accepted' || booking['status'] == 'in_progress') && allAccepted)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.local_shipping, color: Colors.white),
                                label: Text(
                                  t.dispatchBooking,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: () => _dispatchBooking(booking),
                              ),
                            ),
                          // View Driver Location button - show when at least one driver has started journey
                          if (hasJourneyStarted && assignedResourcesMap.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.location_on, color: Colors.white),
                                label: Text(
                                  t.driverLocation,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EnterpriseDriversLiveLocationMap(
                                        requestId: booking['requestId'] ?? '',
                                        assignedResources: assignedResourcesMap,
                                        pickupLocation: booking['pickupLocation'] ?? '',
                                        destinationLocation: booking['destinationLocation'] ?? '',
                                        loadName: booking['loadName'] ?? '',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: Text(
                          t.cancelRequest,
                          style: const TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => _cancelBooking(booking),
                      ),
                    ),
                  ],
                );
              },
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
        return loadType ?? t.nA;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    final t = AppLocalizations.of(context)!;
    
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

  Future<void> _showAssignDriverVehicleDialog(Map<String, dynamic> booking, {bool isEdit = false}) async {
    final t = AppLocalizations.of(context)!;
    final user = _auth.currentUser;
    if (user == null) return;

    final requestId = booking['requestId'] as String?;
    if (requestId == null) return;

    final quantity = booking['quantity'] as int? ?? 1;
    final vehicleType = booking['vehicleType'] as String? ?? '';
    final assignedResourcesRaw = booking['assignedResources'];
    final assignedCount = assignedResourcesRaw != null && assignedResourcesRaw is Map 
        ? assignedResourcesRaw.length 
        : 0;
    final remainingCount = isEdit ? quantity : (quantity - assignedCount);

    // Load enterprise drivers and vehicles
    List<Map<String, dynamic>> drivers = [];
    List<Map<String, dynamic>> vehicles = [];

    try {
      // Load drivers
      final driversSnapshot = await _db.child('users/${user.uid}/drivers').get();
      if (driversSnapshot.exists) {
        final driversData = driversSnapshot.value as Map;
        drivers = driversData.entries.map((entry) {
          final driverData = Map<String, dynamic>.from(entry.value as Map);
          driverData['id'] = entry.key;
          return driverData;
        }).toList();
        
        // Filter out inactive drivers (only show active drivers)
        drivers = drivers.where((driver) {
          final status = driver['status'] as String?;
          return status == null || status == 'active';
        }).toList();
      }

      // Load vehicles and filter by vehicle type
      final vehiclesSnapshot = await _db.child('users/${user.uid}/vehicles').get();
      if (vehiclesSnapshot.exists) {
        final vehiclesData = vehiclesSnapshot.value as Map;
        vehicles = vehiclesData.entries.map((entry) {
          final vehicleData = Map<String, dynamic>.from(entry.value as Map);
          vehicleData['id'] = entry.key;
          return vehicleData;
        }).toList();
        
        // Filter out inactive vehicles (only show active vehicles)
        vehicles = vehicles.where((vehicle) {
          final status = vehicle['status'] as String?;
          return status == null || status == 'active';
        }).toList();
        
        // Filter vehicles by vehicle type if specified
        if (vehicleType.isNotEmpty) {
          vehicles = vehicles.where((vehicle) {
            final vehicleTypeValue = vehicle['type'] as String?;
            if (vehicleTypeValue == null) return false;
            return _vehicleTypesMatch(vehicleTypeValue, vehicleType);
          }).toList();
        }
      }
    } catch (e) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.errorLoadingDriversVehicles} $e')),
      );
      return;
    }

    if (drivers.isEmpty || vehicles.isEmpty) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(drivers.isEmpty 
            ? t.noActiveDriversAvailable
            : vehicleType.isNotEmpty
                ? t.noActiveVehiclesOfTypeAvailable(vehicleType)
                : t.noActiveVehiclesAvailable),
        ),
      );
      return;
    }

    // When editing, we need to ensure currently assigned vehicles/drivers are included
    // even if they don't match the vehicle type filter
    if (isEdit && assignedResourcesRaw != null && assignedResourcesRaw is Map) {
      final assignedResources = Map<String, dynamic>.from(assignedResourcesRaw);
      for (final assignment in assignedResources.values) {
        if (assignment is Map) {
          final assignmentData = Map<String, dynamic>.from(assignment);
          
          // Load assigned driver if not already in list
          final assignedDriverId = assignmentData['driverId'] as String?;
          if (assignedDriverId != null && 
              !drivers.any((d) => d['id'] == assignedDriverId)) {
            try {
              final driverSnapshot = await _db.child('users/${user.uid}/drivers/$assignedDriverId').get();
              if (driverSnapshot.exists) {
                final driverData = Map<String, dynamic>.from(driverSnapshot.value as Map);
                driverData['id'] = assignedDriverId;
                drivers.add(driverData);
              }
            } catch (e) {
              // Ignore errors loading driver
            }
          }
          
          // Load assigned vehicle if not already in list
          final assignedVehicleId = assignmentData['vehicleId'] as String?;
          if (assignedVehicleId != null && 
              !vehicles.any((v) => v['id'] == assignedVehicleId)) {
            try {
              final vehicleSnapshot = await _db.child('users/${user.uid}/vehicles/$assignedVehicleId').get();
              if (vehicleSnapshot.exists) {
                final vehicleData = Map<String, dynamic>.from(vehicleSnapshot.value as Map);
                vehicleData['id'] = assignedVehicleId;
                vehicles.add(vehicleData);
              }
            } catch (e) {
              // Ignore errors loading vehicle
            }
          }
        }
      }
    }

    // When editing, show all drivers/vehicles (including currently assigned ones)
    // When not editing, exclude already assigned ones
    Set<String> assignedDriverIds = {};
    Set<String> assignedVehicleIds = {};
    if (!isEdit && assignedResourcesRaw != null && assignedResourcesRaw is Map) {
      final assignedResources = Map<String, dynamic>.from(assignedResourcesRaw);
      for (final assignment in assignedResources.values) {
        if (assignment is Map) {
          final assignmentData = Map<String, dynamic>.from(assignment);
          if (assignmentData['driverId'] != null) {
            assignedDriverIds.add(assignmentData['driverId'].toString());
          }
          if (assignmentData['vehicleId'] != null) {
            assignedVehicleIds.add(assignmentData['vehicleId'].toString());
          }
        }
      }
    }

    // Filter out already assigned drivers/vehicles (only if not editing)
    // When editing, show all so they can be changed
    // But always filter to only show active drivers/vehicles for new assignments
    final availableDrivers = (isEdit 
        ? drivers 
        : drivers.where((d) => !assignedDriverIds.contains(d['id'])).toList())
        .where((d) {
          final status = d['status'] as String?;
          return status == null || status == 'active';
        }).toList();
    final availableVehicles = (isEdit 
        ? vehicles 
        : vehicles.where((v) => !assignedVehicleIds.contains(v['id'])).toList())
        .where((v) {
          final status = v['status'] as String?;
          return status == null || status == 'active';
        }).toList();

    if (availableDrivers.length < remainingCount || availableVehicles.length < remainingCount) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            availableDrivers.length < remainingCount
                ? t.notEnoughAvailableDrivers(remainingCount.toString(), availableDrivers.length.toString())
                : t.notEnoughAvailableVehicles(remainingCount.toString(), availableVehicles.length.toString()),
          ),
        ),
      );
      return;
    }

    // List of selected assignments - pre-populate if editing
    List<Map<String, dynamic>> assignments = [];
    
    if (isEdit && assignedResourcesRaw != null && assignedResourcesRaw is Map) {
      // Pre-populate with existing assignments
      final assignedResources = Map<String, dynamic>.from(assignedResourcesRaw);
      final sortedEntries = assignedResources.entries.toList()
        ..sort((a, b) {
          final indexA = int.tryParse(a.key) ?? 0;
          final indexB = int.tryParse(b.key) ?? 0;
          return indexA.compareTo(indexB);
        });
      
      for (final entry in sortedEntries) {
        final assignment = entry.value;
        if (assignment is Map) {
          final assignmentData = Map<String, dynamic>.from(assignment);
          assignments.add({
            'driverId': assignmentData['driverId'] as String?,
            'vehicleId': assignmentData['vehicleId'] as String?,
            'index': entry.key,
          });
        }
      }
      
      // Fill remaining slots if quantity increased
      while (assignments.length < quantity) {
        assignments.add({
          'driverId': null,
          'vehicleId': null,
          'index': assignments.length.toString(),
        });
      }
    } else {
      // Create new assignments
      assignments = List.generate(remainingCount, (index) => {
        'driverId': null,
        'vehicleId': null,
        'index': (assignedCount + index).toString(),
      });
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.teal.shade800, width: 1),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade800,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEdit ? t.editDriverVehicleAssignment : t.assignDriversVehicles,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (vehicleType.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              border: Border.all(color: Colors.teal.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.teal.shade800, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.onlyVehiclesOfTypeShown(vehicleType),
                                    style: TextStyle(
                                      color: Colors.teal.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          isEdit 
                              ? t.editAssignmentForVehicles(quantity.toString(), quantity > 1 ? 's' : '')
                              : t.assignDriversAndVehicles(remainingCount.toString(), remainingCount > 1 ? 's' : '', remainingCount > 1 ? 's' : ''),
                          style: TextStyle(
                            color: Colors.teal.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...assignments.asMap().entries.map((entry) {
                          final index = entry.key;
                          final assignment = entry.value;
                          final assignmentIndex = int.tryParse(assignment['index']?.toString() ?? index.toString()) ?? index;
                          final currentDriverId = assignment['driverId'] as String?;
                          final currentVehicleId = assignment['vehicleId'] as String?;
                          
                          // Build unique driver items list, ensuring current selection is included
                          final Set<String> uniqueDriverIds = availableDrivers
                              .where((driver) => driver['id'] != null)
                              .map((driver) => driver['id'] as String)
                              .toSet();
                          if (currentDriverId != null && currentDriverId.isNotEmpty) {
                            uniqueDriverIds.add(currentDriverId);
                          }
                          final driverItems = uniqueDriverIds.map((driverId) {
                            final driver = availableDrivers.firstWhere(
                              (d) => d['id'] == driverId,
                              orElse: () => <String, dynamic>{},
                            );
                            final t = AppLocalizations.of(context)!;
                            final driverName = driver['name'] ?? 
                                              driver['fullName'] ?? 
                                              '${t.driver} $driverId';
                            final driverPhone = driver['phone'] ?? 
                                               driver['phoneNumber'] ?? 
                                               t.nA;
                            return DropdownMenuItem<String>(
                              value: driverId,
                              child: Text(
                                '$driverName ($driverPhone)',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList();
                          
                          // Build unique vehicle items list, ensuring current selection is included
                          final Set<String> uniqueVehicleIds = availableVehicles
                              .where((vehicle) => vehicle['id'] != null)
                              .map((vehicle) => vehicle['id'] as String)
                              .toSet();
                          if (currentVehicleId != null && currentVehicleId.isNotEmpty) {
                            uniqueVehicleIds.add(currentVehicleId);
                          }
                          final vehicleItems = uniqueVehicleIds.map((vehicleId) {
                            final vehicle = availableVehicles.firstWhere(
                              (v) => v['id'] == vehicleId,
                              orElse: () => <String, dynamic>{},
                            );
                            final makeModel = vehicle['makeModel'] ?? 'Vehicle';
                            final registration = vehicle['registrationNumber'] ?? '';
                            return DropdownMenuItem<String>(
                              value: vehicleId,
                              child: Text(
                                registration.isNotEmpty 
                                    ? '$makeModel ($registration)'
                                    : makeModel,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList();
                          
                          // Only set value if it exists in items list
                          final validDriverId = currentDriverId != null && 
                              uniqueDriverIds.contains(currentDriverId) 
                              ? currentDriverId 
                              : null;
                          final validVehicleId = currentVehicleId != null && 
                              uniqueVehicleIds.contains(currentVehicleId) 
                              ? currentVehicleId 
                              : null;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.teal.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t.vehicle} ${assignmentIndex + 1}:',
                                  style: TextStyle(
                                    color: Colors.teal.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Driver dropdown
                                Text(
                                  '${t.driver}:',
                                  style: TextStyle(
                                    color: Colors.teal.shade800,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.teal),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: validDriverId,
                                    hint: Text(t.chooseDriver),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    items: driverItems,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        assignment['driverId'] = value;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Vehicle dropdown
                                Text(
                                  '${t.vehicle}:',
                                  style: TextStyle(
                                    color: Colors.teal.shade800,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.teal),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: validVehicleId,
                                    hint: Text(t.chooseVehicle),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    items: vehicleItems,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        assignment['vehicleId'] = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.teal.shade800,
                        ),
                        child: Text(t.cancel),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Check if all assignments are complete
                          bool allComplete = true;
                          for (final assignment in assignments) {
                            if (assignment['driverId'] == null || assignment['vehicleId'] == null) {
                              allComplete = false;
                              break;
                            }
                          }
                          
                          if (allComplete) {
                            Navigator.pop(context, assignments);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t.pleaseSelectDriverAndVehicleForAllAssignments),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade800,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(isEdit ? t.updateAssignment : t.assignAll),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((result) async {
      if (result != null && mounted && result is List) {
        // Convert List<dynamic> to List<Map<String, dynamic>>
        final assignments = result.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return <String, dynamic>{};
        }).where((item) => item.isNotEmpty).toList();
        
        if (assignments.isNotEmpty) {
          await _assignDriversVehicles(requestId, assignments);
        }
      }
    });
  }

  Future<void> _assignDriversVehicles(
    String requestId,
    List<Map<String, dynamic>> assignments,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get existing assigned resources and request quantity
      final requestSnapshot = await _db.child('requests/$requestId').get();
      Map<String, dynamic> existingResources = {};
      int quantity = 1;
      
      if (requestSnapshot.exists) {
        final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
        quantity = requestData['quantity'] as int? ?? 1;
        final existingResourcesRaw = requestData['assignedResources'];
        if (existingResourcesRaw != null && existingResourcesRaw is Map) {
          existingResources = Map<String, dynamic>.from(existingResourcesRaw);
        }
      }

      // Load driver and vehicle details for each assignment
      final Map<String, dynamic> newResources = {};
      
      for (final assignment in assignments) {
        final driverId = assignment['driverId'] as String?;
        final vehicleId = assignment['vehicleId'] as String?;
        final index = assignment['index']?.toString() ?? '';
        
        if (driverId == null || vehicleId == null || index.isEmpty) continue;

        // Load driver details
        final driverSnapshot = await _db.child('users/${user.uid}/drivers/$driverId').get();
        final vehicleSnapshot = await _db.child('users/${user.uid}/vehicles/$vehicleId').get();
        
        if (driverSnapshot.exists && vehicleSnapshot.exists) {
          final driverData = Map<String, dynamic>.from(driverSnapshot.value as Map);
          final vehicleData = Map<String, dynamic>.from(vehicleSnapshot.value as Map);
          
          // Validate that driver and vehicle are active
          final driverStatus = driverData['status'] as String?;
          final vehicleStatus = vehicleData['status'] as String?;
          
          if (driverStatus != null && driverStatus != 'active') {
            if (mounted) {
              final t = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${t.cannotAssignInactiveDriver} ${driverData['name'] ?? driverData['fullName'] ?? t.driver}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            continue; // Skip this assignment
          }
          
          if (vehicleStatus != null && vehicleStatus != 'active') {
            if (mounted) {
              final t = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${t.cannotAssignInactiveVehicle} ${vehicleData['makeModel'] ?? vehicleData['registrationNumber'] ?? t.vehicle}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            continue; // Skip this assignment
          }
          
          // Get driver's auth UID if available
          final driverAuthUid = driverData['authUid'] as String?;
          
          newResources[index] = {
            'driverId': driverId,
            'driverName': driverData['name'] ?? driverData['fullName'] ?? AppLocalizations.of(context)!.driver,
            'driverPhone': driverData['phone'] ?? driverData['phoneNumber'],
            'vehicleId': vehicleId,
            'vehicleInfo': vehicleData,
            'assignedAt': DateTime.now().millisecondsSinceEpoch,
            'assignedBy': user.uid,
            'status': 'pending', // pending, accepted, rejected
            'driverAuthUid': driverAuthUid, // For notifications
          };
          
          // Create notification for enterprise driver if auth UID exists
          if (driverAuthUid != null) {
            try {
              final requestSnapshot = await _db.child('requests/$requestId').get();
              final t = AppLocalizations.of(context)!;
              String loadName = t.booking;
              String pickupLocation = '';
              String destinationLocation = '';
              
              if (requestSnapshot.exists) {
                final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
                loadName = requestData['loadName'] as String? ?? t.booking;
                pickupLocation = requestData['pickupLocation'] as String? ?? '';
                destinationLocation = requestData['destinationLocation'] as String? ?? '';
              }
              
              final assignmentNotificationRef = _db.child('enterprise_driver_assignments/$driverAuthUid').push();
              final assignmentId = assignmentNotificationRef.key;
              
              if (assignmentId != null) {
                await assignmentNotificationRef.set({
                  'assignmentId': assignmentId,
                  'requestId': requestId,
                  'resourceIndex': index,
                  'driverId': driverId,
                  'vehicleId': vehicleId,
                  'vehicleInfo': vehicleData,
                  'loadName': loadName,
                  'pickupLocation': pickupLocation,
                  'destinationLocation': destinationLocation,
                  'status': 'pending',
                  'assignedAt': DateTime.now().millisecondsSinceEpoch,
                  'assignedBy': user.uid,
                  'enterpriseId': user.uid,
                  'isRead': false,
                });
                
                // Also create a notification in driver_notifications
                final driverNotificationRef = _db.child('driver_notifications/$driverAuthUid').push();
                await driverNotificationRef.set({
                  'type': 'assignment',
                  'assignmentId': assignmentId,
                  'requestId': requestId,
                  'message': '${AppLocalizations.of(context)!.newAssignments}: $loadName ${AppLocalizations.of(context)!.from} $pickupLocation ${AppLocalizations.of(context)!.to} $destinationLocation',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'isRead': false,
                });
              }
            } catch (e) {
              print('Error creating driver notification: $e');
              // Continue even if notification fails
            }
          }
        }
      }

      // Determine if we should replace all or merge
      // If all new assignments have indices starting from 0 and cover the full quantity, replace
      // Otherwise, merge with existing resources
      final Map<String, dynamic> finalResources;
      
      // Check if we have assignments for all indices from 0 to quantity-1
      bool hasAllIndices = true;
      for (int i = 0; i < quantity; i++) {
        if (!newResources.containsKey(i.toString())) {
          hasAllIndices = false;
          break;
        }
      }

      if (hasAllIndices && newResources.length == quantity) {
        // Replace all assignments (editing mode)
        finalResources = newResources;
      } else {
        // Merge with existing resources (adding new assignments)
        finalResources = Map<String, dynamic>.from(existingResources);
        finalResources.addAll(newResources);
      }

      // Update the request with all assigned resources
      await _db.child('requests/$requestId').update({
        'assignedResources': finalResources,
        'lastAssignedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Get customer ID from request
      final customerId = requestSnapshot.exists 
          ? (Map<String, dynamic>.from(requestSnapshot.value as Map)['customerId'] as String?)
          : null;

      if (mounted) {
        final t = AppLocalizations.of(context)!;
        final count = assignments.length;
        final driverPlural = count > 1 ? 's' : '';
        final vehiclePlural = count > 1 ? 's' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.driversAndVehiclesAssignedSuccessfully(count.toString(), driverPlural, vehiclePlural)),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload bookings to show the assignment
      await _loadAcceptedBookings();
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.errorAssigningDriversVehicles} $e')),
        );
      }
    }
  }

  Future<void> _askToNotifyCustomer(
    String requestId,
    String customerId,
    int assignmentCount,
  ) async {
    final t = AppLocalizations.of(context)!;
    
    // Verify that all assigned drivers have accepted before allowing notification
    try {
      final requestSnapshot = await _db.child('requests/$requestId').get();
      if (!requestSnapshot.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.errorRequestIdNotFound),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
      final quantity = requestData['quantity'] as int? ?? 1;
      final assignedResourcesRaw = requestData['assignedResources'];
      
      if (assignedResourcesRaw == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No drivers assigned yet'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Handle both Map and List types from Firebase
      Map<String, dynamic> assignedResourcesMap = {};
      if (assignedResourcesRaw is Map) {
        assignedResourcesMap = Map<String, dynamic>.from(assignedResourcesRaw);
      } else if (assignedResourcesRaw is List) {
        // Convert List to Map with index as key
        for (int i = 0; i < assignedResourcesRaw.length; i++) {
          final item = assignedResourcesRaw[i];
          if (item != null && item is Map) {
            assignedResourcesMap[i.toString()] = Map<String, dynamic>.from(item);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid assignedResources format'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      int acceptedCount = 0;
      int pendingCount = 0;
      int rejectedCount = 0;
      
      for (final assignment in assignedResourcesMap.values) {
        if (assignment is Map) {
          final status = assignment['status'] as String? ?? 'pending';
          if (status == 'accepted') {
            acceptedCount++;
          } else if (status == 'pending') {
            pendingCount++;
          } else if (status == 'rejected') {
            rejectedCount++;
          }
        }
      }
      
      // Check if all required assignments are accepted
      if (acceptedCount < quantity || rejectedCount > 0 || pendingCount > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot notify customer yet. $acceptedCount of $quantity driver${quantity > 1 ? 's' : ''} accepted. ${pendingCount > 0 ? '$pendingCount pending. ' : ''}${rejectedCount > 0 ? '$rejectedCount rejected. Please reassign.' : ''}',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying assignment status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    final shouldNotify = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.teal.shade800, width: 1),
        ),
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.teal.shade800),
            const SizedBox(width: 8),
            Text(
              t.notifyCustomer,
              style: TextStyle(
                color: Colors.teal.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          t.doYouWantToNotifyCustomer(assignmentCount.toString(), assignmentCount > 1 ? 's' : '', assignmentCount > 1 ? 's' : ''),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            child: Text(t.no),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade800,
              foregroundColor: Colors.white,
            ),
            child: Text(t.yesNotify),
          ),
        ],
      ),
    );

    if (shouldNotify == true) {
      await _sendNotificationToCustomer(requestId, customerId, assignmentCount);
    }
  }

  Future<void> _sendNotificationToCustomer(
    String requestId,
    String customerId,
    int assignmentCount,
  ) async {
    try {
      final notificationRef = _db.child('customer_notifications/$customerId').push();
      final notificationId = notificationRef.key;
      
      if (notificationId == null) return;

      // Get request details for the notification message
      final t = AppLocalizations.of(context)!;
      final requestSnapshot = await _db.child('requests/$requestId').get();
      String loadName = t.yourCargo;
      if (requestSnapshot.exists) {
        final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
        loadName = requestData['loadName'] as String? ?? t.yourCargo;
      }

      final vehiclePlural = assignmentCount > 1 ? 's' : '';
      final driverPlural = assignmentCount > 1 ? 's' : '';
      await notificationRef.set({
        'type': 'resources_assigned',
        'requestId': requestId,
        'message': t.vehiclesAndDriversAssignedToCargo(assignmentCount.toString(), vehiclePlural, driverPlural, loadName),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.customerHasBeenNotified),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.errorSendingNotification} $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final t = AppLocalizations.of(context)!;
    final requestId = booking['requestId'] as String?;
    
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
          side: BorderSide(color: Colors.red.shade800, width: 1),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade800),
            const SizedBox(width: 8),
            Text(
              t.cancelRequest,
              style: TextStyle(
                color: Colors.red.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          t.areYouSureCancelRequest,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
            ),
            child: Text(t.cancelRequest),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Get customer ID from booking data
      final customerId = booking['customerId'] as String?;
      
      // Update request status to cancelled
      await _db.child('requests/$requestId').update({
        'status': 'cancelled',
        'cancelledBy': 'enterprise',
        'cancelledAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Remove all customer offers for this request
      await _db.child('customer_offers/$requestId').remove();

      // Notify customer about cancellation
      final t = AppLocalizations.of(context)!;
      if (customerId != null) {
        await _db.child('customer_notifications/$customerId').push().set({
          'type': 'request_cancelled',
          'requestId': requestId,
          'message': t.enterpriseCancelledBooking,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'isRead': false,
        });
      }

      // Notify assigned drivers if any
      final assignedResourcesRaw = booking['assignedResources'];
      if (assignedResourcesRaw != null) {
        Map<String, dynamic> assignedResources = {};
        if (assignedResourcesRaw is Map) {
          assignedResources = Map<String, dynamic>.from(assignedResourcesRaw);
        } else if (assignedResourcesRaw is List) {
          // Convert List to Map with index as key
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
            // Use driverAuthUid if available (for enterprise drivers), otherwise fall back to driverId
            final driverAuthUid = assignmentData['driverAuthUid'] as String?;
            final driverId = assignmentData['driverId'] as String?;
            final notificationDriverId = driverAuthUid ?? driverId;
            
            if (notificationDriverId != null) {
              try {
                await _db.child('driver_notifications/$notificationDriverId').push().set({
                  'type': 'request_cancelled',
                  'requestId': requestId,
                  'message': t.enterpriseCancelledBooking,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'isRead': false,
                });
              } catch (e) {
                // Ignore errors for individual driver notifications
                print('Error notifying driver $notificationDriverId: $e');
              }
            }
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.requestCancelled),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Reload bookings to remove the cancelled one
      await _loadAcceptedBookings();
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.errorCancellingBooking} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _dispatchBooking(Map<String, dynamic> booking) async {
    final t = AppLocalizations.of(context)!;
    final requestId = booking['requestId'] as String?;
    
    if (requestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.errorRequestIdNotFound),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if all vehicles are assigned
    final quantity = booking['quantity'] as int? ?? 1;
    final assignedResourcesRaw = booking['assignedResources'];
    
    // Handle both Map and List types from Firebase
    Map<String, dynamic> assignedResources = {};
    if (assignedResourcesRaw != null) {
      if (assignedResourcesRaw is Map) {
        assignedResources = Map<String, dynamic>.from(assignedResourcesRaw);
      } else if (assignedResourcesRaw is List) {
        // Convert List to Map with index as key
        for (int i = 0; i < assignedResourcesRaw.length; i++) {
          final item = assignedResourcesRaw[i];
          if (item != null && item is Map) {
            assignedResources[i.toString()] = Map<String, dynamic>.from(item);
          }
        }
      }
    }
    
    final assignedCount = assignedResources.length;
    
    if (assignedCount < quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.pleaseAssignAllVehiclesBeforeDispatching(quantity.toString(), quantity > 1 ? 's' : '')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Check if all assigned drivers have accepted their assignments
    int acceptedCount = 0;
    int pendingCount = 0;
    int rejectedCount = 0;
    for (final assignment in assignedResources.values) {
      if (assignment is Map) {
        final assignmentData = Map<String, dynamic>.from(assignment);
        final status = assignmentData['status'] as String? ?? 'pending';
        if (status == 'accepted') {
          acceptedCount++;
        } else if (status == 'pending') {
          pendingCount++;
        } else if (status == 'rejected') {
          rejectedCount++;
        }
      }
    }
    
    // All drivers must have accepted before dispatch
    if (acceptedCount < assignedCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.pleaseWaitForAllDriversToAccept(acceptedCount.toString(), assignedCount.toString())),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    
    // Check if all accepted drivers have started their journey
    int startedCount = 0;
    for (final assignment in assignedResources.values) {
      if (assignment is Map) {
        final assignmentData = Map<String, dynamic>.from(assignment);
        final status = assignmentData['status'] as String?;
        if (status == 'accepted' && assignmentData['journeyStarted'] == true) {
          startedCount++;
        }
      }
    }
    
    if (acceptedCount > 0 && startedCount < acceptedCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.pleaseWaitForAllDriversToStartJourney(startedCount.toString(), acceptedCount.toString())),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
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
            Icon(Icons.local_shipping, color: Colors.green.shade800),
            const SizedBox(width: 8),
            Text(
              t.dispatchBooking,
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          t.areYouSureDispatchBooking,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
            child: Text(t.dispatch),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Get customer ID from booking data
      final customerId = booking['customerId'] as String?;
      
      // Update request status to dispatched
      await _db.child('requests/$requestId').update({
        'status': 'dispatched',
        'dispatchedAt': DateTime.now().millisecondsSinceEpoch,
        'dispatchedBy': _auth.currentUser?.uid,
      });

      // Notify customer about dispatch
      final t = AppLocalizations.of(context)!;
      if (customerId != null) {
        final loadName = booking['loadName'] as String? ?? t.yourCargo;
        await _db.child('customer_notifications/$customerId').push().set({
          'type': 'booking_dispatched',
          'requestId': requestId,
          'message': t.yourBookingHasBeenDispatched(loadName),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'isRead': false,
        });
      }

      // Notify assigned enterprise drivers if any
      final assignedResourcesForNotification = booking['assignedResources'];
      if (assignedResourcesForNotification != null && assignedResourcesForNotification is Map) {
        final assignedResourcesMap = Map<String, dynamic>.from(assignedResourcesForNotification);
        for (final assignment in assignedResourcesMap.values) {
          if (assignment is Map) {
            final assignmentData = Map<String, dynamic>.from(assignment);
            final driverAuthUid = assignmentData['driverAuthUid'] as String?;
            if (driverAuthUid != null) {
              try {
                await _db.child('driver_notifications/$driverAuthUid').push().set({
                  'type': 'booking_dispatched',
                  'requestId': requestId,
                  'message': t.bookingHasBeenDispatched,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'isRead': false,
                });
              } catch (e) {
                // Ignore errors for individual driver notifications
                print('Error notifying driver $driverAuthUid: $e');
              }
            }
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.bookingDispatchedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload bookings to update the list
      await _loadAcceptedBookings();
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.errorDispatchingBooking} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
