import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:vector_math/vector_math_64.dart';

class ArMathUtils {
  /// Calcula el Rumbo (Bearing) inicial desde el punto de origen al destino en grados.
  /// 0 = Norte, 90 = Este, 180 = Sur, 270 = Oeste.
  static double calculateBearing(LatLng start, LatLng end) {
    final double startLat = _degreesToRadians(start.latitude);
    final double startLng = _degreesToRadians(start.longitude);
    final double endLat = _degreesToRadians(end.latitude);
    final double endLng = _degreesToRadians(end.longitude);

    final double dLng = endLng - startLng;

    final double y = math.sin(dLng) * math.cos(endLat);
    final double x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    final double bearing = math.atan2(y, x);
    return (_radiansToDegrees(bearing) + 360) % 360;
  }

  /// Calcula la distancia de Haversine en metros entre dos puntos.
  static double calculateDistance(LatLng start, LatLng end) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, start, end);
  }

  /// Proyecta una posición 3D relativa al usuario a coordenadas 2D de pantalla.
  /// [azimuth] es el ángulo del objeto respecto al norte.
  /// [deviceHeading] es hacia dónde mira el móvil respecto al norte.
  /// [fov] es el Field of View estimado de la cámara (aprox 60º).
  static double? getXOffset(double azimuth, double deviceHeading, double screenWidth, {double fov = 60.0}) {
    double diff = azimuth - deviceHeading;
    
    // Normalizar a [-180, 180]
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    // Si el objeto está fuera del FOV, no se muestra (retornar null)
    if (diff.abs() > fov / 2) return null;

    // Mapear de [-fov/2, fov/2] a [0, screenWidth]
    return (screenWidth / 2) + (diff * (screenWidth / fov));
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180;
  static double _radiansToDegrees(double radians) => radians * 180 / math.pi;
}
