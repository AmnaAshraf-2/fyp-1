import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LocationMapView extends StatefulWidget {
  final String address;
  final String title;

  const LocationMapView({
    super.key,
    required this.address,
    required this.title,
  });

  @override
  State<LocationMapView> createState() => _LocationMapViewState();
}

class _LocationMapViewState extends State<LocationMapView> {
  GoogleMapController? _mapController;
  LatLng? _location;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _geocodeAddress();
  }

  Future<void> _geocodeAddress() async {
    if (widget.address.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(widget.address);
      if (locations.isNotEmpty) {
        setState(() {
          _location = LatLng(locations.first.latitude, locations.first.longitude);
          _isLoading = false;
        });
        // Move camera to the location
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_location!, 15.0),
        );
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null || widget.address.isEmpty
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
                          widget.address.isEmpty
                              ? AppLocalizations.of(context)!.noAddressProvided
                              : _errorMessage ?? AppLocalizations.of(context)!.locationNotFound,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Color(0xFF004d4d)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(AppLocalizations.of(context)!.goBack),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _location ?? const LatLng(33.6844, 73.0479), // Default to Islamabad
                        zoom: 15.0,
                      ),
                      markers: _location != null
                          ? {
                              Marker(
                                markerId: const MarkerId('location'),
                                position: _location!,
                                infoWindow: InfoWindow(
                                  title: widget.title,
                                  snippet: widget.address,
                                ),
                              ),
                            }
                          : {},
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        if (_location != null) {
                          controller.animateCamera(
                            CameraUpdate.newLatLngZoom(_location!, 15.0),
                          );
                        }
                      },
                      myLocationButtonEnabled: true,
                      myLocationEnabled: true,
                      zoomControlsEnabled: true,
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Card(
                        color: Colors.white,
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF004d4d),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.address,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF004d4d)),
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

