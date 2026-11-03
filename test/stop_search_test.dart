// Buscador de paradas: filtra al escribir, sin importar tildes ni mayúsculas.
import 'package:alzitrans/models/bus_stop.dart';
import 'package:alzitrans/utils/stop_search.dart';
import 'package:flutter_test/flutter_test.dart';

BusStop s(int id, String name) => BusStop(id: id, name: name, lat: 39.15, lng: -0.43, lines: const ['L1']);

void main() {
  final stops = [
    s(1, 'ESTACIO RENFE'),
    s(2, "RONDA SEQUIA REIAL D'ALZIRA-CENTRE DE SALUT"),
    s(3, 'PLAÇA DEL REGNE (A HOSPITAL)'),
    s(4, "ESTACIÓ D'AUTOBUSOS"),
    s(5, 'PEREZ GALDÓS'),
    s(6, 'HOSPITAL'),
  ];

  test('"estacio" encuentra las dos estaciones (con y sin tilde) y nada más', () {
    expect(filterStops(stops, 'estacio').map((e) => e.id).toList(), [1, 4]);
  });

  test('sin importar tildes, ç ni mayúsculas', () {
    expect(filterStops(stops, 'placa').map((e) => e.id), [3]);
    expect(filterStops(stops, 'GALDOS').map((e) => e.id), [5]);
    expect(filterStops(stops, 'Plaça Regne').map((e) => e.id), [3]);
  });

  test('varias palabras en cualquier orden; primero las que empiezan por la búsqueda', () {
    expect(filterStops(stops, 'hospital').map((e) => e.id).toList(), [6, 3]);
    expect(filterStops(stops, 'regne plaça').map((e) => e.id), [3]);
  });

  test('vacío devuelve todas; sin coincidencias, ninguna', () {
    expect(filterStops(stops, '  '), hasLength(stops.length));
    expect(filterStops(stops, 'xyz'), isEmpty);
  });
}
