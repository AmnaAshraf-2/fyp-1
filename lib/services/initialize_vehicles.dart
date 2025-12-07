import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'vehicletype.dart';

/// Utility to initialize vehicles in Firebase
/// Call this once to populate the vehicle_types node
class InitializeVehicles {
  static final VehicleTypeService _service = VehicleTypeService();
  static final _db = FirebaseDatabase.instance.ref();

  /// Check if vehicles have already been initialized
  static Future<bool> areVehiclesInitialized() async {
    try {
      final snapshot = await _db.child('vehicle_types').get();
      return snapshot.exists && (snapshot.value as Map?)?.isNotEmpty == true;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking vehicle initialization: $e');
      }
      return false;
    }
  }

  /// Initialize all vehicles (only if not already initialized)
  static Future<Map<String, dynamic>> initializeIfNeeded() async {
    try {
      final isInitialized = await areVehiclesInitialized();
      
      if (isInitialized) {
        if (kDebugMode) {
          print('ℹ️ Vehicles already initialized, skipping...');
        }
        return {
          'success': 0,
          'failed': 0,
          'skipped': true,
          'message': 'Vehicles already initialized',
        };
      }

      if (kDebugMode) {
        print('🚀 Initializing vehicles in Firebase...');
      }

      return await _service.initializeAllVehicles();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during vehicle initialization: $e');
      }
      return {
        'success': 0,
        'failed': 0,
        'errors': [e.toString()],
      };
    }
  }

  /// Force initialize all vehicles (will overwrite existing data)
  static Future<Map<String, dynamic>> forceInitialize() async {
    if (kDebugMode) {
      print('🚀 Force initializing vehicles in Firebase...');
    }
    return await _service.initializeAllVehicles();
  }
}

