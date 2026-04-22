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
- `TripFailure` → `TripNotFoundFailure`, `NoPendingTripFailure`, `TripSaveFailure`.
- Value Objects con `tryParse`:
  - `Email` — normaliza a minúsculas, regex básica.
  - `Password` — `minLength=6`, método `clear()`, `toString()` = `'***'`.
  - `JwtToken` — decodifica payload base64, `isExpiredAt(now)`. **Sustituye la duplicación entre `auth_service.dart:_extractExpiry` y `auth_provider.dart:JwtDecoder`.**
- Entidades: `User`, `Session`, `TripRecord`, `TripStats`, `MonthlyStats`.

### 3.3 Ports (interfaces outbound)
- `PreferencesPort` (SharedPreferences).
- `SecretsPort` (flutter_secure_storage).
- `LoggerPort` (Sentry — `captureFailure`, `captureException`, `log`, `breadcrumb`, `setUser`).
- `HttpPort` (Dio — devuelve `Future<Result<HttpResponse, NetworkFailure>>`).
- `AuthRepository` con sealed `LoginOutcome` = `LoginSucceeded(Session)` | `LoginRequiresOtp(Email)`.
- `SessionStorage`.
- `BiometricCredentialsStorage` + `BiometricCredentials(email, password)`.
- `BiometricAuthenticator`.
- `TripRepository` — fetchAll, addTrip, deleteTrip, clearAll.
- `LocalTripStorage` — gestionar viaje pendiente offline.

### 3.4 Application (use cases)
**Auth:**
- `LoginWithPassword` — valida VOs, llama repo, guarda sesión, `logger.setUser`.
- `VerifyLoginOtp` — valida email + code, guarda sesión.
- `RegisterUser` — valida VOs y delega.
- `Logout` — notifica backend (best-effort con warning), limpia sesión,
  opcionalmente limpia credenciales biométricas, anonimiza Sentry.
  **Sustituye el `catch (_)` silencioso de `auth_service.dart:282`.**
- `LoginWithBiometrics` — sealed `BiometricLoginOutcome` =
  `BiometricNotConfigured` | `BiometricCancelled` | `BiometricSucceeded(Session)`.
  Reutiliza `LoginWithPassword` internamente con `biometric=true`.

**Trips:**
- `FetchTripHistory`, `AddTrip`, `SavePendingTrip`, `ConfirmPendingTrip`, `RejectPendingTrip`, `DeleteTrip`, `ClearTripHistory`. 
  Reemplazan el anterior `TripServiceOrchestrator` y preparan el terreno para retirar `trip_history_service.dart`.

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
- `HttpTripRepository` — adapter HTTP para los viajes (devuelve 404 como `TripNotFoundFailure`).
- `LocalTripStorageImpl` — usa SharedPreferences via `PreferencesPort` para guardar el viaje pendiente de forma local.

### 3.6 DI Riverpod (`lib/presentation/providers/di.dart`)
Todos los providers cableados:
- `dioProvider`, `preferencesPortProvider` (depende del `sharedPreferencesProvider` existente),
  `secretsPortProvider`, `loggerPortProvider`, `httpPortProvider`.
- `sessionStorageProvider`, `biometricCredentialsStorageProvider`, `biometricAuthenticatorProvider`.
- `authRepositoryProvider`, `tripRepositoryProvider`, `localTripStorageProvider`.
- Casos de uso de Auth (`loginWithPasswordProvider`, etc).
- Casos de uso de Trips (`fetchTripHistoryProvider`, etc).

### 3.8 Migración de logout en UI/state
- `lib/core/providers/auth_provider.dart` ya no usa `AuthService.logout()`.
  Ahora invoca el caso de uso `logoutProvider` (hexagonal) y devuelve `bool`
  para que la UI pueda reaccionar a éxito/error.
- `lib/screens/profile_screen.dart` fue adaptado para:
  - navegar a login sólo cuando `logout()` devuelve `true`;
  - mostrar `SnackBar` de error cuando el logout falla.

