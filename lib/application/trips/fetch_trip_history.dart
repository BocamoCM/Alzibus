import '../../domain/entities/trip_record.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/ports/outbound/session_storage.dart';
import '../../domain/ports/outbound/trip_repository.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: cargar todo el historial de viajes desde el backend.
class FetchTripHistory {
  final TripRepository _tripRepo;
  final SessionStorage _sessionStorage;
  final LoggerPort _logger;

  const FetchTripHistory({
    required TripRepository tripRepository,
    required SessionStorage sessionStorage,
    required LoggerPort logger,
  })  : _tripRepo = tripRepository,
        _sessionStorage = sessionStorage,
        _logger = logger;

  /// Devuelve la lista de viajes o un [AppFailure].
  Future<Result<List<TripRecord>, AppFailure>> call() async {
    final sessionResult = await _sessionStorage.read();
    if (sessionResult.isErr) return Err(sessionResult.unwrapErr());
    final session = sessionResult.unwrap();
    if (session == null) return const Err(SessionExpiredFailure());

    final result = await _tripRepo.fetchAll();
    if (result.isErr) {
      await _logger.captureFailure(result.unwrapErr());
    }
    return result;
  }
}
