/// Jerarquía sellada de fallos de dominio.
///
/// El dominio NUNCA lanza excepciones a través de los casos de uso. En lugar
/// de eso devuelve `Result<T, AppFailure>`. Esto fuerza al consumidor (UI o
/// servicio) a manejar todos los casos de forma exhaustiva mediante el
/// `switch` sobre tipos sellados de Dart 3.
///
/// Cada `AppFailure` tiene:
/// - `code`: identificador estable para localización (`auth.invalid_credentials`).
/// - `userMessage`: mensaje opcional ya pensado para mostrar al usuario.
/// - `cause`: objeto opcional con la excepción/origen real para diagnóstico.
///
/// La capa de infraestructura (adaptadores) sí puede capturar excepciones de
/// las librerías concretas (Dio, plugin NFC, SharedPreferences) y mapearlas
/// a una subclase concreta de `AppFailure`.
sealed class AppFailure {
  /// Código estable para i18n y métricas. Formato: `dominio.detalle`.
  final String code;

  /// Mensaje opcional listo para usuario (no localizado por defecto).
  final String? userMessage;

  /// Causa original (excepción capturada) — solo para logging.
  final Object? cause;

  /// Stack trace asociada al `cause`, si existe.
  final StackTrace? stackTrace;

  const AppFailure({
    required this.code,
    this.userMessage,
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() => '$runtimeType($code)';
}

// ───────────────────────── Network ─────────────────────────

/// Fallo relacionado con la red o el servidor HTTP.
sealed class NetworkFailure extends AppFailure {
  const NetworkFailure({
    required super.code,
    super.userMessage,
    super.cause,
    super.stackTrace,
  });
}

final class OfflineFailure extends NetworkFailure {
  const OfflineFailure({super.cause, super.stackTrace})
      : super(code: 'network.offline');
}

final class TimeoutFailure extends NetworkFailure {
  const TimeoutFailure({super.cause, super.stackTrace})
      : super(code: 'network.timeout');
}

final class ServerFailure extends NetworkFailure {
  /// Status HTTP 5xx (o desconocido).
  final int? statusCode;
  final String? body;
  const ServerFailure({this.statusCode, this.body, super.cause, super.stackTrace})
      : super(code: 'network.server');
}

final class UnexpectedResponseFailure extends NetworkFailure {
  /// Respuesta con formato inválido o campos esperados ausentes.
  const UnexpectedResponseFailure({super.cause, super.stackTrace})
      : super(code: 'network.unexpected_response');
}

// ───────────────────────── Auth ─────────────────────────

/// Fallos del dominio de autenticación.
sealed class AuthFailure extends AppFailure {
  const AuthFailure({
    required super.code,
    super.userMessage,
    super.cause,
    super.stackTrace,
  });
}

final class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure()
      : super(code: 'auth.invalid_credentials');
}

/// El servidor exige verificar OTP antes de completar el login.
final class OtpRequiredFailure extends AuthFailure {
  final String email;
  const OtpRequiredFailure(this.email) : super(code: 'auth.otp_required');
}

/// El código OTP introducido no es válido o ha expirado.
final class InvalidOtpFailure extends AuthFailure {
  const InvalidOtpFailure() : super(code: 'auth.invalid_otp');
}

/// La cuenta existe pero aún no se ha verificado el correo.
final class EmailNotVerifiedFailure extends AuthFailure {
  const EmailNotVerifiedFailure() : super(code: 'auth.email_not_verified');
}

/// La biometría no está disponible o el usuario la canceló.
final class BiometricUnavailableFailure extends AuthFailure {
  const BiometricUnavailableFailure({super.cause, super.stackTrace})
      : super(code: 'auth.biometric_unavailable');
}

/// Fallo derivado de problemas de red en la capa de Auth.
final class NetworkAuthFailure extends AuthFailure {
  const NetworkAuthFailure(AppFailure inner)
      : super(
          code: 'auth.network_error',
          cause: inner,
        );
}

/// La sesión ha expirado o el JWT es inválido.
final class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure() : super(code: 'auth.session_expired');
}

