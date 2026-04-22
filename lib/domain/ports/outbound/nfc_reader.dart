import '../../entities/nfc_card.dart';
import '../../exceptions/app_failure.dart';
import '../../shared/result.dart';

/// Puerto que abstrae la lectura de tarjetas NFC Mifare Classic.
///
/// Los adaptadores concretos (plugin `nfc_manager` sobre Android, o un
/// `MethodChannel` nativo) viven en `infrastructure/nfc/` y son responsables
/// de autenticar los sectores con las claves A/B y mapear los bloques
/// crudos a una `NfcCard` del dominio.
///
/// Implementaciones no deben lanzar excepciones — siempre deben devolver
/// `Result<NfcCard, NfcFailure>` (o `AppFailure` más genérico si es crítico).
abstract class NfcReader {
  /// Indica si el dispositivo soporta NFC y está activado.
  Future<bool> isAvailable();

  /// Inicia una sesión NFC y resuelve cuando se haya detectado y leído una
  /// tarjeta. Si el usuario cancela antes de acercar una tarjeta, el Future
  /// debe completarse con [Err] de [NfcReadFailure].
  ///
  /// El parámetro [onStatusChange] permite al adaptador reportar estados
  /// intermedios (por ejemplo, "Acerca tu tarjeta") para que la UI los
  /// muestre — el dominio sigue ignorándolos.
  Future<Result<NfcCard, NfcFailure>> scanCard({
    void Function(String status)? onStatusChange,
  });

  /// Cancela la sesión NFC en curso si la hay. Seguro llamarlo sin sesión
  /// activa.
  Future<void> stopScan();
}
