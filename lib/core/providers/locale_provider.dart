import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tts_provider.dart';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Intentar cargar el idioma guardado de forma síncrona si es posible (no lo es con SharedPreferences puro)
    // El valor inicial vendrá de main.dart si lo inyectamos o lo cargamos aquí.
    return const Locale('es');
  }

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_locale') ?? 'es';
    state = Locale(code);
    ref.read(ttsProvider).setLanguage(code);
  }

  Future<void> setLocale(Locale locale) async {
    if (state == locale) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale.languageCode);
    state = locale;
    
    // Actualizar TTS también
    ref.read(ttsProvider).setLanguage(locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});
