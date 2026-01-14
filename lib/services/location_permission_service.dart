import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Service for requesting and managing location permissions
class LocationPermissionService {
  static final LocationPermissionService _instance = LocationPermissionService._internal();
  factory LocationPermissionService() => _instance;
  LocationPermissionService._internal();

  /// Request location permission and enable location services
  /// Returns true if permission is granted, false otherwise
  /// If permission is already granted, returns early without showing any dialogs
  Future<bool> requestLocationPermission(BuildContext? context) async {
    try {
      // First check if permission is already granted
      LocationPermission permission = await Geolocator.checkPermission();
      
      // If permission is already granted, return early without showing any dialogs
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        if (kDebugMode) {
          print('✅ Location permission already granted');
        }
        return true;
      }

      // Permission is not granted, proceed with request flow
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('⚠️ Location services are disabled');
        }
        
        // Show dialog to enable location services
        if (context != null && context.mounted) {
          await _showEnableLocationDialog(context);
          // Check again after user might have enabled it
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            return false;
          }
        } else {
          return false;
        }
      }

      // Re-check permission status (might have changed)
      permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print('⚠️ Location permissions are denied');
          }
          if (context != null && context.mounted) {
            _showPermissionDeniedDialog(context);
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('⚠️ Location permissions are permanently denied');
        }
        if (context != null && context.mounted) {
          _showPermissionDeniedForeverDialog(context);
        }
        return false;
      }

      // Permission granted
      if (kDebugMode) {
        print('✅ Location permission granted');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error requesting location permission: $e');
      }
      return false;
    }
  }

  /// Check if location permission is granted
  Future<bool> isLocationPermissionGranted() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking location permission: $e');
      }
      return false;
    }
  }

  /// Show dialog to enable location services
  Future<void> _showEnableLocationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Location Services Disabled',
            style: TextStyle(color: Color(0xFF004d4d)),
          ),
          content: const Text(
            'Location services are disabled. Please enable them in your device settings to find nearby customers.',
            style: TextStyle(color: Color(0xFF004d4d)),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004d4d),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog when permission is denied
  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Location Permission Required',
            style: TextStyle(color: Color(0xFF004d4d)),
          ),
          content: const Text(
            'Location permission is required to find nearby customers and receive delivery requests. Please grant location permission in app settings.',
            style: TextStyle(color: Color(0xFF004d4d)),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004d4d),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog when permission is permanently denied
  void _showPermissionDeniedForeverDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Location Permission Required',
            style: TextStyle(color: Color(0xFF004d4d)),
          ),
          content: const Text(
            'Location permission is permanently denied. Please enable it in your device settings to use this feature.',
            style: TextStyle(color: Color(0xFF004d4d)),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004d4d),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Geolocator.openLocationSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004d4d),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}































