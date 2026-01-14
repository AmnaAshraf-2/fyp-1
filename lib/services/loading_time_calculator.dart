import 'package:flutter/foundation.dart' show kDebugMode;

/// Service to calculate loading and unloading time based on vehicle type, load type, and weight
class LoadingTimeCalculator {
  /// Base loading/unloading times in minutes for different vehicle types
  /// These represent the base time needed for standard general goods
  static const Map<String, int> _baseVehicleTimes = {
    'pickupCarry': 10, // 10 minutes base
    'shehzore': 15, // 15 minutes base
    'mazdaTruckOpenBody': 20, // 20 minutes base
    'mazdaTruckCloseBody': 25, // 25 minutes base (closed body takes longer)
    'vehicleCarrier': 30, // 30 minutes base (vehicles need careful loading)
    'containerTruck20ft': 40, // 40 minutes base
    'containerTruck40ft': 50, // 50 minutes base
    'reeferCarrier': 30, // 30 minutes base (temperature control)
    'reeferCarrierLarge': 45, // 45 minutes base
    'miniLoaderRickshaw': 8, // 8 minutes base
    'flatbedTruck': 25, // 25 minutes base
    'dumper': 20, // 20 minutes base
  };

  /// Load type multipliers
  /// These adjust the base time based on how difficult the load is to handle
  static const Map<String, double> _loadTypeMultipliers = {
    'fragile': 1.5, // 50% more time (careful handling)
    'heavy': 1.3, // 30% more time (requires equipment/care)
    'perishable': 1.4, // 40% more time (temperature control, careful handling)
    'general': 1.0, // Standard time
  };

  /// Weight-based time adjustments (in minutes per 1000kg)
  /// Additional time needed for heavier loads
  static const Map<String, double> _weightTimePerTon = {
    'pickupCarry': 2.0, // 2 min per 1000kg
    'shehzore': 2.5, // 2.5 min per 1000kg
    'mazdaTruckOpenBody': 3.0, // 3 min per 1000kg
    'mazdaTruckCloseBody': 3.5, // 3.5 min per 1000kg
    'vehicleCarrier': 5.0, // 5 min per vehicle (not weight-based)
    'containerTruck20ft': 4.0, // 4 min per 1000kg
    'containerTruck40ft': 5.0, // 5 min per 1000kg
    'reeferCarrier': 4.0, // 4 min per 1000kg
    'reeferCarrierLarge': 5.0, // 5 min per 1000kg
    'miniLoaderRickshaw': 1.5, // 1.5 min per 1000kg
    'flatbedTruck': 3.5, // 3.5 min per 1000kg
    'dumper': 3.0, // 3 min per 1000kg
  };

  /// Calculate total loading and unloading time in seconds
  /// 
  /// Parameters:
  /// - vehicleType: The type of vehicle (e.g., 'pickupCarry', 'shehzore', etc.)
  /// - loadType: The type of load ('fragile', 'heavy', 'perishable', 'general')
  /// - weight: Weight in kg
  /// - weightUnit: 'kg' or 'tons'
  /// 
  /// Returns: Total time in seconds (loading + unloading)
  static int calculateLoadingUnloadingTime({
    required String vehicleType,
    required String loadType,
    required double weight,
    String weightUnit = 'kg',
  }) {
    try {
      // Convert weight to kg if needed
      double weightInKg = weight;
      if (weightUnit.toLowerCase() == 'tons') {
        weightInKg = weight * 1000;
      }

      // Get base time for vehicle type (default to 20 minutes if not found)
      final baseTimeMinutes = _baseVehicleTimes[vehicleType] ?? 20;

      // Get load type multiplier (default to 1.0 if not found)
      final loadMultiplier = _loadTypeMultipliers[loadType.toLowerCase()] ?? 1.0;

      // Calculate weight-based additional time
      double weightTimeMinutes = 0;
      if (vehicleType == 'vehicleCarrier') {
        // For vehicle carriers, time is per vehicle, not weight
        // Assume each vehicle is ~1500kg, so divide weight by 1500
        final numberOfVehicles = (weightInKg / 1500).ceil();
        final weightTimePerVehicle = _weightTimePerTon['vehicleCarrier'] ?? 5.0;
        weightTimeMinutes = numberOfVehicles * weightTimePerVehicle;
      } else {
        // For other vehicles, time is based on weight
        final weightTimePerTon = _weightTimePerTon[vehicleType] ?? 3.0;
        final weightInTons = weightInKg / 1000;
        weightTimeMinutes = weightInTons * weightTimePerTon;
      }

      // Calculate total time: (base + weight adjustment) * load type multiplier
      final totalTimeMinutes = (baseTimeMinutes + weightTimeMinutes) * loadMultiplier;

      // Convert to seconds (round up to nearest minute, then convert)
      final totalTimeSeconds = (totalTimeMinutes.ceil() * 60).toInt();

      if (kDebugMode) {
        print('⏱️ Loading/Unloading Time Calculation:');
        print('   Vehicle: $vehicleType');
        print('   Load Type: $loadType (multiplier: $loadMultiplier)');
        print('   Weight: $weightInKg kg');
        print('   Base Time: $baseTimeMinutes min');
        print('   Weight Time: ${weightTimeMinutes.toStringAsFixed(1)} min');
        print('   Total Time: ${totalTimeMinutes.toStringAsFixed(1)} min (${totalTimeSeconds}s)');
      }

      return totalTimeSeconds;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calculating loading/unloading time: $e');
      }
      // Return default of 30 minutes (1800 seconds) on error
      return 1800;
    }
  }

  /// Calculate only loading time (half of total)
  static int calculateLoadingTime({
    required String vehicleType,
    required String loadType,
    required double weight,
    String weightUnit = 'kg',
  }) {
    final totalTime = calculateLoadingUnloadingTime(
      vehicleType: vehicleType,
      loadType: loadType,
      weight: weight,
      weightUnit: weightUnit,
    );
    // Loading time is approximately 60% of total (loading takes longer than unloading)
    return (totalTime * 0.6).round();
  }

  /// Calculate only unloading time (remaining time)
  static int calculateUnloadingTime({
    required String vehicleType,
    required String loadType,
    required double weight,
    String weightUnit = 'kg',
  }) {
    final totalTime = calculateLoadingUnloadingTime(
      vehicleType: vehicleType,
      loadType: loadType,
      weight: weight,
      weightUnit: weightUnit,
    );
    // Unloading time is approximately 40% of total
    return (totalTime * 0.4).round();
  }
}