### 3.9 Migración parcial de `AuthNotifier` (check/login/register)
- `checkLogin()` ya no usa `AuthService.isLoggedIn()`: ahora lee sesión desde
  `sessionStorageProvider` y valida expiración del JWT con `JwtToken`.
- `login()` ya no usa `AuthService.login()`: ahora delega en
  `loginWithPasswordProvider` (use case hexagonal).
  - Mantiene compatibilidad legacy mapeando `AppFailure` a las excepciones
    existentes (`AuthInvalidCredentialsException`,
    `AuthLoginOtpRequiredException`, `AuthNetworkException`).
- `register()` ya no usa `AuthService.register()`: ahora delega en
  `registerUserProvider` y mapea fallos a excepciones de presentación.

### 3.10 Bloque Auth completado: recuperación de contraseña + borrado de cuenta
- Nuevos use cases en `lib/application/auth/`:
  - `request_password_reset.dart`
  - `reset_password.dart`
  - `delete_account.dart`
- `AuthRepository` amplía contrato con `deleteAccount()` y
  `HttpAuthRepository` lo implementa sobre `DELETE /users/profile`.
- DI (`lib/presentation/providers/di.dart`) añade providers:
  - `requestPasswordResetProvider`
  - `resetPasswordProvider`
  - `deleteAccountProvider`
- `ForgotPasswordPage` y `ResetPasswordPage` migradas al pipeline hexagonal
  (sin `AuthService` legacy).
- `AuthNotifier.deleteAccount()` migrado a `deleteAccountProvider`.
- `LoginPage` deja de depender de `AuthService.isUserPremium()` y lee el estado
  premium desde `SessionStorage`.

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

### 3.12 Dominio Favoritos (completo)
- `AppFailure` añade `FavoritesFailure` con tres subtipos
  (`FavoriteAlreadyExistsFailure`, `FavoriteNotFoundFailure`,
  `FavoriteWidgetSyncFailure`).
- Entidad `FavoriteStop` (domain/entities) + value object auxiliar
  `FavoriteWidgetSnapshot` para pintar el widget.
- Puertos outbound:
  - `FavoriteStopRepository` — CRUD de la lista + `getWidgetStopId` /
    `setWidgetStopId`.
  - `FavoriteWidgetGateway` — publica un snapshot en el widget del launcher.
  - `StopArrivalFetcher` — devuelve la próxima llegada de una parada.
- Casos de uso (`lib/application/favorites/`): `ListFavoriteStops`,
  `IsFavoriteStop`, `AddFavoriteStop` (valida duplicados + auto-asigna widget
  si es la primera), `RemoveFavoriteStop` (reasigna widget si la borrada era
  la actual), `GetWidgetFavoriteStop` (con fallback a la primera favorita),
  `SetWidgetFavoriteStop`, `SyncFavoriteWidget` (orquesta fetch arrivals +
  render).
- Infrastructure (`lib/infrastructure/favorites/`):
  - `PrefsFavoriteStopRepository` — usa las claves legacy `favorite_stops`
    y `widget_favorite_stop`.
  - `HomeWidgetGatewayImpl` — adapta `HomeWidget`.
  - `HttpStopArrivalFetcher` — scrappa `PopupPoste.aspx` y mapea
    DioException → NetworkFailure.
- DI wired en `di.dart` (sección "Favorites").
- `lib/widgets/stop_info_sheet.dart` migrado: añadir/quitar favoritos pasa
  por `addFavoriteStopProvider`/`removeFavoriteStopProvider` y dispara
  `syncFavoriteWidgetProvider`.
- `lib/services/assistant_service.dart` migrado: usa un
  `ProviderContainer` temporal (mismo patrón que
  `onBackgroundNotificationResponse` en `home_screen.dart`) para
  invocar los casos de uso desde un servicio estático de platform channel.
- `lib/services/foreground_service.dart` — el widget static refresher ahora
  lee la lista de favoritos vía `PrefsFavoriteStopRepository` en vez de
  parsear la clave cruda.
