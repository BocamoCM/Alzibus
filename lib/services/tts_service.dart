import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _enabled = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('tts_enabled') ?? false;
    final locale = prefs.getString('app_locale') ?? 'es';
    
    await setLanguage(locale);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  bool get isEnabled => _enabled;

  set isEnabled(bool value) {
    _enabled = value;
    _savePreference(value);
  }

  Future<void> _savePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tts_enabled', value);
  }

  Future<void> setLanguage(String languageCode) async {
    // Convertir códigos de app (es, en, ca) a códigos TTS (es-ES, en-US, es-ES o ca-ES si disponible)
    String ttsCode = "es-ES";
    if (languageCode == "en") ttsCode = "en-US";
    if (languageCode == "ca") ttsCode = "ca-ES"; // O es-ES si ca-ES no está en el sistema
    
    await _flutterTts.setLanguage(ttsCode);
  }

  Future<void> speak(String text) async {
    if (!_enabled) return;
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
