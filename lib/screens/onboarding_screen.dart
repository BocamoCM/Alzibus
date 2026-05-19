import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/onboarding_provider.dart';
import '../core/router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/albus_mascot.dart';

/// Key de SharedPreferences que indica si el usuario ya completó el
/// onboarding. Si está a true, no se muestra al arrancar la app.
const String kOnboardingCompletedKey = 'onboarding_completed_v1';

/// Onboarding de 4 páginas con Albus introduciendo la app a usuarios nuevos.
///
/// Se muestra una sola vez (la primera apertura tras instalar). El usuario
/// puede saltarlo en cualquier momento con "Saltar". Al terminar se navega
/// a `/` (home).
///
/// La key tiene sufijo `_v1` por si en el futuro queremos forzar un nuevo
/// onboarding tras un rediseño grande — basta con cambiarla a `_v2`.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  late final List<_OnboardingPageData> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _OnboardingPageData(
        albusState: AlbusState.happy,
        title: '¡Hola! Soy Albus 🚌',
        body: 'Soy tu mascota y guía dentro de Alzitrans, la app del bus '
            'de Alzira. Te voy a contar en 30 segundos qué puedes hacer.',
      ),
      _OnboardingPageData(
        albusState: AlbusState.talking,
        title: 'Planifica tus rutas',
        body: 'Dime de dónde sales y a dónde vas y te explico paso a paso '
            'qué bus coger, dónde bajarte y cuánto tarda. Te muestro hasta '
            '3 alternativas.',
      ),
      _OnboardingPageData(
        albusState: AlbusState.thinking,
        title: 'Comparte tu viaje',
        body: 'Manda un enlace a tu familia o amigos y verán tu posición '
            'en tiempo real en un mapa hasta que llegues. Sin que tengan '
            'que instalar nada.',
      ),
      _OnboardingPageData(
        albusState: AlbusState.happy,
        title: '¡Listos!',
        body: 'Pulsa el botón "Planifica con Albus" en la pantalla '
            'principal para empezar. Estoy aquí si me necesitas.',
        isLast: true,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOnboardingCompletedKey, true);
    } catch (_) {/* silencioso */}
    // Avisamos al provider para que el router se rebuild y deje pasar a
    // la siguiente ruta (login o home).
    ref.read(onboardingCompletedProvider.notifier).state = true;
    if (!mounted) return;
    // Vamos a home — si el usuario no está logueado el redirect del router
    // lo enviará a /login automáticamente.
    const HomeRoute().go(context);
  }

  void _nextPage() {
    if (_currentPage >= _pages.length - 1) {
      _completeOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AlzitransColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header con botón "Saltar" en la esquina derecha
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text(
                      'Saltar',
                      style: TextStyle(
                        color: AlzitransColors.burgundy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PageView con las 4 páginas
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),

            // Indicadores de página + botón siguiente
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AlzitransColors.burgundy
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AlzitransColors.burgundy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage >= _pages.length - 1 ? 'Empezar' : 'Siguiente',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final AlbusState albusState;
  final String title;
  final String body;
  final bool isLast;
  const _OnboardingPageData({
    required this.albusState,
    required this.title,
    required this.body,
    this.isLast = false,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AlbusMascot(state: data.albusState, size: 200),
          const SizedBox(height: 32),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AlzitransColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AlzitransColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
