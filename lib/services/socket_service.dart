import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../constants/app_config.dart';
import '../theme/app_theme.dart';
import '../core/network/api_client.dart';
import '../main.dart'; // Para navigatorKey

/// SocketService — Avisos en tiempo real mediante polling HTTP.
///
/// La librería socket_io_client para Dart tiene un bug conocido donde
/// el puerto de la URL siempre se interpreta como :0, haciendo imposible
/// la conexión WebSocket. Como alternativa robusta, esta clase implementa
/// polling HTTP cada 30 segundos usando la infraestructura HTTP existente
/// que ya funciona correctamente.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  final _attendeesController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onAttendeesUpdate => _attendeesController.stream;

  Timer? _pollingTimer;
  int? _lastSeenNoticeId;
  bool _isPolling = false;

  /// Inicia el polling de avisos. Llama a este método cuando el usuario
  /// ha iniciado sesión y la app está activa.
  void initialize() {
    if (_isPolling) return;
    _isPolling = true;

    debugPrint('[SocketService] ✅ Iniciando polling de avisos cada 30s...');
    _sendDebugLog('Polling de avisos HTTP iniciado correctamente.');

    // Lanzar la primera consulta inmediatamente
    _checkForNewNotices();

    // Repetir cada 30 segundos
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkForNewNotices();
    });
  }

  /// Consulta el endpoint de avisos y muestra un popup si hay uno nuevo.
  Future<void> _checkForNewNotices() async {
    try {
      final response = await ApiClient().get('/notices');
      if (response == null) return;

      List<dynamic> notices;
      if (response is List) {
        notices = response;
      } else if (response is Map && response['notices'] != null) {
        notices = response['notices'] as List;
      } else {
        return;
      }

      if (notices.isEmpty) return;

      // Obtener el aviso más reciente (asumimos que vienen ordenados DESC)
      final latestNotice = notices.first as Map<String, dynamic>;
      final latestId = latestNotice['id'] as int?;

      if (latestId == null) return;

      // Si es la primera consulta, guardar el ID actual sin mostrar popup
      // (no queremos mostrar avisos viejos al iniciar)
      if (_lastSeenNoticeId == null) {
        _lastSeenNoticeId = latestId;
        debugPrint('[SocketService] 🔄 ID inicial de avisos guardado: $latestId');
        return;
      }

      // Si hay un aviso más nuevo, mostrarlo
      if (latestId > _lastSeenNoticeId!) {
        _lastSeenNoticeId = latestId;
        debugPrint('[SocketService] 🔔 Nuevo aviso detectado (ID: $latestId): ${latestNotice['title']}');
        _sendDebugLog('Nuevo aviso detectado por polling: ${latestNotice['title']}', data: latestNotice);
        _showNoticeDialog(latestNotice);
      }
    } catch (e) {
      debugPrint('[SocketService] ⚠️ Error en polling de avisos: $e');
    }
  }

  /// Envía un log de diagnóstico al servidor para que aparezca en Discord.
  Future<void> _sendDebugLog(String message, {dynamic data}) async {
    try {
      await ApiClient().post('/debug/mobile-log', data: {
        'message': '[MOBILE] $message',
        'data': data ?? {},
      });
    } catch (e) {
      debugPrint('[SocketService] Fallo al enviar debug log: $e');
    }
  }

  void _showNoticeDialog(dynamic data) {
    // 1. Verificar contexto disponible con reintento si es null
    if (navigatorKey.currentContext == null) {
      debugPrint('[SocketService] ⚠️ Contexto null, reintentando mostrar diálogo en 1s...');
      Future.delayed(const Duration(seconds: 1), () => _showNoticeDialog(data));
      return;
    }

    // 2. Ejecutar tras el frame actual para evitar conflictos de construcción
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      try {
        final l = AppLocalizations.of(context);
        if (l == null) {
          debugPrint('[SocketService] ⚠️ No se encontró AppLocalizations en este frame. Reintentando...');
          Future.delayed(const Duration(seconds: 1), () => _showNoticeDialog(data));
          return;
        }

        // Extraer datos del aviso de forma segura
        final title = data['title']?.toString() ?? l.newNoticePopupTitle;
        final body = data['body']?.toString() ?? '';
        final line = data['line'];

        debugPrint('[SocketService] 🚀 Mostrando diálogo de aviso: $title');

        showDialog(
          context: context,
          barrierDismissible: true,
          useRootNavigator: true, // Asegurar que sale sobre cualquier otra pantalla/overlay
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.campaign, color: AlzitransColors.burgundy, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (line != null && line.toString().trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AlzitransColors.coral,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${l.line} $line',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(body, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l.understood, style: const TextStyle(color: AlzitransColors.burgundy, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } catch (e) {
        debugPrint('[SocketService] ❌ Error fatal mostrando diálogo: $e');
        _sendDebugLog('Fallo al mostrar el diálogo en el móvil: $e');
      }
    });
  }

  // Mantener compatibilidad con el código existente que usa emitAttendBus
  void emitAttendBus(String line, String stopId) {
    // El polling no requiere emitir eventos, se mantiene por compatibilidad
    debugPrint('[SocketService] emitAttendBus llamado (modo polling): line=$line, stop=$stopId');
  }

  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    if (!_attendeesController.isClosed) {
      _attendeesController.close();
    }
  }
}
