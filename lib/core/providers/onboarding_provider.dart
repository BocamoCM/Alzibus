import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado reactivo de "onboarding completado".
///
/// Inicialmente `true` para no romper si nadie lo sobrescribe (apps que
/// vienen de versiones anteriores siguen funcionando). En `main.dart` se
/// sobrescribe con el valor real de SharedPreferences antes de que se
/// renderice nada.
///
/// Cuando `OnboardingScreen._completeOnboarding()` se ejecuta, además de
/// escribir en prefs, actualiza este StateProvider para que el router se
/// rebuild y deje pasar a `/`.
final onboardingCompletedProvider = StateProvider<bool>((ref) => true);
