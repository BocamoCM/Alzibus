import 'package:alzitrans/application/auth/logout.dart';
import 'package:alzitrans/domain/exceptions/app_failure.dart';
import 'package:alzitrans/domain/ports/outbound/auth_repository.dart';
import 'package:alzitrans/domain/ports/outbound/biometric_credentials_storage.dart';
import 'package:alzitrans/domain/ports/outbound/session_storage.dart';
import 'package:alzitrans/domain/shared/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../fakes/recording_logger.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSessionStorage extends Mock implements SessionStorage {}

class _MockBiometricStorage extends Mock implements BiometricCredentialsStorage {}

void main() {
  late _MockAuthRepository repo;
  late _MockSessionStorage session;
  late _MockBiometricStorage bio;
  late RecordingLogger logger;
  late Logout useCase;

  setUp(() {
    repo = _MockAuthRepository();
    session = _MockSessionStorage();
    bio = _MockBiometricStorage();
    logger = RecordingLogger();
    useCase = Logout(
      authRepository: repo,
      sessionStorage: session,
      biometricStorage: bio,
      logger: logger,
    );
  });

  test('happy path: limpia sesión, biometría y desidentifica al logger', () async {
    when(() => repo.notifyLogout()).thenAnswer((_) async => const Ok(null));
    when(() => session.clear()).thenAnswer((_) async => const Ok(null));
    when(() => bio.clear()).thenAnswer((_) async => const Ok(null));

    final result = await useCase();

    expect(result.isOk, true);
    verifyInOrder([
      () => repo.notifyLogout(),
      () => session.clear(),
      () => bio.clear(),
    ]);
    expect(logger.lastUser, isNotNull);
    expect(logger.lastUser!.email, isNull);
    expect(logger.lastUser!.id, isNull);
  });

  test('si la notificación al backend falla, NO bloquea el logout local', () async {
    when(() => repo.notifyLogout())
        .thenAnswer((_) async => const Err(SessionExpiredFailure()));
    when(() => session.clear()).thenAnswer((_) async => const Ok(null));
    when(() => bio.clear()).thenAnswer((_) async => const Ok(null));

    final result = await useCase();

    expect(result.isOk, true);
    expect(logger.logs.any((l) => l.message.contains('Backend logout')), true);
  });

  test('si limpiar la sesión local falla, devuelve el StorageFailure', () async {
    when(() => repo.notifyLogout()).thenAnswer((_) async => const Ok(null));
    when(() => session.clear())
        .thenAnswer((_) async => const Err(StorageWriteFailure()));

    final result = await useCase();

    expect(result.unwrapErr(), isA<StorageWriteFailure>());
    verifyNever(() => bio.clear());
    expect(logger.failures.any((f) => f is StorageWriteFailure), true);
  });

  test('clearBiometric=false omite la limpieza de credenciales biométricas', () async {
    when(() => repo.notifyLogout()).thenAnswer((_) async => const Ok(null));
    when(() => session.clear()).thenAnswer((_) async => const Ok(null));

    final result = await useCase(clearBiometric: false);

    expect(result.isOk, true);
    verifyNever(() => bio.clear());
  });
}
