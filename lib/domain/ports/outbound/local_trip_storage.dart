import '../../exceptions/app_failure.dart';
import '../../shared/result.dart';

/// Almacenamiento local temporal para el historial de viajes,
/// principalmente para gestionar el viaje pendiente (antes de ser confirmado 
/// por el backend) y el cálculo local offline.
abstract interface class LocalTripStorage {
  /// Guarda un viaje localmente como pendiente.
  Future<Result<void, AppFailure>> savePendingTrip(Map<String, dynamic> tripData);
  
  /// Recupera el viaje local si existe.
  Future<Result<Map<String, dynamic>?, AppFailure>> getPendingTrip();
  
  /// Limpia el viaje local.
  Future<Result<void, AppFailure>> clearPendingTrip();
}
