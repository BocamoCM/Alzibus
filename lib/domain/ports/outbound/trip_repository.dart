import '../../entities/trip_record.dart';
import '../../exceptions/app_failure.dart';
import '../../shared/result.dart';

/// Puerto de salida para las operaciones del historial de viajes.
///
/// Desacopla la lógica de aplicación del cliente HTTP (Dio/ApiClient).
/// Las implementaciones NUNCA lanzan — siempre devuelven `Result`.
///
/// NOTA: los métodos NO reciben `token` porque el adaptador HTTP
/// (`DioHttpAdapter`) ya inyecta el JWT vía interceptors de Dio.
abstract interface class TripRepository {
  /// Carga el historial completo desde el backend.
  Future<Result<List<TripRecord>, AppFailure>> fetchAll();

  /// Guarda un nuevo viaje (confirmado o no) en el servidor.
  Future<Result<TripRecord, AppFailure>> addTrip({
    required String line,
    required String destination,
    required String stopName,
    required int stopId,
    required DateTime timestamp,
    required bool confirmed,
    String? paymentMethod,
  });

  /// Elimina un viaje por su ID de servidor.
  Future<Result<void, AppFailure>> deleteTrip(int tripId);

  /// Vacía todo el historial en el backend.
  Future<Result<void, AppFailure>> clearAll();
}
