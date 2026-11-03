import '../models/bus_stop.dart';

/// Quita tildes y diéresis y pasa a minúsculas, para buscar "estacio" y
/// encontrar "ESTACIÓ" (o "placa" → "PLAÇA").
String normalizeForSearch(String s) {
  const from = 'àáâäèéêëìíîïòóôöùúûüçñ·';
  const to = 'aaaaeeeeiiiioooouuuucn.';
  final lower = s.toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

/// Paradas cuyo nombre contiene todas las palabras de [query] (sin importar
/// tildes, mayúsculas ni el orden). Primero las que empiezan por la búsqueda.
List<BusStop> filterStops(List<BusStop> stops, String query) {
  final words = normalizeForSearch(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return stops;
  final matches = stops.where((s) {
    final name = normalizeForSearch(s.name);
    return words.every(name.contains);
  }).toList();
  final first = words.first;
  matches.sort((a, b) {
    final sa = normalizeForSearch(a.name).startsWith(first) ? 0 : 1;
    final sb = normalizeForSearch(b.name).startsWith(first) ? 0 : 1;
    return sa - sb;
  });
  return matches;
}
