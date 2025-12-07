import 'package:flutter/material.dart';
import 'package:logistics_app/data/modals.dart';
import 'cargoDetails.dart';
import 'waiting_for_response.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/services/driver_search_service.dart';
import 'package:logistics_app/services/fare_calculator.dart';
import 'package:logistics_app/services/vehicle_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class SummaryScreen extends StatefulWidget {
  final CargoDetails initialDetails;

  const SummaryScreen({super.key, required this.initialDetails});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late CargoDetails _currentDetails;
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  final VehicleProvider _vehicleProvider = VehicleProvider();
  List<VehicleModel> _vehicles = [];
  
  // Audio playback variables
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _playbackDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _currentDetails = widget.initialDetails;
    _loadVehicles();
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

  /// Get localized display name for vehicle type
  String _getVehicleDisplayName(String nameKey) {
    for (VehicleModel vehicle in _vehicles) {
      if (vehicle.nameKey == nameKey) {
        final t = AppLocalizations.of(context)!;
        final languageCode = t.localeName.split('_').first;
        return vehicle.getName(languageCode);
      }
    }
    return nameKey; // Fallback to nameKey if not found
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _editDetails() async {
    final result = await Navigator.push<CargoDetails>(
      context,
      MaterialPageRoute(
        builder: (context) => CargoDetailsScreen(
          initialData: _currentDetails,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentDetails = result;
      });
    }
  }

  Future<void> sendRequestToDrivers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseLogin)),
        );
        return;
      }

      // Calculate vehicle count based on weight
      final calculatedQuantity = FareCalculator.calculateVehicleCount(
        weight: _currentDetails.weight,
        weightUnit: _currentDetails.weightUnit,
        vehicleType: _currentDetails.vehicleType,
      );

      // Update quantity if calculated is different
      int finalQuantity = _currentDetails.quantity;
      if (calculatedQuantity > _currentDetails.quantity) {
        final t = AppLocalizations.of(context)!;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.teal.shade800, width: 1),
            ),
            title: Text(
              t.vehicleCountUpdate,
              style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Your cargo requires $calculatedQuantity ${_getVehicleDisplayName(_currentDetails.vehicleType)} vehicles. Update quantity?',
              style: TextStyle(color: Colors.teal.shade800),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.teal.shade800,
                ),
                child: Text(t.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.teal.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(t.update),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          setState(() {
            _currentDetails = CargoDetails(
              loadName: _currentDetails.loadName,
              loadType: _currentDetails.loadType,
              weight: _currentDetails.weight,
              weightUnit: _currentDetails.weightUnit,
              quantity: calculatedQuantity,
              pickupDate: _currentDetails.pickupDate,
              pickupTime: _currentDetails.pickupTime,
              offerFare: _currentDetails.offerFare,
              isInsured: _currentDetails.isInsured,
              vehicleType: _currentDetails.vehicleType,
              isEnterprise: _currentDetails.isEnterprise,
              senderPhone: _currentDetails.senderPhone,
              receiverPhone: _currentDetails.receiverPhone,
            pickupLocation: _currentDetails.pickupLocation,
            destinationLocation: _currentDetails.destinationLocation,
            audioNoteUrl: _currentDetails.audioNoteUrl,
            );
          });
          finalQuantity = calculatedQuantity;
        }
      }

      // If quantity > 1, automatically send to enterprises only
      // If quantity == 1, send to both drivers and enterprises
      String? requestType;
      if (finalQuantity > 1) {
        requestType = 'enterprise'; // Automatically use enterprises for multiple vehicles
      }

      // Show search progress dialog
      final searchResult = await _showSearchProgressDialog(
        vehicleType: _currentDetails.vehicleType,
        requiredCount: finalQuantity,
        isEnterprise: requestType == 'enterprise',
      );

      // Even if searchResult is null (error or cancelled), proceed with fallback method
      // This ensures requests are always sent to drivers with matching vehicle type

      // Create a new booking ID
      final newRequestRef = _db.child('requests').push();
      final requestId = newRequestRef.key;

      // Validate locations before saving
      if (_currentDetails.pickupLocation.isEmpty || _currentDetails.destinationLocation.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.pleaseEnsureLocations),
              backgroundColor: Colors.red,
            ),
          );
        return;
      }

      // Use audio note URL if already uploaded, otherwise upload from local path
      String? audioNoteUrl = _currentDetails.audioNoteUrl;
      if (audioNoteUrl == null && _currentDetails.audioNotePath != null && File(_currentDetails.audioNotePath!).existsSync()) {
        // Fallback: upload from local path (for backward compatibility)
        try {
          final audioFile = File(_currentDetails.audioNotePath!);
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('audio_notes')
              .child('${user.uid}_${requestId}_$timestamp.m4a');
          
          await storageRef.putFile(audioFile);
          audioNoteUrl = await storageRef.getDownloadURL();
        } catch (e) {
          print('Error uploading audio note: $e');
          // Continue without audio note if upload fails
        }
      }

      // Save booking details with locations
      await newRequestRef.set({
        'requestId': requestId,
        'customerId': user.uid,
        'loadName': _currentDetails.loadName,
        'loadType': _currentDetails.loadType,
        'weight': _currentDetails.weight,
        'weightUnit': _currentDetails.weightUnit,
        'quantity': finalQuantity,
        'pickupDate': _currentDetails.pickupDate != null
            ? '${_currentDetails.pickupDate!.day}/${_currentDetails.pickupDate!.month}/${_currentDetails.pickupDate!.year}'
            : 'N/A',
        'pickupTime': _currentDetails.pickupTime?.format(context) ?? 'N/A',
        'offerFare': _currentDetails.offerFare,
        'isInsured': _currentDetails.isInsured,
        'vehicleType': _currentDetails.vehicleType,
        'isEnterprise': requestType == 'enterprise',
        'senderPhone': _currentDetails.senderPhone,
        'receiverPhone': _currentDetails.receiverPhone,
        'pickupLocation': _currentDetails.pickupLocation,
        'destinationLocation': _currentDetails.destinationLocation,
        'audioNoteUrl': audioNoteUrl ?? '',
        'status': 'pending',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'searchRadius': searchResult?['finalRadius'] ?? 0.0,
        'driversFound': searchResult?['foundCount'] ?? 0,
      });

      print('✅ DEBUG: Request saved with pickup: ${_currentDetails.pickupLocation}');
      print('✅ DEBUG: Request saved with destination: ${_currentDetails.destinationLocation}');

      // Send offers to found drivers
      final drivers = searchResult != null 
          ? (searchResult['drivers'] as List<DriverSearchResult>? ?? <DriverSearchResult>[])
          : <DriverSearchResult>[];
      
      if (drivers.isNotEmpty) {
        await _sendOffersToDrivers(requestId!, drivers, requestType == 'enterprise');
      } else {
        // If no drivers found from search, use fallback method (send to all matching drivers)
        // This ensures requests are sent to all drivers with matching vehicle type
        if (requestType == 'enterprise') {
          // Quantity > 1: only send to enterprises
          await _sendToEnterpriseOffers(requestId!);
        } else {
          // Quantity == 1: send to both drivers and enterprises
          await _sendToEnterpriseOffers(requestId!);
          await _sendToIndividualDrivers(requestId!);
        }
      }

      final t = AppLocalizations.of(context)!;
      String message;
      final vehicleDisplayName = _getVehicleDisplayName(_currentDetails.vehicleType);
      if (finalQuantity > 1) {
        // Quantity > 1: automatically sent to enterprises only
        message = t.requestSentToEnterprises(vehicleDisplayName);
      } else {
        // Quantity == 1: sent to both drivers and enterprises
        message = t.requestSentToBoth(vehicleDisplayName);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      // Navigate to waiting screen instead of going back
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingForResponseScreen(requestId: requestId!),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${AppLocalizations.of(context)!.errorSendingRequest} $e"),
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _showSearchProgressDialog({
    required String vehicleType,
    required int requiredCount,
    required bool isEnterprise,
  }) async {
    final searchService = DriverSearchService();
    Map<String, dynamic>? searchResult;
    double currentRadius = 0.0;
    int foundCount = 0;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start search on first build
            if (searchResult == null) {
              searchService.searchNearbyDrivers(
                pickupLocation: _currentDetails.pickupLocation,
                vehicleType: vehicleType,
                requiredCount: requiredCount,
                pickupDate: _currentDetails.pickupDate,
                pickupTime: _currentDetails.pickupTime,
                isEnterprise: isEnterprise,
                onRadiusSearch: (radius, count) {
                  setDialogState(() {
                    currentRadius = radius;
                    foundCount = count;
                  });
                },
              ).then((result) {
                setDialogState(() {
                  searchResult = result;
                });
              });
            }

            final isSearching = searchResult == null;
            final hasError = searchResult != null && searchResult!['success'] != true;
            final drivers = searchResult != null 
                ? (searchResult!['drivers'] as List<DriverSearchResult>?)
                : null;
            final finalFoundCount = drivers?.length ?? (isSearching ? foundCount : 0);
            final finalRadius = searchResult?['finalRadius'] ?? (isSearching ? currentRadius : 0.0);

            // Auto-close dialog and proceed if search completed
            // Even with 0 drivers or errors, proceed (will use fallback method)
            if (!isSearching) {
              // Auto-proceed after a short delay to show the result
              Future.delayed(const Duration(milliseconds: 800), () {
                if (context.mounted) {
                  // If error or no drivers, return empty result (will trigger fallback)
                  Navigator.of(context).pop(hasError ? null : searchResult);
                }
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.teal.shade800, width: 1),
              ),
              title: Text(
                isSearching ? 'Searching Drivers...' : 
                hasError ? 'No Drivers Found' : 
                'Drivers Found',
                style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold),
              ),
              content: isSearching
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF004D4D)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Searching for $vehicleType drivers...',
                          style: TextStyle(color: Colors.teal.shade800),
                        ),
                        if (foundCount > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Found $foundCount driver${foundCount > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    )
                  : hasError
                      ? _buildNoDriversFoundContent(
                          searchResult!['error'] ?? 'Search failed',
                          vehicleType,
                          requiredCount,
                        )
                      : _buildDriversFoundContent(finalFoundCount, finalRadius),
              actions: isSearching
                  ? []
                  : hasError
                      ? [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.teal.shade800,
                            ),
                            child: const Text('Cancel'),
                          ),
                        ]
                      : [
                          // Auto-proceeds, but show button as backup
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(searchResult);
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.teal.shade800,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Continue'),
                          ),
                        ],
            );
          },
        );
      },
    );
  }

  Widget _buildNoDriversFoundContent(String error, String vehicleType, int requiredCount) {
    final searchService = DriverSearchService();
    final alternatives = searchService.getAlternativeVehicleTypes(vehicleType);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange.shade700,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          'No drivers available',
          style: TextStyle(
            color: Colors.teal.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sorry, no ${vehicleType} drivers are available for your selected pickup time.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        if (alternatives.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Alternative vehicles available:',
            style: TextStyle(
              color: Colors.teal.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...alternatives.map((alt) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $alt',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              )),
        ],
        const SizedBox(height: 16),
        Text(
          'You can try again in a few minutes or select a different vehicle type.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDriversFoundContent(int foundCount, double radius) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle,
          color: Colors.green.shade700,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          'Found $foundCount driver${foundCount > 1 ? 's' : ''}',
          style: TextStyle(
            color: Colors.teal.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'All drivers with matching vehicle type',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildPartialDriversFoundContent(
    int foundCount,
    int requiredCount,
    double radius,
    String vehicleType,
  ) {
    final searchService = DriverSearchService();
    final alternatives = searchService.getAlternativeVehicleTypes(vehicleType);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange.shade700,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          'Only $foundCount of $requiredCount drivers found',
          style: TextStyle(
            color: Colors.teal.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Only $foundCount $vehicleType driver${foundCount > 1 ? 's are' : ' is'} available. You can continue with available drivers or try again later.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        if (alternatives.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Alternative vehicles available:',
            style: TextStyle(
              color: Colors.teal.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...alternatives.map((alt) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $alt',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              )),
        ],
      ],
    );
  }

  Future<void> _sendOffersToDrivers(
    String requestId,
    List<DriverSearchResult> drivers,
    bool isEnterprise,
  ) async {
    if (isEnterprise) {
      // Send to enterprises
      for (final driver in drivers) {
        await _db
            .child('enterprise_offers')
            .child(driver.driverId)
            .child('new_offers')
            .child(requestId)
            .set(true);
      }
    } else {
      // Send to individual drivers
      for (final driver in drivers) {
        await _db
            .child('driver_offers')
            .child(driver.driverId)
            .child('new_offers')
            .child(requestId)
            .set(true);
      }
    }
  }

  Future<String?> _showRequestTypeDialog() async {
    final t = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.teal.shade800, width: 1),
          ),
          title: Text(
            t.selectRequestType,
            style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold),
          ),
          content: Text(
            t.youNeedVehicles(_currentDetails.quantity.toString()),
            style: TextStyle(color: Colors.teal.shade800),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('driver'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.teal.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(t.sendToDrivers),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('enterprise'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.teal.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(t.sendToEnterprise),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal.shade800,
              ),
              child: Text(t.cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendToIndividualDrivers(String requestId) async {
    // Find matching drivers in users collection
    final usersSnapshot = await _db.child('users').get();
    print('🔍 DEBUG: Looking for drivers with vehicle type: ${_currentDetails.vehicleType}');
    print('🔍 DEBUG: Found ${usersSnapshot.children.length} users in database');
    
    if (usersSnapshot.exists) {
      int matchedDrivers = 0;
      for (final user in usersSnapshot.children) {
        final userData = user.value as Map;
        final role = userData['role'] as String?;
        final vehicleInfo = userData['vehicleInfo'] as Map?;
        
        print('🔍 DEBUG: User ${user.key} role: $role, vehicle type: ${vehicleInfo?['type']}');
        
        // Only process users with driver role and vehicle info
        // Use _vehicleTypesMatch to handle both nameKey and localized names
        if (role == 'driver' && vehicleInfo != null && 
            _vehicleTypesMatch(vehicleInfo['type'] as String, _currentDetails.vehicleType)) {
          print('✅ DEBUG: Match found! Adding offer to driver ${user.key}');
          await _db
              .child('driver_offers')
              .child(user.key!)
              .child('new_offers')
              .child(requestId)
              .set(true);
          matchedDrivers++;
        }
      }
      print('🔍 DEBUG: Total matched drivers: $matchedDrivers');
    } else {
      print('❌ DEBUG: No users found in database!');
    }
  }

  Future<void> _sendToEnterpriseOffers(String requestId) async {
    // Find enterprises that have the matching vehicle type
    final usersSnapshot = await _db.child('users').get();
    print('🔍 DEBUG: Looking for enterprises with vehicle type: ${_currentDetails.vehicleType}');
    print('🔍 DEBUG: Found ${usersSnapshot.children.length} users in database');
    
    if (usersSnapshot.exists) {
      int matchedEnterprises = 0;
      for (final user in usersSnapshot.children) {
        final userData = user.value as Map;
        final role = userData['role'] as String?;
        
        print('🔍 DEBUG: User ${user.key} role: $role');
        
        // Only process users with enterprise role
        if (role == 'enterprise') {
          // Check if this enterprise has the matching vehicle type
          bool hasMatchingVehicle = await _checkEnterpriseVehicleType(user.key!, _currentDetails.vehicleType);
          
          if (hasMatchingVehicle) {
            print('✅ DEBUG: Enterprise ${user.key} has matching vehicle! Adding offer');
            await _db
                .child('enterprise_offers')
                .child(user.key!)
                .child('new_offers')
                .child(requestId)
                .set(true);
            matchedEnterprises++;
          } else {
            print('❌ DEBUG: Enterprise ${user.key} does not have vehicle type ${_currentDetails.vehicleType}');
          }
        }
      }
      print('🔍 DEBUG: Total matched enterprises: $matchedEnterprises');
    } else {
      print('❌ DEBUG: No users found in database!');
    }
  }

  Future<bool> _checkEnterpriseVehicleType(String enterpriseId, String vehicleType) async {
    try {
      // Check both possible paths for enterprise vehicles
      final usersVehiclesSnapshot = await _db.child('users/$enterpriseId/vehicles').get();
      final enterprisesVehiclesSnapshot = await _db.child('enterprises/$enterpriseId/vehicles').get();
      
      // Check users path
      if (usersVehiclesSnapshot.exists) {
        for (final vehicle in usersVehiclesSnapshot.children) {
          final vehicleData = vehicle.value as Map;
          if (_vehicleTypesMatch(vehicleData['type'] as String, vehicleType)) {
            print('🔍 DEBUG: Found matching vehicle in users path for enterprise $enterpriseId');
            return true;
          }
        }
      }
      
      // Check enterprises path
      if (enterprisesVehiclesSnapshot.exists) {
        for (final vehicle in enterprisesVehiclesSnapshot.children) {
          final vehicleData = vehicle.value as Map;
          if (_vehicleTypesMatch(vehicleData['type'] as String, vehicleType)) {
            print('🔍 DEBUG: Found matching vehicle in enterprises path for enterprise $enterpriseId');
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      print('❌ DEBUG: Error checking enterprise vehicle type: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          t.summaryTitle,
          style: const TextStyle(
            color: Color(0xFF004D4D),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF004D4D)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF004D4D)),
            onPressed: _editDetails,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: _receiptContainer(t),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: sendRequestToDrivers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D4D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  t.sendRequest,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---- Receipt-Style UI Components ----
  Widget _receiptContainer(AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.summaryTitle.toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _dottedDivider(),
          /// ----- LOAD DETAILS -----
          _receiptSectionTitle(t.loadDetails),
          _receiptRow(t.loadName, _currentDetails.loadName),
          _receiptRow(t.loadType, _getLoadTypeLabel(_currentDetails.loadType, t)),
          _receiptRow(
            t.loadWeight,
            "${_currentDetails.weight} ${_currentDetails.weightUnit}",
          ),
          _receiptRow(t.quantityOfVehicles, _currentDetails.quantity.toString()),
          _receiptRow(t.vehicleType, _getVehicleDisplayName(_currentDetails.vehicleType)),
          _dottedDivider(),
          /// ----- CONTACTS -----
          _receiptSectionTitle(t.contactDetails),
          _receiptRow(t.senderPhoneNumber, _currentDetails.senderPhone),
          _receiptRow(t.receiverPhoneNumber, _currentDetails.receiverPhone),
          _dottedDivider(),
          /// ----- ROUTE -----
          _receiptSectionTitle(t.routeInformation),
          _receiptRow(
            t.pickupLocation,
            _currentDetails.pickupLocation.isNotEmpty
                ? _currentDetails.pickupLocation
                : t.notSpecified,
          ),
          _receiptRow(
            t.destinationLocation,
            _currentDetails.destinationLocation.isNotEmpty
                ? _currentDetails.destinationLocation
                : t.notSpecified,
          ),
          _dottedDivider(),
          /// ----- SCHEDULE & FARE -----
          _receiptSectionTitle(t.scheduleFare),
          _receiptRow(
            t.pickupDate,
            _currentDetails.pickupDate != null
                ? "${_currentDetails.pickupDate!.day}/${_currentDetails.pickupDate!.month}/${_currentDetails.pickupDate!.year}"
                : t.notSelected,
          ),
          _receiptRow(
            t.pickupTime,
            _currentDetails.pickupTime?.format(context) ?? t.notSelected,
          ),
          _receiptRow(t.offeredFare, "Rs. ${_currentDetails.offerFare}"),
          _receiptRow(
            t.insuranceStatus,
            _currentDetails.isInsured ? t.insured : t.uninsured,
          ),
          _dottedDivider(),
          /// ----- AUDIO NOTE -----
          if (_currentDetails.audioNoteUrl != null && _currentDetails.audioNoteUrl!.isNotEmpty) ...[
            _receiptSectionTitle('Audio Note'),
            _buildAudioNoteWidget(),
            _dottedDivider(),
          ],
          /// Terms
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "${t.termsAgreement}: ${_currentDetails.isInsured ? t.insuredPolicyAccepted : t.uninsuredPolicyAccepted}",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Colors.teal.shade800,
        ),
      ),
    );
  }

  Widget _dottedDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dashCount = (constraints.maxWidth / 10).floor();
          return Row(
            children: List.generate(
              dashCount,
              (_) => Expanded(
                child: Container(
                  height: 1,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioNoteWidget() {
    if (_currentDetails.audioNoteUrl == null || _currentDetails.audioNoteUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            _isPlaying ? Icons.pause_circle : Icons.play_circle,
            color: Colors.teal,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audio Note',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF004d4d),
                  ),
                ),
                const SizedBox(height: 4),
                if (_isPlaying)
                  StreamBuilder<Duration>(
                    stream: _audioPlayer.onPositionChanged,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = _playbackDuration;
                      return Text(
                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      );
                    },
                  )
                else
                  const Text(
                    'Tap to play audio note',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.teal,
            ),
            onPressed: _playAudioNote,
            tooltip: _isPlaying ? 'Pause' : 'Play',
          ),
        ],
      ),
    );
  }

  Future<void> _playAudioNote() async {
    if (_currentDetails.audioNoteUrl == null || _currentDetails.audioNoteUrl!.isEmpty) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        // Play from Firebase Storage URL
        await _audioPlayer.play(UrlSource(_currentDetails.audioNoteUrl!));
        setState(() {
          _isPlaying = true;
        });

        // Get duration
        final duration = await _audioPlayer.getDuration();
        if (duration != null) {
          setState(() {
            _playbackDuration = duration;
          });
        }

        // Listen for completion
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _playbackPosition = Duration.zero;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _getLoadTypeLabel(String loadTypeKey, AppLocalizations t) {
    switch (loadTypeKey) {
      case 'fragile':
        return t.fragile;
      case 'heavy':
        return t.heavy;
      case 'perishable':
        return t.perishable;
      case 'general':
        return t.generalGoods;
      default:
        return loadTypeKey;
    }
  }
}
