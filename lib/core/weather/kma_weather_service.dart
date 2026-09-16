import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'weather_forecast.dart';
import 'linux_weather_location.dart';

class KmaWeatherService {
  KmaWeatherService({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;
  final http.Client Function() _clientFactory;
  final Set<http.Client> _clients = {};
  Future<List<WeatherRegion>>? _regions;

  Future<List<WeatherRegion>> regions() => _regions ??= _loadRegions();
  Future<List<WeatherRegion>> _loadRegions() async {
    try {
      final json =
          jsonDecode(
                await rootBundle.loadString('assets/weather/kma_regions.json'),
              )
              as List;
      return json
          .map(
            (row) =>
                WeatherRegion.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
    } on Object {
      _regions = null;
      rethrow;
    }
  }

  Future<String> fetch(WeatherRegion region) async {
    final client = _clientFactory();
    _clients.add(client);
    try {
      final response = await client
          .get(
            Uri.https('www.kma.go.kr', '/wid/queryDFS.jsp', {
              'gridx': '${region.x}',
              'gridy': '${region.y}',
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 ||
          response.bodyBytes.length > 512 * 1024) {
        throw const FormatException('KMA response unavailable');
      }
      return utf8.decode(response.bodyBytes);
    } finally {
      _clients.remove(client);
      client.close();
    }
  }

  void cancel() {
    for (final client in _clients.toList()) {
      client.close();
    }
    _clients.clear();
  }
}

abstract class WeatherLocation {
  Future<({double latitude, double longitude})?> current({
    required bool requestPermission,
  });
}

class DeviceWeatherLocation implements WeatherLocation {
  @override
  Future<({double latitude, double longitude})?> current({
    required bool requestPermission,
  }) async {
    if (Platform.isLinux) {
      return linuxWeatherLocation(requestPermission: requestPermission);
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 15),
      ),
    );
    if (!position.accuracy.isFinite || position.accuracy > 30000) return null;
    return (latitude: position.latitude, longitude: position.longitude);
  }
}

WeatherRegion? nearestWeatherRegion(
  List<WeatherRegion> regions,
  double latitude,
  double longitude,
) {
  if (!latitude.isFinite || !longitude.isFinite) return null;
  WeatherRegion? nearest;
  var shortest = double.infinity;
  for (final region in regions) {
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      region.latitude,
      region.longitude,
    );
    if (distance < shortest) {
      shortest = distance;
      nearest = region;
    }
  }
  // Do not substitute a Korean forecast for a location outside the service area.
  return shortest <= 30000 ? nearest : null;
}
