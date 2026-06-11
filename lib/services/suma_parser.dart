import 'dart:typed_data';

/// Parser de tarjetas **SUMA 10** de la ATMV (Generalitat Valenciana).
///
/// La SUMA es una MIFARE Classic 1K con claves propias (no las del bus de
/// Alzira ni las default). El dato que nos interesa vive en el **bloque 5**:
///
///   * Byte 0..3 = `01 00 00 00` (marcador de tarjeta válida con saldo)
///   * Byte 4    = viajes restantes (entero, 0-10)
///   * Byte 5..6 = código de zona (big-endian)
///
/// El resto de bloques tiene histórico de viajes, datos del titular, etc.
/// Aquí solo extraemos viajes + zona porque es lo que necesita la app.
///
/// Las claves y el mapa de zonas vienen del plugin RENFE Suma 10 de
/// Metroflip (firmware Flipper Zero) — son las mismas que se usan en los
/// validadores reales. Comprobado contra dumps reales de tarjetas rojas
/// (Cercanías Valencia + Metrovalencia) y verdes (Renfe regional).
class SumaParser {
  SumaParser._();

  /// Clave A del **sector 1** (donde vive el bloque 5).
  /// Es la única que necesitamos para leer viajes + zona.
  static final Uint8List sector1KeyA = Uint8List.fromList(
    [0xCB, 0x5E, 0xD0, 0xE5, 0x7B, 0x08],
  );

  /// Clave A del sector 0 (validación opcional — si autentica, casi seguro
  /// que es una SUMA y no otra MIFARE Classic).
  static final Uint8List sector0KeyA = Uint8List.fromList(
    [0xA8, 0x84, 0x4B, 0x0B, 0xCA, 0x06],
  );

  /// Resultado del parseado.
  static SumaCardData? parseBlock5(Uint8List block5) {
    if (block5.length < 16) return null;

    // Solo aceptamos bloques con el marcador `01 00 00 00` — el plugin
    // Metroflip valida igual antes de leer viajes. Sin este check podríamos
    // interpretar bytes basura de un bloque vacío como una tarjeta legítima.
    if (block5[0] != 0x01 ||
        block5[1] != 0x00 ||
        block5[2] != 0x00 ||
        block5[3] != 0x00) {
      return null;
    }

    final trips = block5[4]; // 0-255 en la práctica nunca > 10
    final zoneCode = (block5[5] << 8) | block5[6];
    final zone = _zoneName(zoneCode);

    return SumaCardData(trips: trips, zoneCode: zoneCode, zoneName: zone);
  }

  /// Devuelve el nombre legible de la zona desde el código de 16 bits.
  /// Si no lo conoce devuelve `null` para que la UI pueda decidir si
  /// muestra "—" o el código en hex.
  ///
  /// Tabla copiada del plugin RENFE Suma 10 de Metroflip
  /// (`renfe_sum10_get_zone_name`). El switch en C compara contra
  /// `zone_code & 0xFF00`, así que aquí enmascaramos igual.
  static String? _zoneName(int code) {
    final masked = code & 0xFF00;
    final exact = _zonesByCode[code];
    if (exact != null) return exact;
    return _zonesByMaskedCode[masked];
  }

  /// Códigos exactos de 16 bits (subzonas, líneas concretas).
  static const Map<int, String> _zonesByCode = {
    // Subzonas A
    0x6C50: 'A1',
    0x6C80: 'A2',
    0x6C90: 'A3',
    0x6CA0: 'A4',
    0x6CB0: 'A5',
    0x6CC0: 'A6',
    // Subzonas B
    0x6280: 'B2',
    0x6290: 'B3',
    0x62A0: 'B4',
    0x62B0: 'B5',
    0x62C0: 'B6',
    // Subzonas C
    0x6A80: 'C2',
    0x6A90: 'C3',
    0x6AA0: 'C4',
    0x6AB0: 'C5',
    0x6AC0: 'C6',
    0x7260: 'C7',
    // Zonas numéricas (MOBILIS)
    0x8110: '2',
    0x8120: '3',
    0x8130: '4',
    0x8140: '5',
    0x8150: '6',
    0x8210: '2',
    0x8220: '3',
    // Líneas Metro
    0x9210: 'L2',
    0xA110: 'L2',
    0xA120: 'L3',
    0x0C10: 'L2',
    0x6040: 'L4',
    0x6050: 'L6',
    0x6060: 'L8',
    0x6070: 'L9',
    // Euskotren (extranjero, lo dejamos por compatibilidad)
    0xA200: 'E1',
    0xA210: 'E2',
    0xA220: 'E3',
    // Otros
    0x9110: 'Periférico',
    0x9310: 'Norte',
    0x0B00: 'M1',
    0x0B10: 'M2',
  };

  /// Códigos por byte alto (zona "principal"). Si el código exacto no está
  /// en `_zonesByCode`, se busca aquí con `code & 0xFF00`.
  static const Map<int, String> _zonesByMaskedCode = {
    0x6C00: 'ABC',
    0x6200: 'B',
    0x6A00: 'C',
    0x6800: 'D',
    0x6600: 'E',
    0x6400: 'F',
    0x4C00: 'CD',
    // Zonas combinadas
    0x6D00: 'AB',
    0x6E00: 'AC',
    0x6F00: 'BC',
    0x7000: 'ABC',
    0x7100: 'ABCD',
    0x7200: 'ABCDE',
    0x7300: 'ABCDEF',
    // Zonas numéricas (MOBILIS) — byte alto
    0x8100: '1',
    0x8200: '1',
    // Especiales
    0x6700: '7',
    0x6900: '8',
    0x6B00: '9',
    // Líneas Metro principales
    0x9200: 'L1',
    0xA100: 'L1',
    0x0C00: 'L1',
    // Zonas especiales
    0x9100: 'Centro',
    0x9300: 'Centro',
    0xEC00: 'ABC',
    // RENFE estatales (raras en SUMA pero por si acaso)
    0xF000: 'Cercanías',
    0xF100: 'AVE',
    0xF200: 'Media Distancia',
    0xF300: 'Larga Distancia',
  };
}

/// Datos extraídos de una SUMA 10.
class SumaCardData {
  final int trips;
  final int zoneCode;
  final String? zoneName;

  const SumaCardData({
    required this.trips,
    required this.zoneCode,
    required this.zoneName,
  });

  /// Etiqueta para mostrar: el nombre si lo tenemos, si no el código en hex.
  String get zoneLabel {
    if (zoneName != null && zoneName!.isNotEmpty) return zoneName!;
    return '0x${zoneCode.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }
}
