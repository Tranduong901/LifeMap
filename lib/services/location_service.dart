import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;

class LocationService {
  // Mobile: use geocoding plugin
  static Future<String> _reverseGeocodeMobile(double lat, double lng) async {
    try {
      final List<geocoding.Placemark> places = await geocoding
          .placemarkFromCoordinates(lat, lng);
      if (places.isEmpty) {
        return 'Không xác định';
      }
      final geocoding.Placemark p = places.first;
      final parts = <String?>[
        p.street,
        p.subLocality ?? p.locality,
        p.administrativeArea,
        p.country,
      ];
      return parts.where((s) => s != null && s.trim().isNotEmpty).join(', ');
    } catch (e) {
      return 'Lỗi: $e';
    }
  }

  // Web: use Nominatim (OpenStreetMap) by HTTP
  static Future<String> _reverseGeocodeWeb(double lat, double lng) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&accept-language=vi',
    );
    final resp = await http.get(uri, headers: {'User-Agent': 'LifeMap/1.0'});
    if (resp.statusCode != 200) {
      return 'Không xác định (HTTP ${resp.statusCode})';
    }
    final Map<String, dynamic> data =
        jsonDecode(resp.body) as Map<String, dynamic>;
    if (data.containsKey('display_name')) return data['display_name'] as String;
    return 'Không xác định';
  }

  // Public unified method
  static Future<String> getAddressFromLatLng(double lat, double lng) {
    if (kIsWeb) return _reverseGeocodeWeb(lat, lng);
    return _reverseGeocodeMobile(lat, lng);
  }

  static Future<Map<String, double>?> _forwardGeocodeMobile(
    String address,
  ) async {
    try {
      final List<geocoding.Location> locations = await geocoding
          .locationFromAddress(address);
      if (locations.isEmpty) {
        return null;
      }
      final geocoding.Location first = locations.first;
      return <String, double>{'lat': first.latitude, 'lng': first.longitude};
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, double>?> _forwardGeocodeWeb(String address) async {
    final String q = Uri.encodeQueryComponent(address);
    final Uri uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&accept-language=vi&q=$q',
    );

    final http.Response resp = await http.get(
      uri,
      headers: {'User-Agent': 'LifeMap/1.0'},
    );

    if (resp.statusCode != 200) {
      return null;
    }

    final dynamic decoded = jsonDecode(resp.body);
    if (decoded is! List || decoded.isEmpty) {
      return null;
    }

    final dynamic first = decoded.first;
    if (first is! Map<String, dynamic>) {
      return null;
    }

    final double? lat = double.tryParse('${first['lat'] ?? ''}');
    final double? lng = double.tryParse('${first['lon'] ?? ''}');
    if (lat == null || lng == null) {
      return null;
    }

    return <String, double>{'lat': lat, 'lng': lng};
  }

  static Future<Map<String, double>?> getLatLngFromAddress(String address) {
    final String normalized = address.trim();
    if (normalized.isEmpty) {
      return Future<Map<String, double>?>.value(null);
    }
    if (kIsWeb) return _forwardGeocodeWeb(normalized);
    return _forwardGeocodeMobile(normalized);
  }
}
