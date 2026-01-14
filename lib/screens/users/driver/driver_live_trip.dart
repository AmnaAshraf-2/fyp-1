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

      // Check if user is enterprise driver
      final userSnapshot = await _db.child('users/${user.uid}').get();
      bool isEnterpriseDriver = false;
      if (userSnapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        isEnterpriseDriver = userData['role'] == 'enterprise_driver';
      }

      // Listen for active trip (status = in_progress for regular drivers, or journeyStarted = true for enterprise drivers)
      _db.child('requests').onValue.listen((event) {
        if (event.snapshot.exists) {
          Map<String, dynamic>? activeTrip;
          
          for (final request in event.snapshot.children) {
            final requestData = Map<String, dynamic>.from(request.value as Map);
            final requestId = request.key;
            if (requestId == null) continue;
            bool isActiveTrip = false;
            
            if (isEnterpriseDriver) {
              // For enterprise drivers, check assignedResources
              final assignedResourcesRaw = requestData['assignedResources'];
              if (assignedResourcesRaw != null) {
                Map<String, dynamic> assignedResourcesMap = {};
                
                // Handle both Map and List types
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
                
                // Check for active trips - only include if journey started but NOT completed
                for (final entry in assignedResourcesMap.entries) {
                  final index = entry.key;
                  final assignment = entry.value;
                  if (assignment is Map) {
                    final assignmentData = Map<String, dynamic>.from(assignment);
                    final driverAuthUid = assignmentData['driverAuthUid'] as String?;
                    final status = assignmentData['status'] as String?;
                    final journeyStarted = assignmentData['journeyStarted'] == true;
                    final journeyCompleted = assignmentData['journeyCompleted'] == true;
                    
                    // Check if this driver is assigned, accepted, has started journey, but NOT completed
                    // Once journey is completed, it should not appear in live trip section
                    if (driverAuthUid == user.uid && 
                        status == 'accepted' && 
                        journeyStarted && 
                        !journeyCompleted) {
                      isActiveTrip = true;
                      // Add assignment-specific data to requestData
                      requestData['requestId'] = requestId;
                      requestData['assignmentIndex'] = index.toString();
                      requestData['vehicleInfo'] = assignmentData['vehicleInfo'];
                      requestData['journeyStartedAt'] = assignmentData['journeyStartedAt'];
                      requestData['isEnterpriseDriver'] = true;
                      activeTrip = requestData;
                      break; // Found active trip for this driver, no need to check other assignments
                    }
                  }
                }
              }
            } else {
              // For regular drivers, check acceptedDriverId and status
              if (requestData['acceptedDriverId'] == user.uid && 
                  requestData['status'] == 'in_progress') {
                requestData['requestId'] = requestId;
                activeTrip = requestData;
              }
            }
          }
          
          // Update state based on whether active trip was found
          setState(() {
            _liveTrip = activeTrip;
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
          final t = AppLocalizations.of(context)!;
          if (await canLaunchUrl(phoneUri)) {
            await launchUrl(phoneUri);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.cannotMakeCall(phoneNumber))),
            );
          }
        } else {
          final t = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.customerPhoneNumberNotAvailable)),
          );
        }
      }
    } catch (e) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.errorCallingCustomer} $e')),
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
          final t = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.requestNotFound)),
          );
          return;
        }

        final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
        final customerId = requestData['customerId'];
        final driverId = _auth.currentUser?.uid;
        final journeyCompletedAt = DateTime.now().millisecondsSinceEpoch;

        // Check if user is enterprise driver
        final userSnapshot = await _db.child('users/${driverId}').get();
        bool isEnterpriseDriver = false;
        String? assignmentIndex;
        if (userSnapshot.exists) {
          final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
          isEnterpriseDriver = userData['role'] == 'enterprise_driver';
        }

        // Get assignment index if enterprise driver
        if (isEnterpriseDriver && _liveTrip != null) {
          assignmentIndex = _liveTrip!['assignmentIndex'] as String?;
        }

        if (isEnterpriseDriver && assignmentIndex != null) {
          // For enterprise drivers, update the assignment status
          await _db.child('requests/$requestId/assignedResources/$assignmentIndex').update({
            'journeyCompleted': true,
            'journeyCompletedAt': journeyCompletedAt,
          });
          
          // Check if all assigned drivers have completed journey
          final assignedResourcesRaw = requestData['assignedResources'];
          if (assignedResourcesRaw != null) {
            Map<String, dynamic> assignedResourcesMap = {};
            
            // Handle both Map and List types
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
            
            int completedCount = 0;
            int totalAcceptedCount = 0;
            
            for (final assignment in assignedResourcesMap.values) {
              if (assignment is Map) {
                final assignmentData = Map<String, dynamic>.from(assignment);
                final status = assignmentData['status'] as String?;
                if (status == 'accepted') {
                  totalAcceptedCount++;
                  if (assignmentData['journeyCompleted'] == true) {
                    completedCount++;
                  }
                }
              }
            }
            
            // If all accepted drivers have completed, notify enterprise and set flag
            if (completedCount >= totalAcceptedCount && totalAcceptedCount > 0) {
              // Try to get enterprise ID from multiple sources
              String? enterpriseId = requestData['acceptedEnterpriseId'] as String?;
              
              // If acceptedEnterpriseId is not set, try to get from assignedBy in assignedResources
              if (enterpriseId == null && assignedResourcesMap.isNotEmpty) {
                for (final assignment in assignedResourcesMap.values) {
                  if (assignment is Map) {
                    final assignmentData = Map<String, dynamic>.from(assignment);
                    final assignedBy = assignmentData['assignedBy'] as String?;
                    if (assignedBy != null) {
                      enterpriseId = assignedBy;
                      break; // Use the first assignedBy found
                    }
                  }
                }
              }
              
              // Set flag that all drivers have completed (keep status as 'dispatched' until enterprise marks as delivered)
              await _db.child('requests/$requestId').update({
                'allDriversCompleted': true,
                'allDriversCompletedAt': journeyCompletedAt,
                'journeyCompletedAt': journeyCompletedAt,
              });
              
              // Notify enterprise that all drivers have completed
              if (enterpriseId != null) {
                final loadName = requestData['loadName'] as String? ?? 'booking';
                await _db.child('enterprise_notifications/$enterpriseId').push().set({
                  'type': 'all_drivers_completed',
                  'requestId': requestId,
                  'message': 'All drivers have completed journey for $loadName. You can now mark it as delivered.',
                  'timestamp': journeyCompletedAt,
                  'isRead': false,
                });
              }
            }
          }
        } else {
          // For regular drivers, update request status to completed
          await _db.child('requests/$requestId').update({
            'status': 'completed',
            'journeyCompletedAt': journeyCompletedAt,
          });
        }

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
          final t = AppLocalizations.of(context)!;
          await _db.child('customer_notifications/$customerId').push().set({
            'type': 'journey_completed',
            'requestId': requestId,
            'driverId': driverId,
            'message': t.yourCargoHasBeenDeliveredSuccessfully,
            'timestamp': journeyCompletedAt,
          });
        }

        // Stop location tracking
        await LocationTrackingService().stopTracking();

        // For enterprise drivers, explicitly clear the live trip since it's completed
        if (isEnterpriseDriver) {
          if (mounted) {
            setState(() {
              _liveTrip = null;
            });
          }
        }

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
        return loadType ?? t.nA;
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
                        t.noActiveTrip,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF004d4d),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.startJourneyFromUpcomingTrips,
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
                                  Text(
                                    t.journeyInProgress,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  if (_liveTrip!['journeyStartedAt'] != null)
                                    Text(
                                      '${t.started} ${_formatTimestamp(_liveTrip!['journeyStartedAt'])}',
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
                        child: Builder(
                          builder: (context) {
                            // Check if user is enterprise driver
                            final isEnterpriseDriver = _liveTrip!['isEnterpriseDriver'] == true;
                            
                            return Padding(
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
                                  _buildDetailRow(t.loadName, _liveTrip!['loadName'] ?? t.nA),
                                  _buildDetailRow(t.loadType, _getLoadTypeLabel(_liveTrip!['loadType'], t)),
                                  _buildDetailRow(t.weight, '${_liveTrip!['weight']} ${_liveTrip!['weightUnit']}'),
                                  _buildDetailRow(t.quantity, '${_liveTrip!['quantity']} ${t.vehicles}'),
                                  _buildDetailRow(t.vehicleType, _liveTrip!['vehicleType'] ?? t.nA),
                                  if (_liveTrip!['pickupDate'] != null && _liveTrip!['pickupDate'] != t.nA)
                                    _buildDetailRow(t.pickupDate, _liveTrip!['pickupDate']),
                                  _buildDetailRow(t.pickupTime, _liveTrip!['pickupTime'] ?? t.nA),
                                  // Don't show fare for enterprise drivers
                                  if (!isEnterpriseDriver) ...[
                                    Builder(
                                      builder: (context) {
                                        final finalFare = _liveTrip!['finalFare'];
                                        final offerFare = _liveTrip!['offerFare'];
                                        final fareText = finalFare != null 
                                            ? 'Rs $finalFare' 
                                            : (offerFare != null ? 'Rs $offerFare' : t.nA);
                                        return _buildDetailRow(t.fare, fareText);
                                      },
                                    ),
                                  ],
                                  _buildDetailRow(t.insurance, _liveTrip!['isInsured'] == true ? t.yes : t.no),
                                ],
                              ),
                            );
                          },
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
                                            t.pickupLocation,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _liveTrip!['pickupLocation'] ?? t.notSpecified,
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
                                            t.destinationLocation,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _liveTrip!['destinationLocation'] ?? t.notSpecified,
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
                                    label: Text(t.viewDirectionsOnMap, style: const TextStyle(color: Colors.white)),
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

                      // Contact Information - Only show for regular drivers
                      if (_liveTrip!['isEnterpriseDriver'] != true) ...[
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
                                  t.contactInformation,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF004d4d),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_liveTrip!['senderPhone'] != null)
                                  _buildDetailRow(t.senderPhone, _liveTrip!['senderPhone']),
                                if (_liveTrip!['receiverPhone'] != null)
                                  _buildDetailRow(t.receiverPhone, _liveTrip!['receiverPhone']),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.phone, color: Colors.white),
                                    label: Text(t.callCustomer, style: const TextStyle(color: Colors.white)),
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
                      ],

                      // Complete Journey Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, color: Colors.white, size: 24),
                          label: Text(
                            t.completeJourney,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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

