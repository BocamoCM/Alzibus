import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  Timer? _positionTimer;
  final Function(LatLng position, double? heading) onLocationUpdate;

  LocationService({required this.onLocationUpdate});

  Future<void> startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _positionTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        onLocationUpdate(LatLng(pos.latitude, pos.longitude), pos.heading);
      } catch (e) {
        // ignore
      }
    });
  }

  void stopTracking() {
    _positionTimer?.cancel();
  }
}
