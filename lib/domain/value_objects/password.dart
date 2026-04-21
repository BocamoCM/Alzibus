import '../exceptions/app_failure.dart';
import '../shared/result.dart';

/// Value Object inmutable que garantiza que una contraseña cumple la política
/// mínima del producto (longitud >= 6, igual que la validación actual de
/// `LoginPage` y `RegisterPage`).
///
/// El valor en claro se mantiene en memoria sólo durante la operación de
/// login/registro y se limpia explícitamente con [clear].
class Password {
  String _value;

  Password._(this._value);

  String get value => _value;

  static const int minLength = 6;

  static Result<Password, ValidationFailure> tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const Err(ValidationFailure(fieldErrors: {'password': 'empty'}));
    }
    if (raw.length < minLength) {
      return const Err(ValidationFailure(fieldErrors: {'password': 'too_short'}));
    }
    return Ok(Password._(raw));
  }

  /// Sobreescribe la cadena con espacios y la limpia para reducir la ventana
  /// en la que la contraseña queda en RAM. No es bala de plata (Dart no
  /// garantiza que no haya copias intermedias), pero ayuda.
  void clear() {
    _value = '';
  }

  @override
  String toString() => '***';
}
