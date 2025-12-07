import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:logistics_app/services/places_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DriverLiveLocationMap extends StatefulWidget {
  final String requestId;
  final String driverId;
  final String pickupLocation;
  final String destinationLocation;
  final String loadName;

  const DriverLiveLocationMap({
    super.key,
    required this.requestId,
    required this.driverId,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.loadName,
  });

  @override
  State<DriverLiveLocationMap> createState() => _DriverLiveLocationMapState();
}

class _DriverLiveLocationMapState extends State<DriverLiveLocationMap> {
  final _db = FirebaseDatabase.instance.ref();
  GoogleMapController? _mapController;
  LatLng? _driverLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _listenToDriverLocation();
  }

  Future<void> _initializeMap() async {
    try {
      // Geocode pickup and destination locations
      _pickupLocation = await _geocodeAddress(widget.pickupLocation);
      _destinationLocation = await _geocodeAddress(widget.destinationLocation);

      // Get initial driver location
      final driverLocationSnapshot = await _db.child('driver_locations/${widget.driverId}').get();
      if (driverLocationSnapshot.exists) {
        final locationData = Map<String, dynamic>.from(driverLocationSnapshot.value as Map);
        final lat = locationData['latitude'] as double?;
        final lng = locationData['longitude'] as double?;
        if (lat != null && lng != null) {
          _driverLocation = LatLng(lat, lng);
        }
      }

      // If no driver location, use pickup location as center
      if (_driverLocation == null && _pickupLocation != null) {
        _driverLocation = _pickupLocation;
      }

      _updateMarkers();
      await _drawRoute();
      _fitBounds();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing map: $e');
      setState(() {
        _errorMessage = 'Error loading map: $e';
        _isLoading = false;
      });
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      print('Error geocoding address: $e');
      // Try using PlacesService as fallback
      try {
        final location = await PlacesService.geocodeAddress(address);
        if (location != null) {
          return LatLng(location['lat']!, location['lng']!);
        }
      } catch (e2) {
        print('Error with PlacesService: $e2');
      }
    }
    return null;
  }

  void _listenToDriverLocation() {
    // Listen for driver location updates
    _db.child('driver_locations/${widget.driverId}').onValue.listen((event) {
      if (event.snapshot.exists) {
        final locationData = Map<String, dynamic>.from(event.snapshot.value as Map);
        final lat = locationData['latitude'] as double?;
        final lng = locationData['longitude'] as double?;
        if (lat != null && lng != null) {
          setState(() {
            _driverLocation = LatLng(lat, lng);
            _updateMarkers();
            _updateCameraPosition();
          });
        }
      }
    });
  }

  void _updateMarkers() {
    _markers.clear();

    // Add pickup marker
    if (_pickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
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
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }

    // Add driver location marker
    if (_driverLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Driver Location'),
        ),
      );
    }
  }

  Set<Marker> _getLocalizedMarkers() {
    final t = AppLocalizations.of(context)!;
    final markers = <Marker>{};

    // Add pickup marker
    if (_pickupLocation != null) {
      markers.add(
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
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: t.destination),
        ),
      );
    }

    // Add driver location marker
    if (_driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: t.driverLocation),
        ),
      );
    }
    
    return markers;
  }

  void _updateCameraPosition() {
    if (_mapController != null && _driverLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_driverLocation!, 15.0),
      );
    }
  }

  Future<void> _drawRoute() async {
    if (_pickupLocation != null && _destinationLocation != null) {
      try {
        if (kDebugMode) {
          print('🔍 Drawing route from pickup to destination');
        }
        
        // Get directions from Google Directions API
        final directions = await PlacesService.getDirections(
          _pickupLocation!.latitude,
          _pickupLocation!.longitude,
          _destinationLocation!.latitude,
          _destinationLocation!.longitude,
        );

        if (directions != null && directions['polylinePoints'] != null && (directions['polylinePoints'] as String).isNotEmpty) {
          // Decode polyline to get route points
          final polylineString = directions['polylinePoints'] as String;
          if (kDebugMode) {
            print('📍 Polyline received: ${polylineString.substring(0, polylineString.length > 50 ? 50 : polylineString.length)}...');
          }
          
          final routePoints = PlacesService.decodePolyline(polylineString);
          
          if (routePoints.isNotEmpty && routePoints.length >= 3) {
            setState(() {
              _polylines = {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: routePoints,
                  color: Colors.blue,
                  width: 5,
                  patterns: [],
                  geodesic: true,
                ),
              };
            });

            if (kDebugMode) {
              print('✅ Route drawn with ${routePoints.length} points');
            }
          } else {
            if (kDebugMode) {
              print('⚠️ Decoded polyline has only ${routePoints.length} points, using straight line');
            }
            _drawStraightLine();
          }
        } else {
          // Fallback to straight line if directions API fails
          if (kDebugMode) {
            print('⚠️ Directions API returned null or empty polyline, using straight line');
          }
          _drawStraightLine();
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error drawing route: $e');
        }
        // Fallback to straight line
        _drawStraightLine();
      }
    }
  }

  void _drawStraightLine() {
    if (_pickupLocation != null && _destinationLocation != null) {
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: [_pickupLocation!, _destinationLocation!],
            color: Colors.orange,
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            geodesic: true,
          ),
        };
      });
    }
  }

  void _fitBounds() {
    if (_pickupLocation != null && _destinationLocation != null && _mapController != null) {
      // Include driver location if available, otherwise use pickup and destination
      final locations = <LatLng>[_pickupLocation!, _destinationLocation!];
      if (_driverLocation != null) {
        locations.add(_driverLocation!);
      }

      double minLat = locations.map((l) => l.latitude).reduce((a, b) => a < b ? a : b);
      double maxLat = locations.map((l) => l.latitude).reduce((a, b) => a > b ? a : b);
      double minLng = locations.map((l) => l.longitude).reduce((a, b) => a < b ? a : b);
      double maxLng = locations.map((l) => l.longitude).reduce((a, b) => a > b ? a : b);

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${AppLocalizations.of(context)!.liveTracking}: ${widget.loadName}',
          style: const TextStyle(color: Color(0xFF004d4d)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage ?? AppLocalizations.of(context)!.errorLoadingMap,
                        style: const TextStyle(color: Color(0xFF004d4d)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _driverLocation == null
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.waitingForDriverLocation,
                        style: const TextStyle(color: Color(0xFF004d4d)),
                      ),
                    )
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _driverLocation!,
                        zoom: 15.0,
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        // Fit bounds after map is created
                        if (_pickupLocation != null && _destinationLocation != null) {
                          Future.delayed(const Duration(milliseconds: 500), () {
                            _fitBounds();
                          });
                        }
                      },
                      markers: _getLocalizedMarkers(),
                      polylines: _polylines,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                      mapType: MapType.normal,
                    ),
    );
  }
}

