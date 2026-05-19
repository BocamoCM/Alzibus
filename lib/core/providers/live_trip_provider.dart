import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/live_trip_service.dart';

/// Singleton del servicio HTTP de viajes compartidos.
final liveTripServiceProvider = Provider<LiveTripService>((ref) {
  return LiveTripService();
});
