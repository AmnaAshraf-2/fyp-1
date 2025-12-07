import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

/// Driver search result model
class DriverSearchResult {
  final String driverId;
  final String vehicleType;
  final double distanceKm;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? driverInfo;

  DriverSearchResult({
    required this.driverId,
    required this.vehicleType,
    required this.distanceKm,
    this.location,
    this.driverInfo,
  });
}

/// Service for searching drivers by vehicle type (no location filtering)
class DriverSearchService {
  final _db = FirebaseDatabase.instance.ref();

  /// Check if driver is available (not on a trip)
  Future<bool> _isDriverAvailable(String driverId, DateTime? pickupDateTime) async {
    try {
      // For urgent requests (pickupDateTime is null or very soon), check current status
      if (pickupDateTime == null || 
          pickupDateTime.difference(DateTime.now()).inHours < 2) {
        // Check if driver has any active trips
        final requestsSnapshot = await _db.child('requests').get();
        if (requestsSnapshot.exists) {
          for (final request in requestsSnapshot.children) {
            final requestData = request.value as Map?;
            if (requestData != null) {
              final acceptedDriverId = requestData['acceptedDriverId'] as String?;
              final status = requestData['status'] as String?;
              
              if (acceptedDriverId == driverId && 
                  (status == 'accepted' || status == 'in_progress')) {
                return false; // Driver is on a trip
              }
            }
          }
        }
        return true; // No active trips found
      } else {
        // For scheduled requests, check if driver is free at that time
        // This is a simplified check - in production, you'd check scheduled trips
        final requestsSnapshot = await _db.child('requests').get();
        if (requestsSnapshot.exists) {
          for (final request in requestsSnapshot.children) {
            final requestData = request.value as Map?;
            if (requestData != null) {
              final acceptedDriverId = requestData['acceptedDriverId'] as String?;
              final status = requestData['status'] as String?;
              final pickupDate = requestData['pickupDate'] as String?;
              final pickupTime = requestData['pickupTime'] as String?;
              
              if (acceptedDriverId == driverId && 
                  (status == 'accepted' || status == 'in_progress' || status == 'pending')) {
                // Check if the scheduled pickup conflicts with this request
                // This is simplified - you'd need proper date/time parsing
                return false;
              }
            }
          }
        }
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking driver availability: $e');
      }
      return false;
    }
  }

  /// Search for drivers by vehicle type (no location filtering)
  /// Returns all available drivers with matching vehicle type
  Future<List<DriverSearchResult>> _searchDriversByVehicleType({
    required String vehicleType,
    required DateTime? pickupDateTime,
    bool isEnterprise = false,
  }) async {
    final results = <DriverSearchResult>[];

    try {
      // Get all users
      final usersSnapshot = await _db.child('users').get();
      if (!usersSnapshot.exists) {
        if (kDebugMode) {
          print('⚠️ No users found in database');
        }
        return [];
      }

      // Get driver locations (optional - for display purposes only)
      final locationsSnapshot = await _db.child('driver_locations').get();
      final Map<String, Map<String, dynamic>> driverLocations = {};
      
      if (locationsSnapshot.exists) {
        for (final locationEntry in locationsSnapshot.children) {
          final locationData = locationEntry.value as Map?;
          if (locationData != null) {
            driverLocations[locationEntry.key!] = Map<String, dynamic>.from(locationData);
          }
        }
      }

      // Filter drivers by vehicle type and availability
      for (final user in usersSnapshot.children) {
        final userData = user.value as Map?;
        if (userData == null) continue;

        final role = userData['role'] as String?;
        
        // Check if it's the right role
        if (isEnterprise) {
          if (role != 'enterprise') continue;
        } else {
          if (role != 'driver') continue;
        }

        // Check vehicle type
        bool hasMatchingVehicle = false;
        if (isEnterprise) {
          // For enterprises, check if they have the vehicle type
          hasMatchingVehicle = await _checkEnterpriseVehicleType(
            user.key!,
            vehicleType,
          );
        } else {
          // For drivers, check vehicle info
          final vehicleInfo = userData['vehicleInfo'] as Map?;
          hasMatchingVehicle = vehicleInfo != null && vehicleInfo['type'] == vehicleType;
        }
        
        if (!hasMatchingVehicle) continue;

        // Check availability
        final isAvailable = await _isDriverAvailable(user.key!, pickupDateTime);
        if (!isAvailable) continue;

        // Get location if available (for display purposes only, not used for filtering)
        final location = driverLocations[user.key!];

        // Add driver to results (regardless of location)
        results.add(DriverSearchResult(
          driverId: user.key!,
          vehicleType: vehicleType,
          distanceKm: 0.0, // Distance not calculated - not used for filtering
          location: location,
          driverInfo: Map<String, dynamic>.from(userData),
        ));
      }

      if (kDebugMode) {
        print('🔍 Search results:');
        print('   Total drivers with matching vehicle type: ${results.length}');
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error searching drivers: $e');
      }
      return [];
    }
  }

