# Migración a Arquitectura Hexagonal — Estado

> **Propósito de este documento:** snapshot del estado actual de la refactorización
> para poder retomar el trabajo en otro chat sin tener que repetir todo el
> contexto. Léelo entero antes de continuar.

---

## 1. Contexto de la app

- **Alzitrans** — app Flutter (Riverpod, Dio, Sentry, SharedPreferences,
  flutter_secure_storage, local_auth, flutter_local_notifications, Geolocator,
  Socket.IO, AdMob).
- Backend Node.js con endpoints REST (`/login`, `/register`, `/verify-email`,
  `/forgot-password`, `/reset-password`, `/login/verify`, `/users/logout`,
  `/metrics/*`, `/stats/*`).
- **Premium actualmente desconectado** — se mantiene el campo `isPremium` en la
  entidad `User` y en el storage, pero no se migra su lógica.

## 2. Rama de trabajo

- `refactor/hexagonal` creada desde `main`.
- Commits por fase (pendiente dividir — de momento todos los cambios son locales
  sin commit; ver sección 7).

## 3. Lo que ya está hecho

### 3.1 Andamiaje de carpetas
```
lib/
├── domain/
│   ├── entities/               # User, Session
│   ├── exceptions/             # app_failure.dart (sealed AppFailure)
│   ├── ports/outbound/         # interfaces (AuthRepository, SessionStorage, etc.)
│   ├── shared/                 # result.dart (sealed Result<T,F> — Ok/Err)
│   └── value_objects/          # Email, Password, JwtToken
├── application/
│   └── auth/                   # use cases (LoginWithPassword, Logout, ...)
├── infrastructure/
│   ├── auth/                   # HttpAuthRepository, LocalBiometricAuthenticator
│   ├── network/                # DioHttpAdapter
│   ├── observability/          # SentryLogger
│   └── storage/                # SharedPrefs / SecureStorage / SessionStorage / Biometric
└── presentation/providers/
    └── di.dart                 # wiring Riverpod
```

### 3.2 Domain (completo para Auth)
- `Result<T, F>` sealed con `Ok`/`Err`, con `unwrap`, `unwrapErr`, `map`, `mapErr`, equality.
- `AppFailure` jerárquica:
  - `NetworkFailure` → `OfflineFailure`, `TimeoutFailure`, `ServerFailure(statusCode)`, `UnexpectedResponseFailure`.
  - `AuthFailure` → `InvalidCredentialsFailure`, `OtpRequiredFailure`, `InvalidOtpFailure`, `EmailNotVerifiedFailure`, `BiometricUnavailableFailure`, `SessionExpiredFailure`, `RegistrationFailure`.
  - `ValidationFailure` con `fieldErrors: Map<String,String>`.
  - `StorageFailure` → `StorageReadFailure`, `StorageWriteFailure`.
  - `NfcFailure` → `NfcNotSupportedFailure`, `NfcReadFailure`, `NfcChecksumMismatchFailure`.
  - `UnknownFailure`.
  - Todas tienen `code`, `userMessage`, `cause`, `stackTrace`.
- Value Objects con `tryParse`:
  - `Email` — normaliza a minúsculas, regex básica.
  - `Password` — `minLength=6`, método `clear()`, `toString()` = `'***'`.
  - `JwtToken` — decodifica payload base64, `isExpiredAt(now)`. **Sustituye la duplicación entre `auth_service.dart:_extractExpiry` y `auth_provider.dart:JwtDecoder`.**
- Entidades: `User(id, email, isPremium)`, `Session(user, token)`.

### 3.3 Ports (interfaces outbound)
- `PreferencesPort` (SharedPreferences).
- `SecretsPort` (flutter_secure_storage).
- `LoggerPort` (Sentry — `captureFailure`, `captureException`, `log`, `breadcrumb`, `setUser`).
- `HttpPort` (Dio — devuelve `Future<Result<HttpResponse, NetworkFailure>>`).
- `AuthRepository` con sealed `LoginOutcome` = `LoginSucceeded(Session)` | `LoginRequiresOtp(Email)`.
- `SessionStorage`.
- `BiometricCredentialsStorage` + `BiometricCredentials(email, password)`.
- `BiometricAuthenticator`.

### 3.4 Application (use cases)
- `LoginWithPassword` — valida VOs, llama repo, guarda sesión, `logger.setUser`.
- `VerifyLoginOtp` — valida email + code, guarda sesión.
- `RegisterUser` — valida VOs y delega.
- `Logout` — notifica backend (best-effort con warning), limpia sesión,
  opcionalmente limpia credenciales biométricas, anonimiza Sentry.
  **Sustituye el `catch (_)` silencioso de `auth_service.dart:282`.**
