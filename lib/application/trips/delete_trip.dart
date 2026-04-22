import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/ports/outbound/session_storage.dart';
import '../../domain/ports/outbound/trip_repository.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: eliminar un viaje concreto por su ID de servidor.
class DeleteTrip {
  final TripRepository _tripRepo;
  final SessionStorage _sessionStorage;
  final LoggerPort _logger;

  const DeleteTrip({
    required TripRepository tripRepository,
    required SessionStorage sessionStorage,
    required LoggerPort logger,
  })  : _tripRepo = tripRepository,
        _sessionStorage = sessionStorage,
        _logger = logger;

  /// [tripId] es el ID del viaje en la base de datos del servidor.
  Future<Result<void, AppFailure>> call(int tripId) async {
    final sessionResult = await _sessionStorage.read();
    if (sessionResult.isErr) return Err(sessionResult.unwrapErr());
    final session = sessionResult.unwrap();
    if (session == null) return const Err(SessionExpiredFailure());

    final result = await _tripRepo.deleteTrip(tripId);
    if (result.isErr) {
      await _logger.captureFailure(result.unwrapErr());
    }
    return result;
  }
}
