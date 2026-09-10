import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class PaperApplicationService {
  PaperApplicationService(this.client);

  final SupabaseClient client;

  Future<String> uploadForBooking({
    required String bookingId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final normalized = extension.toLowerCase() == 'jpeg'
        ? 'jpg'
        : extension.toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        'contracts/$bookingId/paper-application-$timestamp.$normalized';

    final contentType = switch (normalized) {
      'pdf' => 'application/pdf',
      'jpg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };

    await client.storage.from('wesley-hall-private').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: contentType,
          ),
        );

    await client.from('wesley_contract_records').insert({
      'booking_id': bookingId,
      'storage_path': path,
    });

    return path;
  }
}
