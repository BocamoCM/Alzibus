import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider que gestiona el Modo Personas Mayores globalmente.
/// Usa InheritedNotifier para notificar a toda la árbol de widgets.
class ElderlyModeNotifier extends ChangeNotifier {
  bool _enabled = false;

  bool get enabled => _enabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('elderly_mode_enabled') ?? false;
    notifyListeners();
  }

  Future<void> toggle(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('elderly_mode_enabled', value);
    notifyListeners();
  }
}

/// Singleton global accesible desde toda la app
final elderlyModeNotifier = ElderlyModeNotifier();
