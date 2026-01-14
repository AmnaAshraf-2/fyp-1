import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:logistics_app/services/places_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class RouteMapView extends StatefulWidget {
  final String pickupLocation;
  final String destinationLocation;
  final String? loadName;

  const RouteMapView({
    super.key,
    required this.pickupLocation,
    required this.destinationLocation,
    this.loadName,
  });

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  GoogleMapController? _mapController;
  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  bool _isLoading = true;
  String? _errorMessage;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String? _pickupAddress;
  String? _destinationAddress;
  String? _routeDistance;
  String? _routeDuration;

  @override
  void initState() {
    super.initState();
    _geocodeLocations();
  }

  /// Check if a string looks like coordinates (lat,lng format)
  LatLng? _parseCoordinates(String location) {
    try {
      final parts = location.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null && 
            lat >= -90 && lat <= 90 && 
            lng >= -180 && lng <= 180) {
          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      // Not coordinates, continue with geocoding
    }
    return null;
  }

  Future<void> _geocodeLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? pickupError;
      String? destinationError;

      // Geocode pickup location
      if (widget.pickupLocation.isNotEmpty) {
        // Clean the address - remove any extra whitespace
        final cleanedPickup = widget.pickupLocation.trim();
        
        if (cleanedPickup.isEmpty) {
          pickupError = 'Pickup location is empty after trimming';
        } else {
          // Check if it's already coordinates
          final coords = _parseCoordinates(cleanedPickup);
          if (coords != null) {
            _pickupLatLng = coords;
            _pickupAddress = widget.pickupLocation;
            if (kDebugMode) {
              print('✅ Pickup location parsed as coordinates: ${_pickupLatLng!.latitude}, ${_pickupLatLng!.longitude}');
            }
          } else {
          try {
            if (kDebugMode) {
              print('🔍 Geocoding pickup: $cleanedPickup');
            }
            List<Location> pickupLocations = await locationFromAddress(cleanedPickup);
            if (pickupLocations.isNotEmpty) {
              _pickupLatLng = LatLng(
                pickupLocations.first.latitude,
                pickupLocations.first.longitude,
              );
              _pickupAddress = widget.pickupLocation;
              if (kDebugMode) {
                print('✅ Pickup location geocoded: ${_pickupLatLng!.latitude}, ${_pickupLatLng!.longitude}');
              }
            } else {
              pickupError = 'No results found for: $cleanedPickup';
            }
          } catch (e) {
            pickupError = 'Geocoding package error: ${e.toString()}';
            if (kDebugMode) {
              print('⚠️ Error geocoding pickup with geocoding package: $e');
            }
            // Try using PlacesService as fallback
            try {
              if (kDebugMode) {
                print('🔄 Trying PlacesService for pickup...');
              }
              final coords = await PlacesService.geocodeAddress(cleanedPickup);
              if (coords != null && coords['lat'] != null && coords['lng'] != null) {
                _pickupLatLng = LatLng(coords['lat']!, coords['lng']!);
                _pickupAddress = widget.pickupLocation;
                if (kDebugMode) {
                  print('✅ Pickup geocoded via PlacesService: ${_pickupLatLng!.latitude}, ${_pickupLatLng!.longitude}');
                }
                pickupError = null;
              } else {
                pickupError = 'PlacesService geocoding failed for: $cleanedPickup';
              }
            } catch (e2) {
              if (kDebugMode) {
                print('❌ PlacesService geocoding also failed: $e2');
              }
              pickupError = 'Both geocoding methods failed. Last error: ${e2.toString()}';
            }
          }
          }
        }
      } else {
        pickupError = 'Pickup location is empty';
      }

      // Geocode destination location
      if (widget.destinationLocation.isNotEmpty) {
        // Clean the address - remove any extra whitespace
        final cleanedDestination = widget.destinationLocation.trim();
        
        if (cleanedDestination.isEmpty) {
          destinationError = 'Destination location is empty after trimming';
        } else {
          // Check if it's already coordinates
          final coords = _parseCoordinates(cleanedDestination);
          if (coords != null) {
            _destinationLatLng = coords;
            _destinationAddress = widget.destinationLocation;
            if (kDebugMode) {
              print('✅ Destination location parsed as coordinates: ${_destinationLatLng!.latitude}, ${_destinationLatLng!.longitude}');
            }
          } else {
            try {
              if (kDebugMode) {
                print('🔍 Geocoding destination: $cleanedDestination');
              }
              List<Location> destLocations = await locationFromAddress(cleanedDestination);
              if (destLocations.isNotEmpty) {
                _destinationLatLng = LatLng(
                  destLocations.first.latitude,
                  destLocations.first.longitude,
                );
                _destinationAddress = widget.destinationLocation;
                if (kDebugMode) {
                  print('✅ Destination location geocoded: ${_destinationLatLng!.latitude}, ${_destinationLatLng!.longitude}');
                }
              } else {
                destinationError = 'No results found for: $cleanedDestination';
              }
            } catch (e) {
              destinationError = 'Geocoding package error: ${e.toString()}';
              if (kDebugMode) {
                print('⚠️ Error geocoding destination with geocoding package: $e');
              }
              // Try using PlacesService as fallback
              try {
                if (kDebugMode) {
                  print('🔄 Trying PlacesService for destination...');
                }
                final coords = await PlacesService.geocodeAddress(cleanedDestination);
                if (coords != null && coords['lat'] != null && coords['lng'] != null) {
                  _destinationLatLng = LatLng(coords['lat']!, coords['lng']!);
                  _destinationAddress = widget.destinationLocation;
                  if (kDebugMode) {
                    print('✅ Destination geocoded via PlacesService: ${_destinationLatLng!.latitude}, ${_destinationLatLng!.longitude}');
                  }
                  destinationError = null;
                } else {
                  destinationError = 'PlacesService geocoding failed for: $cleanedDestination';
                }
              } catch (e2) {
                if (kDebugMode) {
                  print('❌ PlacesService geocoding also failed: $e2');
                }
                destinationError = 'Both geocoding methods failed. Last error: ${e2.toString()}';
              }
            }
          }
        }
      } else {
        destinationError = 'Destination location is empty';
      }

      // Check if both locations were geocoded successfully
      if (_pickupLatLng != null && _destinationLatLng != null) {
        if (kDebugMode) {
          print('✅ Both locations geocoded successfully');
          print('📍 Pickup: ${_pickupLatLng!.latitude}, ${_pickupLatLng!.longitude}');
          print('📍 Destination: ${_destinationLatLng!.latitude}, ${_destinationLatLng!.longitude}');
        }
        _updateMarkers();
        await _drawRoute();
        _fitBounds();
        setState(() {
          _isLoading = false;
        });
      } else {
        // Build error message
        String errorMsg = 'Could not geocode locations:\n';
        if (pickupError != null) {
          errorMsg += 'Pickup: $pickupError\n';
        }
        if (destinationError != null) {
          errorMsg += 'Destination: $destinationError';
        }
        if (kDebugMode) {
          print('❌ Geocoding failed: $errorMsg');
        }
        setState(() {
          _errorMessage = errorMsg.trim();
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in _geocodeLocations: $e');
      }
      setState(() {
        _errorMessage = 'Error loading map: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _updateMarkers() {
    _markers = {};

    if (_pickupLatLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(
            title: 'Pickup Location',
            snippet: '',
          ),
        ),
      );
    }

    if (_destinationLatLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(
            title: 'Destination Location',
            snippet: '',
          ),
        ),
      );
    }
  }

  Set<Marker> _getLocalizedMarkers() {
    final t = AppLocalizations.of(context)!;
    final markers = <Marker>{};
    
    if (_pickupLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: t.pickupLocation,
            snippet: _pickupAddress ?? widget.pickupLocation,
          ),
        ),
      );
    }

    if (_destinationLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: t.destinationLocation,
            snippet: _destinationAddress ?? widget.destinationLocation,
          ),
        ),
      );
    }
    
    return markers;
  }

  Future<void> _drawRoute() async {
    if (_pickupLatLng != null && _destinationLatLng != null) {
      try {
        if (kDebugMode) {
          print('🔍 Getting directions from ${_pickupLatLng!.latitude}, ${_pickupLatLng!.longitude} to ${_destinationLatLng!.latitude}, ${_destinationLatLng!.longitude}');
        }
        
        // Get directions from Google Directions API
        final directions = await PlacesService.getDirections(
          _pickupLatLng!.latitude,
          _pickupLatLng!.longitude,
          _destinationLatLng!.latitude,
          _destinationLatLng!.longitude,
        );

        if (directions != null && directions['polylinePoints'] != null && (directions['polylinePoints'] as String).isNotEmpty) {
          // Decode polyline to get route points
          final polylineString = directions['polylinePoints'] as String;
          if (kDebugMode) {
            print('📍 Polyline received: ${polylineString.substring(0, polylineString.length > 50 ? 50 : polylineString.length)}...');
          }
          
          final routePoints = PlacesService.decodePolyline(polylineString);
          final distance = directions['distance'] as Map<String, dynamic>?;
          final duration = directions['duration'] as Map<String, dynamic>?;
          
          if (routePoints.isNotEmpty) {
            // Check if we have enough points for a proper route (at least 3 points)
            // If we only have 2 points, it's likely just start and end, which means the polyline might be invalid
            if (routePoints.length >= 3) {
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
                _routeDistance = distance?['text'] as String?;
                _routeDuration = duration?['text'] as String?;
              });

              if (kDebugMode) {
                print('✅ Route drawn with ${routePoints.length} points');
                print('📍 Distance: ${_routeDistance ?? 'N/A'}');
                print('⏱️ Duration: ${_routeDuration ?? 'N/A'}');
              }
            } else {
              if (kDebugMode) {
                print('⚠️ Decoded polyline has only ${routePoints.length} points (expected at least 3), using straight line');
              }
              _drawStraightLine();
            }
          } else {
            if (kDebugMode) {
              print('⚠️ Decoded polyline is empty, using straight line');
            }
            _drawStraightLine();
          }
        } else {
          // Fallback to straight line if directions API fails
          if (kDebugMode) {
            print('⚠️ Directions API returned null or empty polyline, using straight line');
            print('   Directions response: $directions');
          }
          _drawStraightLine();
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error drawing route: $e');
          print('   Stack trace: ${StackTrace.current}');
        }
        // Fallback to straight line
        _drawStraightLine();
      }
    }
  }

  void _drawStraightLine() {
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_pickupLatLng!, _destinationLatLng!],
          color: Colors.orange,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          geodesic: true,
        ),
      };
      _routeDistance = null;
      _routeDuration = null;
    });
  }

  void _fitBounds() {
    if (_pickupLatLng != null && _destinationLatLng != null && _mapController != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _pickupLatLng!.latitude < _destinationLatLng!.latitude
              ? _pickupLatLng!.latitude
              : _destinationLatLng!.latitude,
          _pickupLatLng!.longitude < _destinationLatLng!.longitude
              ? _pickupLatLng!.longitude
              : _destinationLatLng!.longitude,
        ),
        northeast: LatLng(
          _pickupLatLng!.latitude > _destinationLatLng!.latitude
              ? _pickupLatLng!.latitude
              : _destinationLatLng!.latitude,
          _pickupLatLng!.longitude > _destinationLatLng!.longitude
              ? _pickupLatLng!.longitude
              : _destinationLatLng!.longitude,
        ),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_pickupLatLng != null && _destinationLatLng != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _fitBounds();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.loadName != null 
              ? '${AppLocalizations.of(context)!.route}: ${widget.loadName}' 
              : AppLocalizations.of(context)!.routeMap,
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
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Color(0xFF004d4d)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            _geocodeLocations();
                          },
                          child: Text(AppLocalizations.of(context)!.retry),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      key: const Key('route_map'),
                      initialCameraPosition: CameraPosition(
                        target: _pickupLatLng ?? const LatLng(31.5204, 74.3587),
                        zoom: 12.0,
                      ),
                      markers: _getLocalizedMarkers(),
                      polylines: _polylines,
                      onMapCreated: _onMapCreated,
                      myLocationButtonEnabled: !kIsWeb, // Disable on web - requires HTTPS
                      myLocationEnabled: !kIsWeb, // Disable on web - requires HTTPS
                      zoomControlsEnabled: true,
                      mapType: MapType.normal,
                      // Web-specific options
                      mapToolbarEnabled: true,
                      compassEnabled: true,
                      rotateGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                    ),
                    // Location info card
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Card(
                        color: Colors.white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Route info (distance and duration)
                              if (_routeDistance != null && _routeDuration != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.straighten, color: Colors.blue, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            _routeDistance!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF004d4d),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, color: Colors.blue, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            _routeDuration!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF004d4d),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              if (_routeDistance != null && _routeDuration != null)
                                const SizedBox(height: 16),
                              // Pickup location
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.radio_button_checked, color: Colors.green, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!.pickup,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _pickupAddress ?? widget.pickupLocation,
                                          style: const TextStyle(fontSize: 14, color: Color(0xFF004d4d)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Arrow
                              const Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Icon(Icons.arrow_downward, color: Color(0xFF004d4d), size: 24),
                              ),
                              const SizedBox(height: 16),
                              // Destination location
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.location_on, color: Colors.red, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!.destination,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _destinationAddress ?? widget.destinationLocation,
                                          style: const TextStyle(fontSize: 14, color: Color(0xFF004d4d)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

