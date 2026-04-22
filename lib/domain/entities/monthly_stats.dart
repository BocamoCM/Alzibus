/// Estadísticas mensuales de uso de transporte.
///
/// Lógica pura de dominio — sin I/O, sin Flutter, sin dependencias externas.
class MonthlyStats {
  final int year;
  final int month;
  final int tripCount;
  final Map<String, int> lineUsage;

  const MonthlyStats({
    required this.year,
    required this.month,
    required this.tripCount,
    required this.lineUsage,
  });

  /// Nombre corto del mes (ej. "Ene", "Feb").
  /// TODO(migration): mover a presentación con i18n cuando la UI migre.
  String get monthName {
    const months = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return months[month];
  }

  /// Etiqueta corta para gráficos: "Ene 25", "Feb 25", etc.
  String get label => '$monthName ${year.toString().substring(2)}';

  /// Nombre completo del mes.
  String get fullMonthName {
    const months = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return months[month];
  }
}