- `lib/services/favorite_stops_service.dart` renombrado a
  `.dart.deleted` (ya no se importa en ninguna parte). El sandbox no permite
  el `rm` final — el usuario debe borrarlo a mano antes de commitear.

### 3.11 Dominio Trips — consumidores UI y servicios
- `lib/screens/home_screen.dart` — ya consume `confirmPendingTripProvider`,
  `rejectPendingTripProvider` (card/cash) desde el widget + desde el callback
  del aislante de servicio (IPC `bus_arrived`).
- `lib/screens/trip_history_screen.dart` — consume `tripHistoryNotifierProvider`
  (AsyncNotifier). Borra y refresca vía el notifier.
- `lib/presentation/providers/trip_history_provider.dart` — AsyncNotifier con
  `refresh()`, `deleteTrip(serverId)` y `clearHistory()`. Reemplaza a la
  variable `_records` del antiguo `TripHistoryService`.
- `lib/services/foreground_service.dart` — ya NO escribe la clave cruda
  `pending_trip`. Encapsulado en `LocalTripStorageImpl(SharedPrefsAdapter(prefs))`
  con instrumentación Sentry (`trip.save_pending_failed`).
- `lib/services/bus_alert_service.dart` — mismo cambio en `_savePendingTrip`.
- `lib/services/background_service.dart` — igual (aunque el fichero está
  marcado como deprecated, se deja coherente).
- `lib/services/auth_service.dart:logout` — usa
  `LocalTripStorageImpl.clearPendingTrip()` en vez de `prefs.remove('pending_trip')`.
- `lib/core/network/api_client.dart` interceptor 401 — idem.

Resultado: la única referencia literal a `'pending_trip'` que queda fuera de
`LocalTripStorageImpl` está en `SessionStorageImpl._allKeys` (intencional: esa
clave se limpia en logout junto con las de Auth). Todo el resto de la app lee
y escribe el viaje pendiente a través del puerto de dominio.

## 4. Lo que NO se ha tocado (intencionalmente)

- `lib/services/auth_service.dart` — sólo se parcheó el `catch (_)` de la
  línea 282. El resto del fichero sigue intacto. La nueva arquitectura
  **coexiste** con la legacy; ambas leen/escriben las mismas keys.
- `lib/core/providers/auth_provider.dart` — **parcialmente migrado**:
  `checkLogin/login/register/logout/deleteAccount` ya usan puertos/use cases
  hexagonales. Permanece el provider `authServiceProvider` para otras zonas
  legacy (perfil avanzado, heartbeat, etc.).
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

## 7. Git — commits hechos

Rama `refactor/hexagonal`. Commits ya aplicados (orden reverso):

1. `feat(domain): Result, AppFailure y value objects (Email, Password, JwtToken)` — ec32da0
2. `feat(domain,application): ports outbound + use cases de Auth` — ab277e4
3. `feat(infrastructure,di): adapters + wiring Riverpod` — e7f5ac2
4. `test: dominio y aplicacion de Auth + session storage + fakes` — 1291a5a
5. `fix(obs): conectar Sentry en catch silenciosos criticos` — e4919cc
6. `docs: ARCHITECTURE.md y MIGRATION_PROGRESS.md` — f70ade7

**Pendiente:** push a remoto cuando se confirme en local que
`flutter analyze && flutter test` pasan.

**Importante:** no usar `git add .` ni `git add -A` — el repo tiene
ruido masivo de CRLF/LF (200+ ficheros "modificados" por EOL). Los
ficheros editados se normalizaron a LF antes de comitearlos.

### 8. Cómo continuar en un chat nuevo

1. Abre el proyecto en `refactor/hexagonal`.
2. Lee este documento.
3. Lee `lib/ARCHITECTURE.md`.
4. Ejecuta `flutter pub get && flutter analyze && flutter test` en local.
5. Decide próximo paso:
   - **Opción A** (recomendada) — migrar UI: cablear `login_page.dart` (para que use providers de Auth) o `trip_history_screen.dart` / `home_screen.dart` (para usar los nuevos providers de Trips).
   - **Opción B** — test TDD: añadir los tests unitarios faltantes para los use cases de Trips y sus adapters.
   - **Opción C** — migrar el siguiente dominio (Routes, Notifications).

