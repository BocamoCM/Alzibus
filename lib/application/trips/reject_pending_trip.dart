import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/local_trip_storage.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: el usuario rechaza el viaje pendiente (no cogió el bus).
///
/// Simplemente elimina el viaje pendiente del almacenamiento local.
class RejectPendingTrip {
  final LocalTripStorage _localStorage;

  const RejectPendingTrip({
    required LocalTripStorage localStorage,
  }) : _localStorage = localStorage;

  Future<Result<void, AppFailure>> call() async {
    return await _localStorage.clearPendingTrip();
  }
}
