import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/stops_service.dart';
import '../../models/bus_stop.dart';

// Proveedor base para acceder al servicio
final stopsServiceProvider = Provider<StopsService>((ref) {
  return StopsService();
});

// Proveedor asíncrono para cargar y cachear la lista completa de paradas
final stopsProvider = FutureProvider<List<BusStop>>((ref) async {
  final service = ref.watch(stopsServiceProvider);
  return await service.loadStops();
});

// Proveedor asíncrono con parámetros (family) para cargar y cachear la ruta de una línea específica
final lineRouteProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, lineId) async {
  final service = ref.watch(stopsServiceProvider);
  return await service.loadLineRoute(lineId);
});