## 9. Tareas abiertas

- [x] `lib/ARCHITECTURE.md` — creado (sección 3).
- [x] Commits por fase (sección 7).
- [x] Migrar logout a use case `Logout` en provider/UI.
- [x] Migrar `checkLogin/login/register` de `AuthNotifier` a hexagonal.
- [x] Migrar forgot/reset password y delete account a casos de uso hexagonales.
- [x] Migrar dominio Trips (Entities, Failures, Ports, Use Cases, Adapters, DI).
- [x] Migrar UI de Trips (`trip_history_screen.dart` y `home_screen.dart`) al
  pipeline hexagonal (ya usan `tripHistoryNotifierProvider`,
  `confirmPendingTripProvider`, `rejectPendingTripProvider`).
- [x] Centralizar la clave `pending_trip` dentro de `LocalTripStorageImpl`
  (fuera solo sobrevive el listado de limpieza en `SessionStorageImpl._allKeys`).
- [x] Migrar dominio Favoritos completo (entities, ports, use cases,
  adapters, DI, consumidores `stop_info_sheet.dart` y `assistant_service.dart`
  + `foreground_service.dart`). Legacy `favorite_stops_service.dart`
  renombrado a `.dart.deleted`.
- [ ] Testear dominio Trips y dominio Favoritos (TDD pospuesto a petición del
  usuario).
- [ ] Migrar UI de login al nuevo pipeline.
- [ ] Migrar el resto de los consumidores legacy de `AuthService` (ver bloque).

---

### Bloque Siguiente — erradicar `AuthService`

El objetivo es borrar `lib/services/auth_service.dart` cuando todos sus
consumidores dejen de dependerlo. Clientes remanentes:
1. `lib/screens/profile_screen.dart` — perfil avanzado / heartbeat.
2. `lib/screens/home_screen.dart` — comprobaciones puntuales.
3. `lib/main.dart` — posibles llamadas en arranque.
4. `lib/services/premium_service.dart` — flujo premium (DESACTIVADO hoy, se
   puede dejar para el final).

### Bloque opcional (siguiente dominio)

Candidatos para el próximo corte grande cuando Auth esté limpio:

- **NFC** (`lib/services/nfc_service.dart` + `lib/core/providers/nfc_controller.dart`)
  — ya hay fallos definidos (`NfcNotSupportedFailure`, `NfcReadFailure`,
  `NfcChecksumMismatchFailure`). Resta puerto + use cases + adapter.
  Interactúa con Trips al decrementar `stored_trips` tras confirmar pago
  con tarjeta.
- **Bus times / Stops** (`lib/services/bus_times_service.dart`,
  `lib/services/stops_service.dart`) — dominio más grande pero core de
  la app. Patrón claro: `Stop`, `BusArrival`, puerto
  `BusTimesGateway`, adapter HTTP.
- **Gamificación** (`lib/services/gamification_service.dart`) — usa
  SharedPreferences para logros locales. Pequeño y autocontenido.

### Patrón para servicios estáticos (platform channels, isolates)

Cuando un servicio no puede recibir `Ref` (por ejemplo `AssistantService`,
que responde a method channels, o `onBackgroundNotificationResponse` en
isolate), crear un `ProviderContainer` temporal dentro de la llamada:

```dart
final container = ProviderContainer();
try {
  await container.read(someUseCaseProvider).call();
} finally {
  container.dispose();
}
```

Asume que todos los providers de dominio son instanciables sin overrides —
hoy lo son salvo `sharedPreferencesProvider`, que se obtiene de forma
asíncrona vía `SharedPreferences.getInstance()` dentro del adaptador. Si
alguna vez se añade un provider que requiera override (como ocurre con
`sharedPreferencesProvider` en el container de `main.dart`), replicar el
override aquí también.

**Última actualización de este documento:** 2026-04-21 (iteración 3: dominio Favoritos migrado).
