/// Tipo `Result<T, F>` para representar el resultado de una operación que
/// puede tener éxito (`Ok`) o fallar (`Err`) sin recurrir a excepciones.
///
/// Este tipo es la columna vertebral del flujo de errores del dominio.
/// Los casos de uso devuelven `Result<Output, AppFailure>` y la capa de
/// presentación está obligada por el compilador a manejar ambos casos
/// (vía `switch` exhaustivo sobre `sealed`).
///
/// Ejemplo:
/// ```dart
/// final result = await loginWithPassword(email, password);
/// switch (result) {
///   case Ok(value: final outcome):
///     // navegar a Home
///   case Err(failure: AuthFailure.invalidCredentials()):
///     // mostrar mensaje
///   case Err():
///     // genérico
/// }
/// ```
sealed class Result<T, F> {
  const Result();

  /// Construye un resultado exitoso.
  const factory Result.ok(T value) = Ok<T, F>;

  /// Construye un resultado con fallo.
  const factory Result.err(F failure) = Err<T, F>;

  /// `true` si es [Ok].
  bool get isOk => this is Ok<T, F>;

  /// `true` si es [Err].
  bool get isErr => this is Err<T, F>;

  /// Devuelve el valor o lanza [StateError] si es un [Err].
  ///
  /// Solo usar en tests o cuando se haya comprobado `isOk` antes.
  T unwrap() {
    final self = this;
    if (self is Ok<T, F>) return self.value;
    throw StateError('Called unwrap() on an Err: ${(self as Err).failure}');
  }

  /// Devuelve el fallo o lanza [StateError] si es un [Ok].
  F unwrapErr() {
    final self = this;
    if (self is Err<T, F>) return self.failure;
    throw StateError('Called unwrapErr() on an Ok');
  }

  /// Aplica [mapper] al valor si es [Ok], devuelve el [Err] sin tocar en otro caso.
  Result<R, F> map<R>(R Function(T value) mapper) {
    final self = this;
    if (self is Ok<T, F>) return Ok(mapper(self.value));
    return Err((self as Err<T, F>).failure);
  }

  /// Aplica [mapper] al fallo si es [Err], devuelve el [Ok] sin tocar en otro caso.
  Result<T, R> mapErr<R>(R Function(F failure) mapper) {
    final self = this;
    if (self is Err<T, F>) return Err(mapper(self.failure));
    return Ok((self as Ok<T, F>).value);
  }
}

/// Resultado exitoso.
final class Ok<T, F> extends Result<T, F> {
  final T value;
  const Ok(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Ok<T, F> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Ok($value)';
}

/// Resultado fallido.
final class Err<T, F> extends Result<T, F> {
  final F failure;
  const Err(this.failure);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Err<T, F> && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Err($failure)';
}