  /// Check if enterprise has the vehicle type
  Future<bool> _checkEnterpriseVehicleType(String enterpriseId, String vehicleType) async {
    try {
      final usersVehiclesSnapshot = await _db.child('users/$enterpriseId/vehicles').get();
      final enterprisesVehiclesSnapshot = await _db.child('enterprises/$enterpriseId/vehicles').get();

      if (usersVehiclesSnapshot.exists) {
        for (final vehicle in usersVehiclesSnapshot.children) {
          final vehicleData = vehicle.value as Map?;
          if (vehicleData != null && vehicleData['type'] == vehicleType) {
            return true;
          }
        }
      }

      if (enterprisesVehiclesSnapshot.exists) {
        for (final vehicle in enterprisesVehiclesSnapshot.children) {
          final vehicleData = vehicle.value as Map?;
          if (vehicleData != null && vehicleData['type'] == vehicleType) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking enterprise vehicle: $e');
      }
      return false;
    }
  }

  /// Main search function - finds drivers by vehicle type (no location filtering)
  Future<Map<String, dynamic>> searchNearbyDrivers({
    required String pickupLocation,
    required String vehicleType,
    required int requiredCount,
    DateTime? pickupDate,
    TimeOfDay? pickupTime,
    bool isEnterprise = false,
    Function(double currentRadius, int foundCount)? onRadiusSearch,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 Starting driver search:');
        print('   Pickup: $pickupLocation');
        print('   Vehicle: $vehicleType');
        print('   Required: $requiredCount');
        print('   Type: ${isEnterprise ? "Enterprise" : "Driver"}');
      }

      // Determine if urgent or scheduled
      DateTime? pickupDateTime;
      if (pickupDate != null && pickupTime != null) {
        pickupDateTime = DateTime(
          pickupDate.year,
          pickupDate.month,
          pickupDate.day,
          pickupTime.hour,
          pickupTime.minute,
        );
        
        // If pickup is more than 2 hours away, it's scheduled
        final hoursUntilPickup = pickupDateTime.difference(DateTime.now()).inHours;
        if (hoursUntilPickup > 2) {
          // Scheduled request
        } else {
          // Urgent request
          pickupDateTime = null;
        }
      }

      // Search for drivers by vehicle type (no location filtering)
      final drivers = await _searchDriversByVehicleType(
        vehicleType: vehicleType,
        pickupDateTime: pickupDateTime,
        isEnterprise: isEnterprise,
      );

      // Notify callback if provided (for compatibility)
      if (onRadiusSearch != null) {
        onRadiusSearch(0.0, drivers.length);
      }

      // Return all drivers (don't limit by requiredCount)
      // Requests will be sent to all available drivers with matching vehicle type
      if (kDebugMode) {
        print('✅ Found ${drivers.length} drivers with matching vehicle type');
      }

      return {
        'success': true,
        'drivers': drivers, // Return all drivers, not limited by requiredCount
        'finalRadius': 0.0, // Not used anymore, kept for compatibility
        'foundCount': drivers.length,
        'requiredCount': requiredCount,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in searchNearbyDrivers: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'drivers': <DriverSearchResult>[],
        'finalRadius': 0.0,
      };
    }
  }


  /// Find alternative vehicle types (similar vehicles)
  List<String> getAlternativeVehicleTypes(String vehicleType) {
    // Vehicle hierarchy - if exact type not available, suggest larger vehicles
    const vehicleHierarchy = <String, List<String>>{
      'Suzuki Pickup': ['Shehzore', 'Mazda 14 ft'],
      'Shehzore': ['Mazda 14 ft', 'Container (20 ft)'],
      'Mazda 14 ft': ['Container (20 ft)', 'Trailer'],
      'Container (20 ft)': ['Trailer'],
      'Trailer': [],
    };

    return vehicleHierarchy[vehicleType] ?? <String>[];
  }
}

