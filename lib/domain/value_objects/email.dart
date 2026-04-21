import '../exceptions/app_failure.dart';
import '../shared/result.dart';

/// Value Object inmutable que garantiza que un email es sintácticamente válido.
///
/// Construirlo es la única manera de obtener un email válido en el dominio,
/// así que cualquier función que reciba `Email` puede asumir que está bien
/// formado (no necesita revalidar).
class Email {
  final String value;

  const Email._(this.value);

  /// Expresión razonablemente estricta — coincide con la usada en
  /// `LoginPage` y `RegisterPage` para mantener compatibilidad.
  static final RegExp _regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Construye un [Email] o devuelve un [ValidationFailure] con el campo
  /// `email` y el motivo. Permite usarlo directamente en formularios.
  static Result<Email, ValidationFailure> tryParse(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const Err(ValidationFailure(fieldErrors: {'email': 'empty'}));
    }
    if (!_regex.hasMatch(trimmed)) {
      return const Err(ValidationFailure(fieldErrors: {'email': 'invalid'}));
    }
    return Ok(Email._(trimmed.toLowerCase()));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Email && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
