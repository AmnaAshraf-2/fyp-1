import 'package:flutter/material.dart';
import 'package:logistics_app/data/modals.dart';
import 'cargoDetails.dart';
import 'waiting_for_response.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

  @override
  void initState() {
    super.initState();
    _currentDetails = widget.initialDetails;
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

      // Create a new booking ID
      final newRequestRef = _db.child('requests').push();
      final requestId = newRequestRef.key;

      // Save booking details
      await newRequestRef.set({
        'requestId': requestId,
        'customerId': user.uid,
        'loadName': _currentDetails.loadName,
        'loadType': _currentDetails.loadType,
        'weight': _currentDetails.weight,
        'weightUnit': _currentDetails.weightUnit,
        'quantity': _currentDetails.quantity,
        'pickupTime': _currentDetails.pickupTime?.format(context) ?? 'N/A',
        'offerFare': _currentDetails.offerFare,
        'isInsured': _currentDetails.isInsured,
        'vehicleType': _currentDetails.vehicleType,
        'isEnterprise': _currentDetails.isEnterprise,
        'senderPhone': _currentDetails.senderPhone,
        'receiverPhone': _currentDetails.receiverPhone,
        'pickupLocation': _currentDetails.pickupLocation,
        'destinationLocation': _currentDetails.destinationLocation,
        'status': 'pending',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Send to both individual drivers and enterprises based on vehicle type
      await _sendToIndividualDrivers(requestId!);
      await _sendToEnterpriseOffers(requestId!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to drivers and enterprises with ${_currentDetails.vehicleType} vehicles')),
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
        if (role == 'driver' && vehicleInfo != null && vehicleInfo['type'] == _currentDetails.vehicleType) {
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
          if (vehicleData['type'] == vehicleType) {
            print('🔍 DEBUG: Found matching vehicle in users path for enterprise $enterpriseId');
            return true;
          }
        }
      }
      
      // Check enterprises path
      if (enterprisesVehiclesSnapshot.exists) {
        for (final vehicle in enterprisesVehiclesSnapshot.children) {
          final vehicleData = vehicle.value as Map;
          if (vehicleData['type'] == vehicleType) {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          t.summaryTitle,
          style: const TextStyle(color: Color(0xFF004d4d), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF004d4d)),
            onPressed: _editDetails,
            tooltip: t.editAllDetails,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildSummaryItem(t.loadName, _currentDetails.loadName),
                  _buildSummaryItem(t.loadType, _getLoadTypeLabel(_currentDetails.loadType, t)),
                  _buildSummaryItem(
                      t.loadWeight, '${_currentDetails.weight} ${_currentDetails.weightUnit}'),
                  _buildSummaryItem(t.quantityOfVehicles, _currentDetails.quantity.toString()),
                  _buildSummaryItem(t.vehicleType, _currentDetails.vehicleType),
                  _buildSummaryItem(t.senderPhoneNumber, _currentDetails.senderPhone),
                  _buildSummaryItem(t.receiverPhoneNumber, _currentDetails.receiverPhone),
                  _buildSummaryItem(t.pickupLocation, _currentDetails.pickupLocation),
                  _buildSummaryItem(t.destinationLocation, _currentDetails.destinationLocation),
                  _buildSummaryItem(
                    t.pickupTime,
                    _currentDetails.pickupTime?.format(context) ?? t.notSelected,
                  ),
                  _buildSummaryItem(t.offeredFare, 'Rs ${_currentDetails.offerFare}'),
                  _buildSummaryItem(
                    t.insuranceStatus,
                    _currentDetails.isInsured ? t.insured : t.uninsured,
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF004d4d)),
                  Text(
                    "${t.termsAgreement}: ${_currentDetails.isInsured ? t.insuredPolicyAccepted : t.uninsuredPolicyAccepted}",
                    style: const TextStyle(color: Color(0xFF004d4d)),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: sendRequestToDrivers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004d4d),
                foregroundColor: Colors.white,
              ),
              child: Text(t.sendRequest),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        "$title: $value",
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF004d4d),
        ),
      ),
    );
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
