import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Recorrido circular de una línea medido en metros.
///
/// Todas las posiciones se expresan como distancia recorrida desde el
/// principio del recorrido (`0 ≤ s < length`). Las paradas se proyectan una
/// vez sobre el recorrido, siempre hacia delante, así que la parada k+1
/// queda siempre después de la k (salvo al dar la vuelta).
class RouteGeometry {
  RouteGeometry._(this.points, this._cum, this.stopDistances, this.offRoute);

  final List<LatLng> points;
  final List<double> _cum;

  /// Distancia sobre el recorrido de cada parada, en el orden de la línea.
  final List<double> stopDistances;

  /// Paradas por las que el recorrido no pasa (las que la línea solo hace en
  /// algunas expediciones). La simulación las ignora.
  final List<bool> offRoute;

  double get length => _cum.last;
  int get stopCount => stopDistances.length;

  static const _dist = Distance(roundResult: false);

  /// Tolerancia para considerar que el recorrido pasa por una parada.
  static const double stopToleranceM = 60;

  /// Crea el recorrido. Si [track] está vacío se usa la línea recta entre
  /// paradas (mismo comportamiento que antes, pero sin saltos).
  factory RouteGeometry.build(List<LatLng> track, List<LatLng> stops) {
    var pts = track.length >= 2 ? List<LatLng>.of(track) : [...stops, if (stops.isNotEmpty) stops.first];
    // Cerrar la vuelta si el recorrido no acaba donde empieza.
    if (pts.length >= 2 && _dist(pts.first, pts.last) > 1) pts = [...pts, pts.first];

    final cum = <double>[0];
    for (var i = 0; i < pts.length - 1; i++) {
      cum.add(cum.last + _dist(pts[i], pts[i + 1]));
    }
    final total = cum.last;

    final stopDist = <double>[];
    final off = <bool>[];
    var last = 0.0;
    for (var k = 0; k < stops.length; k++) {
      final r = _projectForward(pts, cum, stops[k], k == 0 ? 0 : last);
      // Si el recorrido no pasa cerca, la parada queda fuera y no hace avanzar
      // la búsqueda (si no, descolocaría a todas las siguientes).
      off.add(!r.near);
      stopDist.add(total > 0 ? (r.near ? r.pos : last) % total : 0);
      if (r.near) last = r.pos;
    }
    return RouteGeometry._(pts, cum, stopDist, off);
  }

  /// Proyecta [p] sobre el recorrido buscando desde [from] hacia delante y
  /// quedándose con el primer paso cerca de la parada (el recorrido puede
  /// pasar dos veces por la misma calle). Si no hay ninguno cerca, el más
  /// cercano por delante.
  static ({double pos, bool near}) _projectForward(List<LatLng> pts, List<double> cum, LatLng p, double from) {
    double? best;
    double bestD = double.infinity;
    double? nearest;
    double nearestD = double.infinity;
    for (var i = 0; i < pts.length - 1; i++) {
      if (cum[i + 1] < from - 1) continue;
      final r = _projectOnSegment(p, pts[i], pts[i + 1]);
      final pos = cum[i] + r.t * (cum[i + 1] - cum[i]);
      if (pos < from - 1) continue;
      if (r.d < nearestD) {
        nearestD = r.d;
        nearest = pos;
      }
      if (r.d <= stopToleranceM) {
        if (r.d < bestD) {
          bestD = r.d;
          best = pos;
        }
      } else if (best != null) {
        break;
      }
    }
    if (best != null) return (pos: best, near: true);
    return (pos: nearest ?? from, near: false);
  }

  static ({double d, double t}) _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    final k = cos(a.latitude * pi / 180);
    final ax = a.longitude * k, ay = a.latitude;
    final dx = b.longitude * k - ax, dy = b.latitude - ay;
    final px = p.longitude * k - ax, py = p.latitude - ay;
    final l2 = dx * dx + dy * dy;
    final t = l2 == 0 ? 0.0 : ((px * dx + py * dy) / l2).clamp(0.0, 1.0);
    final q = LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
    return (d: _dist(p, q), t: t);
  }

  /// Normaliza una distancia al rango [0, length).
  double wrap(double s) {
    if (length <= 0) return 0;
    final r = s % length;
    return r < 0 ? r + length : r;
  }

  /// Distancia hacia delante desde [from] hasta [to] (0 ≤ d < length).
  double forward(double from, double to) => wrap(to - from);

  /// Punto del recorrido a [s] metros del principio.
  LatLng positionAt(double s) {
    if (points.length < 2 || length <= 0) return points.isEmpty ? const LatLng(0, 0) : points.first;
    final x = wrap(s);
    var lo = 0, hi = _cum.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_cum[mid] <= x) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final segLen = _cum[hi] - _cum[lo];
    final t = segLen <= 0 ? 0.0 : (x - _cum[lo]) / segLen;
    final a = points[lo], b = points[hi];
    return LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
  }

  /// Rumbo (grados, 0 = norte) del recorrido en [s].
  double headingAt(double s) {
    final a = positionAt(s - 8), b = positionAt(s + 8);
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final lat1 = a.latitude * pi / 180, lat2 = b.latitude * pi / 180;
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  /// Siguiente parada del recorrido después de [k] (saltando las de fuera).
  int nextOnRoute(int k) {
    for (var i = 1; i <= stopCount; i++) {
      final j = (k + i) % stopCount;
      if (!offRoute[j]) return j;
    }
    return k;
  }

  /// Parada del recorrido anterior a [k] (saltando las de fuera).
  int prevOnRoute(int k) {
    for (var i = 1; i <= stopCount; i++) {
      final j = (k - i + stopCount) % stopCount;
      if (!offRoute[j]) return j;
    }
    return k;
  }

  /// Índice de la primera parada del recorrido que está por delante de [s]
  /// (más de [margin] m).
  int nextStopIndex(double s, {double margin = 5}) {
    if (stopCount == 0) return 0;
    var best = 0;
    var bestD = double.infinity;
    for (var k = 0; k < stopCount; k++) {
      if (offRoute[k]) continue;
      var d = forward(s, stopDistances[k]);
      if (d <= margin) d += length;
      if (d < bestD) {
        bestD = d;
        best = k;
      }
    }
    return best;
  }
}
