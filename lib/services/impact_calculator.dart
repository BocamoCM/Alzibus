/// Calcula el "impacto" ecológico y económico de viajar en bus en vez de
/// en coche, a partir del número de viajes del usuario.
///
/// Es una ESTIMACIÓN pensada para motivar, no una medición exacta: no
/// conocemos la distancia real de cada viaje (el historial solo guarda
/// parada de subida + línea), así que usamos una distancia media por trayecto.
/// Todos los factores están centralizados aquí y son fáciles de ajustar.
class ImpactCalculator {
  /// Distancia media de un trayecto en bus urbano en Alzira. La ciudad es
  /// pequeña; 3 km por viaje es una media conservadora. Si algún día el
  /// historial guarda la distancia real del tramo, se usa esa en su lugar.
  static const double avgTripKm = 3.0;

  /// Emisiones de un coche de gasolina medio: ~0.143 kg CO₂/km (referencia
  /// EEA para turismos). Es lo que el usuario "habría emitido" conduciendo.
  static const double carCo2KgPerKm = 0.143;

  /// Emisiones de un bus urbano repartidas por pasajero: ~0.03 kg CO₂/km.
  static const double busCo2KgPerKmPerPax = 0.03;

  /// CO₂ evitado por km al ir en bus en vez de en coche.
  static const double co2SavedKgPerKm = carCo2KgPerKm - busCo2KgPerKmPerPax;

  /// Coste aproximado de conducir: combustible + desgaste ≈ 0.21 €/km.
  /// Lo presentamos como "lo que te habría costado el coche", no como un
  /// ahorro neto (no restamos el billete), para no exagerar la cifra.
  static const double carCostEurPerKm = 0.21;

  final int trips;

  const ImpactCalculator(this.trips);

  double get km => trips * avgTripKm;

  /// Kilos de CO₂ evitados frente a hacer esos km en coche.
  double get co2SavedKg => km * co2SavedKgPerKm;

  /// Euros que habría costado recorrer esos km en coche.
  double get carCostEur => km * carCostEurPerKm;

  /// CO₂ formateado de forma legible: gramos por debajo de 1 kg, si no kg.
  String get co2Formatted {
    if (co2SavedKg < 1) return '${(co2SavedKg * 1000).round()} g';
    return '${co2SavedKg.toStringAsFixed(1)} kg';
  }

  String get kmFormatted => km.toStringAsFixed(km < 10 ? 1 : 0);

  String get carCostFormatted =>
      '${carCostEur.toStringAsFixed(carCostEur < 10 ? 1 : 0)} €';
}
