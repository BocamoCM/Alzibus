import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alzitrans/l10n/app_localizations.dart';

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

  /// Las 4 páginas del onboarding. Se computan en build() porque los textos
  /// dependen de AppLocalizations (que requiere context). Si el usuario
  /// cambia el idioma a mitad del onboarding, las páginas se re-traducen
  /// automáticamente.
  List<_OnboardingPageData> _buildPages(AppLocalizations l) {
    return [
      _OnboardingPageData(
        albusState: AlbusState.happy,
        title: l.onboardingHelloTitle,
        body: l.onboardingHelloBody,
      ),
      _OnboardingPageData(
        albusState: AlbusState.talking,
        title: l.onboardingPlanTitle,
        body: l.onboardingPlanBody,
      ),
      _OnboardingPageData(
        albusState: AlbusState.thinking,
        title: l.onboardingShareTitle,
        body: l.onboardingShareBody,
      ),
      _OnboardingPageData(
        albusState: AlbusState.happy,
        title: l.onboardingReadyTitle,
        body: l.onboardingReadyBody,
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
    ref.read(onboardingCompletedProvider.notifier).markCompleted();
    if (!mounted) return;
    // Vamos a home — si el usuario no está logueado el redirect del router
    // lo enviará a /login automáticamente.
    const HomeRoute().go(context);
  }

  void _nextPage(int totalPages) {
    if (_currentPage >= totalPages - 1) {
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
    final l = AppLocalizations.of(context)!;
    final pages = _buildPages(l);
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
                    child: Text(
                      l.onboardingSkip,
                      style: const TextStyle(
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
                itemCount: pages.length,
                itemBuilder: (_, i) => _OnboardingPage(data: pages[i]),
              ),
            ),

            // Indicadores de página + botón siguiente
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pages.length, (i) {
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
                      onPressed: () => _nextPage(pages.length),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AlzitransColors.burgundy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage >= pages.length - 1
                            ? l.onboardingStart
                            : l.onboardingNext,
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
