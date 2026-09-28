import 'location/location_platform.dart';

class CrewLocation {
  final double latitude;
  final double longitude;
  final bool isLiveGps;
  final String? statusMessage;

  const CrewLocation({
    required this.latitude,
    required this.longitude,
    this.isLiveGps = false,
    this.statusMessage,
  });

  static const defaultDepot = CrewLocation(
    latitude: 6.9271,
    longitude: 79.8612,
    isLiveGps: false,
    statusMessage: 'Municipal Central Depot (Default)',
  );
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  CrewLocation? _lastKnownLocation;
  CrewLocation? get lastKnownLocation => _lastKnownLocation;

  /// Retrieve device or browser GPS location with robust fallbacks
  Future<CrewLocation> getCurrentLocation() async {
    try {
      final loc = await getPlatformLocation();
      _lastKnownLocation = loc;
      return loc;
    } catch (_) {
      return _lastKnownLocation ?? CrewLocation.defaultDepot;
    }
  }
}
