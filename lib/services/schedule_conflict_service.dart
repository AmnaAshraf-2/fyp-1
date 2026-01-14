import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:logistics_app/services/places_service.dart';
import 'package:logistics_app/services/loading_time_calculator.dart';

/// Service to detect schedule conflicts for drivers
class ScheduleConflictService {
  final _db = FirebaseDatabase.instance.ref();
  static const int _bufferMinutes = 15; // 15 minutes buffer before and after trips

  /// Parse date string (format: "DD/MM/YYYY") to DateTime
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr == 'N/A' || dateStr.isEmpty) {
      return null;
    }
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error parsing date: $dateStr - $e');
      }
    }
    return null;
  }

  /// Parse time string (format: "HH:MM AM/PM" or "HH:MM") to TimeOfDay
  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr == 'N/A' || timeStr.isEmpty) {
      return null;
    }
    try {
      // Try parsing "HH:MM AM/PM" format
      final isPM = timeStr.toUpperCase().contains('PM');
      final isAM = timeStr.toUpperCase().contains('AM');
      
      // Remove AM/PM and whitespace
      String cleanTime = timeStr.toUpperCase().replaceAll('AM', '').replaceAll('PM', '').trim();
      
      final parts = cleanTime.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1].split(' ')[0]); // Handle cases like "12:30 PM"
        
        // Convert to 24-hour format
        if (isPM && hour != 12) {
          hour += 12;
        } else if (isAM && hour == 12) {
          hour = 0;
        }
        
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error parsing time: $timeStr - $e');
      }
    }
    return null;
  }

  /// Convert TimeOfDay and DateTime to a single DateTime
  DateTime? _combineDateTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  /// Get coordinates from address string
  Future<Map<String, double>?> _getCoordinates(String address) async {
    if (address.isEmpty) return null;
    
    // Check if it's already coordinates
    try {
      final parts = address.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          return {'lat': lat, 'lng': lng};
        }
      }
    } catch (e) {
      // Not coordinates, continue with geocoding
    }
    
    // Try geocoding package first
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return {
          'lat': locations.first.latitude,
          'lng': locations.first.longitude,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Geocoding package failed: $e');
      }
    }
    
    // Fallback to PlacesService
    try {
      final coords = await PlacesService.geocodeAddress(address);
      if (coords != null) {
        return coords;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ PlacesService geocoding failed: $e');
      }
    }
    
    return null;
  }

  /// Get trip duration in seconds from maps API
  Future<int?> _getTripDuration(
    String pickupLocation,
    String destinationLocation,
  ) async {
    try {
      final pickupCoords = await _getCoordinates(pickupLocation);
      final destCoords = await _getCoordinates(destinationLocation);
      
      if (pickupCoords == null || destCoords == null) {
        if (kDebugMode) {
          print('⚠️ Could not geocode locations for duration calculation');
        }
        return null;
      }
      
      final directions = await PlacesService.getDirections(
        pickupCoords['lat']!,
        pickupCoords['lng']!,
        destCoords['lat']!,
        destCoords['lng']!,
      );
      
      if (directions != null) {
        final duration = directions['duration'] as Map<String, dynamic>?;
        if (duration != null) {
          final seconds = duration['value'] as int?;
          if (seconds != null && seconds > 0) {
            return seconds;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error getting trip duration: $e');
      }
    }
    return null;
  }

  /// Get driver's existing trips for a specific date
  Future<List<Map<String, dynamic>>> _getDriverTripsForDate(
    String driverId,
    DateTime targetDate,
  ) async {
    final trips = <Map<String, dynamic>>[];
    
    try {
      final requestsSnapshot = await _db.child('requests').get();
      if (!requestsSnapshot.exists) {
        return trips;
      }
      
      for (final request in requestsSnapshot.children) {
        final requestData = Map<String, dynamic>.from(request.value as Map);
        final acceptedDriverId = requestData['acceptedDriverId'] as String?;
        final status = requestData['status'] as String?;
        
        // Only consider accepted or in_progress trips
        if (acceptedDriverId != driverId || 
            (status != 'accepted' && status != 'in_progress')) {
          continue;
        }
        
        // Check if trip is on the same date
        final pickupDateStr = requestData['pickupDate'] as String?;
        final tripDate = _parseDate(pickupDateStr);
        
        if (tripDate != null) {
          // Compare dates (ignore time)
          if (tripDate.year == targetDate.year &&
              tripDate.month == targetDate.month &&
              tripDate.day == targetDate.day) {
            trips.add(requestData);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting driver trips: $e');
      }
    }
    
    return trips;
  }

  /// Calculate blocked time windows for a driver on a specific date
  Future<List<Map<String, DateTime>>> _getBlockedWindows(
    String driverId,
    DateTime targetDate,
  ) async {
    final blockedWindows = <Map<String, DateTime>>[];
    
    final trips = await _getDriverTripsForDate(driverId, targetDate);
    
    for (final trip in trips) {
      final pickupDateStr = trip['pickupDate'] as String?;
      final pickupTimeStr = trip['pickupTime'] as String?;
      final pickupLocation = trip['pickupLocation'] as String? ?? '';
      final destinationLocation = trip['destinationLocation'] as String? ?? '';
      
      final tripDate = _parseDate(pickupDateStr);
      final tripTime = _parseTime(pickupTimeStr);
      final pickupDateTime = _combineDateTime(tripDate, tripTime);
      
      if (pickupDateTime == null) {
        if (kDebugMode) {
          print('⚠️ Could not parse pickup date/time for trip');
        }
        continue;
      }
      
      // Get trip duration from maps (travel time only)
      int? travelDurationSeconds;
      if (pickupLocation.isNotEmpty && destinationLocation.isNotEmpty) {
        travelDurationSeconds = await _getTripDuration(pickupLocation, destinationLocation);
      }
      
      // Default to 1 hour if duration cannot be calculated
      if (travelDurationSeconds == null || travelDurationSeconds <= 0) {
        travelDurationSeconds = 3600; // 1 hour default
        if (kDebugMode) {
          print('⚠️ Using default travel duration of 1 hour for trip');
        }
      }
      
      // Get loading/unloading time based on vehicle type, load type, and weight
      final vehicleType = trip['vehicleType'] as String? ?? 'pickupCarry';
      final loadType = trip['loadType'] as String? ?? 'general';
      final weight = (trip['weight'] as num?)?.toDouble() ?? 100.0;
      final weightUnit = trip['weightUnit'] as String? ?? 'kg';
      
      final loadingUnloadingSeconds = LoadingTimeCalculator.calculateLoadingUnloadingTime(
        vehicleType: vehicleType,
        loadType: loadType,
        weight: weight,
        weightUnit: weightUnit,
      );
      
      // Total trip duration = travel time + loading time + unloading time
      // Note: Loading happens at pickup, unloading at destination
      // For blocked window calculation, we need: pickup time + loading + travel + unloading
      final totalDurationSeconds = travelDurationSeconds + loadingUnloadingSeconds;
      
      if (kDebugMode) {
        print('⏱️ Trip Duration Breakdown:');
        print('   Travel Time: ${travelDurationSeconds}s (${(travelDurationSeconds / 60).toStringAsFixed(1)} min)');
        print('   Loading/Unloading Time: ${loadingUnloadingSeconds}s (${(loadingUnloadingSeconds / 60).toStringAsFixed(1)} min)');
        print('   Total Duration: ${totalDurationSeconds}s (${(totalDurationSeconds / 60).toStringAsFixed(1)} min)');
      }
      
      // Calculate dropoff time (pickup + loading + travel + unloading)
      final dropoffDateTime = pickupDateTime.add(Duration(seconds: totalDurationSeconds));
      
      // Calculate blocked window (pickup - 15 mins to dropoff + 15 mins)
      final blockedStart = pickupDateTime.subtract(Duration(minutes: _bufferMinutes));
      final blockedEnd = dropoffDateTime.add(Duration(minutes: _bufferMinutes));
      
      blockedWindows.add({
        'start': blockedStart,
        'end': blockedEnd,
      });
      
      if (kDebugMode) {
        print('🚫 Blocked window: ${blockedStart.toString()} to ${blockedEnd.toString()}');
      }
    }
    
    return blockedWindows;
  }

  /// Check if a request conflicts with driver's existing schedule
  /// Returns true if there's a conflict (should NOT show the request)
  Future<bool> hasConflict(
    String driverId,
    String requestPickupDate,
    String requestPickupTime,
  ) async {
    try {
      final requestDate = _parseDate(requestPickupDate);
      final requestTime = _parseTime(requestPickupTime);
      final requestDateTime = _combineDateTime(requestDate, requestTime);
      
      if (requestDateTime == null) {
        if (kDebugMode) {
          print('⚠️ Could not parse request date/time, allowing request');
        }
        return false; // If we can't parse, allow the request (safer)
      }
      
      // Get blocked windows for that date
      final blockedWindows = await _getBlockedWindows(driverId, requestDateTime);
      
      // Check if request pickup time falls within any blocked window
      for (final window in blockedWindows) {
        final start = window['start']!;
        final end = window['end']!;
        
        // Check if request pickup time is within the blocked window
        if (requestDateTime.isAfter(start.subtract(Duration(seconds: 1))) &&
            requestDateTime.isBefore(end.add(Duration(seconds: 1)))) {
          if (kDebugMode) {
            print('❌ CONFLICT: Request pickup time ${requestDateTime.toString()} conflicts with blocked window ${start.toString()} to ${end.toString()}');
          }
          return true; // Conflict found
        }
      }
      
      if (kDebugMode) {
        print('✅ NO CONFLICT: Request pickup time ${requestDateTime.toString()} is available');
      }
      return false; // No conflict
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking conflict: $e');
      }
      // On error, allow the request (safer than blocking it)
      return false;
    }
  }
}

