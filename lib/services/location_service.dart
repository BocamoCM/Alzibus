import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;
  final Function(LatLng position, double? heading) onLocationUpdate;

  LocationService({required this.onLocationUpdate});

  Future<void> startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // SI EL USUARIO HA RECHAZADO EXPLÍCITAMENTE EN NUESTRO DIÁLOGO, NO PEDIR MÁS
      final prefs = await SharedPreferences.getInstance();
      final backgroundDisabled = prefs.getBool('background_location_disabled') ?? false;
      
      if (backgroundDisabled) {
        print('[LocationService] Tracking skipped: user explicitly disabled background location');
        return;
      }
      
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // Se cambia el Timer.periodic por un Stream nativo para mayor precisión (menor desplazamiento)
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1, // Emitir solo cuando se mueva 1 metro físicamente
      ),
    ).listen((Position pos) {
      // Ignorar "saltos" fantasmas si la antena reporta mala precisión (>30 metros de radio de error)
      if (pos.accuracy > 30.0) return;
      
      onLocationUpdate(LatLng(pos.latitude, pos.longitude), pos.heading);
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
  }
}
