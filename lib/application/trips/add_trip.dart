import '../../domain/entities/trip_record.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/ports/outbound/session_storage.dart';
import '../../domain/ports/outbound/trip_repository.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: registrar un viaje directamente (ya confirmado).
class AddTrip {
  final TripRepository _tripRepo;
  final SessionStorage _sessionStorage;
  final LoggerPort _logger;

  const AddTrip({
    required TripRepository tripRepository,
    required SessionStorage sessionStorage,
    required LoggerPort logger,
  })  : _tripRepo = tripRepository,
        _sessionStorage = sessionStorage,
        _logger = logger;

  Future<Result<TripRecord, AppFailure>> call({
    required String line,
    required String destination,
    required String stopName,
    required int stopId,
    bool confirmed = true,
    String paymentMethod = 'card',
  }) async {
    final sessionResult = await _sessionStorage.read();
    if (sessionResult.isErr) return Err(sessionResult.unwrapErr());
    final session = sessionResult.unwrap();
    if (session == null) return const Err(SessionExpiredFailure());

    final result = await _tripRepo.addTrip(
      line: line,
      destination: destination,
      stopName: stopName,
      stopId: stopId,
      timestamp: DateTime.now(),
      confirmed: confirmed,
      paymentMethod: paymentMethod,
    );

    if (result.isErr) {
      await _logger.captureFailure(result.unwrapErr());
    }
    return result;
  }
}
