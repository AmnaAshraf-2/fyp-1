import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class FareCalculator {
  // Vehicle-based rate table
  static const Map<String, Map<String, double>> vehicleRates = {
    'Suzuki Pickup': {
      'ratePerKm': 30.0,
      'baseFare': 300.0,
      'maxLoad': 800.0, // kg
    },
    'Mazda 14 ft': {
      'ratePerKm': 50.0,
      'baseFare': 500.0,
      'maxLoad': 2000.0, // kg
    },
    'Shehzore': {
      'ratePerKm': 45.0,
      'baseFare': 400.0,
      'maxLoad': 1500.0, // kg
    },
    'Container (20 ft)': {
      'ratePerKm': 70.0,
      'baseFare': 800.0,
      'maxLoad': 5000.0, // kg
    },
    'Trailer': {
      'ratePerKm': 100.0,
      'baseFare': 1000.0,
      'maxLoad': 10000.0, // kg
    },
  };

  // Weight unit conversion to tons
  static const Map<String, double> weightUnitToTons = {
    'kg': 0.001,
    'tons': 1.0,
    'lbs': 0.000453592,
  };

  // Load type multipliers (as percentages)
  static const Map<String, double> loadTypeMultipliers = {
    'fragile': 0.10,      // +10% for fragile items
    'heavy': 0.20,        // +20% for heavy items
    'perishable': 0.15,   // +15% for perishable items
    'general': 0.0,       // No extra charge for general goods
  };

  // Insurance multiplier
  static const double insuranceMultiplier = 1.2; // 20% extra for insurance

  // Weight factor rate (Rs. 200 per ton)
  static const double weightFactorRate = 200.0;

  /// Calculate suggested fare using the exact formula:
  /// Estimated Fare = Base Fare + (Distance × Rate per km) + (Weight Factor) + (Load Type Multiplier)
  static Future<double> calculateSuggestedFare({
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
      
      // Convert weight to tons
      double weightInTons = weight * (weightUnitToTons[weightUnit] ?? 0.001);
      
      // Calculate weight factor (Rs. 200 per ton)
      double weightFactor = weightInTons * weightFactorRate;
      
      // Calculate base fare components
      double distanceCost = distance * ratePerKm;
      
      // Calculate total before load type multiplier
      double subtotal = baseFare + distanceCost + weightFactor;
      
      // Apply load type multiplier (as percentage)
      double loadTypeMultiplier = loadTypeMultipliers[cargoType] ?? 0.0;
      double loadTypeCost = subtotal * loadTypeMultiplier;
      
      // Calculate final fare
      double finalFare = subtotal + loadTypeCost;
      
      // Apply insurance multiplier if insured
      if (isInsured) {
        finalFare *= insuranceMultiplier;
      }
      
      return double.parse(finalFare.toStringAsFixed(0));
    } catch (e) {
      // Return a default fare if calculation fails
      return _getDefaultFare(weight, cargoType, vehicleType, isInsured);
    }
  }

  /// Calculate distance between two locations
  static Future<double> _calculateDistance(String pickup, String destination) async {
    try {
      // Get coordinates for pickup location
      List<Location> pickupLocations = await locationFromAddress(pickup);
      if (pickupLocations.isEmpty) return 10.0; // Default distance
      
      // Get coordinates for destination location
      List<Location> destinationLocations = await locationFromAddress(destination);
      if (destinationLocations.isEmpty) return 10.0; // Default distance
      
      // Calculate distance using Haversine formula
      double distance = Geolocator.distanceBetween(
        pickupLocations.first.latitude,
        pickupLocations.first.longitude,
        destinationLocations.first.latitude,
        destinationLocations.first.longitude,
      );
      
      // Convert from meters to kilometers
      return distance / 1000;
    } catch (e) {
      // Return default distance if geocoding fails
      return 10.0;
    }
  }

  /// Get default fare when distance calculation fails
  static double _getDefaultFare(double weight, String cargoType, String vehicleType, bool isInsured) {
    // Get vehicle rates
    final vehicleRate = vehicleRates[vehicleType] ?? vehicleRates['Suzuki Pickup']!;
    final baseFare = vehicleRate['baseFare']!;
    final ratePerKm = vehicleRate['ratePerKm']!;
    
    // Use default distance of 50 km
    double defaultDistance = 50.0;
    
    // Convert weight to tons
    double weightInTons = weight * 0.001; // Assume kg if not specified
    
    // Calculate weight factor (Rs. 200 per ton)
    double weightFactor = weightInTons * weightFactorRate;
    
    // Calculate base fare components
    double distanceCost = defaultDistance * ratePerKm;
    
    // Calculate total before load type multiplier
    double subtotal = baseFare + distanceCost + weightFactor;
    
    // Apply load type multiplier (as percentage)
    double loadTypeMultiplier = loadTypeMultipliers[cargoType] ?? 0.0;
    double loadTypeCost = subtotal * loadTypeMultiplier;
    
    // Calculate final fare
    double finalFare = subtotal + loadTypeCost;
    
    // Apply insurance multiplier if insured
    if (isInsured) {
      finalFare *= insuranceMultiplier;
    }
    
    return finalFare;
  }

  /// Get fare breakdown for display using the new formula
  static Map<String, dynamic> getFareBreakdown({
    required double distance,
    required double weight,
    required String weightUnit,
    required String cargoType,
    required String vehicleType,
    required bool isInsured,
  }) {
    // Get vehicle rates
    final vehicleRate = vehicleRates[vehicleType] ?? vehicleRates['Suzuki Pickup']!;
    final baseFare = vehicleRate['baseFare']!;
    final ratePerKm = vehicleRate['ratePerKm']!;
    
    // Convert weight to tons
    double weightInTons = weight * (weightUnitToTons[weightUnit] ?? 0.001);
    
    // Calculate weight factor (Rs. 200 per ton)
    double weightFactor = weightInTons * weightFactorRate;
    
    // Calculate base fare components
    double distanceCost = distance * ratePerKm;
    
    // Calculate total before load type multiplier
    double subtotal = baseFare + distanceCost + weightFactor;
    
    // Apply load type multiplier (as percentage)
    double loadTypeMultiplier = loadTypeMultipliers[cargoType] ?? 0.0;
    double loadTypeCost = subtotal * loadTypeMultiplier;
    
    // Calculate final fare
    double finalFare = subtotal + loadTypeCost;
    
    // Apply insurance multiplier if insured
    if (isInsured) {
      finalFare *= insuranceMultiplier;
    }
    
    return {
      'distance': distance,
      'baseFare': baseFare,
      'ratePerKm': ratePerKm,
      'distanceCost': distanceCost,
      'weightInTons': weightInTons,
      'weightFactor': weightFactor,
      'subtotal': subtotal,
      'loadTypeMultiplier': loadTypeMultiplier,
      'loadTypeCost': loadTypeCost,
      'insuranceMultiplier': isInsured ? insuranceMultiplier : 1.0,
      'finalFare': finalFare,
    };
  }
}
