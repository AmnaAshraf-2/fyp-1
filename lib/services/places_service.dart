import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:geocoding/geocoding.dart' as geocoding;

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
  static const String _apiKey = 'AIzaSyAJMxGoUZZWjgfFtfXAADRzryzVug96vZM';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';

  /// Get autocomplete predictions for a search query
  static Future<List<PlacePrediction>> getAutocompletePredictions(
    String query, {
    String? sessionToken,
  }) async {
    if (query.isEmpty) {
      return [];
    }

    // On web, use JavaScript API instead of REST API to avoid CORS issues
    if (kIsWeb) {
      return await _getAutocompletePredictionsWeb(query);
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_apiKey&components=country:pk',
      );

      if (kDebugMode) {
        print('🔍 Places API Request: $url');
      }

      final response = await http.get(url);

      if (kDebugMode) {
        print('📥 Places API Response Status: ${response.statusCode}');
        print('📥 Places API Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS') {
          final predictions = (data['predictions'] as List?)
                  ?.map((json) => PlacePrediction.fromJson(json as Map<String, dynamic>))
                  .toList() ??
              [];
          if (kDebugMode) {
            print('✅ Found ${predictions.length} predictions');
          }
          return predictions;
        } else {
          if (kDebugMode) {
            print('❌ Places API Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
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
        print('❌ Exception in getAutocompletePredictions: $e');
      }
      return [];
    }
  }

  /// Get place details from place ID
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    // On web, handle place details differently since REST API has CORS issues
    if (kIsWeb) {
      return await _getPlaceDetailsWeb(placeId);
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/place/details/json?place_id=$placeId&key=$_apiKey&fields=formatted_address,geometry',
      );

      if (kDebugMode) {
        print('🔍 Place Details Request: $url');
      }

      final response = await http.get(url);

      if (kDebugMode) {
        print('📥 Place Details Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'] as Map<String, dynamic>;
          final geometry = result['geometry'] as Map<String, dynamic>;
          final location = geometry['location'] as Map<String, dynamic>;

          final placeDetails = PlaceDetails(
            formattedAddress: result['formatted_address'] as String,
            latitude: (location['lat'] as num).toDouble(),
            longitude: (location['lng'] as num).toDouble(),
            placeId: placeId,
          );

          if (kDebugMode) {
            print('✅ Place Details: ${placeDetails.formattedAddress}');
            print('📍 Coordinates: ${placeDetails.latitude}, ${placeDetails.longitude}');
          }

          return placeDetails;
        } else {
          if (kDebugMode) {
            print('❌ Place Details Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
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
        print('❌ Exception in getPlaceDetails: $e');
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

  // Web-specific implementation for place details
  static Future<PlaceDetails?> _getPlaceDetailsWeb(String placeId) async {
    if (kDebugMode) {
      print('🌐 Using web implementation for place details');
    }

    // On web, if placeId starts with 'search_', it's a fallback prediction
    // We'll need to geocode the description instead
    if (placeId.startsWith('search_')) {
      if (kDebugMode) {
        print('⚠️ Fallback place ID detected, cannot get details via REST API on web');
      }
      return null;
    }

    // For real place IDs, we'd need to use JavaScript interop
    // For now, return null and let the user use map picker
    if (kDebugMode) {
      print('💡 Use "Choose on Map" for better location selection on web');
    }
    return null;
  }

  // Web-specific implementations - for web, we'll use a simpler approach
  // Since REST API has CORS issues, we return the query as a suggestion
  // and encourage users to use the map picker for better results
  static Future<List<PlacePrediction>> _getAutocompletePredictionsWeb(String query) async {
    if (kDebugMode) {
      print('🌐 Using web implementation for autocomplete');
      print('⚠️ Note: Google Places REST API has CORS restrictions on web.');
      print('💡 Users can use "Choose on Map" button for better location selection.');
    }

    try {
      // On web, we can't use REST API due to CORS
      // Return the query as a suggestion so users can still proceed
      // The map picker will work fine using the geocoding package
      return [
        PlacePrediction(
          placeId: 'search_${query.hashCode}',
          description: query,
          mainText: query,
        ),
      ];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Web autocomplete error: $e');
      }
      return [];
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
}