- `LoginWithBiometrics` — sealed `BiometricLoginOutcome` =
  `BiometricNotConfigured` | `BiometricCancelled` | `BiometricSucceeded(Session)`.
  Reutiliza `LoginWithPassword` internamente con `biometric=true`.

### 3.5 Infrastructure (adapters)
- `SharedPrefsAdapter` — envuelve `SharedPreferences` inyectado.
- `SecureStorageAdapter` — envuelve `FlutterSecureStorage`.
- `SessionStorageImpl` — **mantiene claves legacy** (`jwt_token`, `user_email`,
  `user_id`, `is_premium`, `token_expiry`, `pending_trip`) para que
  `auth_service.dart`, `auth_provider.dart`, `api_client.dart` sigan
  funcionando durante la migración. Si el token está corrupto, limpia y devuelve `null`.
- `BiometricCredentialsStorageImpl` — claves legacy `biometric_email`,
  `biometric_password`, `biometric_enabled`.
- `LocalBiometricAuthenticator` — wrap de `local_auth` con `catch (_)`
  intencional en `isAvailable()` (fallo del plugin = no disponible).
- `SentryLogger` — mapea `captureFailure` a `Sentry.captureException` con tag
  `failure_code`, o a `captureMessage` si no hay causa. Mapea `LogLevel` a `SentryLevel`.
- `DioHttpAdapter` — reusa `ApiClient().dio` singleton. Mapea:
  - `connectionTimeout`/`sendTimeout`/`receiveTimeout` → `TimeoutFailure`.
  - `connectionError` → `OfflineFailure`.
  - `badResponse` → `ServerFailure(statusCode)`.
- `HttpAuthRepository` — adapter HTTP. Habla con los endpoints del backend.
  - `200 con token` → `LoginSucceeded`.
  - `200 con requiresOtp` → `LoginRequiresOtp`.
  - `401` → `SessionExpiredFailure`.
  - `403` con `"verificar tu correo"` → `EmailNotVerifiedFailure`.
  - Resto → `InvalidCredentialsFailure` / `RegistrationFailure`.

### 3.6 DI Riverpod (`lib/presentation/providers/di.dart`)
Todos los providers cableados:
- `dioProvider`, `preferencesPortProvider` (depende del `sharedPreferencesProvider` existente),
  `secretsPortProvider`, `loggerPortProvider`, `httpPortProvider`.
- `sessionStorageProvider`, `biometricCredentialsStorageProvider`, `biometricAuthenticatorProvider`.
- `authRepositoryProvider`.
- `loginWithPasswordProvider`, `verifyLoginOtpProvider`, `registerUserProvider`,
  `logoutProvider`, `loginWithBiometricsProvider`.

### 3.7 Parches Sentry (silent catches críticos)
Convertidos de `catch (_) {}` a `catch (e, s)` + `Sentry.captureException` con
tag `failure_code`:
- `lib/services/auth_service.dart:282` — notificación backend logout
  (`auth.logout_notify_failed`, warning).
- `lib/main.dart:311` — métrica app-open (`metrics.app_open_schedule_failed`, warning).
- `lib/services/bus_simulation_service.dart:269` — tracking buses (breadcrumbs
  por candidato fallido, `captureMessage` warning si ningún candidato responde:
  `bus_tracking.no_candidate_matched`).
- `lib/services/foreground_service.dart:108` — geolocalización (ambos caminos:
  `geolocation.current_position_failed`, `geolocation.last_known_failed`).
- `lib/widgets/stop_info_sheet.dart:293` — métrica log-alert
  (`metrics.log_alert_failed`, info).

## 4. Lo que NO se ha tocado (intencionalmente)

- `lib/services/auth_service.dart` — sólo se parcheó el `catch (_)` de la
  línea 282. El resto del fichero sigue intacto. La nueva arquitectura
  **coexiste** con la legacy; ambas leen/escriben las mismas keys.
- `lib/core/providers/auth_provider.dart` — sin tocar. Mantiene su propia
  lógica de `JwtDecoder`.
- `lib/core/network/api_client.dart` — sin tocar. El nuevo `DioHttpAdapter`
  **reusa** el singleton existente.
- `lib/pages/login_page.dart` — sin tocar. Sigue consumiendo `AuthService` viejo.
- Todo lo de Premium (no se usa).
- Tests del dominio Auth y de `SessionStorageImpl` **fueron creados** pero
  todavía no se han ejecutado (sandbox no tiene Dart toolchain). Ver sección 6.

## 5. Silent catches pendientes (NO críticos, menor prioridad)

Identificados por el audit original pero NO parcheados todavía. Si se quieren
migrar, el patrón es siempre el mismo:

