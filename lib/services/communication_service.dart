import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class CommunicationEntry {
  const CommunicationEntry({
    required this.id,
    required this.type,
    required this.recipientEmail,
    required this.subject,
    required this.status,
    required this.createdAt,
    this.attachmentName,
    this.errorMessage,
  });

  final String id;
  final String type;
  final String recipientEmail;
  final String subject;
  final String status;
  final DateTime createdAt;
  final String? attachmentName;
  final String? errorMessage;

  factory CommunicationEntry.fromMap(Map<String, dynamic> map) {
    return CommunicationEntry(
      id: map['id']?.toString() ?? '',
      type: map['communication_type']?.toString() ?? 'custom',
      recipientEmail: map['recipient_email']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      status: map['status']?.toString() ?? 'sent',
      createdAt: DateTime.tryParse(map['sent_at']?.toString() ?? '') ??
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      attachmentName: map['attachment_name']?.toString(),
      errorMessage: map['error_message']?.toString(),
    );
  }
}

class WesleyCommunicationService {
  WesleyCommunicationService(this.client);

  final SupabaseClient client;

  Future<List<CommunicationEntry>> listForBooking(String bookingId) async {
    final rows = await client
        .from('wesley_communication_log')
        .select(
          'id, communication_type, recipient_email, subject, status, attachment_name, error_message, sent_at, created_at',
        )
        .eq('booking_id', bookingId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => CommunicationEntry.fromMap(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<void> sendEmail({
    required String bookingId,
    required String communicationType,
    required String recipientEmail,
    required String subject,
    required String body,
    Uint8List? attachmentBytes,
    String? attachmentName,
    String attachmentContentType = 'application/pdf',
  }) async {
    final response = await client.functions.invoke(
      'wesley-send-email',
      body: {
        'booking_id': bookingId,
        'communication_type': communicationType,
        'recipient_email': recipientEmail,
        'subject': subject,
        'body': body,
        if (attachmentBytes != null)
          'attachment': {
            'name': attachmentName ?? 'attachment.pdf',
            'content_type': attachmentContentType,
            'base64': base64Encode(attachmentBytes),
          },
      },
    );

    final data = response.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['error'] != null) {
        throw Exception(map['error'].toString());
      }
    }

    if (response.status < 200 || response.status >= 300) {
      throw Exception('Email service returned ${response.status}.');
    }
  }
}
