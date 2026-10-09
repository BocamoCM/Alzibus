/// Un "hábito de viaje" detectado: un trayecto que el usuario repite en el
/// mismo día de la semana a una hora parecida (p. ej. L1 desde "Mercat" los
/// lunes sobre las 8:00). Es la base del aviso proactivo de Albus.
class TravelHabit {
  final String line;
  final String stopName;
  final int stopId;

  /// Día de la semana 1 (lunes) … 7 (domingo), como DateTime.weekday.
  final int weekday;

  /// Hora típica de salida (hora:minuto) calculada a partir del historial.
  final int hour;
  final int minute;

  /// Cuántos días distintos se ha repetido este trayecto (confianza).
  final int occurrences;

  const TravelHabit({
    required this.line,
    required this.stopName,
    required this.stopId,
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.occurrences,
  });

  /// Clave estable para persistir si el aviso está activado y para derivar
  /// el id de la notificación.
  String get id => '$stopId|$line|$weekday';

  /// Id numérico estable y acotado a int32 positivo para la notificación.
  int get notificationId => (id.hashCode & 0x7fffffff) % 1000000;

  /// Minutos desde medianoche de la hora típica.
  int get minuteOfDay => hour * 60 + minute;
}
