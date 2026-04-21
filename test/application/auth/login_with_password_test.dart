import 'package:alzitrans/application/auth/login_with_password.dart';
import 'package:alzitrans/domain/entities/session.dart';
import 'package:alzitrans/domain/entities/user.dart';
import 'package:alzitrans/domain/exceptions/app_failure.dart';
import 'package:alzitrans/domain/ports/outbound/auth_repository.dart';
import 'package:alzitrans/domain/ports/outbound/session_storage.dart';
import 'package:alzitrans/domain/shared/result.dart';
import 'package:alzitrans/domain/value_objects/email.dart';
import 'package:alzitrans/domain/value_objects/jwt_token.dart';
import 'package:alzitrans/domain/value_objects/password.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../fakes/recording_logger.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSessionStorage extends Mock implements SessionStorage {}

class _AnyEmail extends Fake implements Email {}

class _AnyPassword extends Fake implements Password {}

class _AnySession extends Fake implements Session {}

void main() {
  setUpAll(() {
    registerFallbackValue(_AnyEmail());
    registerFallbackValue(_AnyPassword());
    registerFallbackValue(_AnySession());
  });

  late _MockAuthRepository repo;
  late _MockSessionStorage storage;
  late RecordingLogger logger;
  late LoginWithPassword useCase;

  setUp(() {
    repo = _MockAuthRepository();
    storage = _MockSessionStorage();
    logger = RecordingLogger();
    useCase = LoginWithPassword(
      authRepository: repo,
      sessionStorage: storage,
      logger: logger,
    );
  });

  Session _fakeSession() {
    final email = Email.tryParse('a@b.com').unwrap();
    final token = JwtToken.tryParse(
      // payload mínimo válido base64 → {"exp": 9999999999}
      'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjk5OTk5OTk5OTl9.sig',
    ).unwrap();
    return Session(user: User(id: 1, email: email), token: token);
  }

  group('validación previa al backend', () {
    test('devuelve ValidationFailure si el email es inválido', () async {
      final result = await useCase(rawEmail: 'foo', rawPassword: '123456');
      expect(result.isErr, true);
      expect(result.unwrapErr(), isA<ValidationFailure>());
      verifyNever(() => repo.login(any(), any()));
    });

    test('devuelve ValidationFailure si la contraseña es corta', () async {
      final result = await useCase(rawEmail: 'a@b.com', rawPassword: '12');
      expect(result.isErr, true);
      expect(result.unwrapErr(), isA<ValidationFailure>());
      verifyNever(() => repo.login(any(), any()));
    });
  });

  group('happy path', () {
    test('login directo guarda la sesión y configura usuario en el logger', () async {
      final session = _fakeSession();
      when(() => repo.login(any(), any(), biometric: any(named: 'biometric')))
          .thenAnswer((_) async => Ok(LoginSucceeded(session)));
      when(() => storage.save(any())).thenAnswer((_) async => const Ok(null));

      final result = await useCase(rawEmail: 'a@b.com', rawPassword: '123456');

      expect(result.isOk, true);
      expect(result.unwrap(), isA<LoginSucceeded>());
      verify(() => storage.save(session)).called(1);
      expect(logger.lastUser?.email, 'a@b.com');
      expect(logger.failures, isEmpty);
    });

    test('cuando se requiere OTP no guarda sesión', () async {
      final email = Email.tryParse('a@b.com').unwrap();
      when(() => repo.login(any(), any(), biometric: any(named: 'biometric')))
          .thenAnswer((_) async => Ok(LoginRequiresOtp(email)));

      final result = await useCase(rawEmail: 'a@b.com', rawPassword: '123456');

      expect(result.unwrap(), isA<LoginRequiresOtp>());
      verifyNever(() => storage.save(any()));
      expect(logger.lastUser, isNull);
    });
  });

  group('errores', () {
    test('propaga InvalidCredentialsFailure y la registra en el logger', () async {
      when(() => repo.login(any(), any(), biometric: any(named: 'biometric')))
          .thenAnswer((_) async => const Err(InvalidCredentialsFailure()));

      final result = await useCase(rawEmail: 'a@b.com', rawPassword: '123456');

      expect(result.unwrapErr(), isA<InvalidCredentialsFailure>());
      expect(logger.failures, hasLength(1));
      expect(logger.failures.first.code, 'auth.invalid_credentials');
    });

    test('si guardar la sesión falla, devuelve StorageWriteFailure', () async {
      final session = _fakeSession();
      when(() => repo.login(any(), any(), biometric: any(named: 'biometric')))
          .thenAnswer((_) async => Ok(LoginSucceeded(session)));
      when(() => storage.save(any()))
          .thenAnswer((_) async => const Err(StorageWriteFailure()));

      final result = await useCase(rawEmail: 'a@b.com', rawPassword: '123456');

      expect(result.unwrapErr(), isA<StorageWriteFailure>());
      expect(logger.failures.last, isA<StorageWriteFailure>());
    });
  });

  test('cuando biometric=true, lo propaga al repositorio', () async {
    final session = _fakeSession();
    when(() => repo.login(any(), any(), biometric: any(named: 'biometric')))
        .thenAnswer((_) async => Ok(LoginSucceeded(session)));
    when(() => storage.save(any())).thenAnswer((_) async => const Ok(null));

    await useCase(rawEmail: 'a@b.com', rawPassword: '123456', biometric: true);
    verify(() => repo.login(any(), any(), biometric: true)).called(1);
  });
}
