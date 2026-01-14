import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/vehicles.dart';

/// Vehicle model compatible with the existing app structure
class VehicleModel {
  final String nameKey;
  final String capacityKey;
  final Map<String, String> name; // Multilingual name
  final Map<String, String> capacity; // Multilingual capacity
  final String firebaseKey;
  final String? image; // Vehicle image path

  VehicleModel({
    required this.nameKey,
    required this.capacityKey,
    required this.name,
    required this.capacity,
    required this.firebaseKey,
    this.image,
  });

  /// Get localized name based on current language
  String getName(String languageCode) {
    return name[languageCode] ?? name['en'] ?? nameKey;
  }

  /// Get localized capacity based on current language
  String getCapacity(String languageCode) {
    return capacity[languageCode] ?? capacity['en'] ?? capacityKey;
  }

  /// Factory constructor from Vehicle
  factory VehicleModel.fromVehicle(Vehicle vehicle, String key) {
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

    final vehicleModel = VehicleModel(
      nameKey: vehicle.nameKey,
      capacityKey: vehicle.capacityKey,
      name: Map<String, String>.from(nameMap),
      capacity: Map<String, String>.from(capacityMap),
      firebaseKey: key,
      image: vehicle.image,
    );
    
    // Debug: print image path if available
    if (kDebugMode && vehicle.image != null) {
      print('🚚 Vehicle ${vehicle.nameKey} has image: ${vehicle.image}');
    }
    
    return vehicleModel;
  }
}

/// Map of multilingual vehicle names
/// Structure: { nameKey: { en: "...", ur: "...", ps: "..." } }
const Map<String, Map<String, String>> _vehicleNames = {
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
    'ur': 'بulan',
    'ps': 'Bulan',
  },
};

/// Map of multilingual vehicle capacities
/// Structure: { capacityKey: { en: "...", ur: "...", ps: "..." } }
const Map<String, Map<String, String>> _vehicleCapacities = {
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

/// Provider service for vehicles loaded from vehicles.dart
class VehicleProvider {
  static final VehicleProvider _instance = VehicleProvider._internal();
  factory VehicleProvider() => _instance;
  VehicleProvider._internal();

  List<VehicleModel>? _cachedVehicles;
  DateTime? _lastFetch;

  /// Get current language code from SharedPreferences
  Future<String> _getCurrentLanguageCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Try to get user-specific language first
      final userLanguage = prefs.getString('languageCode');
      if (userLanguage != null) {
        return userLanguage;
      }
      return 'en'; // Default to English
    } catch (e) {
      return 'en';
    }
  }

  /// Load vehicles from vehicles.dart
  Future<List<VehicleModel>> loadVehicles({bool forceRefresh = false}) async {
    // Return cached data if available and not forcing refresh
    if (!forceRefresh && _cachedVehicles != null && _lastFetch != null) {
      final cacheAge = DateTime.now().difference(_lastFetch!);
      if (cacheAge.inMinutes < 5) { // Cache for 5 minutes
        if (kDebugMode) {
          print('📦 Returning cached vehicles (${_cachedVehicles!.length} items)');
        }
        return _cachedVehicles!;
      }
    }

    try {
      if (kDebugMode) {
        print('🔄 Loading vehicles from vehicles.dart...');
      }

      final vehicles = <VehicleModel>[];
      for (final vehicle in vehicleList) {
        try {
          // Use composite key (nameKey_capacityKey) to handle duplicates
          final key = '${vehicle.nameKey}_${vehicle.capacityKey}';
          final vehicleModel = VehicleModel.fromVehicle(vehicle, key);
          vehicles.add(vehicleModel);
        } catch (e, stackTrace) {
          if (kDebugMode) {
            print('⚠️ Error converting vehicle ${vehicle.nameKey}: $e');
            print('Stack trace: $stackTrace');
          }
        }
      }

      // Sort vehicles by nameKey for consistency
      vehicles.sort((a, b) => a.nameKey.compareTo(b.nameKey));

      _cachedVehicles = vehicles;
      _lastFetch = DateTime.now();

      if (kDebugMode) {
        print('✅ Loaded ${vehicles.length} vehicles from vehicles.dart');
      }

      return vehicles;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error loading vehicles: $e');
        print('Stack trace: $stackTrace');
      }
      return _cachedVehicles ?? [];
    }
  }

  /// Get vehicle by nameKey (for backward compatibility)
  Future<VehicleModel?> getVehicleByNameKey(String nameKey) async {
    final vehicles = await loadVehicles();
    try {
      return vehicles.firstWhere((v) => v.nameKey == nameKey);
    } catch (e) {
      return null;
    }
  }

  /// Clear cache
  void clearCache() {
    _cachedVehicles = null;
    _lastFetch = null;
  }

  /// Listen to vehicle updates (returns current vehicles from vehicles.dart)
  /// Note: Since we're using static data from vehicles.dart, this just returns the current list
  Stream<List<VehicleModel>> listenToVehicles() async* {
    // Load vehicles and yield them
    final vehicles = await loadVehicles();
    yield vehicles;
    
    // Since vehicles.dart is static, we don't need to listen for changes
    // If you need real-time updates in the future, you can add periodic refresh here
  }
}

