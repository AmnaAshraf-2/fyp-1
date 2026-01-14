import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logistics_app/services/places_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
  bool _mapLoaded = false;
  String? _errorMessage;
  LatLng _currentPosition = const LatLng(31.5204, 74.3587); // Default to Lahore

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('🗺️ MapPickerScreen initialized');
    }
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Always use Lahore, Pakistan as the default location
      // This ensures the map always opens to Lahore regardless of user's actual location
      if (kDebugMode) {
        print('🗺️ Using default location: Lahore, Pakistan (31.5204, 74.3587)');
      }
      
      setState(() {
        _currentPosition = const LatLng(31.5204, 74.3587); // Lahore, Pakistan
        _selectedLocation = _currentPosition;
        _isLoading = false;
      });
      
      // Get address for default location
      _getAddressForLocation(_currentPosition);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error setting default location: $e');
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
    
    // Set a timeout to detect if map doesn't load
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_mapLoaded) {
        if (kDebugMode) {
          print('⚠️ Map may not have loaded properly after 5 seconds');
        }
        setState(() {
          // Error message will be shown in build method using localization
        });
      }
    });
    
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
        SnackBar(content: Text(AppLocalizations.of(context)!.tapMapToSelectLocation)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.chooseLocationOnMap, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.unableToLoadMap,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Text(
                              _errorMessage ?? AppLocalizations.of(context)!.mapLoadingTimeout,
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
                            child: Text(AppLocalizations.of(context)!.retry),
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
                      onCameraMoveStarted: () {
                        if (kDebugMode) {
                          print('🗺️ Camera move started');
                        }
                      },
                      onCameraIdle: () {
                        if (kDebugMode) {
                          print('🗺️ Camera idle - Map is loaded');
                        }
                        if (mounted && !_mapLoaded) {
                          setState(() {
                            _mapLoaded = true;
                            _isLoading = false;
                          });
                        }
                      },
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
                          SnackBar(
                            content: Text(AppLocalizations.of(context)!.waitForAddressOrConfirm),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        // Allow confirming even without address
                        if (_selectedLocation != null) {
                          final coordsAddress = '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}';
                          Navigator.pop(context, coordsAddress);
                        }
                      },
                icon: const Icon(Icons.check),
                label: Text(AppLocalizations.of(context)!.confirm),
                backgroundColor: Colors.blue,
              ),
            ),
          // Address card at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Card(
              color: Colors.white,
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
                    Text(
                      '${AppLocalizations.of(context)!.selectedLocation}:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF004d4d),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingAddress)
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF004d4d)),
                          ),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.loadingAddress, style: const TextStyle(color: Color(0xFF004d4d))),
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
                        AppLocalizations.of(context)!.couldNotGetAddress,
                        style: const TextStyle(color: Colors.red),
                      )
                    else
                      Text(
                        AppLocalizations.of(context)!.tapMapToSelectLocation,
                        style: const TextStyle(color: Color(0xFF004d4d)),
                      ),
                    if (_selectedLocation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${AppLocalizations.of(context)!.coordinates}: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
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

