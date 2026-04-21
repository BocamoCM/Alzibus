import 'package:alzitrans/domain/exceptions/app_failure.dart';
import 'package:alzitrans/domain/shared/result.dart';
import 'package:alzitrans/domain/value_objects/email.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Email.tryParse', () {
    test('acepta un email válido y lo normaliza a minúsculas', () {
      final r = Email.tryParse('  Foo@Bar.COM  ');
      expect(r.isOk, true);
      expect(r.unwrap().value, 'foo@bar.com');
    });

    test('falla con `empty` si está vacío o es null', () {
      for (final raw in [null, '', '   ']) {
        final r = Email.tryParse(raw);
        expect(r.isErr, true);
        final f = r.unwrapErr();
        expect(f.fieldErrors['email'], 'empty');
      }
    });

    test('falla con `invalid` si no encaja con el patrón', () {
      for (final raw in ['no-at', 'a@b', 'a@b.', '@b.com', 'a@.com', 'a b@c.com']) {
        final r = Email.tryParse(raw);
        expect(r.isErr, true, reason: 'esperaba fallo para "$raw"');
        expect(r.unwrapErr().fieldErrors['email'], 'invalid');
      }
    });

    test('dos emails con el mismo valor son iguales (==)', () {
      final a = Email.tryParse('a@b.com').unwrap();
      final b = Email.tryParse('A@B.COM').unwrap();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