```dart
} catch (e, s) {
  Sentry.captureException(e, stackTrace: s, withScope: (scope) {
    scope.setTag('failure_code', '<scope>.<reason>');
    scope.level = SentryLevel.warning; // o info
  });
}
```

Lista pendiente (ubicaciones aproximadas, puede haber shift por los edits ya hechos):
- `lib/services/tts_service.dart:96` — fallo al inicializar TTS.
- `lib/services/gamification_service.dart:30` — fallo cargando progreso.
- `lib/pages/routes_page.dart:237` — fallo cargando rutas.
- `lib/pages/map_page.dart:267` — fallo cargando mapa.
- `lib/core/providers/nfc_controller.dart:294` — fallo NFC.

**NO tocar** (son intencionales en el código nuevo):
- `lib/infrastructure/auth/local_biometric_authenticator.dart:20`.
- `lib/domain/value_objects/jwt_token.dart:35`.

## 6. Verificación pendiente (requiere toolchain Dart/Flutter local)

El sandbox del chat no tiene Dart/Flutter. El usuario debe ejecutar en local:

```bash
# Desde la raíz del proyecto
flutter pub get
flutter analyze
flutter test
```

Tests creados (en `test/`):
- `fakes/in_memory_preferences.dart`, `fakes/in_memory_secrets.dart`,
  `fakes/recording_logger.dart`.
- `domain/value_objects/email_test.dart` (4 tests).
- `domain/value_objects/password_test.dart` (5 tests).
- `domain/value_objects/jwt_token_test.dart` (5 tests, con helper `_fakeJwt`).
- `domain/shared/result_test.dart` (6 tests).
- `application/auth/login_with_password_test.dart` — validación + happy path + errores + biometric.
- `application/auth/logout_test.dart` — happy path, backend failure no bloquea, storage failure aborta, `clearBiometric=false`.
- `application/auth/verify_login_otp_test.dart`, `register_user_test.dart`.
- `infrastructure/session_storage_impl_test.dart` — roundtrip, null, clear, token corrupto.
- `widget_test.dart` reescrito (placeholder; el default estaba roto).

Dependencia añadida en `pubspec.yaml` (dev):
```yaml
mocktail: ^1.0.4
```

## 7. Git — commits pendientes

Todo el trabajo está **sin commitear** (excepto la creación de la rama).
La propuesta de división en commits lógicos:

1. `chore: andamiaje carpetas domain/application/infrastructure/presentation`
2. `feat(domain): Result, AppFailure, value objects (Email, Password, JwtToken)`
3. `feat(domain): ports outbound (Auth, Session, Biometric, Logger, Http, Prefs, Secrets)`
4. `feat(application): use cases de Auth (login, logout, register, otp, biometrics)`
5. `feat(infrastructure): adapters (Dio, SharedPrefs, SecureStorage, Sentry, Local auth)`
6. `feat(infrastructure): HttpAuthRepository + SessionStorageImpl + BiometricStorageImpl`
7. `feat(di): wiring Riverpod de nuevo dominio Auth`
8. `test: dominio Auth + application + infrastructure (session storage)`
9. `fix(obs): conectar Sentry en catch silenciosos críticos`

**Importante:** no usar `git add .` ni `git add -A` — el repo tiene ruido
masivo de CRLF/LF (200+ ficheros "modificados" por EOL). Usar siempre
`git add <path>` con rutas específicas.

## 8. Cómo continuar en un chat nuevo

1. Abre el proyecto en `refactor/hexagonal`.
2. Lee este documento.
3. Lee `lib/ARCHITECTURE.md` cuando exista (pendiente — ver sección 9).
4. Ejecuta `flutter pub get && flutter analyze && flutter test` en local.
5. Decide próximo paso:
   - **Opción A** (recomendada) — cablear `login_page.dart` para que consuma los
     nuevos providers (`loginWithPasswordProvider`, `verifyLoginOtpProvider`).
     Esto empieza a "retirar" el `AuthService` viejo sin romperlo.
   - **Opción B** — migrar el siguiente dominio (Routes, Trips, Notifications).
   - **Opción C** — terminar silent catches de la sección 5.
6. Commitear por fases según sección 7.

## 9. Tareas abiertas

- [ ] `lib/ARCHITECTURE.md` — documento explicando la estructura hexagonal,
  cómo añadir un nuevo use case, cómo mapear port→adapter, cómo testear.
- [ ] Commits por fase (sección 7).
- [ ] `flutter pub get && flutter analyze && flutter test` — verificar en local.
- [ ] (Opcional) Migrar UI de login al nuevo pipeline.
- [ ] (Opcional) Silent catches restantes (sección 5).

---

**Última actualización de este documento:** 2026-04-21.
