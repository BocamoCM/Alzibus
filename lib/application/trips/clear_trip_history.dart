import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/local_trip_storage.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/ports/outbound/session_storage.dart';
import '../../domain/ports/outbound/trip_repository.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: vaciar todo el historial de viajes.
///
/// Borra tanto el historial del backend como el viaje pendiente local.
class ClearTripHistory {
  final TripRepository _tripRepo;
  final LocalTripStorage _localStorage;
  final SessionStorage _sessionStorage;
  final LoggerPort _logger;

  const ClearTripHistory({
    required TripRepository tripRepository,
    required LocalTripStorage localStorage,
    required SessionStorage sessionStorage,
    required LoggerPort logger,
  })  : _tripRepo = tripRepository,
        _localStorage = localStorage,
        _sessionStorage = sessionStorage,
        _logger = logger;

  Future<Result<void, AppFailure>> call() async {
    final sessionResult = await _sessionStorage.read();
    if (sessionResult.isErr) return Err(sessionResult.unwrapErr());
    final session = sessionResult.unwrap();
    if (session == null) return const Err(SessionExpiredFailure());

    final result = await _tripRepo.clearAll();

    // Limpiar viaje pendiente local independientemente del resultado del backend
    await _localStorage.clearPendingTrip();

    if (result.isErr) {
      await _logger.captureFailure(result.unwrapErr());
    }
    return result;
  }
}
