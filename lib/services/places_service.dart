import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Conditional import: use dart:js on web, stub on other platforms
import 'js_interop_stub.dart' if (dart.library.js) 'js_interop_web.dart' as js;

class PlacePrediction {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] as Map<String, dynamic>?;
    return PlacePrediction(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
      mainText: structuredFormatting?['main_text'] as String?,
      secondaryText: structuredFormatting?['secondary_text'] as String?,
    );
  }
}

class PlaceDetails {
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? placeId;

  PlaceDetails({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.placeId,
  });
}

class PlacesService {
  // Use the same API key from your Firebase config
  static const String _apiKey = 'AIzaSyDFOW1G-RFnsMNn7OWS-adyuR9-2beZUPk';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  // New Places API (New) endpoint
  static const String _newPlacesBaseUrl = 'https://places.googleapis.com/v1';

  /// Get autocomplete predictions using Places API (New)
  static Future<List<PlacePrediction>> getAutocompletePredictions(
    String query, {
    String? sessionToken,
    double? latitude,
    double? longitude,
    int? radius,
  }) async {
    if (query.isEmpty) {
      return [];
    }

    // On web, use JavaScript API instead of REST API to avoid CORS issues
    if (kIsWeb) {
      return await _getAutocompletePredictionsWeb(query, latitude: latitude, longitude: longitude, radius: radius);
    }

    try {
      // Use Places API (New) - Autocomplete
      final url = Uri.parse('$_newPlacesBaseUrl/places:autocomplete');
      
      final requestBody = <String, dynamic>{
        'input': query,
        'locationBias': {
          'circle': {
            'center': {
              'latitude': latitude ?? 33.6844,
              'longitude': longitude ?? 73.0479,
            },
            'radius': (radius ?? 5000).toDouble(),
          },
        },
        'includedRegionCodes': ['PK'],
        'languageCode': 'en',
      };

      if (kDebugMode) {
        print('🔍 Places API (New) Autocomplete Request: $url');
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'suggestions.placePrediction.placeId,suggestions.placePrediction.text',
        },
        body: json.encode(requestBody),
      );

      if (kDebugMode) {
        print('📥 Places API (New) Response Status: ${response.statusCode}');
        if (response.statusCode != 200) {
          print('📥 Response Body: ${response.body}');
        }
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['suggestions'] != null) {
          final suggestions = (data['suggestions'] as List);
          final predictions = suggestions.map((suggestion) {
            final placePrediction = suggestion['placePrediction'] as Map<String, dynamic>?;
            if (placePrediction == null) return null;
            
            final text = placePrediction['text'] as Map<String, dynamic>?;
            final placeId = placePrediction['placeId'] as String? ?? '';
            final mainText = text?['text'] as String? ?? '';
            
            return PlacePrediction(
              placeId: placeId,
              description: mainText,
              mainText: mainText,
              secondaryText: null,
            );
          }).whereType<PlacePrediction>().toList();
          
          if (kDebugMode) {
            print('✅ Found ${predictions.length} predictions (Places API New) ✅');
          }
          return predictions;
        } else {
          if (kDebugMode) {
            print('❌ No suggestions in response');
          }
          return [];
        }
      } else {
        // Fallback to Geocoding API if new API fails
        if (kDebugMode) {
          print('⚠️ Places API (New) failed with status ${response.statusCode}');
          if (response.statusCode == 403) {
            print('💡 Note: Places API (New) may not be enabled yet. Using Geocoding API as fallback.');
            print('💡 Enable it at: https://console.developers.google.com/apis/api/places.googleapis.com/overview?project=798522688381');
          }
          print('🔄 Falling back to Geocoding API...');
        }
        return await _getAutocompletePredictionsGeocoding(query, latitude, longitude, radius);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Exception in getAutocompletePredictions: $e');
      }
      // Fallback to Geocoding API
      return await _getAutocompletePredictionsGeocoding(query, latitude, longitude, radius);
    }
  }

  /// Fallback to Geocoding API for place search
  static Future<List<PlacePrediction>> _getAutocompletePredictionsGeocoding(
    String query,
    double? latitude,
    double? longitude,
    int? radius,
  ) async {
    try {
      // Use Geocoding API to search for addresses
      String url = '$_baseUrl/geocode/json?address=${Uri.encodeComponent(query)}&key=$_apiKey';
      
      if (latitude != null && longitude != null) {
        // Add location bias using bounds
        final offset = (radius ?? 5000) / 111000.0; // Convert meters to degrees (approximate)
        final south = latitude - offset;
        final north = latitude + offset;
        final west = longitude - offset;
        final east = longitude + offset;
        url += '&bounds=$south,$west|$north,$east';
      } else {
        // Add country restriction
        url += '&components=country:pk';
      }

      if (kDebugMode) {
        print('🔍 Geocoding API Request: $url');
      }

      final response = await http.get(Uri.parse(url));
      
      if (kDebugMode) {
        print('📥 Geocoding API Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final results = (data['results'] as List);
          final predictions = results.map((result) {
            final formattedAddress = result['formatted_address'] as String? ?? '';
            final placeId = result['place_id'] as String? ?? 'geocode_${formattedAddress.hashCode}';
            
            return PlacePrediction(
              placeId: placeId,
              description: formattedAddress,
              mainText: formattedAddress,
              secondaryText: null,
            );
          }).toList();

          if (kDebugMode) {
            print('✅ Found ${predictions.length} predictions using Geocoding API');
          }
          return predictions;
        } else {
          if (kDebugMode) {
            print('❌ Geocoding API returned no results: ${data['status']}');
            print('🔄 Trying Routes API as fallback...');
          }
          // Try Routes API fallback
          return await _getAutocompletePredictionsRoutes(query, latitude, longitude, radius);
        }
      } else {
        if (kDebugMode) {
          print('❌ Geocoding API failed with status ${response.statusCode}');
          print('🔄 Trying Routes API as fallback...');
        }
        // Try Routes API fallback
        return await _getAutocompletePredictionsRoutes(query, latitude, longitude, radius);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Geocoding API fallback failed: $e');
        print('🔄 Trying Routes API as fallback...');
      }
      // Try Routes API fallback
      return await _getAutocompletePredictionsRoutes(query, latitude, longitude, radius);
    }
  }

  /// Fallback to Routes API (Note: Routes API doesn't support autocomplete, so this uses Places Text Search)
  static Future<List<PlacePrediction>> _getAutocompletePredictionsRoutes(
    String query,
    double? latitude,
    double? longitude,
    int? radius,
  ) async {
    try {
      // Routes API doesn't have autocomplete, so we use Places API Text Search instead
      // This is the most appropriate fallback for place search
      String url = '$_baseUrl/place/textsearch/json?query=${Uri.encodeComponent(query)}&key=$_apiKey';
      
      if (latitude != null && longitude != null) {
        url += '&location=$latitude,$longitude';
        if (radius != null) {
          url += '&radius=$radius';
        }
      } else {
        url += '&components=country:pk';
      }

      if (kDebugMode) {
        print('🔍 Places Text Search API Request (via Routes API fallback): $url');
      }

      final response = await http.get(Uri.parse(url));
      
      if (kDebugMode) {
        print('📥 Places Text Search API Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final results = (data['results'] as List);
          final predictions = results.map((result) {
            final formattedAddress = result['formatted_address'] as String? ?? '';
            final name = result['name'] as String? ?? '';
            final placeId = result['place_id'] as String? ?? 'textsearch_${formattedAddress.hashCode}';
            final displayText = name.isNotEmpty ? '$name, $formattedAddress' : formattedAddress;
            
            return PlacePrediction(
              placeId: placeId,
              description: displayText,
              mainText: name.isNotEmpty ? name : formattedAddress,
              secondaryText: name.isNotEmpty ? formattedAddress : null,
            );
          }).toList();

          if (kDebugMode) {
            print('✅ Found ${predictions.length} predictions using Places Text Search API');
          }
          return predictions;
        } else {
          if (kDebugMode) {
            print('❌ Places Text Search API returned no results: ${data['status']}');
            print('🔄 Falling back to legacy Places Autocomplete API...');
          }
          // Final fallback to legacy Places Autocomplete API
          return await _getAutocompletePredictionsLegacy(query, latitude, longitude, radius);
        }
      } else {
        if (kDebugMode) {
          print('❌ Places Text Search API failed with status ${response.statusCode}');
          print('🔄 Falling back to legacy Places Autocomplete API...');
        }
        // Final fallback to legacy Places Autocomplete API
        return await _getAutocompletePredictionsLegacy(query, latitude, longitude, radius);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Places Text Search API fallback failed: $e');
        print('🔄 Falling back to legacy Places Autocomplete API...');
      }
      // Final fallback to legacy Places Autocomplete API
      return await _getAutocompletePredictionsLegacy(query, latitude, longitude, radius);
    }
  }

  /// Final fallback to legacy Places Autocomplete API
  static Future<List<PlacePrediction>> _getAutocompletePredictionsLegacy(
    String query,
    double? latitude,
    double? longitude,
    int? radius,
  ) async {
    try {
      String url = '$_baseUrl/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_apiKey&components=country:pk';
      
      if (latitude != null && longitude != null) {
        url += '&location=$latitude,$longitude';
        if (radius != null) {
          url += '&radius=$radius';
        }
      }

      if (kDebugMode) {
        print('🔍 Legacy Places Autocomplete API Request: $url');
      }

      final response = await http.get(Uri.parse(url));
      
      if (kDebugMode) {
        print('📥 Legacy Places Autocomplete API Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List?)
                  ?.map((json) => PlacePrediction.fromJson(json as Map<String, dynamic>))
                  .toList() ??
              [];
          
          if (kDebugMode) {
            print('✅ Found ${predictions.length} predictions using Legacy Places Autocomplete API');
          }
          return predictions;
        } else {
          if (kDebugMode) {
            print('❌ Legacy Places Autocomplete API returned: ${data['status']}');
          }
          return [];
        }
      } else {
        if (kDebugMode) {
          print('❌ Legacy Places Autocomplete API failed with status ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Legacy Places Autocomplete API also failed: $e');
      }
      return [];
    }
  }

  /// Get place details from place ID using Places API (New)
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    // On web, handle place details differently since REST API has CORS issues
    if (kIsWeb) {
      return await _getPlaceDetailsWeb(placeId);
    }

    try {
      // Try Places API (New) first
      final url = Uri.parse('$_newPlacesBaseUrl/places/$placeId');
      
      if (kDebugMode) {
        print('🔍 Place Details Request (Places API New): $url');
      }

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'id,formattedAddress,location',
        },
      );

      if (kDebugMode) {
        print('📥 Place Details Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final location = data['location'] as Map<String, dynamic>?;
        
        if (location != null) {
          final placeDetails = PlaceDetails(
            formattedAddress: data['formattedAddress'] as String? ?? '',
            latitude: (location['latitude'] as num).toDouble(),
            longitude: (location['longitude'] as num).toDouble(),
            placeId: placeId,
          );

          if (kDebugMode) {
            print('✅ Place Details (Places API New): ${placeDetails.formattedAddress}');
            print('📍 Coordinates: ${placeDetails.latitude}, ${placeDetails.longitude}');
          }

          return placeDetails;
        } else {
          if (kDebugMode) {
            print('❌ No location data in response');
          }
          // Fallback to legacy API
          return await _getPlaceDetailsLegacy(placeId);
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Places API (New) failed with status ${response.statusCode}, trying legacy API');
          print('Response: ${response.body}');
        }
        // Fallback to legacy API
        return await _getPlaceDetailsLegacy(placeId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Exception in getPlaceDetails: $e');
      }
      // Fallback to legacy API
      return await _getPlaceDetailsLegacy(placeId);
    }
  }

  /// Fallback to legacy Place Details API
  static Future<PlaceDetails?> _getPlaceDetailsLegacy(String placeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/place/details/json?place_id=$placeId&key=$_apiKey&fields=formatted_address,geometry',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'] as Map<String, dynamic>;
          final geometry = result['geometry'] as Map<String, dynamic>;
          final location = geometry['location'] as Map<String, dynamic>;

          return PlaceDetails(
            formattedAddress: result['formatted_address'] as String,
            latitude: (location['lat'] as num).toDouble(),
            longitude: (location['lng'] as num).toDouble(),
            placeId: placeId,
          );
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Legacy place details also failed: $e');
      }
      return null;
    }
  }

  /// Geocode an address to coordinates
  static Future<Map<String, double>?> geocodeAddress(String address) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocode/json?address=${Uri.encodeComponent(address)}&key=$_apiKey',
      );

      if (kDebugMode) {
        print('🔍 Geocode Request: $url');
      }

      final response = await http.get(url);

      if (kDebugMode) {
        print('📥 Geocode Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final result = data['results'][0] as Map<String, dynamic>;
          final geometry = result['geometry'] as Map<String, dynamic>;
          final location = geometry['location'] as Map<String, dynamic>;

          final coords = {
            'lat': (location['lat'] as num).toDouble(),
            'lng': (location['lng'] as num).toDouble(),
          };

          if (kDebugMode) {
            print('✅ Geocode Coordinates: ${coords['lat']}, ${coords['lng']}');
          }

          return coords;
        } else {
          if (kDebugMode) {
            print('❌ Geocode Error: ${data['status']}');
          }
          return null;
        }
      } else {
        if (kDebugMode) {
          print('❌ HTTP Error: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Exception in geocodeAddress: $e');
      }
      return null;
    }
  }

  /// Reverse geocode coordinates to address
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    // On web, use JavaScript API instead of REST API to avoid CORS issues
    if (kIsWeb) {
      return await _reverseGeocodeWeb(latitude, longitude);
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/geocode/json?latlng=$latitude,$longitude&key=$_apiKey',
      );

      if (kDebugMode) {
        print('🔍 Reverse Geocode Request: $url');
      }

      final response = await http.get(url);

      if (kDebugMode) {
        print('📥 Reverse Geocode Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final result = data['results'][0] as Map<String, dynamic>;
          final address = result['formatted_address'] as String;

          if (kDebugMode) {
            print('✅ Reverse Geocode Address: $address');
          }

          return address;
        } else {
          if (kDebugMode) {
            print('❌ Reverse Geocode Error: ${data['status']}');
          }
          return null;
        }
      } else {
        if (kDebugMode) {
          print('❌ HTTP Error: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Exception in reverseGeocode: $e');
      }
      return null;
    }
  }

  // Web-specific implementation for place details using JavaScript API
  static Future<PlaceDetails?> _getPlaceDetailsWeb(String placeId) async {
    if (kDebugMode) {
      print('🌐 Using Google Places JavaScript API for place details');
    }

    // On web, if placeId starts with 'search_', it's a fallback prediction
    // We'll need to geocode the description instead
    if (placeId.startsWith('search_')) {
      if (kDebugMode) {
        print('⚠️ Fallback place ID detected, cannot get details');
      }
      return null;
    }

    try {
      // Wait for Google Maps API to be loaded
      if (!_isGoogleMapsLoaded()) {
        await _waitForGoogleMaps();
      }

      // Get the PlacesService from Google Maps
      final placesService = js.context['google']?['maps']?['places']?['PlacesService'];
      
      if (placesService == null) {
        if (kDebugMode) {
          print('❌ Google Places PlacesService not available');
        }
        return null;
      }

      // Create a completer to handle the async callback
      final completer = Completer<PlaceDetails?>();
      
      // Create a dummy map element (required by PlacesService)
      final mapDiv = js.context['document'].callMethod('createElement', ['div']);
      final mapOptions = js.JsObject.jsify({
        'center': {'lat': 0, 'lng': 0},
        'zoom': 1,
      });
      final map = js.JsObject(js.context['google']['maps']['Map'], [mapDiv, mapOptions]);
      
      // Create the service instance
      final service = js.JsObject(placesService, [map]);
      
      // Create request object
      final request = js.JsObject.jsify({
        'placeId': placeId,
        'fields': ['formatted_address', 'geometry'],
      });

      // Callback for getDetails
      // The callback receives (place, status) where place is a PlaceResult object
      final callback = (dynamic placeData, dynamic statusData) {
        try {
          final status = statusData?.toString();
          
          if (status == 'OK' && placeData != null) {
            js.JsObject? place;
            if (placeData is js.JsObject) {
              place = placeData;
            } else if (placeData is Map) {
              place = js.JsObject.jsify(placeData);
            }
            
            if (place != null) {
              final geometry = place['geometry'];
              if (geometry != null) {
                js.JsObject? geometryObj;
                if (geometry is js.JsObject) {
                  geometryObj = geometry;
                } else if (geometry is Map) {
                  geometryObj = js.JsObject.jsify(geometry);
                }
                
                if (geometryObj != null) {
                  final location = geometryObj['location'];
                  if (location != null) {
                    double? lat;
                    double? lng;
                    
                    if (location is js.JsObject) {
                      // Google Maps LatLng object has lat() and lng() methods
                      try {
                        lat = (location.callMethod('lat', []) as num?)?.toDouble();
                        lng = (location.callMethod('lng', []) as num?)?.toDouble();
                      } catch (e) {
                        // Try accessing as properties
                        lat = (location['lat'] as num?)?.toDouble();
                        lng = (location['lng'] as num?)?.toDouble();
                      }
                    } else if (location is Map) {
                      lat = (location['lat'] as num?)?.toDouble();
                      lng = (location['lng'] as num?)?.toDouble();
                    }
                    
                    if (lat != null && lng != null) {
                      final formattedAddress = place['formatted_address']?.toString() ?? '';
                      
                      final details = PlaceDetails(
                        formattedAddress: formattedAddress,
                        latitude: lat,
                        longitude: lng,
                        placeId: placeId,
                      );
                      
                      if (kDebugMode) {
                        print('✅ Place details retrieved via JavaScript API');
                      }
                      completer.complete(details);
                      return;
                    }
                  }
                }
              }
            }
          }
          
          if (kDebugMode) {
            print('⚠️ Place details status: $status');
          }
          completer.complete(null);
        } catch (e, stackTrace) {
          if (kDebugMode) {
            print('❌ Error processing place details: $e');
            print('Stack trace: $stackTrace');
          }
          completer.complete(null);
        }
      };

      // Wrap callback in JsFunction
      final jsCallback = js.allowInterop(callback);
      
      // Call getDetails
      service.callMethod('getDetails', [request, jsCallback]);

      // Wait for results with timeout
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) {
            print('⏱️ Place details request timed out');
          }
          return null;
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Web place details error: $e');
      }
      return null;
    }
  }

  // Web-specific implementations - use Google Places JavaScript API via interop
  static Future<List<PlacePrediction>> _getAutocompletePredictionsWeb(
    String query, {
    double? latitude,
    double? longitude,
    int? radius,
  }) async {
    if (kDebugMode) {
      print('🌐 Using Google Places JavaScript API for autocomplete');
    }

    try {
      // Wait for Google Maps API to be loaded
      if (!_isGoogleMapsLoaded()) {
        await _waitForGoogleMaps();
      }

      // Get the autocomplete service from Google Maps
      final autocompleteService = js.context['google']?['maps']?['places']?['AutocompleteService'];
      
      if (autocompleteService == null) {
        if (kDebugMode) {
          print('❌ Google Places AutocompleteService not available');
        }
        return [];
      }

      // Create request object
      final request = js.JsObject.jsify({
        'input': query,
        'componentRestrictions': {'country': 'pk'},
      });

      // Add location bias if available
      if (latitude != null && longitude != null) {
        request['location'] = js.JsObject.jsify({
          'lat': latitude,
          'lng': longitude,
        });
        if (radius != null) {
          request['radius'] = radius;
        }
      }

      // Create a completer to handle the async callback
      final completer = Completer<List<PlacePrediction>>();
      
      // Create the service instance
      final service = js.JsObject(autocompleteService, []);
      
      // Callback for getPlacePredictions
      // The callback receives (predictions, status) where predictions is an array
      final callback = (dynamic predictionsData, dynamic statusData) {
        try {
          final status = statusData?.toString();
          
          if (status == 'OK' && predictionsData != null) {
            // Convert JavaScript array to Dart list
            List<dynamic> predictionsList = [];
            if (predictionsData is js.JsArray) {
              predictionsList = predictionsData.toList();
            } else if (predictionsData is List) {
              predictionsList = predictionsData;
            } else if (predictionsData is js.JsObject) {
              // Sometimes it might be wrapped in an object
              final arr = predictionsData['predictions'];
              if (arr != null) {
                if (arr is js.JsArray) {
                  predictionsList = arr.toList();
                } else if (arr is List) {
                  predictionsList = arr;
                }
              }
            }
            
            if (predictionsList.isNotEmpty) {
              final results = predictionsList.map((pred) {
                try {
                  js.JsObject? predObj;
                  if (pred is js.JsObject) {
                    predObj = pred;
                  } else if (pred is Map) {
                    // Convert Map to JsObject if needed
                    predObj = js.JsObject.jsify(pred);
                  }
                  
                  if (predObj != null) {
                    final structuredFormatting = predObj['structured_formatting'];
                    String? mainText;
                    String? secondaryText;
                    
                    if (structuredFormatting is js.JsObject) {
                      mainText = structuredFormatting['main_text']?.toString();
                      secondaryText = structuredFormatting['secondary_text']?.toString();
                    } else if (structuredFormatting is Map) {
                      mainText = structuredFormatting['main_text']?.toString();
                      secondaryText = structuredFormatting['secondary_text']?.toString();
                    }
                    
                    return PlacePrediction(
                      placeId: predObj['place_id']?.toString() ?? 'web_${query.hashCode}',
                      description: predObj['description']?.toString() ?? query,
                      mainText: mainText ?? predObj['description']?.toString() ?? query,
                      secondaryText: secondaryText,
                    );
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('⚠️ Error parsing prediction: $e');
                  }
                }
                return null;
              }).whereType<PlacePrediction>().toList();
              
              if (kDebugMode) {
                print('✅ Found ${results.length} predictions via JavaScript API');
              }
              completer.complete(results);
              return;
            }
          }
          
          if (kDebugMode) {
            print('⚠️ Autocomplete status: $status');
          }
          completer.complete([]);
        } catch (e, stackTrace) {
          if (kDebugMode) {
            print('❌ Error processing autocomplete results: $e');
            print('Stack trace: $stackTrace');
          }
          completer.complete([]);
        }
      };

      // Wrap callback in JsFunction
      final jsCallback = js.allowInterop(callback);
      
      // Call the autocomplete method
      // Google Places AutocompleteService uses getPlacePredictions
      try {
        service.callMethod('getPlacePredictions', [request, jsCallback]);
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error calling autocomplete service: $e');
          print('💡 Trying alternative method...');
        }
        // Try alternative method name (some API versions use different names)
        try {
          service.callMethod('getQueryPredictions', [request, jsCallback]);
        } catch (e2) {
          if (kDebugMode) {
            print('❌ Alternative method also failed: $e2');
          }
          completer.complete([]);
        }
      }

      // Wait for results with timeout
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) {
            print('⏱️ Autocomplete request timed out');
          }
          return <PlacePrediction>[];
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Web autocomplete error: $e');
      }
      return [];
    }
  }

  // Helper to check if Google Maps is loaded (web only)
  static bool _isGoogleMapsLoaded() {
    if (!kIsWeb) return false;
    try {
      final google = js.context['google'];
      return google != null && 
             google['maps'] != null && 
             google['maps']['places'] != null &&
             google['maps']['places']['AutocompleteService'] != null;
    } catch (e) {
      return false;
    }
  }

  // Wait for Google Maps API to load (web only)
  static Future<void> _waitForGoogleMaps() async {
    if (!kIsWeb) return;
    int attempts = 0;
    const maxAttempts = 50; // 5 seconds max wait
    
    while (!_isGoogleMapsLoaded() && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    if (!_isGoogleMapsLoaded() && kDebugMode) {
      print('⚠️ Google Maps API not loaded after waiting');
    }
  }

  static Future<String?> _reverseGeocodeWeb(double latitude, double longitude) async {
    if (kDebugMode) {
      print('🌐 Using web implementation for reverse geocode');
    }

    try {
      // Use geocoding package which works on web without CORS issues
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Build address string
        final parts = <String>[];
        if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
        if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          parts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) parts.add(place.country!);
        
        final address = parts.join(', ');
        if (kDebugMode) {
          print('✅ Reverse Geocode Address (web): $address');
        }
        return address;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Web reverse geocode error: $e');
      }
      return null;
    }
  }

  /// Get nearby places based on location and query
  /// Uses autocomplete with location bias instead of legacy nearbysearch API
  static Future<List<PlacePrediction>> getNearbyPlaces(
    double latitude,
    double longitude, {
    String? query,
    int radius = 5000, // 5km default radius
  }) async {
    try {
      // Use autocomplete API with location bias instead of legacy nearbysearch
      // This works better and doesn't require the legacy API
      String searchQuery = query ?? 'nearby places';
      
      // Use autocomplete with location bias to get nearby places
      final url = Uri.parse(
        '$_baseUrl/place/autocomplete/json?input=${Uri.encodeComponent(searchQuery)}&location=$latitude,$longitude&radius=$radius&key=$_apiKey&components=country:pk',
      );

      if (kDebugMode) {
        print('🔍 Nearby Places Request (using autocomplete with location bias): $url');
      }

      final response = await http.get(url);

      if (kDebugMode) {
        print('📥 Nearby Places Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS') {
          final predictions = (data['predictions'] as List?)
                  ?.map((json) => PlacePrediction.fromJson(json as Map<String, dynamic>))
                  .toList() ??
              [];

          if (kDebugMode) {
            print('✅ Found ${predictions.length} nearby places');
          }
          return predictions;
        } else {
          if (kDebugMode) {
            print('❌ Nearby Places Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
          }
          return [];
        }
      } else {
        if (kDebugMode) {
          print('❌ HTTP Error: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Exception in getNearbyPlaces: $e');
      }
      return [];
    }
  }

  /// Get directions between two points using Routes API (New) or Directions API
  static Future<Map<String, dynamic>?> getDirections(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    try {
      // Try Routes API (New) first
      final routesUrl = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
      
      final requestBody = {
        'origin': {
          'location': {
            'latLng': {
              'latitude': originLat,
              'longitude': originLng,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': destLat,
              'longitude': destLng,
            },
          },
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
        'computeAlternativeRoutes': false,
        'routeModifiers': {
          'avoidTolls': false,
          'avoidHighways': false,
          'avoidFerries': false,
        },
        'languageCode': 'en-US',
        'units': 'IMPERIAL',
      };

      if (kDebugMode) {
        print('🔍 Directions Request (Routes API New): $routesUrl');
      }

      final routesResponse = await http.post(
        routesUrl,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.polyline,routes.legs.startLocation,routes.legs.endLocation',
        },
        body: json.encode(requestBody),
      );

      if (routesResponse.statusCode == 200) {
        final data = json.decode(routesResponse.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = (data['routes'] as List)[0] as Map<String, dynamic>;
          final polyline = route['polyline'] as Map<String, dynamic>?;
          final durationObj = route['duration'];
          final distanceMeters = route['distanceMeters'] as int?;
          final legs = route['legs'] as List?;

          // Get polyline - check both encodedPolyline and polyline formats
          String? polylineString;
          if (polyline != null) {
            if (kDebugMode) {
              print('📍 Polyline object: $polyline');
            }
            // Try encodedPolyline first (new format)
            polylineString = polyline['encodedPolyline'] as String?;
            // If encodedPolyline is not available, try points (legacy format)
            if (polylineString == null || polylineString.isEmpty) {
              polylineString = polyline['points'] as String?;
            }
            // If still empty, check if polyline itself is a string
            if ((polylineString == null || polylineString.isEmpty) && polyline is String) {
              polylineString = polyline as String;
            }
          }
          
          if (kDebugMode) {
            print('📍 Extracted polyline string: ${polylineString != null ? (polylineString.length > 50 ? "${polylineString.substring(0, 50)}..." : polylineString) : "null"}');
          }

          if (polylineString == null || polylineString.isEmpty) {
            if (kDebugMode) {
              print('⚠️ Routes API (New) returned empty polyline, falling back to legacy API');
            }
            // Don't return, fall through to legacy API below
          } else {
            // Parse duration - Routes API returns it as a string like "3600s" or as an object
            String durationText = 'N/A';
            int durationSeconds = 0;
            
            if (durationObj != null) {
              try {
                if (durationObj is String) {
                  // Format: "3600s"
                  if (durationObj.endsWith('s')) {
                    durationSeconds = int.tryParse(durationObj.replaceAll('s', '')) ?? 0;
                  } else {
                    durationSeconds = int.tryParse(durationObj) ?? 0;
                  }
                } else if (durationObj is Map) {
                  // Could be in object format
                  durationSeconds = (durationObj['seconds'] as int?) ?? 0;
                } else if (durationObj is int) {
                  durationSeconds = durationObj;
                }
                
                // Format duration text
                if (durationSeconds > 0) {
                  final hours = durationSeconds ~/ 3600;
                  final minutes = (durationSeconds % 3600) ~/ 60;
                  if (hours > 0) {
                    durationText = '${hours}h ${minutes}m';
                  } else {
                    durationText = '${minutes}m';
                  }
                }
              } catch (e) {
                if (kDebugMode) {
                  print('⚠️ Error parsing duration: $e');
                }
              }
            }

            final result = {
              'polylinePoints': polylineString,
              'distance': {
                'text': distanceMeters != null ? '${(distanceMeters / 1000).toStringAsFixed(1)} km' : 'N/A',
                'value': distanceMeters ?? 0,
              },
              'duration': {
                'text': durationText,
                'value': durationSeconds,
              },
              'startAddress': '',
              'endAddress': '',
              'steps': <dynamic>[],
            };

            if (kDebugMode) {
              print('✅ Directions retrieved successfully (Routes API New)');
              print('📍 Polyline length: ${polylineString.length}');
              final distance = result['distance'] as Map<String, dynamic>;
              final duration = result['duration'] as Map<String, dynamic>;
              print('📍 Distance: ${distance['text']}');
              print('⏱️ Duration: ${duration['text']}');
            }

            return result;
          }
        } else {
          if (kDebugMode) {
            print('⚠️ Routes API (New) returned no routes, falling back to legacy API');
            print('Response body: ${routesResponse.body}');
          }
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Routes API (New) failed with status ${routesResponse.statusCode}');
          if (routesResponse.statusCode == 403) {
            print('💡 Note: Routes API may not be enabled yet. Using legacy Directions API as fallback.');
            print('💡 Enable it at: https://console.developers.google.com/apis/api/routes.googleapis.com/overview?project=798522688381');
          } else {
            print('Response: ${routesResponse.body}');
          }
          print('🔄 Falling back to legacy Directions API...');
        }
      }
      
      // If we reach here, Routes API (New) failed or returned empty, try legacy API

      // Fallback to legacy Directions API
      if (kDebugMode) {
        print('⚠️ Routes API (New) failed, trying legacy Directions API');
      }
      
      final url = Uri.parse(
        '$_baseUrl/directions/json?origin=$originLat,$originLng&destination=$destLat,$destLng&key=$_apiKey&mode=driving',
      );

      if (kDebugMode) {
        print('🔍 Directions Request (Legacy): $url');
      }

      final response = await http.get(url);

      if (kDebugMode) {
        print('📥 Directions Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0] as Map<String, dynamic>;
          final leg = (route['legs'] as List)[0] as Map<String, dynamic>;
          final overviewPolyline = route['overview_polyline'] as Map<String, dynamic>;
          
          final result = {
            'polylinePoints': overviewPolyline['points'] as String,
            'distance': leg['distance'] as Map<String, dynamic>,
            'duration': leg['duration'] as Map<String, dynamic>,
            'startAddress': leg['start_address'] as String,
            'endAddress': leg['end_address'] as String,
            'steps': leg['steps'] as List,
          };

          if (kDebugMode) {
            print('✅ Directions retrieved successfully');
            final distance = result['distance'] as Map<String, dynamic>;
            final duration = result['duration'] as Map<String, dynamic>;
            print('📍 Distance: ${distance['text']}');
            print('⏱️ Duration: ${duration['text']}');
          }

          return result;
        } else {
          if (kDebugMode) {
            print('❌ Directions Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
          }
          return null;
        }
      } else {
        if (kDebugMode) {
          print('❌ HTTP Error: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Exception in getDirections: $e');
      }
      return null;
    }
  }

  /// Decode polyline string to list of LatLng points
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }
}

