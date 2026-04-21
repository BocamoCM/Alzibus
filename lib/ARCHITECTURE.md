# Arquitectura hexagonal — Alzitrans (Flutter)

Esta guía describe cómo está organizado el código en `lib/` tras el refactor a
Ports & Adapters, y cómo añadir funcionalidad nueva respetando la arquitectura.

> **Estado:** migración en curso. El dominio **Auth** está migrado. El código
> legacy (`services/`, `core/`, `pages/`) sigue funcionando sin cambios y
> coexiste con la nueva arquitectura durante la transición. Ver
> [`../MIGRATION_PROGRESS.md`](../MIGRATION_PROGRESS.md) para el snapshot.

## 1. Capas

```
lib/
├── domain/              ← reglas de negocio puras (sin Flutter, sin I/O)
│   ├── entities/        ← objetos con identidad (User, Session)
│   ├── value_objects/   ← objetos inmutables validados (Email, Password, JwtToken)
│   ├── exceptions/      ← sealed AppFailure
│   ├── shared/          ← Result<T, F>
│   └── ports/outbound/  ← interfaces: lo que el dominio le pide al mundo
│
├── application/         ← use cases (orquestan dominio + ports)
│   └── auth/            ← LoginWithPassword, Logout, RegisterUser, …
│
├── infrastructure/      ← adapters concretos que implementan los ports
│   ├── auth/            ← HttpAuthRepository, LocalBiometricAuthenticator
│   ├── network/         ← DioHttpAdapter
│   ├── observability/   ← SentryLogger
│   └── storage/         ← SharedPrefsAdapter, SecureStorageAdapter, SessionStorageImpl, …
│
└── presentation/        ← UI + wiring
    └── providers/di.dart  ← Riverpod Providers que cablean todo
```

### Regla de dependencia
```
presentation ──▶ application ──▶ domain ◀── infrastructure
                                   ▲
                                   └── ports (outbound)
```

- **domain** no depende de nada más que de sí mismo. No importa Flutter, Dio,
  SharedPreferences, Sentry, ni Riverpod. Se puede ejecutar y testear en una
  VM Dart pelada.
- **application** depende sólo de **domain** (incluidos sus ports). NO importa
  implementaciones concretas.
- **infrastructure** implementa los ports del dominio. Depende de domain y de
  las librerías externas (Dio, SharedPreferences, Sentry, local_auth…).
- **presentation** depende de application + domain. Cablea los adapters vía
  Riverpod. Las páginas/widgets no deben importar nada de `infrastructure/`
  directamente — siempre a través de los Providers.

## 2. Bloques de construcción

### 2.1 `Result<T, F>`
Sustituye a `throw`/`try-catch` a través de límites de caso de uso. Obligamos
a tratar el error de forma explícita.

```dart
sealed class Result<T, F> { … }
final class Ok<T, F>  extends Result<T, F> { final T value; }
final class Err<T, F> extends Result<T, F> { final F failure; }
```

Uso con pattern matching (Dart 3):
```dart
switch (await login(email, password)) {
  case Ok(value: LoginSucceeded(:final session)): …
  case Ok(value: LoginRequiresOtp(:final email)): …
  case Err(failure: InvalidCredentialsFailure()): …
  case Err(failure: final f):                      // exhaustivo
    logger.captureFailure(f);
}
```

### 2.2 `AppFailure` (sealed)
Jerarquía en `domain/exceptions/app_failure.dart`:

- `NetworkFailure` → `OfflineFailure`, `TimeoutFailure`, `ServerFailure(statusCode)`, `UnexpectedResponseFailure`.
- `AuthFailure` → `InvalidCredentialsFailure`, `OtpRequiredFailure`, `InvalidOtpFailure`, `EmailNotVerifiedFailure`, `BiometricUnavailableFailure`, `SessionExpiredFailure`, `RegistrationFailure`.
- `ValidationFailure(fieldErrors: Map<String,String>)`.
- `StorageFailure` → `StorageReadFailure`, `StorageWriteFailure`.
- `NfcFailure` → `NfcNotSupportedFailure`, `NfcReadFailure`, `NfcChecksumMismatchFailure`.
- `UnknownFailure`.

Todos tienen `code`, `userMessage`, `cause`, `stackTrace`.

**Convención de `code`:** `<scope>.<reason>` (ej. `auth.invalid_credentials`,
`network.timeout`, `storage.read_failed`). Se usa como tag `failure_code` en
Sentry para filtrar.

### 2.3 Value Objects
`Email.tryParse(String) → Result<Email, ValidationFailure>`, etc. NO hay
constructores públicos sin validar. Los VOs no se pueden construir en estado
inválido.

```dart
final result = Email.tryParse(input);
if (result case Err(failure: final f)) return Err(f);
final email = result.unwrap();
```

### 2.4 Ports (interfaces outbound)
Viven en `domain/ports/outbound/`. Son interfaces puras.

| Port                            | Responsabilidad                          |
|---------------------------------|------------------------------------------|
| `HttpPort`                      | requests HTTP → `Result<HttpResponse, NetworkFailure>` |
| `PreferencesPort`               | SharedPreferences                        |
| `SecretsPort`                   | flutter_secure_storage                   |
| `LoggerPort`                    | Sentry (capture, log, breadcrumb, setUser) |
| `AuthRepository`                | login/register/otp/password/logout       |
| `SessionStorage`                | persistir `Session`                      |
| `BiometricCredentialsStorage`   | credenciales biométricas                 |
| `BiometricAuthenticator`        | `local_auth`                             |

### 2.5 Use cases
Clases en `application/<feature>/`. Una clase por caso de uso. Firma típica:

