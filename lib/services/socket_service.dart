import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../constants/app_config.dart';
import '../theme/app_theme.dart';
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

    // Remueve '/api' de la URL base para conectar al servidor raíz de WebSockets.
    final wsUrl = AppConfig.baseUrl.replaceAll('/api', '');
    
    _socket = IO.io(wsUrl, <String, dynamic>{
      // 'transports': ['websocket'], // Permite negociación (polling -> websocket) para mayor compatibilidad
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      debugPrint('[SocketService] ✅ Conectado a WebSockets (ID: ${_socket!.id})');
    });

    _socket!.onConnectError((err) {
      debugPrint('[SocketService] ❌ Error de conexión: $err');
    });

    _socket!.onError((err) {
      debugPrint('[SocketService] ⚠️ Error en Socket: $err');
    });

    _socket!.on('new_notice', (data) {
      debugPrint('[SocketService] 🔔 Nuevo aviso recibido: $data');
      try {
        final noticeData = data is String ? jsonDecode(data) : data;
        _showNoticeDialog(noticeData);
      } catch (e) {
        debugPrint('[SocketService] ❌ Error al procesar aviso: $e');
      }
    });

    _socket!.on('bus_attendees_update', (data) {
      debugPrint('[SocketService] 👥 Actualización de pasajeros: $data');
      _attendeesController.add(Map<String, dynamic>.from(data));
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[SocketService] 🔌 Desconectado de WebSockets: $reason');
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

  void _showNoticeDialog(dynamic data) {
    // 1. Verificar contexto disponible
    if (navigatorKey.currentContext == null) {
      debugPrint('[SocketService] ⚠️ No se puede mostrar diálogo: navigatorKey.currentContext es null');
      return;
    }
    
    // 2. Ejecutar tras el frame actual para evitar conflictos de construcción (build phase)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context == null) return;
      
      try {
        final l = AppLocalizations.of(context);
        if (l == null) {
          debugPrint('[SocketService] ⚠️ No se encontró AppLocalizations en el contexto actual');
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
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.campaign, color: AlzitransColors.burgundy, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            ),
            content: Column(
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
                Text(body),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l.understood),
              ),
            ],
          ),
        );
      } catch (e) {
        debugPrint('[SocketService] ❌ Error fatal mostrando diálogo: $e');
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
