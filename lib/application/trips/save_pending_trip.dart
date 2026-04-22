import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/local_trip_storage.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: guardar un viaje como pendiente localmente.
///
/// El viaje pendiente permanece en almacenamiento local hasta que el usuario
/// lo confirme ([ConfirmPendingTrip]) o lo rechace ([RejectPendingTrip]).
class SavePendingTrip {
  final LocalTripStorage _localStorage;

  const SavePendingTrip({
    required LocalTripStorage localStorage,
  }) : _localStorage = localStorage;

  Future<Result<void, AppFailure>> call({
    required String line,
    required String destination,
    required String stopName,
    required int stopId,
  }) async {
    final trip = {
      'line': line,
      'destination': destination,
      'stopName': stopName,
      'stopId': stopId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return await _localStorage.savePendingTrip(trip);
  }
}
