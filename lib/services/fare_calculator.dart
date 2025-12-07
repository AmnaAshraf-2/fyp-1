import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class FareCalculator {
  // Vehicle-based rate table
  static const Map<String, Map<String, double>> vehicleRates = {
    'Suzuki Pickup': {
      'ratePerKm': 30.0,
      'baseFare': 300.0,
      'maxLoad': 800.0,
    },
    'Mazda 14 ft': {
      'ratePerKm': 50.0,
      'baseFare': 500.0,
      'maxLoad': 2000.0,
    },
    'Shehzore': {
      'ratePerKm': 45.0,
      'baseFare': 400.0,
      'maxLoad': 1500.0,
    },
    'Container (20 ft)': {
      'ratePerKm': 70.0,
      'baseFare': 800.0,
      'maxLoad': 5000.0,
    },
    'Trailer': {
      'ratePerKm': 100.0,
      'baseFare': 1000.0,
      'maxLoad': 10000.0,
    },
  };

  /// Get vehicle capacity in kg
  static double? getVehicleCapacity(String vehicleType) {
    return vehicleRates[vehicleType]?['maxLoad'];
  }

  /// Calculate required vehicle count based on weight
  static int calculateVehicleCount({
    required double weight,
    required String weightUnit,
    required String vehicleType,
  }) {
    // Convert weight to kg
    double weightInKg = weight;
    if (weightUnit == 'tons') {
      weightInKg = weight * 1000;
    } else if (weightUnit == 'lbs') {
      weightInKg = weight * 0.453592;
    }

    // Get vehicle capacity
    final capacity = getVehicleCapacity(vehicleType);
    if (capacity == null) {
      return 1; // Default to 1 if capacity unknown
    }

    // Calculate required vehicles (ceiling)
    return (weightInKg / capacity).ceil();
  }

  // Weight unit conversion to tons
  static const Map<String, double> weightUnitToTons = {
    'kg': 0.001,
    'tons': 1.0,
    'lbs': 0.000453592,
  };

  // Load type multipliers
  static const Map<String, double> loadTypeMultipliers = {
    'fragile': 0.10,
    'heavy': 0.20,
    'perishable': 0.15,
    'general': 0.0,
  };

  // Insurance multiplier
  static const double insuranceMultiplier = 1.2;

  // Weight factor rate
  static const double weightFactorRate = 200.0;

  // 🔥 Hybrid Commission
  static const double commissionRate = 0.10;  // 10%
  static const double minimumCommission = 100.0;

  /// MAIN FARE CALCULATION
  static Future<Map<String, dynamic>> calculateFareWithCommission({
    required String pickupLocation,
    required String destinationLocation,
    required double weight,
    required String weightUnit,
    required String cargoType,
    required String vehicleType,
    required bool isInsured,
  }) async {
    try {
      // Get vehicle rates
      final vehicleRate = vehicleRates[vehicleType] ?? vehicleRates['Suzuki Pickup']!;
      final baseFare = vehicleRate['baseFare']!;
      final ratePerKm = vehicleRate['ratePerKm']!;

      // Calculate distance
      double distance = await _calculateDistance(pickupLocation, destinationLocation);

      // Weight conversion
      double weightInTons = weight * (weightUnitToTons[weightUnit] ?? 0.001);

      // Weight factor
      double weightFactor = weightInTons * weightFactorRate;

      // Distance cost
      double distanceCost = distance * ratePerKm;

      // Subtotal
      double subtotal = baseFare + distanceCost + weightFactor;

      // Load type multiplier
      double loadTypeMultiplier = loadTypeMultipliers[cargoType] ?? 0.0;
      double loadTypeCost = subtotal * loadTypeMultiplier;

      // Fare before insurance
      double finalFare = subtotal + loadTypeCost;

      // Insurance
      if (isInsured) finalFare *= insuranceMultiplier;

      // 🔥 Hybrid commission
      double percentageCommission = finalFare * commissionRate;
      double commission = percentageCommission < minimumCommission
          ? minimumCommission
          : percentageCommission;

      double driverReceives = finalFare - commission;

      return {
        "distance": distance,
        "baseFare": baseFare,
        "distanceCost": distanceCost,
        "weightFactor": weightFactor,
        "loadTypeCost": loadTypeCost,
        "subtotal": subtotal,
        "insuranceApplied": isInsured,
        "finalFare": finalFare,
        "commission": commission,
        "driverReceives": driverReceives,
      };
    } catch (e) {
      return {
        "error": e.toString(),
      };
    }
  }

  /// Distance calculation
  static Future<double> _calculateDistance(String pickup, String destination) async {
    try {
      List<Location> p = await locationFromAddress(pickup);
      List<Location> d = await locationFromAddress(destination);

      double distance = Geolocator.distanceBetween(
        p.first.latitude,
        p.first.longitude,
        d.first.latitude,
        d.first.longitude,
      );

      return distance / 1000;
    } catch (e) {
      return 10.0;
    }
  }
}
