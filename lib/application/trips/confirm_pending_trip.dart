import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/local_trip_storage.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/ports/outbound/preferences_port.dart';
import '../../domain/ports/outbound/session_storage.dart';
import '../../domain/ports/outbound/trip_repository.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: el usuario confirma que sí cogió el bus.
///
/// 1. Lee el viaje pendiente local.
/// 2. Lo guarda en el backend como confirmado.
/// 3. Si el pago fue con tarjeta NFC y hay saldo, descuenta un viaje.
/// 4. Limpia el viaje pendiente local.
class ConfirmPendingTrip {
  final TripRepository _tripRepo;
  final LocalTripStorage _localStorage;
  final SessionStorage _sessionStorage;
  final PreferencesPort _prefs;
  final LoggerPort _logger;

  const ConfirmPendingTrip({
    required TripRepository tripRepository,
    required LocalTripStorage localStorage,
    required SessionStorage sessionStorage,
    required PreferencesPort preferences,
    required LoggerPort logger,
  })  : _tripRepo = tripRepository,
        _localStorage = localStorage,
        _sessionStorage = sessionStorage,
        _prefs = preferences,
        _logger = logger;

  Future<Result<void, AppFailure>> call({
    String paymentMethod = 'card',
  }) async {
    // 1. Leer viaje pendiente
    final pendingResult = await _localStorage.getPendingTrip();
    if (pendingResult.isErr) return Err(pendingResult.unwrapErr());

    final pending = pendingResult.unwrap();
    if (pending == null) return const Err(NoPendingTripFailure());

    // 2. Verificar sesión
    final sessionResult = await _sessionStorage.read();
    if (sessionResult.isErr) return Err(sessionResult.unwrapErr());
    final session = sessionResult.unwrap();
    if (session == null) return const Err(SessionExpiredFailure());

    // 3. Guardar en backend
    final result = await _tripRepo.addTrip(
      line: pending['line'],
      destination: pending['destination'],
      stopName: pending['stopName'],
      stopId: pending['stopId'],
      timestamp: DateTime.parse(pending['timestamp']),
      confirmed: true,
      paymentMethod: paymentMethod,
    );

    if (result.isOk) {
      // 4. Auto-descuento NFC si aplica
      final isUnlimited = (await _prefs.readBool('is_unlimited')) ?? false;
      final storedTrips = (await _prefs.readInt('stored_trips')) ?? 0;
      if (!isUnlimited && storedTrips > 0 && paymentMethod == 'card') {
        await _prefs.writeInt('stored_trips', storedTrips - 1);
        _logger.log(
          LogLevel.info,
          'Auto-descuento NFC (Tarjeta): $storedTrips -> ${storedTrips - 1}',
        );
      }

      // 5. Limpiar pendiente local
      return await _localStorage.clearPendingTrip();
    }

    await _logger.captureFailure(result.unwrapErr());
    return Err(result.unwrapErr());
  }
}