```dart
class LoginWithPassword {
  final AuthRepository _repo;
  final SessionStorage _session;
  final LoggerPort _logger;

  Future<Result<LoginOutcome, AppFailure>> call(String email, String password) async { … }
}
```

Reglas:
- Validan entrada con VOs.
- Orquestan ports — **no** contienen I/O ellos mismos.
- Devuelven siempre `Result`.
- Hacen logging relevante vía `LoggerPort` (no acceden a Sentry directamente).

## 3. Cómo añadir una feature nueva

Ejemplo: "Favoritos de paradas".

1. **Modelar entidades y VOs** en `domain/entities/` y `domain/value_objects/`:
   - `FavoriteStop(stopId, addedAt)`.

2. **Definir fallos específicos** si hacen falta, en `app_failure.dart`:
   - `class FavoritesFailure extends AppFailure { … }` + subtipos.

3. **Definir port outbound** en `domain/ports/outbound/`:
   ```dart
   abstract class FavoritesRepository {
     Future<Result<List<FavoriteStop>, AppFailure>> list();
     Future<Result<void, AppFailure>> add(int stopId);
     Future<Result<void, AppFailure>> remove(int stopId);
   }
   ```

4. **Escribir use cases** en `application/favorites/`:
   - `AddFavoriteStop`, `RemoveFavoriteStop`, `ListFavoriteStops`.
   - Tests primero (TDD) en `test/application/favorites/` usando fakes.

5. **Implementar adapter** en `infrastructure/favorites/`:
   - `HttpFavoritesRepository` sobre `HttpPort`, o
   - `LocalFavoritesRepository` sobre `PreferencesPort`.

6. **Cablear Riverpod** en `presentation/providers/di.dart`:
   ```dart
   final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) =>
     HttpFavoritesRepository(ref.watch(httpPortProvider)));
   final addFavoriteStopProvider = Provider((ref) =>
     AddFavoriteStop(ref.watch(favoritesRepositoryProvider)));
   ```

7. **Consumir desde UI**:
   ```dart
   final addFav = ref.read(addFavoriteStopProvider);
   final result = await addFav(stopId);
   switch (result) {
     case Ok(): showSnack('Añadido'); 
     case Err(failure: final f): showError(f.userMessage);
   }
   ```

## 4. Testing

### 4.1 Fakes in-memory
Viven en `test/fakes/`. Implementan ports con estado en memoria:
- `InMemoryPreferences` — mapa interno + `snapshot` getter.
- `InMemorySecrets` — idem con secretos.
- `RecordingLogger` — graba `failures`, `exceptions`, `logs`, `breadcrumbs`, `lastUser`.

### 4.2 Mocktail
Para ports específicos de feature (`AuthRepository`, etc.) se usan `Mock`
classes. `Fake` para tipos que el matcher default no puede representar
(`Email`, `Password`).

### 4.3 Ejemplo típico
```dart
test('login guarda sesión y setea usuario en logger', () async {
  final repo = _MockAuthRepo();
  final storage = _RecordingSessionStorage();
  final logger = RecordingLogger();
  final uc = LoginWithPassword(repo: repo, sessionStorage: storage, logger: logger);

  when(() => repo.login(any(), any(), biometric: any(named: 'biometric')))
    .thenAnswer((_) async => Ok(LoginSucceeded(_session)));

  final result = await uc('test@test.com', 'secret123');

  expect(result, isA<Ok>());
  expect(storage.saved, equals(_session));
  expect(logger.lastUser?.email, equals('test@test.com'));
});
```

### 4.4 Ejecución
```bash
flutter pub get
flutter analyze
flutter test
```

## 5. Convenciones

### 5.1 Error handling
- **NUNCA** `catch (_) {}` silencioso. Si hay razón para ignorar, loguear
  como `LogLevel.info` con contexto.
- **NUNCA** `throw` a través de límites de use case; devolver `Err(failure)`.
- Todo `AppFailure` lleva `code` con formato `<scope>.<reason>` para filtrar
  en Sentry.

### 5.2 Naming
- Ports: sustantivo o `<X>Repository` / `<X>Port` / `<X>Storage`.
- Use cases: verbo imperativo en camelCase como clase (`LoginWithPassword`,
  `AddFavoriteStop`).
- Adapters: `<Impl><X>` o `<Tech><X>` (`HttpAuthRepository`,
  `SessionStorageImpl`).

### 5.3 Inmutabilidad
- Entidades y VOs son `final` y usan `copyWith` cuando hace falta mutar.
- Nada de mutación in-place en el dominio.

### 5.4 Riverpod
- Todos los providers de puertos son `Provider<TPort>` (no family, no
  autoDispose) para poder overridearlos en tests con `ProviderContainer`.
- Un use case = un provider.

## 6. Anti-patrones que evitamos

- ❌ Importar `shared_preferences` o `dio` en `lib/pages/` o `lib/widgets/`.
- ❌ Lanzar excepciones desde use cases en vez de `Result`.
- ❌ Crear instancias de adapters manualmente en lugar de leer del Provider.
- ❌ Acoplar domain a Flutter (`BuildContext`, `MediaQuery`, …).
- ❌ `catch (_) {}` silencioso.
- ❌ Duplicar lógica de JWT / normalización de email / validación fuera de los VOs.

## 7. Próximos pasos (roadmap)

Ver [`../MIGRATION_PROGRESS.md`](../MIGRATION_PROGRESS.md) §8–§9 para el detalle.
Resumen:
1. Cablear `login_page.dart` al nuevo pipeline (`loginWithPasswordProvider`).
2. Migrar dominios restantes: Trips, Routes, Notifications, NFC.
3. Retirar `services/auth_service.dart` una vez que no lo use nadie.
4. Terminar silent catches no críticos.
