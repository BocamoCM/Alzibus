import 'bus_stop.dart';

/// Un plan de viaje completo entre dos paradas (o ubicación → parada).
///
/// Compuesto por una secuencia de [TripStep]: caminar, coger un bus, transbordo.
/// El planificador puede devolver varios planes alternativos (ej: directo más
/// largo vs con transbordo más corto). El usuario elige cuál usar.
class TripPlan {
  final List<TripStep> steps;

  /// Duración total estimada en minutos (suma de todos los pasos).
  final int totalDurationMin;

  /// Número de transbordos. 0 = ruta directa.
  final int transferCount;

  /// Distancia total caminando en metros (suma de WalkSteps).
  final int walkingDistanceM;

  const TripPlan({
    required this.steps,
    required this.totalDurationMin,
    required this.transferCount,
    required this.walkingDistanceM,
  });

  /// Líneas usadas en el plan, en orden. Útil para el resumen.
  List<String> get linesUsed =>
      steps.whereType<BusStep>().map((s) => s.line).toList();

  /// `true` si el plan tiene 0 transbordos.
  bool get isDirect => transferCount == 0;
}

/// Un paso del plan. Sealed-style: solo puede ser [WalkStep], [BusStep] o
/// [TransferStep].
abstract class TripStep {
  /// Duración estimada en minutos.
  int get durationMin;

  /// Descripción corta usada por Albus para "hablar" el paso.
  /// Debe ser corta (1 frase) y en español castizo, family-friendly.
  String albusSays();
}

/// Paso a pie: del origen a una parada de bus, de una parada a otra (transbordo
/// corto), o de la parada de bajada al destino final.
class WalkStep extends TripStep {
  /// Descripción del origen ("Tu ubicación", "Parada X").
  final String fromLabel;

  /// Descripción del destino ("Parada Y", "Tu destino").
  final String toLabel;

  /// Distancia a caminar en metros.
  final int distanceM;

  @override
  final int durationMin;

  WalkStep({
    required this.fromLabel,
    required this.toLabel,
    required this.distanceM,
    required this.durationMin,
  });

  @override
  String albusSays() {
    if (distanceM < 100) {
      return 'Da unos pasos hasta $toLabel — no está lejos.';
    }
    if (distanceM < 500) {
      return 'Camina unos $distanceM metros hasta $toLabel. ¡En $durationMin min lo tienes!';
    }
    return 'Camina hasta $toLabel ($distanceM m, unos $durationMin min).';
  }
}

/// Paso en bus: coger una línea en una parada, bajarse en otra. Puede tener
/// paradas intermedias.
class BusStep extends TripStep {
  /// Identificador de línea ("L1", "L2", "L3").
  final String line;

  /// Parada donde subes.
  final BusStop fromStop;

  /// Parada donde te bajas.
  final BusStop toStop;

  /// Paradas intermedias entre [fromStop] y [toStop], en orden.
  /// NO incluye [fromStop] ni [toStop].
  final List<BusStop> intermediateStops;

  @override
  final int durationMin;

  BusStep({
    required this.line,
    required this.fromStop,
    required this.toStop,
    required this.intermediateStops,
    required this.durationMin,
  });

  /// Número total de paradas que el bus visita en este tramo, incluyendo
  /// origen y destino (ej: 5 paradas significa que pasas por 3 intermedias).
  int get totalStopsCount => intermediateStops.length + 2;

  /// Paradas a contar hasta bajarse: si subes en A y bajas en C pasando por B,
  /// son "2 paradas más" (B y C). Lo que el usuario diría: "me bajo en la 2ª".
  int get stopsToCount => intermediateStops.length + 1;

  @override
  String albusSays() {
    final stops = stopsToCount;
    final stopWord = stops == 1 ? 'parada' : 'paradas';
    return 'Coge la $line en ${fromStop.name}. Bájate $stops $stopWord '
        'después, en ${toStop.name}.';
  }
}

/// Transbordo entre dos líneas. Modelado como paso independiente para que la
/// UI pueda destacarlo (icono distinto, color de aviso). El "andar" del
/// transbordo (si la parada de bajada y subida son distintas) se modela como
/// un WalkStep aparte.
class TransferStep extends TripStep {
  final String fromLine;
  final String toLine;
  final BusStop atStop;

  @override
  final int durationMin;

  TransferStep({
    required this.fromLine,
    required this.toLine,
    required this.atStop,
    this.durationMin = 5,
  });

  @override
  String albusSays() {
    return 'En ${atStop.name} bájate y coge la $toLine. '
        '¡Échale un ojo al horario, son unos $durationMin min!';
  }
}
