import '../../exceptions/app_failure.dart';
import '../../shared/result.dart';

/// Información de la próxima llegada a una parada — pensada para alimentar
/// el widget. No incluye la lista completa de horarios porque el widget sólo
/// muestra el primer candidato.
class StopNextArrival {
  final String line;
  final String destination;
  final String displayTime;

  const StopNextArrival({
    required this.line,
    required this.destination,
    required this.displayTime,
  });
}

/// Puerto de salida para consultar la próxima llegada en una parada. La
/// implementación actual scrappa la web de Autocares Lozano; mañana podría
/// apuntar a un endpoint propio.
abstract interface class StopArrivalFetcher {
  Future<Result<StopNextArrival?, AppFailure>> fetchNextArrival(int stopId);
}
