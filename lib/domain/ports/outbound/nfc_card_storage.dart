import '../../entities/stored_trips_balance.dart';
import '../../exceptions/app_failure.dart';
import '../../shared/result.dart';

/// Puerto para persistir el estado local de la tarjeta NFC
/// (viajes almacenados, último UID, configuración de avisos…).
///
/// Esto desacopla al controlador NFC del hecho de que hoy se guarden en
/// `SharedPreferences`; mañana podría ser Hive, SQLite o un Value Store.
abstract class NfcCardStorage {
  /// Lee el saldo local de viajes almacenados.
  Future<Result<StoredTripsBalance, AppFailure>> readStoredTrips();

  /// Guarda el nuevo saldo local.
  Future<Result<void, AppFailure>> writeStoredTrips(StoredTripsBalance balance);

  /// Devuelve los ajustes de aviso de saldo bajo.
  Future<Result<LowBalanceSettings, AppFailure>> readLowBalanceSettings();

  /// Persiste los ajustes de aviso de saldo bajo.
  Future<Result<void, AppFailure>> writeLowBalanceSettings(
    LowBalanceSettings settings,
  );

  /// Incrementa el contador de escaneos y devuelve el valor resultante —
  /// útil para decidir cuándo mostrar un anuncio intersticial.
  Future<int> incrementScanCounter();
}
