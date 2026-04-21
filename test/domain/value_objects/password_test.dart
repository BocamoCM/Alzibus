import 'package:alzitrans/domain/value_objects/password.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Password.tryParse', () {
    test('acepta una contraseña con longitud mínima', () {
      final r = Password.tryParse('123456');
      expect(r.isOk, true);
      expect(r.unwrap().value, '123456');
    });

    test('rechaza contraseñas vacías o nulas', () {
      for (final raw in [null, '']) {
        final r = Password.tryParse(raw);
        expect(r.isErr, true);
        expect(r.unwrapErr().fieldErrors['password'], 'empty');
      }
    });

    test('rechaza contraseñas demasiado cortas', () {
      final r = Password.tryParse('abc');
      expect(r.isErr, true);
      expect(r.unwrapErr().fieldErrors['password'], 'too_short');
    });

    test('clear() vacía el valor en memoria', () {
      final p = Password.tryParse('secret123').unwrap();
      p.clear();
      expect(p.value, '');
    });

    test('toString() nunca filtra el valor', () {
      final p = Password.tryParse('topsecret').unwrap();
      expect(p.toString(), '***');
    });
  });
}
