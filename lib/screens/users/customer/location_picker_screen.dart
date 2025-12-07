import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/services/places_service.dart';
import 'package:logistics_app/screens/users/customer/map_picker_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class LocationPickerScreen extends StatefulWidget {
  final String title;
  final String? initialValue;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initialValue,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PlacePrediction> _predictions = [];
  List<PlacePrediction> _nearbyPlaces = [];
  bool _isLoading = false;
  bool _isLoadingNearby = false;
  String? _selectedLocation;
  String? _errorMessage;
  String _lastSearchQuery = '';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _searchController.text = widget.initialValue!;
      _selectedLocation = widget.initialValue;
    }
    _getCurrentLocationAndNearbyPlaces();
  }

  Future<void> _getCurrentLocationAndNearbyPlaces() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      setState(() {
        _currentPosition = position;
      });

      // Load nearby places when user hasn't typed anything
      if (_searchController.text.trim().isEmpty) {
        _loadNearbyPlaces();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error getting current location: $e');
      }
    }
  }

  Future<void> _loadNearbyPlaces() async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoadingNearby = true;
    });

    try {
      // Use autocomplete with location bias and common search terms to get nearby places
      // This works without requiring the legacy nearbysearch API
      final commonSearches = ['restaurant', 'shop', 'market'];
      final allNearby = <PlacePrediction>[];
      
      // Try a few common search terms with location bias
      for (var searchTerm in commonSearches) {
        try {
          final nearby = await PlacesService.getAutocompletePredictions(
            searchTerm,
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            radius: 2000, // 2km radius
          );
          allNearby.addAll(nearby);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error loading nearby places for $searchTerm: $e');
          }
        }
      }

      // Remove duplicates and limit to top 5
      final uniqueNearby = <String, PlacePrediction>{};
      for (var place in allNearby) {
        if (!uniqueNearby.containsKey(place.placeId)) {
          uniqueNearby[place.placeId] = place;
        }
      }

      setState(() {
        _nearbyPlaces = uniqueNearby.values.take(5).toList(); // Show top 5 nearest places
        _isLoadingNearby = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error loading nearby places: $e');
      }
      setState(() {
        _isLoadingNearby = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    final trimmedQuery = query.trim();
    
    if (trimmedQuery.isEmpty) {
      setState(() {
        _predictions = [];
        _isLoading = false;
        _lastSearchQuery = '';
      });
      // Show nearby places when search is cleared
      if (_currentPosition != null) {
        _loadNearbyPlaces();
      }
      return;
    }

    // Don't search if it's the same query
    if (trimmedQuery == _lastSearchQuery) {
      return;
    }

    _lastSearchQuery = trimmedQuery;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _nearbyPlaces = []; // Clear nearby places when searching
    });

    try {
      // Add a small delay for better UX (debounce)
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Check if query still matches (user might have continued typing)
      if (trimmedQuery != _searchController.text.trim()) {
        return;
      }

      List<PlacePrediction> predictions = [];
      
      // Get autocomplete predictions with location bias if available
      if (_currentPosition != null) {
        // Use autocomplete with location bias for better nearby results
        final autocompletePredictions = await PlacesService.getAutocompletePredictions(
          trimmedQuery,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          radius: 5000, // 5km radius for location bias
        );
        predictions.addAll(autocompletePredictions);
      } else {
        // No location available, just use autocomplete
        final autocompletePredictions = await PlacesService.getAutocompletePredictions(trimmedQuery);
        predictions.addAll(autocompletePredictions);
      }
      
      // Remove duplicates based on placeId
      final uniquePredictions = <String, PlacePrediction>{};
      for (var prediction in predictions) {
        if (!uniquePredictions.containsKey(prediction.placeId)) {
          uniquePredictions[prediction.placeId] = prediction;
        }
      }
      
      // Only update if query still matches
      if (mounted && trimmedQuery == _searchController.text.trim()) {
        setState(() {
          _predictions = uniquePredictions.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        setState(() {
          _errorMessage = loc.errorSearchingPlaces(e.toString());
          _isLoading = false;
          _predictions = [];
        });
      }
    }
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final placeDetails = await PlacesService.getPlaceDetails(prediction.placeId);
      if (placeDetails != null) {
        setState(() {
          _selectedLocation = placeDetails.formattedAddress;
          _searchController.text = placeDetails.formattedAddress;
          _isLoading = false;
        });

        // Return the selected location
        if (mounted) {
          Navigator.pop(context, placeDetails.formattedAddress);
        }
      } else {
        // On web, place details might not be available due to CORS
        // Use the description directly as a fallback
        if (prediction.placeId.startsWith('search_')) {
          setState(() {
            _selectedLocation = prediction.description;
            _searchController.text = prediction.description;
            _isLoading = false;
          });

          // Return the description as the location
          if (mounted) {
            Navigator.pop(context, prediction.description);
          }
        } else {
          if (mounted) {
            final loc = AppLocalizations.of(context)!;
            setState(() {
              _errorMessage = loc.couldNotGetPlaceDetails;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        setState(() {
          _errorMessage = loc.errorGettingPlaceDetails(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const MapPickerScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLocation = result;
        _searchController.text = result;
      });
      Navigator.pop(context, result);
    }
  }

  void _confirmSelection() {
    final text = _searchController.text.trim();
    if (text.isNotEmpty) {
      Navigator.pop(context, text);
    } else {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.pleaseSelectOrEnterLocation)),
      );
    }
  }

  Widget _buildSearchBar() {
    final loc = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (context, value, child) {
          return TextField(
            controller: _searchController,
            onChanged: (value) {
              _searchPlaces(value);
            },
            decoration: InputDecoration(
              hintText: loc.searchForLocation,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _predictions = [];
                          _selectedLocation = null;
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapButton() {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _openMapPicker,
          icon: const Icon(Icons.map, color: Colors.white),
          label: Text(loc.chooseLocationOnMap, style: const TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(PlacePrediction prediction, {bool isNearby = false}) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          isNearby ? Icons.near_me : Icons.place,
          color: isNearby ? Colors.orange : Colors.blueAccent,
        ),
        title: Text(
          prediction.mainText ?? prediction.description,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        subtitle: prediction.secondaryText != null
            ? Text(
                prediction.secondaryText!,
                style: const TextStyle(color: Colors.black54),
              )
            : prediction.placeId.startsWith('search_')
                ? Text(
                    loc.tapToUseAddress,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.black54,
                    ),
                  )
                : null,
        onTap: () => _selectPlace(prediction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F8),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
        actions: [
          if (_selectedLocation != null || _searchController.text.trim().isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: Text(
                loc.confirm,
                style: const TextStyle(color: Color(0xFF004d4d)),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 4),
          _buildMapButton(),
          const SizedBox(height: 20),
          
          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // Loading indicator
          if (_isLoading || _isLoadingNearby)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // Content
          Expanded(
            child: _isLoading || _isLoadingNearby
                ? const SizedBox.shrink()
                : _predictions.isEmpty && _nearbyPlaces.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.trim().isEmpty
                                  ? loc.startTypingToSearch
                                  : loc.noSuggestionsFound,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF004d4d)),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Show nearby places section when search is empty
                            if (_searchController.text.trim().isEmpty && _nearbyPlaces.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _buildSectionHeader(loc.nearestPlaces, Icons.near_me),
                              const SizedBox(height: 10),
                              ..._nearbyPlaces.map((prediction) => _buildCardItem(prediction, isNearby: true)),
                              const SizedBox(height: 20),
                            ],
                            
                            // Show search results section
                            if (_predictions.isNotEmpty) ...[
                              if (_searchController.text.trim().isNotEmpty) ...[
                                _buildSectionHeader(loc.searchResults, Icons.search),
                                const SizedBox(height: 10),
                              ],
                              ..._predictions.map((prediction) => _buildCardItem(prediction)),
                            ],
                            
                            // Show empty state for search results
                            if (_searchController.text.trim().isNotEmpty && _predictions.isEmpty && !_isLoading) ...[
                              _buildSectionHeader(loc.searchResults, Icons.search),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  loc.noSuggestionsFound,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

