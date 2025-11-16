import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/services/places_service.dart';
import 'package:logistics_app/screens/users/customer/map_picker_screen.dart';

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
  bool _isLoading = false;
  String? _selectedLocation;
  String? _errorMessage;
  String _lastSearchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _searchController.text = widget.initialValue!;
      _selectedLocation = widget.initialValue;
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
    });

    try {
      // Add a small delay for better UX (debounce)
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Check if query still matches (user might have continued typing)
      if (trimmedQuery != _searchController.text.trim()) {
        return;
      }

      final predictions = await PlacesService.getAutocompletePredictions(trimmedQuery);
      
      // Only update if query still matches
      if (mounted && trimmedQuery == _searchController.text.trim()) {
        setState(() {
          _predictions = predictions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error searching places: $e';
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
          setState(() {
            _errorMessage = 'Could not get place details. Please use "Choose on Map" instead.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting place details: $e';
        _isLoading = false;
      });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a location')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
        actions: [
          if (_selectedLocation != null || _searchController.text.trim().isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: const Text(
                'Confirm',
                style: TextStyle(color: Color(0xFF004d4d)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                _searchPlaces(value);
              },
            ),
          ),

          // Choose on Map button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openMapPicker,
                icon: const Icon(Icons.map),
                label: const Text('Choose on Map'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          const Divider(),

          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),

          // Predictions list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _predictions.isEmpty
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
                                  ? 'Start typing to search for locations'
                                  : 'No suggestions found. Try "Choose on Map" or type a full address.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF004d4d)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _predictions.length,
                        itemBuilder: (context, index) {
                          final prediction = _predictions[index];
                          return ListTile(
                            leading: const Icon(Icons.place),
                            title: Text(
                              prediction.mainText ?? prediction.description,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: prediction.secondaryText != null
                                ? Text(prediction.secondaryText!)
                                : prediction.placeId.startsWith('search_')
                                    ? const Text(
                                        'Tap to use this address',
                                        style: TextStyle(fontStyle: FontStyle.italic),
                                      )
                                    : null,
                            onTap: () => _selectPlace(prediction),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

