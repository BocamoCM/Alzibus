import 'package:alzitrans/application/auth/register_user.dart';
import 'package:alzitrans/domain/exceptions/app_failure.dart';
import 'package:alzitrans/domain/ports/outbound/auth_repository.dart';
import 'package:alzitrans/domain/shared/result.dart';
import 'package:alzitrans/domain/value_objects/email.dart';
import 'package:alzitrans/domain/value_objects/password.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../fakes/recording_logger.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _AnyEmail extends Fake implements Email {}

class _AnyPassword extends Fake implements Password {}

void main() {
  setUpAll(() {
    registerFallbackValue(_AnyEmail());
    registerFallbackValue(_AnyPassword());
  });

  late _MockAuthRepository repo;
  late RecordingLogger logger;
  late RegisterUser useCase;

  setUp(() {
    repo = _MockAuthRepository();
    logger = RecordingLogger();
    useCase = RegisterUser(authRepository: repo, logger: logger);
  });

  test('feliz: delega en el repositorio cuando los datos son válidos', () async {
    when(() => repo.register(any(), any()))
        .thenAnswer((_) async => const Ok(null));
    final result = await useCase(rawEmail: 'a@b.com', rawPassword: '123456');
    expect(result.isOk, true);
    verify(() => repo.register(any(), any())).called(1);
  });

  test('rechaza email malformado sin llamar al repositorio', () async {
    final result = await useCase(rawEmail: 'foo', rawPassword: '123456');
    expect(result.unwrapErr(), isA<ValidationFailure>());
    verifyNever(() => repo.register(any(), any()));
  });

  test('rechaza contraseña corta sin llamar al repositorio', () async {
    final result = await useCase(rawEmail: 'a@b.com', rawPassword: '12');
    expect(result.unwrapErr(), isA<ValidationFailure>());
    verifyNever(() => repo.register(any(), any()));
  });

  test('registra el fallo en el logger cuando el backend lo rechaza', () async {
    when(() => repo.register(any(), any())).thenAnswer(
        (_) async => const Err(RegistrationFailure(serverMessage: 'taken')));
    final result = await useCase(rawEmail: 'a@b.com', rawPassword: '123456');
    expect(result.unwrapErr(), isA<RegistrationFailure>());
    expect(logger.failures, hasLength(1));
  });
}
