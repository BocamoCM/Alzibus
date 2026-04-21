import 'dart:convert';

import '../exceptions/app_failure.dart';
import '../shared/result.dart';

/// Value Object inmutable que representa un JWT decodificado parcialmente.
///
/// Sólo se decodifica el payload (sin validar firma — eso lo hace el backend).
/// Expone el `expiresAt` para comprobar caducidad sin tener que volver a
/// parsear, y centraliza la lógica que estaba duplicada entre `AuthService`
/// (`_extractExpiry`) y `auth_provider.dart` (`JwtDecoder`).
class JwtToken {
  final String raw;
  final DateTime? expiresAt;

  const JwtToken._({required this.raw, this.expiresAt});

  /// Construye el token o devuelve [InvalidCredentialsFailure] si el formato
  /// no es un JWT válido (3 partes separadas por puntos + payload base64).
  static Result<JwtToken, AuthFailure> tryParse(String raw) {
    final parts = raw.split('.');
    if (parts.length != 3) {
      return const Err(InvalidCredentialsFailure());
    }
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'];
      DateTime? expiresAt;
      if (exp is int) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      return Ok(JwtToken._(raw: raw, expiresAt: expiresAt));
    } catch (_) {
      return const Err(InvalidCredentialsFailure());
    }
  }

  bool isExpiredAt(DateTime now) {
    final exp = expiresAt;
    if (exp == null) return false; // sin exp → asumimos vivo
    return now.isAfter(exp);
  }

  @override
  String toString() => 'JwtToken(exp=$expiresAt)';
}
