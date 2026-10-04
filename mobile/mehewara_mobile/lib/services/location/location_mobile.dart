import 'package:geolocator/geolocator.dart';
import '../location_service.dart';

Future<CrewLocation> getPlatformLocation() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return CrewLocation.defaultDepot;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return CrewLocation.defaultDepot;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return CrewLocation.defaultDepot;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );

    return CrewLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      isLiveGps: true,
      statusMessage: 'Active Live GPS',
    );
  } catch (_) {
    return CrewLocation.defaultDepot;
  }
}
