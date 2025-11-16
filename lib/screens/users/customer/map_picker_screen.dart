import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logistics_app/services/places_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoadingAddress = false;
  bool _isLoading = true;
  String? _errorMessage;
  LatLng _currentPosition = const LatLng(33.6844, 73.0479); // Default to Islamabad

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // On web, location services might not be available
      // Just set a default location and continue
      if (kIsWeb) {
        if (kDebugMode) {
          print('🌐 Running on web, using default location');
        }
        setState(() {
          _currentPosition = const LatLng(33.6844, 73.0479); // Islamabad
          _selectedLocation = _currentPosition;
          _isLoading = false;
        });
        _getAddressForLocation(_currentPosition);
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('⚠️ Location services are disabled');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print('⚠️ Location permissions are denied');
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('⚠️ Location permissions are permanently denied');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (kDebugMode) {
        print('📍 Current location: ${position.latitude}, ${position.longitude}');
      }

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _selectedLocation = _currentPosition;
        _isLoading = false;
      });

      // Get address for current location
      _getAddressForLocation(_currentPosition);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting current location: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getAddressForLocation(LatLng location) async {
    setState(() {
      _isLoadingAddress = true;
      _errorMessage = null;
    });

    try {
      final address = await PlacesService.reverseGeocode(
        location.latitude,
        location.longitude,
      );

      if (kDebugMode) {
        print('📍 Address for ${location.latitude}, ${location.longitude}: $address');
      }

      setState(() {
        _selectedAddress = address;
        _isLoadingAddress = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting address: $e');
      }
      setState(() {
        _errorMessage = 'Could not get address for this location';
        _isLoadingAddress = false;
      });
    }
  }

  void _onMapTap(LatLng location) {
    if (kDebugMode) {
      print('🗺️ Map tapped at: ${location.latitude}, ${location.longitude}');
    }
    setState(() {
      _selectedLocation = location;
    });
    _getAddressForLocation(location);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (kDebugMode) {
      print('🗺️ Map created successfully');
    }
    
    // Wait a bit before animating camera to ensure map is fully loaded
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_selectedLocation != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation!, 15.0),
        );
      }
    });
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      // Use address if available, otherwise use coordinates
      final result = _selectedAddress ?? 
          '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}';
      
      if (kDebugMode) {
        print('✅ Confirmed selection: $result');
      }
      Navigator.pop(context, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please tap on the map to select a location')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Choose Location on Map', style: TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null && _errorMessage!.contains('map')
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text(
                            'Unable to load map',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF004d4d)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                                _isLoading = true;
                              });
                              _getCurrentLocation();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : GoogleMap(
                      key: const Key('map_picker'),
                      initialCameraPosition: CameraPosition(
                        target: _currentPosition,
                        zoom: 15.0,
                      ),
                      onMapCreated: _onMapCreated,
                      onTap: _onMapTap,
                      markers: _selectedLocation != null
                          ? {
                              Marker(
                                markerId: const MarkerId('selected'),
                                position: _selectedLocation!,
                                draggable: true,
                                onDragEnd: (LatLng newPosition) {
                                  if (kDebugMode) {
                                    print('📍 Marker dragged to: ${newPosition.latitude}, ${newPosition.longitude}');
                                  }
                                  setState(() {
                                    _selectedLocation = newPosition;
                                  });
                                  _getAddressForLocation(newPosition);
                                },
                              ),
                            }
                          : {},
                      myLocationButtonEnabled: !kIsWeb, // Disable on web as it might not work
                      myLocationEnabled: !kIsWeb,
                      zoomControlsEnabled: true,
                      mapType: MapType.normal,
                    ),
          // Floating confirm button
          if (_selectedLocation != null)
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: _selectedAddress != null
                    ? _confirmSelection
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please wait for address to load, or tap Confirm anyway to use coordinates'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        // Allow confirming even without address
                        if (_selectedLocation != null) {
                          final coordsAddress = '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}';
                          Navigator.pop(context, coordsAddress);
                        }
                      },
                icon: const Icon(Icons.check),
                label: const Text('Confirm'),
                backgroundColor: Colors.blue,
              ),
            ),
          // Address card at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 8,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected Location:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF004d4d),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingAddress)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF004d4d)),
                          ),
                          SizedBox(width: 8),
                          Text('Loading address...', style: TextStyle(color: Color(0xFF004d4d))),
                        ],
                      )
                    else if (_selectedAddress != null)
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFF004d4d)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedAddress!,
                              style: const TextStyle(fontSize: 14, color: Color(0xFF004d4d)),
                            ),
                          ),
                        ],
                      )
                    else if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      )
                    else
                      const Text(
                        'Tap on the map to select a location',
                        style: TextStyle(color: Color(0xFF004d4d)),
                      ),
                    if (_selectedLocation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Coordinates: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
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

