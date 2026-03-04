import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import '../constants/app_config.dart';
import 'auth_service.dart';

class PremiumService {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  final AuthService _authService = AuthService();

  /// Inicializa Stripe con la clave pública.
  /// TODO: Mover 'pk_test_...' a AppConfig y usar la de producción al desplegar.
  Future<void> init() async {
    Stripe.publishableKey = "pk_test_51QuA6pG64rU91p80T7FmAn4R5OqK15G2M7mC3Oq8zQ8J3F4N9D2m6W8F3P9U0Q5M2R1S7T3V5W8B7C9L0";
    try {
      await Stripe.instance.applySettings();
    } catch (e) {
      debugPrint('Error en Stripe.applySettings: $e');
    }
  }

  /// Proceso completo de pago para obtener Premium.
  Future<bool> purchasePremium(BuildContext context) async {
    try {
      debugPrint('PremiumService: Iniciando compra...');
      final token = await _authService.getToken();
      if (token == null) {
        debugPrint('PremiumService: Error - Sesión no iniciada');
        throw Exception("Sesión no iniciada");
      }

      // 1. Crear Intent en el backend
      debugPrint('PremiumService: Creando PaymentIntent en el backend...');
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/payments/create-intent'),
        headers: {
          ...AppConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'amount': 299}), // 2.99€
      );

      debugPrint('PremiumService: Respuesta backend: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('PremiumService: Error backend: ${response.body}');
        throw Exception("Error del servidor al crear el pago");
      }

      final data = jsonDecode(response.body);
      final clientSecret = data['clientSecret'];
      debugPrint('PremiumService: ClientSecret recibido.');

      // 2. Configurar Payment Sheet
      debugPrint('PremiumService: Inicializando Payment Sheet...');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Alzitrans Premium',
          style: ThemeMode.system,
        ),
      );

      // 3. Mostrar Payment Sheet
      debugPrint('PremiumService: Presentando Payment Sheet...');
      await Stripe.instance.presentPaymentSheet();
      debugPrint('PremiumService: Payment Sheet completado.');

      // 3.5. Confirmación Manual (Nueva: No depende de webhooks)
      debugPrint('PremiumService: Enviando confirmación manual al backend...');
      try {
        final confirmRes = await http.post(
          Uri.parse('${AppConfig.baseUrl}/payments/confirm-manual'),
          headers: {
            ...AppConfig.headers,
            'Authorization': 'Bearer $token',
          },
        );
        debugPrint('PremiumService: Resultado confirmación manual: ${confirmRes.statusCode}');
      } catch (e) {
        debugPrint('PremiumService: Fallo en confirmación manual (continuando): $e');
      }

      // 4. Verificar éxito
      debugPrint('PremiumService: Verificando estado premium...');
      final profile = await _authService.getProfile(token);
      if (profile != null && profile['isPremium'] == true) {
        debugPrint('PremiumService: ¡Compra exitosa!');
        AppConfig.showAds = false;
        return true;
      }

      debugPrint('PremiumService: El perfil no marca premium aún.');
      return false;
    } on StripeException catch (e) {
      debugPrint('PremiumService: Error de Stripe: ${e.error.localizedMessage}');
      return false;
    } catch (e) {
      debugPrint('PremiumService: Error inesperado: $e');
      return false;
    }
  }
}
