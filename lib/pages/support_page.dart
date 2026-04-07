import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../constants/app_config.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda y Soporte'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SECCIÓN FAQ
          const Text(
            'Preguntas Frecuentes',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AlzitransColors.burgundy),
          ),
          const SizedBox(height: 16),
          _buildFaqItem(
            '¿Cómo funcionan las alertas?',
            'Cuando activas una alerta en una llegada, la app monitoriza en segundo plano el tiempo restante. Te avisará cuando el bus esté a menos de la distancia configurada (ej: 80 metros) para que no lo pierdas.',
          ),
          _buildFaqItem(
            '¿Por qué pide ubicación "Siempre"?',
            'Para que las alertas funcionen aunque tengas el móvil en el bolsillo o estés usando otra app. Alzitrans solo usa tu ubicación cuando tienes una alerta activa para avisarte justo a tiempo.',
          ),
          _buildFaqItem(
            '¿Cómo recargar mi tarjeta Alzibus?',
            'Las tarjetas físicas de Alzibus se pueden recargar directamente en el autobús al subir o en los puntos de venta autorizados de la ciudad. Muy pronto podrás consultar tu saldo real aproximado desde la app.',
          ),
          _buildFaqItem(
            '¿Qué son los puntos y el Rank?',
            'Es nuestro sistema de Gamificación. Ganarás puntos por cada viaje registrado y por abrir la app diariamente. ¡Sube de Rank para demostrar que eres el usuario #1 de Alzitrans!',
          ),
          
          const SizedBox(height: 32),
          
          // SECCIÓN CONTACTO
          const Text(
            '¿Tienes sugerencias?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AlzitransColors.burgundy),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nos encanta escuchar vuestras ideas para mejorar Alzitrans. ¡Escríbenos!',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: () => _launchEmail(context),
            icon: const Icon(Icons.email),
            label: const Text('Enviar Propuesta de Mejora'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AlzitransColors.burgundy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // VERSIÓN
          const Center(
            child: Text(
              'Versión 5.1.2\nHecho con ❤️ en Alzira',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'bcarreres55@gmail.com', // Uso tu correo vinculado por seguridad
      query: encodeQueryParameters(<String, String>{
        'subject': 'Sugerencia Alzitrans - Mejora',
        'body': 'Hola,\n\nMe gustaría sugerir lo siguiente para Alzitrans:\n\n'
      }),
    );

    try {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido abrir la app de correo')),
        );
      }
    }
  }

  String encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
