import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../data/vehicles.dart';

/// Service for managing vehicle types in Firebase Realtime Database
class VehicleTypeService {
  final _db = FirebaseDatabase.instance.ref();
  
  /// Reference to the vehicle_types node in Firebase
  DatabaseReference get _vehicleTypesRef => _db.child('vehicle_types');

  /// Create or update vehicle type data in Firebase
  /// 
  /// [data] - Map containing the vehicle type data to store
  /// Returns the key of the created/updated node
  Future<String?> createOrUpdateVehicleType(Map<String, dynamic> data) async {
    try {
      // Push data to vehicle_types node (creates a new entry with auto-generated key)
      final newRef = _vehicleTypesRef.push();
      await newRef.set(data);
      
      if (kDebugMode) {
        print('✅ Vehicle type data created successfully with key: ${newRef.key}');
      }
      
      return newRef.key;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating vehicle type: $e');
      }
      return null;
    }
  }

  /// Create or update vehicle type data with a specific key
  /// 
  /// [key] - The key for the vehicle type entry
  /// [data] - Map containing the vehicle type data to store
  Future<bool> createOrUpdateVehicleTypeWithKey(String key, Map<String, dynamic> data) async {
    try {
      await _vehicleTypesRef.child(key).set(data);
      
      if (kDebugMode) {
        print('✅ Vehicle type data created/updated successfully with key: $key');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating/updating vehicle type: $e');
      }
      return false;
    }
  }

  /// Get all vehicle types from Firebase
  Future<Map<String, dynamic>?> getAllVehicleTypes() async {
    try {
      final snapshot = await _vehicleTypesRef.get();
      
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        
        if (kDebugMode) {
          print('✅ Retrieved ${data.length} vehicle type(s)');
        }
        
        return data;
      } else {
        if (kDebugMode) {
          print('⚠️ No vehicle types found in database');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error retrieving vehicle types: $e');
      }
      return null;
    }
  }

  /// Get a specific vehicle type by key
  Future<Map<String, dynamic>?> getVehicleTypeByKey(String key) async {
    try {
      final snapshot = await _vehicleTypesRef.child(key).get();
      
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        
        if (kDebugMode) {
          print('✅ Retrieved vehicle type with key: $key');
        }
        
        return data;
      } else {
        if (kDebugMode) {
          print('⚠️ Vehicle type with key $key not found');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error retrieving vehicle type: $e');
      }
      return null;
    }
  }

  /// Update a specific vehicle type
  Future<bool> updateVehicleType(String key, Map<String, dynamic> updates) async {
    try {
      await _vehicleTypesRef.child(key).update(updates);
      
      if (kDebugMode) {
        print('✅ Vehicle type updated successfully with key: $key');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating vehicle type: $e');
      }
      return false;
    }
  }

  /// Delete a vehicle type
  Future<bool> deleteVehicleType(String key) async {
    try {
      await _vehicleTypesRef.child(key).remove();
      
      if (kDebugMode) {
        print('✅ Vehicle type deleted successfully with key: $key');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting vehicle type: $e');
      }
      return false;
    }
  }

  /// Listen to real-time changes in vehicle types
  Stream<DatabaseEvent> listenToVehicleTypes() {
    return _vehicleTypesRef.onValue;
  }

  /// Get localized name for a vehicle type
  /// 
  /// [vehicleData] - Map containing vehicle data from Firebase
  /// [languageCode] - Language code ('en', 'ur', or 'ps')
  /// Returns the localized name or English as fallback
  static String getLocalizedName(Map<String, dynamic> vehicleData, String languageCode) {
    try {
      final nameData = vehicleData['name'];
      if (nameData is Map) {
        return nameData[languageCode] ?? nameData['en'] ?? vehicleData['nameKey'] ?? 'Unknown';
      }
      // Fallback for old data structure (single string)
      if (nameData is String) {
        return nameData;
      }
      return vehicleData['nameKey'] ?? 'Unknown';
    } catch (e) {
      return vehicleData['nameKey'] ?? 'Unknown';
    }
  }

  /// Get localized capacity for a vehicle type
  /// 
  /// [vehicleData] - Map containing vehicle data from Firebase
  /// [languageCode] - Language code ('en', 'ur', or 'ps')
  /// Returns the localized capacity or English as fallback
  static String getLocalizedCapacity(Map<String, dynamic> vehicleData, String languageCode) {
    try {
      final capacityData = vehicleData['capacity'];
      if (capacityData is Map) {
        return capacityData[languageCode] ?? capacityData['en'] ?? vehicleData['capacityKey'] ?? 'N/A';
      }
      // Fallback for old data structure (single string)
      if (capacityData is String) {
        return capacityData;
      }
      return vehicleData['capacityKey'] ?? 'N/A';
    } catch (e) {
      return vehicleData['capacityKey'] ?? 'N/A';
    }
  }

  /// Map of multilingual vehicle names (from localization)
  /// Structure: { nameKey: { en: "...", ur: "...", ps: "..." } }
  static const Map<String, Map<String, String>> _vehicleNames = {
    'pickupCarry': {
      'en': 'Pickup Carry',
      'ur': 'پک اپ کیری',
      'ps': 'پک اپ کیری',
    },
    'shehzore': {
      'en': 'Shehzore',
      'ur': 'شہزور',
      'ps': 'شهزور',
    },
    'mazdaTruckOpenBody': {
      'en': 'Mazda Truck (Open Body)',
      'ur': 'مزدا ٹرک (کھلا باڈی)',
      'ps': 'مزدا ټرک (خلاصه بدن)',
    },
    'mazdaTruckCloseBody': {
      'en': 'Mazda Truck (Close Body)',
      'ur': 'مزدا ٹرک (بند باڈی)',
      'ps': 'مزدا ټرک (تړلی بدن)',
    },
    'vehicleCarrier': {
      'en': 'Vehicle Carrier',
      'ur': 'گاڑی کیریئر',
      'ps': 'د موټرو لیونکی',
    },
    'containerTruck20ft': {
      'en': 'Container Truck (20 ft)',
      'ur': 'کنٹینر ٹرک (20 فٹ)',
      'ps': 'د کنټینر ټرک (20 فټه)',
    },
    'containerTruck40ft': {
      'en': 'Container Truck (40 ft)',
      'ur': 'کنٹینر ٹرک (40 فٹ)',
      'ps': 'د کنټینر ټرک (40 فټه)',
    },
    'oilTanker': {
      'en': 'Oil Tanker',
      'ur': 'تیل ٹینکر',
      'ps': 'د تیلو ټانکر',
    },
    'reeferCarrier': {
      'en': 'Reefer Carrier',
      'ur': 'ریفریئر کیریئر',
      'ps': 'د سړولو لیونکی',
    },
    'reeferCarrierLarge': {
      'en': 'Reefer Carrier',
      'ur': 'ریفریئر کیریئر',
      'ps': 'د سړولو لیونکی',
    },
    'miniLoaderRickshaw': {
      'en': 'Mini Loader Rickshaw',
      'ur': 'منی لوڈر رکشہ',
      'ps': 'د کوچني لوډر رکشه',
    },
    'flatbedTruck': {
      'en': 'Flatbed Truck',
      'ur': 'فلیٹ بیڈ ٹرک',
      'ps': 'د فلیټ بیډ ټرک',
    },
    'dumper': {
      'en': 'Dumper',
      'ur': 'ڈمپر',
      'ps': 'ډمپر',
    },
    'Bulan': {
      'en': 'Bulan',
      'ur': 'بulan', // Add Urdu translation if available
      'ps': 'Bulan', // Add Pashto translation if available
    },
  };

  /// Map of multilingual vehicle capacities (from localization)
  /// Structure: { capacityKey: { en: "...", ur: "...", ps: "..." } }
  static const Map<String, Map<String, String>> _vehicleCapacities = {
    'pickupCarryCapacity': {
      'en': 'Up to 800kg',
      'ur': '800 کلوگرام تک',
      'ps': 'تر 800 کیلوګرامه',
    },
    'shehzoreCapacity': {
      'en': 'Up to 1200kg',
      'ur': '1200 کلوگرام تک',
      'ps': 'تر 1200 کیلوګرامه',
    },
    'mazdaTruckOpenBodyCapacity': {
      'en': 'Up to 2000kg',
      'ur': '2000 کلوگرام تک',
      'ps': 'تر 2000 کیلوګرامه',
    },
    'mazdaTruckCloseBodyCapacity': {
      'en': 'Up to 2000kg',
      'ur': '2000 کلوگرام تک',
      'ps': 'تر 2000 کیلوګرامه',
    },
    'vehicleCarrierCapacity': {
      'en': 'Up to 10 Vehicles',
      'ur': '10 گاڑیاں تک',
      'ps': 'تر 10 موټرو',
    },
    'containerTruck20ftCapacity': {
      'en': 'Up to 24,000kg',
      'ur': '24,000 کلوگرام تک',
      'ps': 'تر 24,000 کیلوګرامه',
    },
    'containerTruck40ftCapacity': {
      'en': 'Up to 32,000kg',
      'ur': '32,000 کلوگرام تک',
      'ps': 'تر 32,000 کیلوګرامه',
    },
    'oilTankerCapacity': {
      'en': 'Up to 30,000 liters',
      'ur': '30,000 لیٹر تک',
      'ps': 'تر 30,000 لیتره',
    },
    'reeferCarrierCapacity': {
      'en': 'Up to 5000kg (for perishable goods)',
      'ur': '5000 کلوگرام تک (خراب ہونے والے سامان کے لیے)',
      'ps': 'تر 5000 کیلوګرامه (د خرابیدونکو توکو لپاره)',
    },
    'reeferCarrierLargeCapacity': {
      'en': 'Up to 35,000kg (for perishable goods)',
      'ur': '35,000 کلوگرام تک (خراب ہونے والے سامان کے لیے)',
      'ps': 'تر 35,000 کیلوګرامه (د خرابیدونکو توکو لپاره)',
    },
    'miniLoaderRickshawCapacity': {
      'en': 'Up to 500kg',
      'ur': '500 کلوگرام تک',
      'ps': 'تر 500 کیلوګرامه',
    },
    'flatbedTruckCapacity1': {
      'en': 'Up to 10,000kg',
      'ur': '10,000 کلوگرام تک',
      'ps': 'تر 10,000 کیلوګرامه',
    },
    'flatbedTruckCapacity2': {
      'en': 'Up to 6,000kg',
      'ur': '6,000 کلوگرام تک',
      'ps': 'تر 6,000 کیلوګرامه',
    },
    'flatbedTruckCapacity3': {
      'en': 'Up to 16,000kg',
      'ur': '16,000 کلوگرام تک',
      'ps': 'تر 16,000 کیلوګرامه',
    },
    'flatbedTruckCapacity4': {
      'en': 'Up to 35,000kg',
      'ur': '35,000 کلوگرام تک',
      'ps': 'تر 35,000 کیلوګرامه',
    },
    'dumperCapacity': {
      'en': 'Up to 25,000kg',
      'ur': '25,000 کلوگرام تک',
      'ps': 'تر 25,000 کیلوګرامه',
    },
    'trailerCapacity': {
      'en': 'N/A',
      'ur': 'N/A',
      'ps': 'N/A',
    },
  };

  /// Initialize all vehicles from vehicles.dart to Firebase
  /// This will upload all vehicles with their names and capacities
  Future<Map<String, dynamic>> initializeAllVehicles() async {
    final results = <String, dynamic>{
      'success': 0,
      'failed': 0,
      'errors': <String>[],
    };

    try {
      if (kDebugMode) {
        print('🚀 Starting vehicle initialization...');
        print('   Total vehicles to upload: ${vehicleList.length}');
      }

      for (final vehicle in vehicleList) {
        try {
          // Get multilingual names and capacities
          final nameMap = _vehicleNames[vehicle.nameKey] ?? {
            'en': vehicle.nameKey,
            'ur': vehicle.nameKey,
            'ps': vehicle.nameKey,
          };
          final capacityMap = _vehicleCapacities[vehicle.capacityKey] ?? {
            'en': 'N/A',
            'ur': 'N/A',
            'ps': 'N/A',
          };

          // Create data map for Firebase with multilingual support
          final vehicleData = <String, dynamic>{
            'nameKey': vehicle.nameKey,
            'capacityKey': vehicle.capacityKey,
            'name': {
              'en': nameMap['en'] ?? vehicle.nameKey,
              'ur': nameMap['ur'] ?? vehicle.nameKey,
              'ps': nameMap['ps'] ?? vehicle.nameKey,
            },
            'capacity': {
              'en': capacityMap['en'] ?? 'N/A',
              'ur': capacityMap['ur'] ?? 'N/A',
              'ps': capacityMap['ps'] ?? 'N/A',
            },
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          };

          // Use a composite key (nameKey_capacityKey) to handle duplicates
          // For example: flatbedTruck_flatbedTruckCapacity1, flatbedTruck_flatbedTruckCapacity2, etc.
          final firebaseKey = '${vehicle.nameKey}_${vehicle.capacityKey}';
          
          final success = await createOrUpdateVehicleTypeWithKey(
            firebaseKey,
            vehicleData,
          );

          if (success) {
            results['success'] = (results['success'] as int) + 1;
            if (kDebugMode) {
              print('   ✅ Uploaded: ${nameMap['en']} (${nameMap['ur']})');
            }
          } else {
            results['failed'] = (results['failed'] as int) + 1;
            final errorMsg = 'Failed to upload: ${nameMap['en']}';
            (results['errors'] as List<String>).add(errorMsg);
            if (kDebugMode) {
              print('   ❌ $errorMsg');
            }
          }
        } catch (e) {
          results['failed'] = (results['failed'] as int) + 1;
          final errorMsg = 'Error uploading ${vehicle.nameKey}: $e';
          (results['errors'] as List<String>).add(errorMsg);
          if (kDebugMode) {
            print('   ❌ $errorMsg');
          }
        }
      }

      if (kDebugMode) {
        print('✅ Vehicle initialization completed!');
        print('   Success: ${results['success']}');
        print('   Failed: ${results['failed']}');
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during vehicle initialization: $e');
      }
      results['errors'].add('Initialization error: $e');
      return results;
    }
  }
}

