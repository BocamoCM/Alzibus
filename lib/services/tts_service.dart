import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  TtsService();

  final FlutterTts _flutterTts = FlutterTts();
  bool _enabled = false;
  bool _isSpeaking = false;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  Future<void> init() async {
    if (_initialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('tts_enabled') ?? false;
      final locale = prefs.getString('app_locale') ?? 'es';

      // Configurar idioma inicial (sequential)
      await _setLanguageInternal(locale);
      
      // Speech rate más lento para mayor claridad
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Configuraciones para evitar deletreo
      await _flutterTts.setQueueMode(0); // Flush mode: interrumpir el anterior

      // Listeners de estado
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
      });
      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
      });
      
      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
    }
  }

  bool get isEnabled => _enabled;

  set isEnabled(bool value) {
    _enabled = value;
    _savePreference(value);
    if (!value) stop();
  }

  Future<void> _savePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tts_enabled', value);
  }

  Future<void> setLanguage(String languageCode) async {
    // Si no está inicializado, esperar a que lo esté o inicializar
    if (!_initialized) {
      await init();
    }
    await _setLanguageInternal(languageCode);
  }

  Future<void> _setLanguageInternal(String languageCode) async {
    String ttsCode = "es-ES";
    if (languageCode == "en") ttsCode = "en-US";
    if (languageCode == "ca") ttsCode = "ca-ES";

    // Cambiar idioma en el motor
    await _flutterTts.setLanguage(ttsCode);
    
    // Intentar forzar motor de Google TTS que pronuncia mejor
    // NOTA: setEngine puede causar re-inicialización y errores en release si se llama mucho
    try {
      await _flutterTts.setEngine('com.google.android.tts');
    } catch (_) {
      // Si no está disponible, usar el motor por defecto
    }
  }

  /// Limpia el texto para evitar que el TTS deletree abreviaciones o símbolos
  String _cleanTextForSpeech(String text) {
    String result = text;

    // --- Expansión de abreviaciones de nombres de paradas (orden importa: más largas primero) ---
    final Map<Pattern, String> replacements = {
      // Prefijos de calles/avenidas
      RegExp(r'\bAV\.\s*', caseSensitive: false): 'Avenida ',
      RegExp(r'\bPL\.\s*', caseSensitive: false): 'Plaza ',
      RegExp(r'\bPLAÇA\b', caseSensitive: false): 'Plaça ',
      RegExp(r'\bC\.\s*C\.\s*', caseSensitive: false): 'Centro Comercial ',
      RegExp(r'\bGV\.\s*', caseSensitive: false): 'Gran Vía ',
      RegExp(r'\bDR\.\s*', caseSensitive: false): 'Doctor ',
      RegExp(r'\bSTS\.\s*', caseSensitive: false): 'Sants ',
      RegExp(r'\bST\.\s*', caseSensitive: false): 'Sant ',
      // Instituciones/centros
      RegExp(r'\bCIPFP\b', caseSensitive: false): 'Centro Integrado ',
      RegExp(r'\bIES\b', caseSensitive: false): 'Instituto ',
      RegExp(r'\bCIPFP\b', caseSensitive: false): 'Centro Integrado ',
      RegExp(r'\bCOL\.\s*', caseSensitive: false): 'Colegio ',
      RegExp(r'\bSERVEF\b', caseSensitive: false): 'Servef ',
      // Líneas de bus
      RegExp(r'\bL1\b'): 'Línea uno',
      RegExp(r'\bL2\b'): 'Línea dos',
      RegExp(r'\bL3\b'): 'Línea tres',
      // Abreviaciones con números/unidades
      RegExp(r'(\d+)\s*min\b', caseSensitive: false): r'\1 minutos',
      RegExp(r'(\d+)\s*m\b'): r'\1 metros',
      // Caracteres especiales que provocan deletreo
      'Mª': 'María ',
      'Nª': 'Nuestra ',
      RegExp(r'[-–/\\]'): ', ',
      // Paréntesis con dirección
      RegExp(r'\(A\s*HOSPITAL\)', caseSensitive: false): ', dirección Hospital',
      RegExp(r'\(A\s*ESTACI[OÓ]N?\)', caseSensitive: false): ', dirección Estación',
      RegExp(r'\(A\s*ESTACIÓ\)', caseSensitive: false): ', dirección Estació',
      RegExp(r'[()]'): '',
    };

    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    // Convertir PALABRAS EN MAYÚSCULAS a Title Case para que TTS las lea como palabras
    // (evita deletreo de siglas que no están en el diccionario)
    result = result.replaceAllMapped(
      RegExp(r'\b[A-ZÁÉÍÓÚÜÑ]{3,}\b'),
      (match) {
        final word = match.group(0)!;
        // Dejar en mayúsculas solo si son siglas conocidas (2 letras)
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      },
    );

    // Normalizar espacios múltiples y puntos sueltos
    result = result
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'\s*,\s*,\s*'), ', ')
        .replaceAll(RegExp(r'\.\s*$'), '')
        .trim();

    return result;
  }


  Future<void> speak(String text) async {
    if (!_enabled) return;

    final cleanText = _cleanTextForSpeech(text);
    if (cleanText.isEmpty) return;

    // Parar cualquier lectura anterior antes de empezar
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
      // Pequeña pausa para asegurar que paró
      await Future.delayed(const Duration(milliseconds: 150));
    }

    _isSpeaking = true;
    await _flutterTts.speak(cleanText);
  }

  /// Habla el texto DESPUÉS de que termine la locución actual (no la interrumpe).
  /// Útil para encadenar frases: nombre de parada → "no hay buses".
  Future<void> speakQueued(String text) async {
    if (!_enabled) return;

    final cleanText = _cleanTextForSpeech(text);
    if (cleanText.isEmpty) return;

    // Si acabamos de llamar a speak(), puede que _isSpeaking tarde unos ms en ser true.
    // Damos un margen mínimo si se llama muy rápido.
    await Future.delayed(const Duration(milliseconds: 100));

    // Esperar a que termine la locución actual
    while (_isSpeaking) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _isSpeaking = true;
    await _flutterTts.speak(cleanText);
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _flutterTts.stop();
  }
}
