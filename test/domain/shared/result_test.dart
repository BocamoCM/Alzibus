import 'package:alzitrans/domain/exceptions/app_failure.dart';
import 'package:alzitrans/domain/shared/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Ok.unwrap devuelve el valor', () {
      final r = Result<int, AppFailure>.ok(42);
      expect(r.isOk, true);
      expect(r.isErr, false);
      expect(r.unwrap(), 42);
    });

    test('Err.unwrapErr devuelve el fallo', () {
      const f = OfflineFailure();
      final r = Result<int, AppFailure>.err(f);
      expect(r.isErr, true);
      expect(r.unwrapErr(), same(f));
    });

    test('unwrap sobre Err lanza StateError', () {
      final r = Result<int, AppFailure>.err(const OfflineFailure());
      expect(() => r.unwrap(), throwsA(isA<StateError>()));
    });

    test('map transforma Ok y deja Err intacto', () {
      final ok = Result<int, AppFailure>.ok(2).map((v) => v * 10);
      expect(ok.unwrap(), 20);

      const f = OfflineFailure();
      final err = Result<int, AppFailure>.err(f).map((v) => v * 10);
      expect(err.unwrapErr(), same(f));
    });

    test('mapErr transforma Err y deja Ok intacto', () {
      final ok = Result<int, AppFailure>.ok(7)
          .mapErr<String>((f) => f.code);
      expect(ok.unwrap(), 7);

      final err = Result<int, AppFailure>.err(const OfflineFailure())
          .mapErr<String>((f) => f.code);
      expect(err.unwrapErr(), 'network.offline');
    });

    test('Ok y Err implementan == correctamente', () {
      expect(Result<int, AppFailure>.ok(1), equals(Result<int, AppFailure>.ok(1)));
      expect(Result<int, AppFailure>.err(const OfflineFailure()),
          equals(Result<int, AppFailure>.err(const OfflineFailure())));
    });
  });
}
