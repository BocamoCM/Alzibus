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
    await Stripe.instance.applySettings();
  }

  /// Proceso completo de pago para obtener Premium.
  Future<bool> purchasePremium(BuildContext context) async {
    try {
      final token = await _authService.getToken();
      if (token == null) throw Exception("Sesión no iniciada");

      // 1. Crear Intent en el backend
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/payments/create-intent'),
        headers: {
          ...AppConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'amount': 299}), // 2.99€
      );

      if (response.statusCode != 200) {
        throw Exception("Error del servidor al crear el pago");
      }

      final data = jsonDecode(response.body);
      final clientSecret = data['clientSecret'];

      // 2. Configurar Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Alzitrans Premium',
          style: ThemeMode.system,
          // ApplePay / GooglePay se pueden configurar aquí
        ),
      );

      // 3. Mostrar Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. Verificar éxito (el webhook del backend ya habrá actualizado la DB, 
      // pero refrescamos el perfil local para confirmación inmediata en la UI).
      final profile = await _authService.getProfile(token);
      if (profile != null && profile['isPremium'] == true) {
        AppConfig.showAds = false; // Desactivar anuncios en tiempo real
        return true;
      }

      return false;
    } on StripeException catch (e) {
      debugPrint('Error de Stripe: ${e.error.localizedMessage}');
      return false;
    } catch (e) {
      debugPrint('Error en purchasePremium: $e');
      return false;
    }
  }
}
