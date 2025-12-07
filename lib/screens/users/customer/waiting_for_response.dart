import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/screens/users/customer/customer_accepted_offer.dart';
import 'package:logistics_app/screens/users/customer/customerDashboard.dart';
import 'package:logistics_app/screens/users/customer/upcoming_bookings.dart';
import 'package:logistics_app/services/vehicle_provider.dart';

class WaitingForResponseScreen extends StatefulWidget {
  final String requestId;

  const WaitingForResponseScreen({super.key, required this.requestId});

  @override
  State<WaitingForResponseScreen> createState() => _WaitingForResponseScreenState();
}

class _WaitingForResponseScreenState extends State<WaitingForResponseScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  final VehicleProvider _vehicleProvider = VehicleProvider();
  List<VehicleModel> _vehicles = [];
  bool _isLoading = true;
  Map<String, dynamic>? _requestData;
  List<Map<String, dynamic>> _driverOffers = [];
  bool _hasShownTimeoutDialog = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadRequestData();
    _listenForOffers();
    // Set up periodic check for expired counter offers (every second)
    _startCounterOfferTimeoutCheck();
    // Set up periodic check for 5-minute timeout (every 10 seconds)
    _startRequestTimeoutCheck();
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
      // Handle error
    }
  }

  /// Convert vehicle type (could be nameKey or localized name) to nameKey
  /// This handles backward compatibility with old data that might have localized names
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
    
    return false;
  }

  void _startCounterOfferTimeoutCheck() {
    // Check for expired counter offers every second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _checkAndRemoveExpiredCounterOffers();
        _startCounterOfferTimeoutCheck(); // Schedule next check
      }
    });
  }

  Future<void> _checkAndRemoveExpiredCounterOffers() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      for (final offer in _driverOffers) {
        // Check both counter offers and acceptances (both expire after 10 seconds)
        if ((offer['offerType'] == 'counter' || offer['offerType'] == 'acceptance') && 
            offer['status'] == 'pending') {
          final offerTimestamp = offer['timestamp'] as int? ?? 0;
          if (offerTimestamp > 0) {
            final elapsedSeconds = (now - offerTimestamp) / 1000;
            if (elapsedSeconds > 10) {
              // Response expired (10 seconds), remove it
              final offerId = offer['offerId'] as String?;
              if (offerId != null) {
                await _db.child('customer_offers/${widget.requestId}/$offerId').remove();
                
                // Also remove from driver/enterprise new_offers if it was an acceptance
                if (offer['offerType'] == 'acceptance') {
                  final driverId = offer['driverId'];
                  final enterpriseId = offer['enterpriseId'];
                  
                  if (driverId != null) {
                    await _db.child('driver_offers/$driverId/new_offers/${widget.requestId}').remove();
                  }
                  if (enterpriseId != null) {
                    await _db.child('enterprise_offers/$enterpriseId/new_offers/${widget.requestId}').remove();
                  }
                }
              }
              // The listener will automatically update the UI
              return; // Exit after removing one to avoid multiple operations
            }
          }
        }
      }
    } catch (e) {
      print('🔍 DEBUG: Error checking expired offers: $e');
    }
  }

  void _startRequestTimeoutCheck() {
    // Check for 5-minute timeout every 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _checkRequestTimeout();
        _startRequestTimeoutCheck(); // Schedule next check
      }
    });
  }

  Future<void> _checkRequestTimeout() async {
    try {
      // Don't show dialog if already shown or if request is accepted/cancelled
      if (_hasShownTimeoutDialog || _requestData == null) return;
      
      final requestStatus = _requestData!['status'] as String?;
      if (requestStatus != 'pending') return;

      // Check if there are any offers (acceptances or counter offers)
      if (_driverOffers.isNotEmpty) return; // Has offers, no timeout needed

      // Check if 5 minutes have passed since request creation
      final requestTimestamp = _requestData!['timestamp'] as int? ?? 0;
      if (requestTimestamp == 0) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedMinutes = (now - requestTimestamp) / (1000 * 60);

      if (elapsedMinutes >= 2 && elapsedMinutes < 5) {
        // 2 minutes passed with no offers, show dialog
        if (!_hasShownTimeoutDialog) {
          _hasShownTimeoutDialog = true;
          _showTimeoutDialog();
        }
      } else if (elapsedMinutes >= 5) {
        // 5 minutes passed with no offers and user didn't respond to dialog
        // Auto-delete the request (it was never accepted)
        await _deleteUnacceptedRequest();
      }
    } catch (e) {
      print('🔍 DEBUG: Error checking request timeout: $e');
    }
  }

  Future<void> _showTimeoutDialog() async {
    if (!mounted) return;
    
    // Double-check request status before showing dialog
    final requestSnapshot = await _db.child('requests/${widget.requestId}').get();
    if (!requestSnapshot.exists) return;
    
    final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
    if (requestData['status'] != 'pending') {
      _hasShownTimeoutDialog = true;
      return; // Request is no longer pending
    }

    final currentFare = (requestData['offerFare'] ?? 0).toDouble();
    final fareController = TextEditingController(text: currentFare.toStringAsFixed(0));

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(Icons.timer_off, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.noResponseReceived,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004d4d),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.noDriversResponded,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF004d4d),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.increaseFare,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF004d4d),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fareController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.newFareAmount,
                labelStyle: const TextStyle(color: Colors.teal),
                prefixText: 'Rs ',
                prefixStyle: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _cancelRequest(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(AppLocalizations.of(context)!.cancelRequest),
          ),
          ElevatedButton(
            onPressed: () {
              final newFare = double.tryParse(fareController.text);
              if (newFare != null && newFare > 0) {
                Navigator.of(context).pop();
                _resendRequestWithNewFare(newFare);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterValidFareAmount)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade800,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.updateFareResend),
          ),
        ],
      ),
    );
  }

  Future<void> _resendRequestWithNewFare(double newFare) async {
    try {
      final t = AppLocalizations.of(context)!;
      
      // Update request with new fare and reset timestamp
      await _db.child('requests/${widget.requestId}').update({
        'offerFare': newFare,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Resend to drivers and enterprises
      await _sendToIndividualDrivers();
      await _sendToEnterpriseOffers();

      // Reset the timeout dialog flag
      _hasShownTimeoutDialog = false;

      // Reload request data to update UI
      await _loadRequestData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.requestResent(newFare.toStringAsFixed(0))),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.errorResending}: $e')),
      );
    }
  }

  Future<void> _sendToIndividualDrivers() async {
    if (_requestData == null) return;
    
    final vehicleType = _requestData!['vehicleType'] as String?;
    if (vehicleType == null) return;

    // Find matching drivers
    final usersSnapshot = await _db.child('users').get();
    
    if (usersSnapshot.exists) {
      for (final user in usersSnapshot.children) {
        final userData = user.value as Map;
        final role = userData['role'] as String?;
        final vehicleInfo = userData['vehicleInfo'] as Map?;
        
        // Only process users with driver role and matching vehicle type
        // Use _vehicleTypesMatch to handle both nameKey and localized names
        if (role == 'driver' && vehicleInfo != null && 
            _vehicleTypesMatch(vehicleInfo['type'] as String, vehicleType)) {
          await _db
              .child('driver_offers')
              .child(user.key!)
              .child('new_offers')
              .child(widget.requestId)
              .set(true);
        }
      }
    }
  }

  Future<void> _sendToEnterpriseOffers() async {
    if (_requestData == null) return;
    
    final vehicleType = _requestData!['vehicleType'] as String?;
    if (vehicleType == null) return;

    final usersSnapshot = await _db.child('users').get();
    
    if (usersSnapshot.exists) {
      for (final user in usersSnapshot.children) {
        final userData = user.value as Map;
        final role = userData['role'] as String?;
        
        // Only process users with enterprise role
        if (role == 'enterprise') {
          // Check if this enterprise has the matching vehicle type
          bool hasMatchingVehicle = await _checkEnterpriseVehicleType(user.key!, vehicleType);
          
          if (hasMatchingVehicle) {
            await _db
                .child('enterprise_offers')
                .child(user.key!)
                .child('new_offers')
                .child(widget.requestId)
                .set(true);
          }
        }
      }
    }
  }

  Future<bool> _checkEnterpriseVehicleType(String enterpriseId, String vehicleType) async {
    try {
      // Check if enterprise has vehicles with matching type
      final vehiclesSnapshot = await _db.child('users/$enterpriseId/vehicles').get();
      if (vehiclesSnapshot.exists) {
        for (final vehicle in vehiclesSnapshot.children) {
          final vehicleData = vehicle.value as Map;
          if (_vehicleTypesMatch(vehicleData['type'] as String, vehicleType)) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('Error checking enterprise vehicle type: $e');
      return false;
    }
  }

  Future<void> _showCancelConfirmationDialog(AppLocalizations t) async {
    if (!mounted) return;
    
    // Don't allow cancellation if request is already accepted
    if (_requestData != null && _requestData!['status'] == 'accepted') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Request has already been accepted'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.cancelRequest,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004d4d),
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this request? This action cannot be undone.',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF004d4d),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.teal.shade800,
            ),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(t.cancelRequest),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelRequest();
    }
  }

  Future<void> _cancelRequest() async {
    try {
      final t = AppLocalizations.of(context)!;
      
      // Get request data to check if it was accepted
      final requestSnapshot = await _db.child('requests/${widget.requestId}').get();
      String? driverId;
      String? enterpriseId;
      bool wasAccepted = false;
      String? currentStatus;
      
      if (requestSnapshot.exists) {
        final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
        driverId = requestData['acceptedDriverId'];
        enterpriseId = requestData['acceptedEnterpriseId'];
        currentStatus = requestData['status'] as String?;
        wasAccepted = currentStatus == 'accepted' || driverId != null || enterpriseId != null;
        
        print('🗑️ DEBUG: Cancelling request - Status: $currentStatus, Accepted: $wasAccepted, DriverId: $driverId, EnterpriseId: $enterpriseId');
      }
      
      // If request was accepted, just mark as cancelled (don't delete)
      // If request was never accepted, delete it completely
      if (wasAccepted) {
        print('🗑️ DEBUG: Request was accepted - marking as cancelled (keeping in DB)');
        // Update request status to cancelled (keep in database for history)
        await _db.child('requests/${widget.requestId}').update({
          'status': 'cancelled',
          'cancelledBy': 'customer',
          'cancelledAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Notify driver/enterprise about cancellation
        if (driverId != null) {
          await _db.child('driver_notifications/$driverId').push().set({
            'type': 'request_cancelled',
            'requestId': widget.requestId,
            'message': 'Customer cancelled the request',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
        if (enterpriseId != null) {
          await _db.child('enterprise_notifications/$enterpriseId').push().set({
            'type': 'request_cancelled',
            'requestId': widget.requestId,
            'message': 'Customer cancelled the request',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
      } else {
        // Request was never accepted - delete it completely from database
        // Remove all related data
        print('🗑️ DEBUG: Request was never accepted - deleting completely from database');
        
        // Delete all customer offers for this request first
        await _db.child('customer_offers/${widget.requestId}').remove();
        print('🗑️ DEBUG: Deleted customer_offers');
        
        // Delete audio note from storage if exists
        if (_requestData != null && _requestData!['audioNoteUrl'] != null) {
          try {
            final audioUrl = _requestData!['audioNoteUrl'] as String;
            if (audioUrl.isNotEmpty && audioUrl != '') {
              final ref = FirebaseStorage.instance.refFromURL(audioUrl);
              await ref.delete();
              print('🗑️ DEBUG: Deleted audio note from storage');
            }
          } catch (e) {
            print('⚠️ DEBUG: Error deleting audio note: $e');
            // Continue even if audio deletion fails
          }
        }
        
        // Remove from all new_offers before deleting request
        await _removeFromAllNewOffers();
        print('🗑️ DEBUG: Removed from all new_offers');
        
        // Delete the request itself (do this last)
        await _db.child('requests/${widget.requestId}').remove();
        print('✅ DEBUG: Request deleted successfully from database');
      }

      // Remove from driver/enterprise new_offers (only if request was accepted)
      // For unaccepted requests, this is already done in the else block above
      if (wasAccepted) {
        await _removeFromAllNewOffers();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.requestCancelled ?? 'Request cancelled'),
          backgroundColor: Colors.orange,
        ),
      );

      // Navigate back to customer dashboard
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerDashboard(),
          ),
        );
      }
    } catch (e) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.errorCancelling}: $e')),
      );
    }
  }

  Future<void> _removeFromAllNewOffers() async {
    try {
      // Remove from all driver new_offers
      final driversSnapshot = await _db.child('driver_offers').get();
      if (driversSnapshot.exists) {
        for (final driver in driversSnapshot.children) {
          await _db.child('driver_offers/${driver.key}/new_offers/${widget.requestId}').remove();
        }
      }

      // Remove from all enterprise new_offers
      final enterprisesSnapshot = await _db.child('enterprise_offers').get();
      if (enterprisesSnapshot.exists) {
        for (final enterprise in enterprisesSnapshot.children) {
          await _db.child('enterprise_offers/${enterprise.key}/new_offers/${widget.requestId}').remove();
        }
      }
    } catch (e) {
      print('Error removing from new offers: $e');
    }
  }

  /// Delete a request that was never accepted (cleanup)
  Future<void> _deleteUnacceptedRequest() async {
    try {
      print('🗑️ DEBUG: Deleting unaccepted request: ${widget.requestId}');
      
      // Delete the request itself
      await _db.child('requests/${widget.requestId}').remove();
      
      // Delete all customer offers for this request
      await _db.child('customer_offers/${widget.requestId}').remove();
      
      // Delete audio note from storage if exists
      if (_requestData != null && _requestData!['audioNoteUrl'] != null) {
        try {
          final audioUrl = _requestData!['audioNoteUrl'] as String;
          if (audioUrl.isNotEmpty) {
            final ref = FirebaseStorage.instance.refFromURL(audioUrl);
            await ref.delete();
            print('🗑️ DEBUG: Audio note deleted from storage');
          }
        } catch (e) {
          print('⚠️ DEBUG: Error deleting audio note: $e');
          // Continue even if audio deletion fails
        }
      }
      
      // Remove from all new_offers
      await _removeFromAllNewOffers();
      
      print('✅ DEBUG: Unaccepted request deleted successfully');
      
      // Navigate back to dashboard if still mounted
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerDashboard(),
          ),
        );
      }
    } catch (e) {
      print('❌ DEBUG: Error deleting unaccepted request: $e');
    }
  }

  Future<void> _loadRequestData() async {
    try {
      final snapshot = await _db.child('requests/${widget.requestId}').get();
      if (snapshot.exists) {
        setState(() {
          _requestData = Map<String, dynamic>.from(snapshot.value as Map);
        });
      }
    } catch (e) {
      print('Error loading request data: $e');
    }
  }

  void _listenForOffers() {
    // Listen for driver and enterprise offers on this request
    _db.child('customer_offers/${widget.requestId}').onValue.listen((event) {
      if (event.snapshot.exists) {
        final offers = <Map<String, dynamic>>[];
        final now = DateTime.now().millisecondsSinceEpoch;
        
        for (final offer in event.snapshot.children) {
          final offerData = Map<String, dynamic>.from(offer.value as Map);
          
          // Check if offer (counter or acceptance) has expired (10 seconds timeout)
          if ((offerData['offerType'] == 'counter' || offerData['offerType'] == 'acceptance') && 
              offerData['status'] == 'pending') {
            final offerTimestamp = offerData['timestamp'] as int? ?? 0;
            final elapsedSeconds = (now - offerTimestamp) / 1000;
            
            if (elapsedSeconds > 10) {
              // Response expired, remove it
              _db.child('customer_offers/${widget.requestId}/${offer.key}').remove();
              continue; // Skip adding this expired offer
            }
          }
          
          offerData['offerId'] = offer.key;
          offers.add(offerData);
        }
        setState(() {
          _driverOffers = offers;
          _isLoading = false;
        });
      } else {
        setState(() {
          _driverOffers = [];
          _isLoading = false;
        });
      }
    });

    // Listen for driver or enterprise acceptance
    _db.child('requests/${widget.requestId}').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        // Update request data
        setState(() {
          _requestData = data;
        });
        
        if (data['status'] == 'accepted') {
          // Prevent timeout dialog from showing
          _hasShownTimeoutDialog = true;
          
          // Check if driver or enterprise accepted
          final driverId = data['acceptedDriverId'];
          final enterpriseId = data['acceptedEnterpriseId'];
          
          if (driverId != null || enterpriseId != null) {
            // Show success dialog popup
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.offerAccepted,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF004d4d),
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    driverId != null
                        ? AppLocalizations.of(context)!.requestAcceptedByDriver
                        : AppLocalizations.of(context)!.requestAcceptedByEnterprise,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF004d4d),
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UpcomingBookingsScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(AppLocalizations.of(context)!.viewBookings),
                    ),
                  ],
                ),
              );
            }
          }
        }
      }
    });
  }

  Future<void> _acceptOffer(String offerId, double offeredFare) async {
    final t = AppLocalizations.of(context)!;
    try {
      print('🔍 DEBUG: Customer accepting offer: $offerId with fare: $offeredFare');
      
      // Find the selected offer
      final selectedOffer = _driverOffers.firstWhere((offer) => offer['offerId'] == offerId);
      final driverId = selectedOffer['driverId'];
      final enterpriseId = selectedOffer['enterpriseId'];
      
      print('🔍 DEBUG: Selected driver ID: $driverId, enterprise ID: $enterpriseId');
      
      // Update request status to accepted
      final updateData = {
        'status': 'accepted',
        'acceptedOfferId': offerId,
        'finalFare': offeredFare,
      };
      
      if (driverId != null) {
        updateData['acceptedDriverId'] = driverId;
      }
      if (enterpriseId != null) {
        updateData['acceptedEnterpriseId'] = enterpriseId;
      }
      
      await _db.child('requests/${widget.requestId}').update(updateData);

      print('🔍 DEBUG: Request status updated to accepted');

      // Update offer status
      await _db.child('customer_offers/${widget.requestId}/$offerId').update({
        'status': 'accepted',
      });

      print('🔍 DEBUG: Offer status updated to accepted');

      // Update local state to show "accepted" status on the offer card
      setState(() {
        final offerIndex = _driverOffers.indexWhere((offer) => offer['offerId'] == offerId);
        if (offerIndex != -1) {
          _driverOffers[offerIndex]['status'] = 'accepted';
        }
      });

      // Remove all other offers and remove from driver/enterprise new_offers
      final otherOffers = _driverOffers.where((offer) => offer['offerId'] != offerId).toList();
      for (final offer in otherOffers) {
        await _db.child('customer_offers/${widget.requestId}/${offer['offerId']}').remove();
        
        // Remove from driver/enterprise new_offers
        if (offer['driverId'] != null) {
          await _db.child('driver_offers/${offer['driverId']}/new_offers/${widget.requestId}').remove();
        }
        if (offer['enterpriseId'] != null) {
          await _db.child('enterprise_offers/${offer['enterpriseId']}/new_offers/${widget.requestId}').remove();
        }
      }
      
      // Also remove the accepted offer from new_offers
      if (driverId != null) {
        await _db.child('driver_offers/$driverId/new_offers/${widget.requestId}').remove();
      }
      if (enterpriseId != null) {
        await _db.child('enterprise_offers/$enterpriseId/new_offers/${widget.requestId}').remove();
      }

      print('🔍 DEBUG: Other offers removed and new_offers cleaned up');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.offerAccepted)),
      );

      // Wait a moment to show the "accepted" status on the card
      await Future.delayed(const Duration(milliseconds: 1500));

      print('🔍 DEBUG: Navigating to upcoming bookings');

      // Navigate to upcoming bookings
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const UpcomingBookingsScreen(),
          ),
        );
      }
    } catch (e) {
      print('❌ DEBUG: Error accepting offer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.errorOccurred} $e')),
      );
    }
  }

  Future<void> _rejectOffer(String offerId) async {
    final t = AppLocalizations.of(context)!;
    try {
      // Get offer details before removing
      final offerSnapshot = await _db.child('customer_offers/${widget.requestId}/$offerId').get();
      if (offerSnapshot.exists) {
        final offerData = Map<String, dynamic>.from(offerSnapshot.value as Map);
        final driverId = offerData['driverId'];
        final enterpriseId = offerData['enterpriseId'];
        
        // Remove the offer
        await _db.child('customer_offers/${widget.requestId}/$offerId').remove();
        
        // Remove from driver/enterprise new_offers only if this was the only counter offer
        // Check if there are other pending offers from this driver/enterprise
        bool hasOtherOffers = false;
        final allOffersSnapshot = await _db.child('customer_offers/${widget.requestId}').get();
        if (allOffersSnapshot.exists) {
          for (final offer in allOffersSnapshot.children) {
            final otherOfferData = Map<String, dynamic>.from(offer.value as Map);
            if (offer.key != offerId && 
                otherOfferData['status'] == 'pending' &&
                ((driverId != null && otherOfferData['driverId'] == driverId) ||
                 (enterpriseId != null && otherOfferData['enterpriseId'] == enterpriseId))) {
              hasOtherOffers = true;
              break;
            }
          }
        }
        
        // If no other offers from this driver/enterprise, remove from new_offers
        if (!hasOtherOffers) {
          if (driverId != null) {
            await _db.child('driver_offers/$driverId/new_offers/${widget.requestId}').remove();
          }
          if (enterpriseId != null) {
            await _db.child('enterprise_offers/$enterpriseId/new_offers/${widget.requestId}').remove();
          }
        }
      } else {
        // If offer doesn't exist, just try to remove from new_offers as fallback
        await _db.child('customer_offers/${widget.requestId}/$offerId').remove();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.offerRejected)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.errorOccurred} $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          t.waitingForResponse,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF004D4D),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF004D4D)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            onPressed: () => _showCancelConfirmationDialog(t),
            tooltip: t.cancelRequest,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requestData == null
              ? Center(
                  child: Text(
                    t.requestNotFound,
                    style: const TextStyle(color: Color(0xFF004D4D)),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    /// --- REQUEST DETAILS CARD ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.05),
                              spreadRadius: 2,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_shipping,
                                    color: Colors.teal, size: 28),
                                const SizedBox(width: 10),
                                Text(
                                  t.yourRequest,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF004D4D),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _detailRow(t.load, _requestData!['loadName']),
                            _detailRow(t.type, _requestData!['loadType']),
                            _detailRow(t.weight,
                                '${_requestData!['weight']} ${_requestData!['weightUnit']}'),
                            _detailRow(
                                t.fareOffered, 'Rs ${_requestData!['offerFare']}'),
                            if (_requestData!['pickupDate'] != null &&
                                _requestData!['pickupDate'] != 'N/A')
                              _detailRow(t.pickupDate, _requestData!['pickupDate']),
                            _detailRow(
                                t.pickupTime, _requestData!['pickupTime']),
                            const SizedBox(height: 12),
                            // Cancel Request Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                label: Text(
                                  t.cancelRequest,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _showCancelConfirmationDialog(t),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    /// --- OFFERS LIST ---
                    Expanded(
                      child: _driverOffers.isEmpty
                          ? _waitingWidget(t)
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _driverOffers.length,
                              itemBuilder: (context, index) =>
                                  _offerCard(_driverOffers[index], t),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "$label:",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF004D4D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitingWidget(AppLocalizations t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timelapse, size: 80, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            t.waitingForDrivers,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF004D4D),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.driversWillRespondSoon,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _offerCard(Map<String, dynamic> offer, AppLocalizations t) {
    final isEnterprise = offer['enterpriseId'] != null;
    final isAcceptance = offer['offerType'] == 'acceptance';
    final isAccepted = offer['status'] == 'accepted';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
        border: isAccepted ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER WITH BADGES
          Row(
            children: [
              Icon(
                isEnterprise ? Icons.business : Icons.person,
                color: isEnterprise ? Colors.orange : Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                isEnterprise ? t.enterprise : t.driver,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              /// Offer type tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isAccepted
                      ? Colors.green.withOpacity(0.2)
                      : isAcceptance
                          ? Colors.green.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isAccepted ? t.accepted : (isAcceptance ? t.accepted : t.counter),
                  style: TextStyle(
                    fontSize: 12,
                    color: isAccepted ? Colors.green : (isAcceptance ? Colors.green : Colors.blue),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          /// NAME - More prominent for acceptance
          Text(
            isEnterprise
                ? "${t.enterprise}: ${offer['enterpriseName'] ?? t.unknown}"
                : "${t.driver}: ${offer['driverName'] ?? t.unknown}",
            style: TextStyle(
              fontSize: isAcceptance ? 18 : 15,
              color: const Color(0xFF004D4D),
              fontWeight: isAcceptance ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 12),
          /// FARES
          if (!isAcceptance)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${t.offeredFare}:",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.teal.shade800,
                  ),
                ),
                Text(
                  "Rs ${offer['offeredFare']}",
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                )
              ],
            ),
          if (isAcceptance)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    "${t.accepted}: Rs ${offer['offeredFare']?.toStringAsFixed(0) ?? 'N/A'}",
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          /// ACTION BUTTONS - Hide if already accepted
          if (!isAccepted)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptOffer(
                      offer['offerId'],
                      offer['offeredFare'].toDouble(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(t.accept),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectOffer(offer['offerId']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(t.reject),
                  ),
                ),
              ],
            ),
          if (isAccepted)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    t.offerAccepted,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
