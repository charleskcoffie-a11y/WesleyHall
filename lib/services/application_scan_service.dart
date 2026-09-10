import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ExtractedApplication {
  const ExtractedApplication({
    required this.clientName,
    required this.address,
    required this.phone,
    required this.email,
    required this.eventDate,
    required this.eventName,
    required this.guestCount,
    required this.startTime,
    required this.endTime,
    required this.hallSpaceName,
    required this.selectedServices,
    required this.notes,
    required this.confidence,
  });

  final String clientName;
  final String address;
  final String phone;
  final String email;
  final String eventDate;
  final String eventName;
  final int? guestCount;
  final String startTime;
  final String endTime;
  final String hallSpaceName;
  final List<String> selectedServices;
  final String notes;
  final Map<String, dynamic> confidence;

  factory ExtractedApplication.fromMap(Map<String, dynamic> map) {
    return ExtractedApplication(
      clientName: map['client_name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      eventDate: map['event_date']?.toString() ?? '',
      eventName: map['event_name']?.toString() ?? '',
      guestCount: map['guest_count'] is num
          ? (map['guest_count'] as num).toInt()
          : int.tryParse(map['guest_count']?.toString() ?? ''),
      startTime: map['start_time']?.toString() ?? '',
      endTime: map['end_time']?.toString() ?? '',
      hallSpaceName: map['hall_space_name']?.toString() ?? '',
      selectedServices: (map['selected_services'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      notes: map['notes']?.toString() ?? '',
      confidence: Map<String, dynamic>.from(
          map['confidence'] as Map? ?? const <String, dynamic>{}),
    );
  }
}

class ApplicationScanService {
  ApplicationScanService(this.client);

  final SupabaseClient client;

  Future<ExtractedApplication> extractImage({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final response = await client.functions.invoke(
      'wesley-extract-application',
      body: {
        'mime_type': mimeType,
        'image_base64': base64Encode(bytes),
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw Exception('Extraction service returned ${response.status}.');
    }

    final data = response.data;
    if (data is! Map) {
      throw Exception('Unexpected extraction response.');
    }
    final map = Map<String, dynamic>.from(data);
    if (map['error'] != null) {
      throw Exception(map['error'].toString());
    }
    final extracted = map['application'];
    if (extracted is! Map) {
      throw Exception('No application data was extracted.');
    }
    return ExtractedApplication.fromMap(
      Map<String, dynamic>.from(extracted),
    );
  }
}
