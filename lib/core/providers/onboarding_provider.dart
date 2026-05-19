import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado reactivo de "onboarding completado".
///
/// Riverpod 3 eliminó `StateProvider` y `StateNotifier`, así que usamos el
/// patrón nuevo (Notifier + NotifierProvider). El estado inicial se inyecta
/// desde `main.dart` mediante `overrideWith()` antes de renderizar nada:
///
/// ```dart
/// ProviderContainer(overrides: [
///   onboardingCompletedProvider.overrideWith(
///     () => OnboardingCompletedNotifier(initial: !shouldShowOnboarding),
///   ),
/// ])
/// ```
///
/// Cuando `OnboardingScreen._completeOnboarding()` se ejecuta, llama a
/// `markCompleted()` para que el router rebuild deje pasar a `/`.
class OnboardingCompletedNotifier extends Notifier<bool> {
  /// Valor inicial — los providers se construyen "lazy" y este es el que se
  /// usa cuando el primer `watch` lee el estado. Si no se inyecta override,
  /// por defecto es `true` (asumimos onboarding hecho, para no romper apps
  /// antiguas que vienen de versiones previas a esta feature).
  final bool initial;

  OnboardingCompletedNotifier({this.initial = true});

  @override
  bool build() => initial;

  /// Marca el onboarding como completado y notifica a los listeners (el
  /// router watch-ea este estado y se rebuild → deja salir a `/`).
  void markCompleted() {
    state = true;
  }
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(
  OnboardingCompletedNotifier.new,
);
