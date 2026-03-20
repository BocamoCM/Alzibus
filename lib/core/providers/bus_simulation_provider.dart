import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/bus_simulation_service.dart';

final busSimulationProvider = Provider<BusSimulationService>((ref) {
  final service = BusSimulationService();
  ref.onDispose(() {
    service.stopSimulation();
  });
  return service;
});

final busesStreamProvider = StreamProvider<Map<String, SimulatedBus>>((ref) {
  final service = ref.watch(busSimulationProvider);
  return service.busStream;
});
