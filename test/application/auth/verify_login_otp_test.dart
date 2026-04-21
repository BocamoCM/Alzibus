import 'package:alzitrans/application/auth/verify_login_otp.dart';
import 'package:alzitrans/domain/entities/session.dart';
import 'package:alzitrans/domain/entities/user.dart';
import 'package:alzitrans/domain/exceptions/app_failure.dart';
import 'package:alzitrans/domain/ports/outbound/auth_repository.dart';
import 'package:alzitrans/domain/ports/outbound/session_storage.dart';
import 'package:alzitrans/domain/shared/result.dart';
import 'package:alzitrans/domain/value_objects/email.dart';
import 'package:alzitrans/domain/value_objects/jwt_token.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../fakes/recording_logger.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSessionStorage extends Mock implements SessionStorage {}

class _AnyEmail extends Fake implements Email {}

class _AnySession extends Fake implements Session {}

void main() {
  setUpAll(() {
    registerFallbackValue(_AnyEmail());
    registerFallbackValue(_AnySession());
  });

  late _MockAuthRepository repo;
  late _MockSessionStorage storage;
  late RecordingLogger logger;
  late VerifyLoginOtp useCase;

  setUp(() {
    repo = _MockAuthRepository();
    storage = _MockSessionStorage();
    logger = RecordingLogger();
    useCase = VerifyLoginOtp(
      authRepository: repo,
      sessionStorage: storage,
      logger: logger,
    );
  });

  Session _fakeSession() => Session(
        user: User(id: 1, email: Email.tryParse('a@b.com').unwrap()),
        token: JwtToken.tryParse(
          'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjk5OTk5OTk5OTl9.sig',
        ).unwrap(),
      );

  test('rechaza email inválido sin llamar al repositorio', () async {
    final result = await useCase(rawEmail: 'foo', code: '123456');
    expect(result.unwrapErr(), isA<ValidationFailure>());
    verifyNever(() => repo.verifyLoginOtp(any(), any()));
  });

  test('rechaza código vacío', () async {
    final result = await useCase(rawEmail: 'a@b.com', code: '   ');
    expect(result.unwrapErr(), isA<ValidationFailure>());
  });

  test('happy path: guarda sesión y configura el logger', () async {
    final session = _fakeSession();
    when(() => repo.verifyLoginOtp(any(), any()))
        .thenAnswer((_) async => Ok(session));
    when(() => storage.save(any())).thenAnswer((_) async => const Ok(null));

    final result = await useCase(rawEmail: 'a@b.com', code: '123456');

    expect(result.isOk, true);
    expect(result.unwrap().user.id, 1);
    verify(() => storage.save(session)).called(1);
    expect(logger.lastUser?.email, 'a@b.com');
  });

  test('propaga InvalidOtpFailure y la registra', () async {
    when(() => repo.verifyLoginOtp(any(), any()))
        .thenAnswer((_) async => const Err(InvalidOtpFailure()));

    final result = await useCase(rawEmail: 'a@b.com', code: '000000');

    expect(result.unwrapErr(), isA<InvalidOtpFailure>());
    expect(logger.failures.first.code, 'auth.invalid_otp');
  });
}
