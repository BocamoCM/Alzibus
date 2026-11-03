// Trenes desde nuestro backend: orden por hora real, sin cancelados ni pasados.
import 'package:alzitrans/services/renfe_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordena por hora real (con retraso) y quita cancelados y trenes ya pasados', () {
    final now = DateTime(2026, 11, 3, 18, 30);
    final directions = {
      'valencia': [
        {'scheduled': '18:42', 'delayMin': 1, 'canceled': false},
        {'scheduled': '19:04', 'delayMin': 0, 'canceled': true},
        {'scheduled': '18:10', 'delayMin': 0, 'canceled': false}, // ya ha salido
      ],
      'xativa': [
        {'scheduled': '18:28', 'delayMin': 10, 'canceled': false}, // 18:38 real
        {'scheduled': 'xx', 'delayMin': 0},
      ],
    };
    final trains = RenfeService.parseBackendTrains(directions, limit: 6, now: now);
    expect(trains.map((t) => '${t.actualTime} ${t.destination}').toList(), ['18:38 Xàtiva', '18:43 València Nord']);
    expect(trains.first.delayMinutes, 10);
  });

  test('respeta el límite', () {
    final now = DateTime(2026, 11, 3, 8, 0);
    final directions = {
      'valencia': [for (var h = 9; h < 20; h++) {'scheduled': '${h.toString().padLeft(2, '0')}:00', 'delayMin': 0}],
    };
    expect(RenfeService.parseBackendTrains(directions, limit: 4, now: now), hasLength(4));
  });
}
