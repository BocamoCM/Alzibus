import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';

class FeedbackTicket {
  final int id;
  final String tag;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;
  final int? lastAdminReplyId;
  // Mensajes del admin que aún no he leído (desde la última vez que abrí
  // este ticket). Sirve para mostrar un badge en la lista.
  final int unreadAdminCount;

  const FeedbackTicket({
    required this.id,
    required this.tag,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.lastAdminReplyId,
    this.unreadAdminCount = 0,
  });

  factory FeedbackTicket.fromJson(Map<String, dynamic> json) => FeedbackTicket(
        id: json['id'] as int,
        tag: json['tag'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        // Estado canónico en inglés (open/in_progress/resolved/dismissed).
        status: json['status'] as String? ?? 'open',
        createdAt: DateTime.parse(json['created_at'] as String),
        lastAdminReplyId: json['last_admin_reply_id'] as int?,
        unreadAdminCount: (json['unread_admin_count'] as num?)?.toInt() ?? 0,
      );
}

class FeedbackAttachment {
  final int id;
  final String originalName;
  final String mimeType;
  final int sizeBytes;

  const FeedbackAttachment({
    required this.id,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  factory FeedbackAttachment.fromJson(Map<String, dynamic> json) => FeedbackAttachment(
        id: (json['id'] as num).toInt(),
        originalName: json['original_name'] as String? ?? 'archivo',
        mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      );
}

class FeedbackMessage {
  final int id;
  final int ticketId;
  final String message;
  final String senderType;
  final DateTime createdAt;
  // Cuando el destinatario abrió el chat. Para mensajes míos (user) si está
  // a no-null significa que el admin lo ha leído. Para mensajes del admin
  // si está a no-null significa que YO lo leí.
  final DateTime? readAt;
  final List<FeedbackAttachment> attachments;

  const FeedbackMessage({
    required this.id,
    required this.ticketId,
    required this.message,
    required this.senderType,
    required this.createdAt,
    this.readAt,
    this.attachments = const [],
  });

  bool get isFromAdmin => senderType == 'admin';

  factory FeedbackMessage.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
    final list = rawAttachments is List
        ? rawAttachments
            .whereType<Map<String, dynamic>>()
            .map(FeedbackAttachment.fromJson)
            .toList()
        : const <FeedbackAttachment>[];
    return FeedbackMessage(
      id: json['id'] as int,
      ticketId: json['ticket_id'] as int,
      message: json['message'] as String? ?? '',
      senderType: json['sender_type'] as String? ?? 'user',
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
      attachments: list,
    );
  }
}

class FeedbackService {
  FeedbackService._privateConstructor();
  static final FeedbackService instance = FeedbackService._privateConstructor();

  List<FeedbackTicket> _tickets = [];
  List<FeedbackTicket> get tickets => List.unmodifiable(_tickets);

  Future<List<FeedbackTicket>> loadMyTickets() async {
    try {
      final response = await ApiClient().get('/feedback');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _tickets = data.map((e) => FeedbackTicket.fromJson(e as Map<String, dynamic>)).toList();
        return _tickets;
      }
    } catch (e) {
      debugPrint('[FeedbackService] Error cargando tickets: $e');
    }
    return [];
  }

  Future<FeedbackTicket?> createTicket(String tag, String title, String description) async {
    try {
      final response = await ApiClient().post(
        '/feedback',
        data: {
          'tag': tag,
          'title': title,
          'description': description,
        },
      );
      if (response.statusCode == 201) {
        final newTicket = FeedbackTicket.fromJson(response.data);
        _tickets.insert(0, newTicket);
        return newTicket;
      }
    } catch (e) {
      debugPrint('[FeedbackService] Error creando ticket: $e');
    }
    return null;
  }

  Future<List<FeedbackMessage>> getTicketMessages(int ticketId) async {
    try {
      final response = await ApiClient().get('/feedback/$ticketId/messages');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => FeedbackMessage.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[FeedbackService] Error cargando mensajes del ticket: $e');
    }
    return [];
  }

  // Responde a un ticket. Si `attachments` no está vacío manda multipart;
  // si no, JSON normal (más eficiente y compatible con clientes que
  // no acepten multipart).
  //
  // Devuelve true en éxito y un mensaje de error legible en caso contrario
  // (para mostrar "Archivo demasiado grande" etc. al usuario en vez de un
  // simple "false").
  Future<({bool ok, String? error})> replyToTicket(
    int ticketId,
    String message, {
    List<FeedbackAttachmentUpload> attachments = const [],
  }) async {
    try {
      if (attachments.isEmpty) {
        final response = await ApiClient().post(
          '/feedback/$ticketId/reply',
          data: {'message': message},
        );
        return (ok: response.statusCode == 201, error: null);
      }

      final formData = FormData();
      formData.fields.add(MapEntry('message', message));
      for (final att in attachments) {
        formData.files.add(MapEntry('attachments', await att.toMultipartFile()));
      }
      final response = await ApiClient().post(
        '/feedback/$ticketId/reply',
        data: formData,
      );
      return (ok: response.statusCode == 201, error: null);
    } on DioException catch (e) {
      final serverMsg = e.response?.data is Map
          ? (e.response!.data['error']?.toString())
          : null;
      debugPrint('[FeedbackService] Error respondiendo: ${e.message} / $serverMsg');
      return (ok: false, error: serverMsg ?? 'No se pudo enviar el mensaje');
    } catch (e) {
      debugPrint('[FeedbackService] Error respondiendo: $e');
      return (ok: false, error: 'No se pudo enviar el mensaje');
    }
  }

  // Notifica al backend que el usuario ha "leído" todos los mensajes del
  // admin de este ticket. Es idempotente — si no hay nada nuevo, no pasa nada.
  Future<void> markTicketRead(int ticketId) async {
    try {
      await ApiClient().post('/feedback/$ticketId/read');
    } catch (e) {
      // Silencioso: la marca de leído no es crítica para que el usuario
      // siga conversando.
      debugPrint('[FeedbackService] No se pudo marcar como leído: $e');
    }
  }

  // URL absoluta a la que apuntar para descargar un adjunto. Se usa con
  // ApiClient ya que necesita el header Authorization.
  String attachmentUrl(int attachmentId) => '/feedback/attachments/$attachmentId';
}

/// Wrapper sencillo para encapsular un archivo a subir, soportando tanto
/// la ruta del sistema (móvil) como bytes en memoria (web).
class FeedbackAttachmentUpload {
  final String filename;
  final String? filePath;
  final List<int>? bytes;

  const FeedbackAttachmentUpload._({
    required this.filename,
    this.filePath,
    this.bytes,
  });

  factory FeedbackAttachmentUpload.fromPath(String path, {String? filename}) =>
      FeedbackAttachmentUpload._(
        filename: filename ?? path.split(RegExp(r'[\\/]')).last,
        filePath: path,
      );

  factory FeedbackAttachmentUpload.fromBytes(List<int> bytes, String filename) =>
      FeedbackAttachmentUpload._(filename: filename, bytes: bytes);

  Future<MultipartFile> toMultipartFile() async {
    if (bytes != null) {
      return MultipartFile.fromBytes(bytes!, filename: filename);
    }
    return MultipartFile.fromFile(filePath!, filename: filename);
  }
}
