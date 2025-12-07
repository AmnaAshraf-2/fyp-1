import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  final _db = FirebaseDatabase.instance.ref();
  StreamSubscription<Position>? _positionStream;
  String? _currentDriverId;
  bool _isTracking = false;

  /// Start tracking driver location
  Future<bool> startTracking(String driverId) async {
    if (_isTracking && _currentDriverId == driverId) {
      if (kDebugMode) {
        print('📍 Location tracking already active for driver: $driverId');
      }
      return true;
    }

    try {
      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('⚠️ Location services are disabled');
        }
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print('⚠️ Location permissions are denied');
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('⚠️ Location permissions are permanently denied');
        }
        return false;
      }

      // Stop any existing tracking
      await stopTracking();

      _currentDriverId = driverId;
      _isTracking = true;

      // Get initial position
      Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _updateLocation(driverId, initialPosition);

      // Listen to position updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        (Position position) {
          _updateLocation(driverId, position);
        },
        onError: (error) {
          if (kDebugMode) {
            print('❌ Error in position stream: $error');
          }
        },
      );

      if (kDebugMode) {
        print('✅ Location tracking started for driver: $driverId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting location tracking: $e');
      }
      _isTracking = false;
      _currentDriverId = null;
      return false;
    }
  }

  /// Stop tracking driver location
  Future<void> stopTracking() async {
    if (_positionStream != null) {
      await _positionStream!.cancel();
      _positionStream = null;
    }

    if (_currentDriverId != null) {
      // Optionally clear location from database
      // await _db.child('driver_locations/$_currentDriverId').remove();
    }

    _isTracking = false;
    _currentDriverId = null;

    if (kDebugMode) {
      print('🛑 Location tracking stopped');
    }
  }

  /// Update driver location in Firebase
  Future<void> _updateLocation(String driverId, Position position) async {
    try {
      await _db.child('driver_locations/$driverId').set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'accuracy': position.accuracy,
        'heading': position.heading,
        'speed': position.speed,
      });

      if (kDebugMode) {
        print('📍 Updated location: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating location: $e');
      }
    }
  }

  /// Check if tracking is active
  bool get isTracking => _isTracking;

  /// Get current driver ID being tracked
  String? get currentDriverId => _currentDriverId;
}

