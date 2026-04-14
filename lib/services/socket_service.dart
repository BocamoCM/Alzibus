import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../constants/app_config.dart';
import '../theme/app_theme.dart';
import '../core/network/api_client.dart';
import '../main.dart'; // Para navigatorKey

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  final _attendeesController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onAttendeesUpdate => _attendeesController.stream;

  void initialize() {
    if (_socket != null && _socket!.connected) return;

    // Remueve '/api' y slashes finales para evitar errores de construcción de URL en el cliente
    final wsUrl = AppConfig.baseUrl.replaceAll('/api', '').trim().replaceAll(RegExp(r'/$'), '');
    
    debugPrint('[SocketService] 🔄 Iniciando conexión a: $wsUrl');
    _socket = IO.io(wsUrl, <String, dynamic>{
      'transports': ['websocket'], // Forzar websocket directo para evitar conflictos de upgrade con polling
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': double.infinity,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 5000,
      'timeout': 45000,
      'forceNew': true,
      'path': '/realtime', // TÚNEL REAL: Ruta dedicada, pública y segura
    });

    _socket!.onConnect((_) {
      debugPrint('[SocketService] ✅ Conectado a WebSockets (ID: ${_socket!.id})');
      _sendDebugLog('App móvil conectada exitosamente a WebSockets.');
    });

    _socket!.onConnectError((err) {
      debugPrint('[SocketService] ❌ Error de conexión ($wsUrl): $err');
      // ENVIAR DATA DETALLADA A DISCORD
      _sendDebugLog('ERROR DE CONEXIÓN WebSocket a URL ($wsUrl): $err');
    });

    _socket!.onError((err) {
      debugPrint('[SocketService] ⚠️ Error en Socket: $err');
    });

    _socket!.on('new_notice', (data) {
      debugPrint('[SocketService] 🔔 Nuevo aviso recibido: $data');
      try {
        final noticeData = data is String ? jsonDecode(data) : data;
        
        // PUENTE DE DIAGNÓSTICO: Notificar a Discord que el evento LLEGÓ al móvil
        _sendDebugLog('Aviso recibido vía WebSocket en el móvil.', data: noticeData);
        
        _showNoticeDialog(noticeData);
      } catch (e) {
        debugPrint('[SocketService] ❌ Error al procesar aviso: $e');
        _sendDebugLog('Error al procesar el aviso recibido en el móvil: $e');
      }
    });

    _socket!.on('bus_attendees_update', (data) {
      debugPrint('[SocketService] 👥 Actualización de pasajeros: $data');
      _attendeesController.add(Map<String, dynamic>.from(data));
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[SocketService] 🔌 Desconectado de WebSockets: $reason');
      _sendDebugLog('Desconectado de WebSockets. Razón: $reason');
      // Intentar reconectar si la desconexión fue inesperada
      if (reason != 'io client disconnect') {
        Future.delayed(const Duration(seconds: 5), () {
          if (_socket != null && !_socket!.connected) {
            debugPrint('[SocketService] 🔄 Intentando reconexión automática...');
            _socket!.connect();
          }
        });
      }
    });
  }

  /// Envía un log de diagnóstico al servidor para que aparezca en Discord.
  Future<void> _sendDebugLog(String message, {dynamic data}) async {
    try {
      // Usar ApiClient para enviar el log de depuración al backend
      // El endpoint /api/debug/mobile-log reenviará esto a Discord
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

  void emitAttendBus(String line, String stopId) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('attend_bus', {
      'line': line,
      'stopId': stopId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    // Fix #1: Cerrar el StreamController para liberar la memoria correctamente
    if (!_attendeesController.isClosed) {
      _attendeesController.close();
    }
  }
}
