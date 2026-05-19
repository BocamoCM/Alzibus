import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/trip_planner_service.dart';
import 'stops_provider.dart';

/// Servicio singleton de planificación. Se crea una vez y se reutiliza —
/// internamente cachea paradas y rutas en memoria.
final tripPlannerServiceProvider = Provider<TripPlannerService>((ref) {
  final stopsService = ref.watch(stopsServiceProvider);
  return TripPlannerService(stopsService);
});
