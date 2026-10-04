import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../location_service.dart';

Future<CrewLocation> getPlatformLocation() async {
  final completer = Completer<CrewLocation>();

  try {
    web.window.navigator.geolocation.getCurrentPosition(
      (web.GeolocationPosition pos) {
        final lat = pos.coords.latitude;
        final lon = pos.coords.longitude;
        if (!completer.isCompleted) {
          completer.complete(
            CrewLocation(
              latitude: lat.toDouble(),
              longitude: lon.toDouble(),
              isLiveGps: true,
              statusMessage: 'Active Browser GPS',
            ),
          );
        }
      }.toJS,
      (web.GeolocationPositionError err) {
        if (!completer.isCompleted) {
          completer.complete(CrewLocation.defaultDepot);
        }
      }.toJS,
      web.PositionOptions(
        enableHighAccuracy: true,
        timeout: 6000,
        maximumAge: 60000,
      ),
    );
  } catch (_) {
    return CrewLocation.defaultDepot;
  }

  return completer.future.timeout(
    const Duration(seconds: 7),
    onTimeout: () => CrewLocation.defaultDepot,
  );
}