/// Error registrando un nuevo usuario (ej: email ya en uso).
final class RegistrationFailure extends AuthFailure {
  final String? serverMessage;
  const RegistrationFailure({this.serverMessage})
      : super(code: 'auth.registration_failed');
}

// ───────────────────────── Validation ─────────────────────────

/// Datos de entrada inválidos detectados antes de llegar al backend.
final class ValidationFailure extends AppFailure {
  /// Mapa campo → razón. Útil para pintar errores en formularios.
  final Map<String, String> fieldErrors;
  const ValidationFailure({this.fieldErrors = const {}})
      : super(code: 'validation.invalid_input');
}

// ───────────────────────── Storage ─────────────────────────

sealed class StorageFailure extends AppFailure {
  const StorageFailure({
    required super.code,
    super.cause,
    super.stackTrace,
  });
}

final class StorageReadFailure extends StorageFailure {
  const StorageReadFailure({super.cause, super.stackTrace})
      : super(code: 'storage.read_failed');
}

final class StorageWriteFailure extends StorageFailure {
  const StorageWriteFailure({super.cause, super.stackTrace})
      : super(code: 'storage.write_failed');
}

// ───────────────────────── NFC ─────────────────────────

sealed class NfcFailure extends AppFailure {
  const NfcFailure({
    required super.code,
    super.cause,
    super.stackTrace,
  });
}

final class NfcNotSupportedFailure extends NfcFailure {
  const NfcNotSupportedFailure() : super(code: 'nfc.not_supported');
}

final class NfcReadFailure extends NfcFailure {
  const NfcReadFailure({super.cause, super.stackTrace})
      : super(code: 'nfc.read_failed');
}

final class NfcChecksumMismatchFailure extends NfcFailure {
  const NfcChecksumMismatchFailure() : super(code: 'nfc.checksum_mismatch');
}

// ───────────────────────── Trip ─────────────────────────

/// Fallos del dominio de viajes/historial.
sealed class TripFailure extends AppFailure {
  const TripFailure({
    required super.code,
    super.userMessage,
    super.cause,
    super.stackTrace,
  });
}

/// El viaje solicitado no existe en el backend (404).
final class TripNotFoundFailure extends TripFailure {
  const TripNotFoundFailure() : super(code: 'trip.not_found');
}

/// Se intentó confirmar/rechazar un viaje pendiente que no existe localmente.
final class NoPendingTripFailure extends TripFailure {
  const NoPendingTripFailure() : super(code: 'trip.no_pending');
}

/// Error genérico al guardar un viaje en el backend.
final class TripSaveFailure extends TripFailure {
  const TripSaveFailure({super.cause, super.stackTrace})
      : super(code: 'trip.save_failed');
}

// ───────────────────────── Favorites ─────────────────────────

/// Fallos del dominio de paradas favoritas.
sealed class FavoritesFailure extends AppFailure {
  const FavoritesFailure({
    required super.code,
    super.userMessage,
    super.cause,
    super.stackTrace,
  });
}

/// La parada que se intentaba añadir ya estaba en favoritos.
final class FavoriteAlreadyExistsFailure extends FavoritesFailure {
  const FavoriteAlreadyExistsFailure()
      : super(code: 'favorites.already_exists');
}

/// La parada indicada no está en favoritos.
final class FavoriteNotFoundFailure extends FavoritesFailure {
  const FavoriteNotFoundFailure() : super(code: 'favorites.not_found');
}

/// No se pudo sincronizar el widget de inicio.
final class FavoriteWidgetSyncFailure extends FavoritesFailure {
  const FavoriteWidgetSyncFailure({super.cause, super.stackTrace})
      : super(code: 'favorites.widget_sync_failed');
}

// ───────────────────────── Genérico ─────────────────────────

/// Fallo desconocido — usar SOLO como último recurso. Cualquier captura debe
/// loguearse en Sentry vía LoggerPort.
final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.cause, super.stackTrace})
      : super(code: 'unknown');
}
