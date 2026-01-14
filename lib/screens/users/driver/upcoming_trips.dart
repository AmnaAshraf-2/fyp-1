import 'dart:async';
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
  StreamSubscription? _requestsSubscription;
  StreamSubscription? _assignmentsSubscription;
  Map<String, Map<String, dynamic>> _acceptedAssignments = {};

  @override
  void initState() {
    super.initState();
    _loadUpcomingTrips();
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _assignmentsSubscription?.cancel();
    super.dispose();
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

      // Check if user is enterprise driver and get enterprise info
      final userSnapshot = await _db.child('users/${user.uid}').get();
      bool isEnterpriseDriver = false;
      String? userEnterpriseId;
      String? userEnterpriseDriverId;
      if (userSnapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        isEnterpriseDriver = userData['role'] == 'enterprise_driver';
        if (isEnterpriseDriver) {
          userEnterpriseId = userData['enterpriseId'] as String?;
          userEnterpriseDriverId = userData['enterpriseDriverId'] as String?;
        }
      }

      // Set a timeout for Firebase operations
      final timeout = Duration(seconds: 10);

      if (isEnterpriseDriver) {
        // For enterprise drivers, use enterprise-specific logic
        _loadUpcomingTripsForEnterpriseDriver(userEnterpriseId);
      } else {
        // For freelance drivers, use freelance-specific logic
        _loadUpcomingTripsForFreelanceDriver();
      }
    } catch (e) {
      print('Error loading upcoming trips: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Load upcoming trips specifically for enterprise drivers
  /// Enterprise drivers get trips from assignedResources where their assignment is accepted
  void _loadUpcomingTripsForEnterpriseDriver(String? userEnterpriseId) {
    final timeout = Duration(seconds: 10);
    
    // For enterprise drivers, the source of truth is assignedResources in requests
    // We can optionally load assignments for reference, but we'll primarily use assignedResources
    _acceptedAssignments.clear();
    
    // Listen to enterprise driver assignments (optional, for reference)
    _assignmentsSubscription?.cancel();
    _assignmentsSubscription = _db
        .child('enterprise_driver_assignments/${_auth.currentUser?.uid}')
        .onValue
        .timeout(timeout)
        .listen((assignmentsEvent) {
      if (assignmentsEvent.snapshot.exists) {
        _acceptedAssignments.clear();
        // Get all accepted assignments for this driver
        for (final assignment in assignmentsEvent.snapshot.children) {
          try {
            // Handle both Map and List types
            Map<String, dynamic> assignmentData;
            if (assignment.value is Map) {
              assignmentData = Map<String, dynamic>.from(assignment.value as Map);
            } else {
              print('⚠️ Warning: Assignment value is not a Map. Type: ${assignment.value.runtimeType}');
              continue;
            }
            
            final status = assignmentData['status'] as String?;
            if (status == 'accepted') {
              final requestId = assignmentData['requestId'] as String?;
              if (requestId != null) {
                _acceptedAssignments[requestId] = assignmentData;
                print('✅ DEBUG: Found accepted assignment - requestId: $requestId, resourceIndex: ${assignmentData['resourceIndex']}');
              }
            }
          } catch (e) {
            print('⚠️ Error processing assignment: $e');
          }
        }
        print('✅ DEBUG: Total accepted assignments: ${_acceptedAssignments.length}');
        // Trigger reload of requests
        _loadRequestsForEnterpriseDriver(userEnterpriseId);
      } else {
        _acceptedAssignments.clear();
        print('⚠️ DEBUG: No assignments found in enterprise_driver_assignments, will check assignedResources directly');
        // Still load requests - the fallback will find them in assignedResources
        _loadRequestsForEnterpriseDriver(userEnterpriseId);
      }
    }, onError: (error) {
      print('❌ Error loading assignments: $error');
      // Even if assignments fail, try to load from requests directly
      _loadRequestsForEnterpriseDriver(userEnterpriseId);
    });

    // Always listen to requests - this is the primary source of truth
    _loadRequestsForEnterpriseDriver(userEnterpriseId);
  }

  /// Load upcoming trips specifically for freelance drivers
  /// Freelance drivers get trips where acceptedDriverId matches their UID
  void _loadUpcomingTripsForFreelanceDriver() {
    final timeout = Duration(seconds: 10);
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    _requestsSubscription?.cancel();
    _requestsSubscription = _db.child('requests').onValue.timeout(timeout).listen((event) {
      if (event.snapshot.exists) {
        final trips = <Map<String, dynamic>>[];
        for (final request in event.snapshot.children) {
          final requestId = request.key;
          if (requestId == null) continue;
          
          // Handle both Map and List types from Firebase
          Map<String, dynamic> requestData;
          if (request.value is Map) {
            requestData = Map<String, dynamic>.from(request.value as Map);
          } else {
            print('⚠️ Warning: Request value is not a Map. Type: ${request.value.runtimeType}, RequestId: $requestId');
            continue;
          }
          
          // FREELANCE DRIVER LOGIC: Check acceptedDriverId (NOT assignedResources)
          // Enterprise drivers should NEVER use this logic
          final acceptedDriverId = requestData['acceptedDriverId'] as String?;
          final requestStatus = requestData['status'] as String?;
          
          // Explicitly ignore assignedResources for freelance drivers
          // Only check acceptedDriverId for freelance drivers
          if (acceptedDriverId == user.uid && 
              (requestStatus == 'accepted' || 
               requestStatus == 'in_progress' || 
               requestStatus == 'dispatched')) {
            requestData['requestId'] = requestId;
            requestData['isEnterpriseDriver'] = false; // Explicitly mark as freelance
            trips.add(requestData);
          }
        }
        if (mounted) {
          setState(() {
            _upcomingTrips = trips;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _upcomingTrips = [];
            _isLoading = false;
          });
        }
      }
    }, onError: (error) {
      print('Error loading upcoming trips for freelance driver: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  /// Helper method to load requests for enterprise drivers
  /// This matches accepted assignments with requests
  void _loadRequestsForEnterpriseDriver(String? userEnterpriseId) {
    final timeout = Duration(seconds: 10);
    _requestsSubscription?.cancel();
    _requestsSubscription = _db.child('requests').onValue.timeout(timeout).listen((event) {
      if (event.snapshot.exists) {
        final trips = <Map<String, dynamic>>[];
        final user = _auth.currentUser;
        if (user == null) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }

        for (final request in event.snapshot.children) {
          final requestId = request.key;
          if (requestId == null) continue;
          
          // Handle both Map and List types from Firebase
          Map<String, dynamic> requestData;
          if (request.value is Map) {
            requestData = Map<String, dynamic>.from(request.value as Map);
          } else {
            print('⚠️ Warning: Request value is not a Map. Type: ${request.value.runtimeType}, RequestId: $requestId');
            continue;
          }
          
          // ENTERPRISE DRIVER LOGIC: Check assignedResources directly (PRIMARY SOURCE OF TRUTH)
          // assignedResources in the request is the authoritative source, not enterprise_driver_assignments
          // Freelance drivers should NEVER use this logic - they use _loadUpcomingTripsForFreelanceDriver()
          final assignedResources = requestData['assignedResources'];
          if (assignedResources != null) {
            Map<String, dynamic> assignedResourcesMap;
            
            // Handle assignedResources as either Map or List
            if (assignedResources is Map) {
              assignedResourcesMap = Map<String, dynamic>.from(assignedResources);
            } else if (assignedResources is List) {
              // Convert List to Map if needed
              assignedResourcesMap = {};
              for (int i = 0; i < assignedResources.length; i++) {
                if (assignedResources[i] is Map) {
                  assignedResourcesMap[i.toString()] = Map<String, dynamic>.from(assignedResources[i] as Map);
                }
              }
            } else {
              continue; // Skip if not Map or List
            }
            
            print('🔍 DEBUG: Checking ${assignedResourcesMap.length} resources in assignedResources for requestId: $requestId');
            
            // Check each assigned resource to find one matching this driver
            for (final entry in assignedResourcesMap.entries) {
              final resourceIndex = entry.key;
              final assignmentEntry = entry.value;
              
              if (assignmentEntry is Map) {
                final assignmentData = Map<String, dynamic>.from(assignmentEntry);
                final driverAuthUid = assignmentData['driverAuthUid'] as String?;
                final status = assignmentData['status'] as String?;
                
                print('🔍 DEBUG: Resource $resourceIndex - driverAuthUid: $driverAuthUid, currentUser: ${user.uid}, status: $status');
                
                // Check if this assignment belongs to the current driver and is accepted
                if (driverAuthUid == user.uid && status == 'accepted') {
                  final journeyStarted = assignmentData['journeyStarted'] == true;
                  
                  // Only show in upcoming trips if journey hasn't started yet
                  // Once journey starts, it should only appear in live trip section
                  if (journeyStarted) {
                    print('⚠️ DEBUG: Journey already started for requestId: $requestId, skipping from upcoming trips');
                    break; // Journey started, don't add to upcoming trips
                  }
                  
                  print('✅ DEBUG: Found accepted assignment - requestId: $requestId, resourceIndex: $resourceIndex');
                  
                  // Add all request data with assignment info
                  requestData['requestId'] = requestId;
                  requestData['isEnterpriseDriver'] = true;
                  requestData['assignmentIndex'] = resourceIndex;
                  requestData['vehicleInfo'] = assignmentData['vehicleInfo'];
                  requestData['journeyStarted'] = false; // Not started yet
                  requestData['enterpriseId'] = assignmentData['assignedBy'] ?? 
                                               requestData['acceptedEnterpriseId'] ??
                                               userEnterpriseId;
                  
                  final requestStatus = requestData['status'] as String?;
                  print('🔍 DEBUG: Request status: $requestStatus');
                  
                  // For enterprise drivers, show accepted assignments even if request is still pending
                  // (the request will be accepted/dispatched when enterprise dispatches)
                  // But only if journey hasn't started
                  if (requestStatus == 'accepted' || 
                      requestStatus == 'dispatched' ||
                      (requestStatus == 'pending' && requestData['isEnterpriseDriver'] == true)) {
                    print('✅ DEBUG: Adding trip - requestId: $requestId, status: $requestStatus');
                    trips.add(requestData);
                  } else {
                    print('⚠️ DEBUG: Request status $requestStatus does not allow showing trip');
                  }
                  break; // Found matching assignment, no need to check other resources
                }
              }
            }
          } else {
            print('⚠️ DEBUG: assignedResources is null for requestId: $requestId');
          }
        }
        
        if (mounted) {
          setState(() {
            _upcomingTrips = trips;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _upcomingTrips = [];
            _isLoading = false;
          });
        }
      }
    }, onError: (error) {
      print('Error loading requests: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
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

  Future<void> _callEnterprise(String? enterpriseId) async {
    if (enterpriseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enterprise ID not available')),
      );
      return;
    }

    try {
      final enterpriseSnapshot = await _db.child('users/$enterpriseId').get();
      if (enterpriseSnapshot.exists) {
        final enterpriseData = Map<String, dynamic>.from(enterpriseSnapshot.value as Map);
        final phoneNumber = enterpriseData['phone']?.toString() ?? 
                           enterpriseData['phoneNumber']?.toString() ??
                           enterpriseData['contactNumber']?.toString();
        
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
            const SnackBar(content: Text('Enterprise phone number not available')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enterprise information not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calling enterprise: $e')),
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
              'message': t.driverCancelledRequest,
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

  Future<void> _startJourney(String requestId, {String? assignmentIndex}) async {
    final t = AppLocalizations.of(context)!;
    final user = _auth.currentUser;
    if (user == null) return;
    
    // Check if user is enterprise driver
    final userSnapshot = await _db.child('users/${user.uid}').get();
    bool isEnterpriseDriver = false;
    if (userSnapshot.exists) {
      final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
      isEnterpriseDriver = userData['role'] == 'enterprise_driver';
    }
    
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
        final requestSnapshot = await _db.child('requests/$requestId').get();
        if (!requestSnapshot.exists) return;
        
        final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
        final enterpriseId = requestData['enterpriseId'] as String?;
        
        if (isEnterpriseDriver && assignmentIndex != null) {
          // Update assignment status to journey_started
          await _db.child('requests/$requestId/assignedResources/$assignmentIndex').update({
            'journeyStartedAt': DateTime.now().millisecondsSinceEpoch,
            'journeyStarted': true,
          });
          
          // Check if all assigned drivers have started journey
          final assignedResources = requestData['assignedResources'] as Map?;
          if (assignedResources != null) {
            int startedCount = 0;
            int totalAcceptedCount = 0;
            
            for (final assignment in assignedResources.values) {
              if (assignment is Map) {
                final assignmentData = Map<String, dynamic>.from(assignment);
                final status = assignmentData['status'] as String?;
                if (status == 'accepted') {
                  totalAcceptedCount++;
                  if (assignmentData['journeyStarted'] == true) {
                    startedCount++;
                  }
                }
              }
            }
            
            // If all accepted drivers have started, notify enterprise
            if (startedCount >= totalAcceptedCount && totalAcceptedCount > 0 && enterpriseId != null) {
              final loadName = requestData['loadName'] as String? ?? t.yourCargo;
              await _db.child('enterprise_notifications/$enterpriseId').push().set({
                'type': 'all_drivers_started',
                'requestId': requestId,
                'message': t.allDriversStartedCanMarkDispatched(loadName),
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'isRead': false,
              });
            }
          }
        } else {
          // Regular driver flow
          await _db.child('requests/$requestId').update({
            'status': 'in_progress',
            'journeyStartedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }

        // Start location tracking for driver
        final trackingService = LocationTrackingService();
        await trackingService.startTracking(user.uid);

        // Notify customer that cargo is now in transit (only for regular drivers or when all enterprise drivers start)
        if (!isEnterpriseDriver) {
          final customerId = requestData['customerId'];
          if (customerId != null) {
            await _db.child('customer_notifications/$customerId').push().set({
              'type': 'journey_started',
              'requestId': requestId,
              'message': t.cargoInTransit,
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
                            // Don't show fare for enterprise drivers
                            if (trip['isEnterpriseDriver'] != true)
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
                            
                            // Contact Information - Different for enterprise vs regular drivers
                            if (trip['isEnterpriseDriver'] == true) ...[
                              // For enterprise drivers, show call enterprise option
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.phone, size: 18),
                                  label: const Text('Call Enterprise'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _callEnterprise(trip['enterpriseId'] ?? trip['acceptedEnterpriseId']),
                                ),
                              ),
                              // Determine button to show based on journey status
                              Builder(
                                builder: (context) {
                                  final journeyStarted = trip['journeyStarted'] == true;
                                  final requestStatus = trip['status'] as String?;
                                  final isInProgress = requestStatus == 'in_progress';
                                  
                                  // Show "Start Journey" button if:
                                  // - Status is accepted, dispatched, or pending (for enterprise drivers)
                                  // - Journey hasn't started yet (!journeyStarted)
                                  // - Status is not in_progress
                                  if (!journeyStarted && !isInProgress && 
                                      (requestStatus == 'accepted' || 
                                       requestStatus == 'dispatched' || 
                                       requestStatus == 'pending')) {
                                    return Column(
                                      children: [
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
                                            onPressed: () => _startJourney(
                                              trip['requestId'],
                                              assignmentIndex: trip['assignmentIndex'] as String?,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  
                                  // Show "Start Journey" button if journey has started (to navigate to live trip)
                                  // - Journey has actually started (journeyStarted == true) OR
                                  // - Status is in_progress
                                  if (journeyStarted || isInProgress) {
                                    return Column(
                                      children: [
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
                                    );
                                  }
                                  
                                  return const SizedBox.shrink();
                                },
                              ),
                            ] else ...[
                              // For regular drivers, show customer contact
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
                              // Start Journey button for regular drivers (only if not already started)
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
                                    onPressed: () => _startJourney(
                                      trip['requestId'],
                                      assignmentIndex: trip['assignmentIndex'] as String?,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                            // View Live Trip button (shown for both types when journey started)
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
