import 'package:flutter/material.dart';
import 'package:alzitrans/constants/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationPermissionDialog extends StatelessWidget {
  const LocationPermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
          'Permiso de ubicación en segundo plano',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Alzitrans recopila datos de ubicación para permitir la detección de paradas cercanas y alertas de llegada en tiempo real, incluso cuando la aplicación está cerrada o no se está utilizando.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 15),
          const Text(
            'Tu ubicación no se comparte con terceros y se usa exclusivamente para mejorar la precisión de los avisos.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => launchUrl(Uri.parse(AppConfig.privacyPolicyUrl)),
            child: const Text(
              'Ver Política de Privacidad',
              style: TextStyle(
                color: Color(0xFF4A1D3D),
                decoration: TextDecoration.underline,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            '¿Deseas permitir el acceso a tu ubicación en segundo plano?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No permitir', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A1D3D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Permitir', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
