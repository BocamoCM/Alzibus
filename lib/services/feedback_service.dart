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

  const FeedbackTicket({
    required this.id,
    required this.tag,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.lastAdminReplyId,
  });

  factory FeedbackTicket.fromJson(Map<String, dynamic> json) => FeedbackTicket(
        id: json['id'] as int,
        tag: json['tag'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        status: json['status'] as String? ?? 'Abierto',
        createdAt: DateTime.parse(json['created_at'] as String),
        lastAdminReplyId: json['last_admin_reply_id'] as int?,
      );
}

class FeedbackMessage {
  final int id;
  final int ticketId;
  final String message;
  final String senderType;
  final DateTime createdAt;

  const FeedbackMessage({
    required this.id,
    required this.ticketId,
    required this.message,
    required this.senderType,
    required this.createdAt,
  });

  bool get isFromAdmin => senderType == 'admin';

  factory FeedbackMessage.fromJson(Map<String, dynamic> json) => FeedbackMessage(
        id: json['id'] as int,
        ticketId: json['ticket_id'] as int,
        message: json['message'] as String,
        senderType: json['sender_type'] as String? ?? 'user',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
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

  Future<bool> replyToTicket(int ticketId, String message) async {
    try {
      final response = await ApiClient().post(
        '/feedback/$ticketId/reply',
        data: {'message': message},
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('[FeedbackService] Error respondiendo al ticket: $e');
      return false;
    }
  }
}
