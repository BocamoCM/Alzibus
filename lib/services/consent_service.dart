import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Gestiona el consentimiento del usuario (GDPR/UMP) requerido por Google AdMob
/// para servir anuncios personalizados en EU. Sin esto, el eCPM en EU cae ~50%.
class ConsentService {
  ConsentService._();

  /// Solicita actualización de info de consentimiento y muestra el formulario
  /// si es necesario. Debe llamarse ANTES de inicializar MobileAds.
  ///
  /// IMPORTANTE: NO forzamos debugGeography aquí. Antes había
  ///   consentDebugSettings: kDebugMode ? ConsentDebugSettings(
  ///       debugGeography: DebugGeography.debugGeographyEea) : null
  /// que en debug obligaba a UMP a tratarte como si estuvieras en la EEA.
  /// Eso forzaba al SDK a CARGAR EL WEBVIEW del consent screen en cada
  /// arranque debug (porque debugGeography no respeta cache). Y si el
  /// usuario minimizaba antes de aceptar, el WebView del consent se
  /// llevaba la app entera por delante (OOM kill).
  /// Sin el debugGeography, UMP detecta la geografía real del dispositivo
  /// y solo abre el WebView cuando es necesario y solo una vez.
  static Future<void> gatherConsent() async {
    final completer = Completer<void>();

    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              debugPrint(
                'UMP: error mostrando formulario: ${formError.message}',
              );
            }
            if (!completer.isCompleted) completer.complete();
          });
        } catch (e) {
          debugPrint('UMP: excepción mostrando formulario: $e');
          if (!completer.isCompleted) completer.complete();
        }
      },
      (FormError error) {
        debugPrint('UMP: error obteniendo info: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  /// Indica si el SDK puede solicitar anuncios según el consentimiento actual.
  static Future<bool> canRequestAds() async {
    return ConsentInformation.instance.canRequestAds();
  }

  /// Permite al usuario reabrir el formulario de privacidad (Settings).
  static Future<void> showPrivacyOptionsForm() async {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((formError) {
      if (formError != null) {
        debugPrint('UMP: error en privacy options: ${formError.message}');
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// ¿Debe mostrarse la entrada de privacidad en Settings?
  static bool get isPrivacyOptionsRequired =>
      ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;
}
