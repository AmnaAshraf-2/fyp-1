import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:logistics_app/services/places_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EnterpriseDriversLiveLocationMap extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> assignedResources;
  final String pickupLocation;
  final String destinationLocation;
  final String loadName;

  const EnterpriseDriversLiveLocationMap({
    super.key,
    required this.requestId,
    required this.assignedResources,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.loadName,
  });

  @override
  State<EnterpriseDriversLiveLocationMap> createState() => _EnterpriseDriversLiveLocationMapState();
}

class _EnterpriseDriversLiveLocationMapState extends State<EnterpriseDriversLiveLocationMap> {
  final _db = FirebaseDatabase.instance.ref();
  GoogleMapController? _mapController;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  Map<String, LatLng> _driverLocations = {};
  Map<String, StreamSubscription> _locationSubscriptions = {};
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Call _listenToDriverLocations here so context is ready for AppLocalizations
    if (_locationSubscriptions.isEmpty) {
      _listenToDriverLocations();
    }
  }

  @override
  void dispose() {
    // Cancel all location subscriptions
    for (final subscription in _locationSubscriptions.values) {
      subscription.cancel();
    }
    _locationSubscriptions.clear();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      // Geocode pickup and destination locations
      _pickupLocation = await _geocodeAddress(widget.pickupLocation);
      _destinationLocation = await _geocodeAddress(widget.destinationLocation);

      setState(() {
        _isLoading = false;
        _updateMarkers();
      });

      // Fit bounds after map is created
      if (_pickupLocation != null && _destinationLocation != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _fitBounds();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing map: $e');
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading map: $e';
      });
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    if (address.isEmpty) return null;

    try {
      // Try geocoding first
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error geocoding address: $e');
      }
      // Try using PlacesService as fallback
      try {
        final location = await PlacesService.geocodeAddress(address);
        if (location != null) {
          return LatLng(location['lat']!, location['lng']!);
        }
      } catch (e2) {
        if (kDebugMode) {
          print('Error with PlacesService: $e2');
        }
      }
    }
    return null;
  }

  void _listenToDriverLocations() {
    final t = AppLocalizations.of(context)!;
    
    // Listen to each assigned driver's location
    for (final entry in widget.assignedResources.entries) {
      final assignment = entry.value;
      if (assignment is Map) {
        final assignmentData = Map<String, dynamic>.from(assignment);
        final driverAuthUid = assignmentData['driverAuthUid'] as String?;
        final driverName = assignmentData['driverName'] as String? ?? t.driver;
        final status = assignmentData['status'] as String?;
        final journeyStarted = assignmentData['journeyStarted'] == true;
        
        // Only track drivers who have accepted and started their journey
        if (driverAuthUid != null && status == 'accepted' && journeyStarted) {
          // Get initial location
          _db.child('driver_locations/$driverAuthUid').once().then((snapshot) {
            if (snapshot.snapshot.exists) {
              final locationData = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
              final lat = locationData['latitude'] as double?;
              final lng = locationData['longitude'] as double?;
              if (lat != null && lng != null && mounted) {
                setState(() {
                  _driverLocations[driverAuthUid] = LatLng(lat, lng);
                  _updateMarkers();
                });
              }
            }
          });

          // Listen for location updates
          final subscription = _db.child('driver_locations/$driverAuthUid').onValue.listen((event) {
            if (event.snapshot.exists && mounted) {
              final locationData = Map<String, dynamic>.from(event.snapshot.value as Map);
              final lat = locationData['latitude'] as double?;
              final lng = locationData['longitude'] as double?;
              if (lat != null && lng != null) {
                setState(() {
                  _driverLocations[driverAuthUid] = LatLng(lat, lng);
                  _updateMarkers();
                });
              }
            }
          });
          
          _locationSubscriptions[driverAuthUid] = subscription;
        }
      }
    }
  }

  void _updateMarkers() {
    final t = AppLocalizations.of(context)!;
    _markers.clear();

    // Add pickup marker
    if (_pickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: t.pickupLocation),
        ),
      );
    }

    // Add destination marker
    if (_destinationLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: t.destination),
        ),
      );
    }

    // Add driver location markers
    for (final entry in widget.assignedResources.entries) {
      final assignment = entry.value;
      if (assignment is Map) {
        final assignmentData = Map<String, dynamic>.from(assignment);
        final driverAuthUid = assignmentData['driverAuthUid'] as String?;
        final driverName = assignmentData['driverName'] as String? ?? t.driver;
        final status = assignmentData['status'] as String?;
        final journeyStarted = assignmentData['journeyStarted'] == true;
        
        if (driverAuthUid != null && 
            status == 'accepted' && 
            journeyStarted && 
            _driverLocations.containsKey(driverAuthUid)) {
          _markers.add(
            Marker(
              markerId: MarkerId('driver_$driverAuthUid'),
              position: _driverLocations[driverAuthUid]!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: InfoWindow(title: driverName),
            ),
          );
        }
      }
    }
  }

  void _fitBounds() {
    if (_mapController == null) return;

    final List<LatLng> locations = [];
    
    if (_pickupLocation != null) {
      locations.add(_pickupLocation!);
    }
    if (_destinationLocation != null) {
      locations.add(_destinationLocation!);
    }
    locations.addAll(_driverLocations.values);

    if (locations.isEmpty) return;

    if (locations.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(locations.first, 15.0),
      );
      return;
    }

    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final location in locations) {
      minLat = minLat < location.latitude ? minLat : location.latitude;
      maxLat = maxLat > location.latitude ? maxLat : location.latitude;
      minLng = minLng < location.longitude ? minLng : location.longitude;
      maxLng = maxLng > location.longitude ? maxLng : location.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(t.driverLocation),
        backgroundColor: const Color(0xFF004D4D),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _pickupLocation == null && _destinationLocation == null && _driverLocations.isEmpty
                  ? Center(
                      child: Text(
                        t.waitingForDriverLocation,
                        style: const TextStyle(color: Color(0xFF004d4d)),
                      ),
                    )
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _pickupLocation ?? 
                                _destinationLocation ?? 
                                (_driverLocations.values.isNotEmpty ? _driverLocations.values.first : const LatLng(0, 0)),
                        zoom: 15.0,
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        // Fit bounds after map is created
                        if (_pickupLocation != null || _destinationLocation != null || _driverLocations.isNotEmpty) {
                          Future.delayed(const Duration(milliseconds: 500), () {
                            _fitBounds();
                          });
                        }
                      },
                      markers: _markers,
                      polylines: _polylines,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                      mapType: MapType.normal,
                    ),
    );
  }
}

