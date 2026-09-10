import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wesley_models.dart';
import 'wesley_repository.dart';

class SupabaseWesleyRepository implements WesleyRepository {
  SupabaseWesleyRepository(this.client);

  final SupabaseClient client;

  @override
  bool get isDemoMode => false;

  @override
  Future<SettingsBundle> loadSettings() async {
    final orgRows =
        await client.from('wesley_organization_settings').select().limit(1);
    final ruleRows =
        await client.from('wesley_rental_settings').select().limit(1);
    final spacesRows =
        await client.from('wesley_hall_spaces').select().order('name');
    final servicesRows = await client
        .from('wesley_services')
        .select()
        .order('display_order');
    final termsRows = await client
        .from('wesley_rental_terms')
        .select()
        .order('display_order');

    final org = orgRows.first;
    final rules = ruleRows.first;

    return SettingsBundle(
      organization: OrganizationSettings(
        churchName: org['church_name'] as String? ?? '',
        hallName: org['hall_name'] as String? ?? 'Wesley Hall',
        address: org['address'] as String? ?? '',
        phone: org['phone'] as String? ?? '',
        email: org['email'] as String? ?? '',
        managerName: org['manager_name'] as String? ?? '',
        managerTitle: org['manager_title'] as String? ?? '',
        organizationLogoPath: org['organization_logo_path'] as String?,
        managerSignaturePath: org['manager_signature_path'] as String?,
        autoIncludeManagerSignature:
            org['auto_include_manager_signature'] as bool? ?? true,
      ),
      rules: RentalRules(
        standardRentalHours:
            (rules['standard_rental_hours'] as num?)?.toInt() ?? 6,
        setupMinutesBefore:
            (rules['setup_minutes_before'] as num?)?.toInt() ?? 120,
        cleanupMinutesAfter:
            (rules['cleanup_minutes_after'] as num?)?.toInt() ?? 60,
        earliestAccess:
            rules['earliest_access']?.toString().substring(0, 5) ?? '08:00',
        latestVacate:
            rules['latest_vacate']?.toString().substring(0, 5) ?? '00:00',
        extraHourRate:
            (rules['extra_hour_rate'] as num?)?.toDouble() ?? 0,
        bookingDepositPercent:
            (rules['booking_deposit_percent'] as num?)?.toDouble() ?? 50,
        damageDepositAmount:
            (rules['damage_deposit_amount'] as num?)?.toDouble() ?? 500,
        chargeSetupTime: rules['charge_setup_time'] as bool? ?? false,
        chargeCleanupTime: rules['charge_cleanup_time'] as bool? ?? false,
        holdHours: (rules['hold_hours'] as num?)?.toInt() ?? 48,
      ),
      spaces: spacesRows
          .map<HallSpace>((m) => HallSpace(
                id: m['id'].toString(),
                name: m['name'] as String,
                baseRate: (m['base_rate'] as num?)?.toDouble() ?? 0,
                capacity: (m['capacity'] as num?)?.toInt(),
                active: m['active'] as bool? ?? true,
              ))
          .toList(),
      services: servicesRows
          .map<ServiceItem>((m) => ServiceItem(
                id: m['id'].toString(),
                name: m['name'] as String,
                pricingType: m['pricing_type'] as String? ?? 'flat',
                price: (m['price'] as num?)?.toDouble() ?? 0,
                active: m['active'] as bool? ?? true,
              ))
          .toList(),
      terms: termsRows
          .map<RentalTerm>((m) => RentalTerm(
                id: m['id'].toString(),
                text: m['term_text'] as String? ?? '',
                order: (m['display_order'] as num?)?.toInt() ?? 0,
                active: m['active'] as bool? ?? true,
              ))
          .toList(),
    );
  }

  @override
  Future<void> saveOrganization(OrganizationSettings settings) async {
    await client.from('wesley_organization_settings').upsert({
      'id': 1,
      'church_name': settings.churchName,
      'hall_name': settings.hallName,
      'address': settings.address,
      'phone': settings.phone,
      'email': settings.email,
      'manager_name': settings.managerName,
      'manager_title': settings.managerTitle,
      'organization_logo_path': settings.organizationLogoPath,
      'manager_signature_path': settings.managerSignaturePath,
      'auto_include_manager_signature': settings.autoIncludeManagerSignature,
    });
  }

  @override
  Future<void> saveRentalRules(RentalRules rules) async {
    await client.from('wesley_rental_settings').upsert({
      'id': 1,
      'standard_rental_hours': rules.standardRentalHours,
      'setup_minutes_before': rules.setupMinutesBefore,
      'cleanup_minutes_after': rules.cleanupMinutesAfter,
      'earliest_access': rules.earliestAccess,
      'latest_vacate': rules.latestVacate,
      'extra_hour_rate': rules.extraHourRate,
      'booking_deposit_percent': rules.bookingDepositPercent,
      'damage_deposit_amount': rules.damageDepositAmount,
      'charge_setup_time': rules.chargeSetupTime,
      'charge_cleanup_time': rules.chargeCleanupTime,
      'hold_hours': rules.holdHours,
    });
  }

  @override
  Future<void> saveTerms(List<RentalTerm> terms) async {
    for (final term in terms) {
      await client.from('wesley_rental_terms').upsert({
        'id': term.id,
        'term_text': term.text,
        'display_order': term.order,
        'active': term.active,
      });
    }
  }

  @override
  Future<void> saveSpaces(List<HallSpace> spaces) async {
    for (final space in spaces) {
      await client.from('wesley_hall_spaces').upsert({
        'id': space.id,
        'name': space.name,
        'base_rate': space.baseRate,
        'capacity': space.capacity,
        'active': space.active,
      });
    }
  }

  @override
  Future<void> saveServices(List<ServiceItem> services) async {
    for (var i = 0; i < services.length; i++) {
      final service = services[i];
      await client.from('wesley_services').upsert({
        'id': service.id,
        'name': service.name,
        'pricing_type': service.pricingType,
        'price': service.price,
        'active': service.active,
        'display_order': i + 1,
      });
    }
  }

  @override
  Future<void> deleteTerm(String id) async =>
      client.from('wesley_rental_terms').delete().eq('id', id);

  @override
  Future<void> deleteSpace(String id) async =>
      client.from('wesley_hall_spaces').delete().eq('id', id);

  @override
  Future<void> deleteService(String id) async =>
      client.from('wesley_services').delete().eq('id', id);

  Future<String?> _uploadImage(
    Uint8List bytes,
    String extension,
    String folder,
    String fileName,
  ) async {
    final path = '$folder/$fileName.$extension';
    await client.storage.from('wesley-hall-private').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _imageContentType(extension),
          ),
        );
    return path;
  }

  String _imageContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Future<String?> uploadOrganizationLogo(
          Uint8List bytes, String extension) =>
      _uploadImage(bytes, extension, 'organization-logos', 'church-logo');

  @override
  Future<Uint8List?> loadOrganizationLogo(String? path) async {
    if (path == null || path.isEmpty) return null;
    return client.storage.from('wesley-hall-private').download(path);
  }

  @override
  Future<String?> uploadManagerSignature(
          Uint8List bytes, String extension) =>
      _uploadImage(bytes, extension, 'manager-signatures', 'manager-signature');

  @override
  Future<Uint8List?> loadManagerSignature(String? path) async {
    if (path == null || path.isEmpty) return null;
    return client.storage.from('wesley-hall-private').download(path);
  }

  @override
  Future<String?> saveClientSignature(String bookingId, Uint8List bytes) async {
    final path = 'contracts/$bookingId/client-signature.png';
    await client.storage.from('wesley-hall-private').uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/png'),
        );
    await client.from('wesley_bookings').update({
      'client_signature_path': path,
      'client_signed_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
    return path;
  }

  @override
  Future<Uint8List?> loadClientSignature(String? path) async {
    if (path == null || path.isEmpty) return null;
    return client.storage.from('wesley-hall-private').download(path);
  }

  @override
  Future<String> uploadInspectionPhoto(
    String bookingId,
    Uint8List bytes,
    String extension,
  ) async {
    final safeExtension =
        extension.toLowerCase() == 'jpeg' ? 'jpg' : extension.toLowerCase();
    final path =
        'contracts/$bookingId/inspection/inspection-${DateTime.now().microsecondsSinceEpoch}.$safeExtension';
    await client.storage.from('wesley-hall-private').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _imageContentType(safeExtension),
          ),
        );
    return path;
  }

  @override
  Future<Uint8List?> loadInspectionPhoto(String path) async {
    if (path.isEmpty) return null;
    return client.storage.from('wesley-hall-private').download(path);
  }

  @override
  Future<List<Booking>> listBookings() async {
    final rows = await client
        .from('wesley_bookings')
        .select(
          '*, hall:wesley_hall_spaces(name), '
          'extras:wesley_booking_services(*, service:wesley_services(name)), '
          'payments:wesley_payments(*), '
          'inspection:wesley_booking_inspections(*)',
        )
        .order('event_start');

    return rows.map<Booking>((row) {
      final hall = row['hall'] as Map<String, dynamic>?;
      final extrasRaw = row['extras'] as List<dynamic>? ?? [];
      final paymentsRaw = row['payments'] as List<dynamic>? ?? [];
      final inspection = _inspectionFromRelation(row['inspection']);
      return Booking(
        id: row['id'].toString(),
        referenceNumber: row['reference_number'] as String,
        clientName: row['client_name'] as String,
        clientAddress: row['client_address'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
        email: row['email'] as String? ?? '',
        eventDate: DateTime.parse(row['event_date'] as String),
        eventStart: DateTime.parse(row['event_start'] as String),
        eventEnd: DateTime.parse(row['event_end'] as String),
        accessStart: DateTime.parse(row['access_start'] as String),
        vacateEnd: DateTime.parse(row['vacate_end'] as String),
        eventDetails: row['event_details'] as String? ?? '',
        guestCount: (row['guest_count'] as num?)?.toInt() ?? 0,
        hallSpaceId: row['hall_space_id'].toString(),
        hallSpaceName: hall?['name'] as String? ?? 'Hall',
        hallCharge: (row['hall_charge'] as num?)?.toDouble() ?? 0,
        extraTimeCharge:
            (row['extra_time_charge'] as num?)?.toDouble() ?? 0,
        status: row['status'] as String? ?? 'draft',
        reservationType:
            row['reservation_type'] as String? ?? 'external_rental',
        churchGroup: row['church_group'] as String? ?? '',
        bookingDepositPercent:
            (row['booking_deposit_percent'] as num?)?.toDouble() ?? 50,
        damageDepositRequired:
            (row['damage_deposit_required'] as num?)?.toDouble() ?? 500,
        notes: row['notes'] as String? ?? '',
        clientSignaturePath: row['client_signature_path'] as String?,
        clientSignedAt: row['client_signed_at'] == null
            ? null
            : DateTime.tryParse(row['client_signed_at'].toString()),
        holdExpiresAt: row['hold_expires_at'] == null
            ? null
            : DateTime.tryParse(row['hold_expires_at'].toString()),
        inspection: inspection,
        seriesKey: row['series_key'] as String?,
        seriesRule: row['series_rule'] as String?,
        seriesIndex: (row['series_index'] as num?)?.toInt(),
        seriesCount: (row['series_count'] as num?)?.toInt(),
        extras: extrasRaw.map<BookingExtra>((raw) {
          final item = raw as Map<String, dynamic>;
          final service = item['service'] as Map<String, dynamic>?;
          return BookingExtra(
            serviceId: item['service_id'].toString(),
            name: service?['name'] as String? ?? 'Service',
            quantity: (item['quantity'] as num?)?.toDouble() ?? 1,
            unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
          );
        }).toList(),
        payments: paymentsRaw.map<PaymentRecord>((raw) {
          final item = raw as Map<String, dynamic>;
          return PaymentRecord(
            id: item['id'].toString(),
            paymentType: item['payment_type'] as String? ?? 'other',
            amount: (item['amount'] as num?)?.toDouble() ?? 0,
            paymentDate:
                DateTime.tryParse(item['payment_date']?.toString() ?? '') ??
                    DateTime.now(),
            paymentMethod: item['payment_method'] as String? ?? '',
            paymentReference: item['payment_reference'] as String? ?? '',
            notes: item['notes'] as String? ?? '',
          );
        }).toList(),
      );
    }).toList();
  }

  DamageInspection? _inspectionFromRelation(dynamic raw) {
    Map<String, dynamic>? item;
    if (raw is Map<String, dynamic>) {
      item = raw;
    } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
      item = Map<String, dynamic>.from(raw.first as Map);
    }
    if (item == null) return null;
    return _inspectionFromMap(item);
  }

  DamageInspection _inspectionFromMap(Map<String, dynamic> item) {
    final photoPaths = (item['photo_paths'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    return DamageInspection(
      id: item['id'].toString(),
      bookingId: item['booking_id'].toString(),
      outcome: item['outcome'] as String? ?? 'no_damage',
      notes: item['notes'] as String? ?? '',
      damageDeduction: (item['damage_deduction'] as num?)?.toDouble() ?? 0,
      refundAmount: (item['refund_amount'] as num?)?.toDouble() ?? 0,
      photoPaths: photoPaths,
      inspectedAt:
          DateTime.tryParse(item['inspected_at']?.toString() ?? '') ??
              DateTime.now(),
      completedAt: item['completed_at'] == null
          ? null
          : DateTime.tryParse(item['completed_at'].toString()),
    );
  }

  @override
  Future<List<AuditEvent>> listAuditLog(String bookingId) async {
    final rows = await client
        .from('wesley_audit_log')
        .select('id, entity_type, action, summary, created_at')
        .eq('booking_id', bookingId)
        .order('created_at', ascending: false);

    return rows
        .map<AuditEvent>((row) => AuditEvent(
              id: row['id'].toString(),
              entityType: row['entity_type'] as String? ?? 'booking',
              action: row['action'] as String? ?? 'updated',
              summary: row['summary'] as String? ?? 'Booking activity',
              createdAt:
                  DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                      DateTime.now(),
            ))
        .toList();
  }

  Map<String, dynamic> _bookingValues(Booking booking) => {
        'client_name': booking.clientName,
        'client_address': booking.clientAddress,
        'phone': booking.phone,
        'email': booking.email,
        'event_date': _dateOnly(booking.eventDate),
        'event_start': booking.eventStart.toIso8601String(),
        'event_end': booking.eventEnd.toIso8601String(),
        'access_start': booking.accessStart.toIso8601String(),
        'vacate_end': booking.vacateEnd.toIso8601String(),
        'event_details': booking.eventDetails,
        'guest_count': booking.guestCount,
        'hall_space_id': booking.hallSpaceId,
        'hall_charge': booking.hallCharge,
        'extra_time_charge': booking.extraTimeCharge,
        'status': booking.status,
        'reservation_type': booking.reservationType,
        'church_group': booking.churchGroup,
        'booking_deposit_percent': booking.bookingDepositPercent,
        'damage_deposit_required': booking.damageDepositRequired,
        'notes': booking.notes,
        'hold_expires_at': booking.holdExpiresAt?.toIso8601String(),
        'series_key': booking.seriesKey,
        'series_rule': booking.seriesRule,
        'series_index': booking.seriesIndex,
        'series_count': booking.seriesCount,
      };

  @override
  Future<void> createBooking(Booking booking) async {
    final inserted = await client
        .from('wesley_bookings')
        .insert(_bookingValues(booking))
        .select('id')
        .single();

    final bookingId = inserted['id'].toString();
    if (!booking.isChurchUse && booking.extras.isNotEmpty) {
      await client.from('wesley_booking_services').insert(
            booking.extras
                .map((e) => {
                      'booking_id': bookingId,
                      'service_id': e.serviceId,
                      'quantity': e.quantity,
                      'unit_price': e.unitPrice,
                    })
                .toList(),
          );
    }
  }

  @override
  Future<void> updateBooking(Booking booking) async {
    await client
        .from('wesley_bookings')
        .update(_bookingValues(booking))
        .eq('id', booking.id);

    await client
        .from('wesley_booking_services')
        .delete()
        .eq('booking_id', booking.id);

    if (!booking.isChurchUse && booking.extras.isNotEmpty) {
      await client.from('wesley_booking_services').insert(
            booking.extras
                .map((e) => {
                      'booking_id': booking.id,
                      'service_id': e.serviceId,
                      'quantity': e.quantity,
                      'unit_price': e.unitPrice,
                    })
                .toList(),
          );
    }
  }

  @override
  Future<DamageInspection> saveDamageInspection(
    DamageInspection inspection,
  ) async {
    final saved = await client
        .from('wesley_booking_inspections')
        .upsert(
          {
            'booking_id': inspection.bookingId,
            'outcome': inspection.outcome,
            'notes': inspection.notes,
            'damage_deduction': inspection.damageDeduction,
            'refund_amount': inspection.refundAmount,
            'photo_paths': inspection.photoPaths,
            'inspected_at': inspection.inspectedAt.toIso8601String(),
            'completed_at': inspection.completedAt?.toIso8601String(),
          },
          onConflict: 'booking_id',
        )
        .select()
        .single();
    return _inspectionFromMap(saved);
  }

  @override
  Future<void> completeDamageInspection({
    required DamageInspection inspection,
    required double refundAmount,
  }) async {
    final completedAt = DateTime.now();
    await saveDamageInspection(
      DamageInspection(
        id: inspection.id,
        bookingId: inspection.bookingId,
        outcome: inspection.outcome,
        notes: inspection.notes,
        damageDeduction: inspection.damageDeduction,
        refundAmount: refundAmount,
        photoPaths: inspection.photoPaths,
        inspectedAt: inspection.inspectedAt,
        completedAt: completedAt,
      ),
    );

    if (refundAmount > 0) {
      final reference = 'INSPECTION-REFUND-${inspection.bookingId}';
      final existing = await client
          .from('wesley_payments')
          .select('id')
          .eq('booking_id', inspection.bookingId)
          .eq('payment_type', 'damage_refund')
          .eq('payment_reference', reference)
          .limit(1);
      if (existing.isEmpty) {
        await client.from('wesley_payments').insert({
          'booking_id': inspection.bookingId,
          'payment_type': 'damage_refund',
          'amount': refundAmount,
          'payment_method': 'Damage Deposit Refund',
          'payment_reference': reference,
          'payment_date': completedAt.toIso8601String(),
          'notes': inspection.damageDeduction > 0
              ? 'Damage deposit refund after deduction of \$${inspection.damageDeduction.toStringAsFixed(2)}.'
              : 'Damage deposit refunded after inspection.',
        });
      }
    }

    await client
        .from('wesley_bookings')
        .update({'status': 'completed', 'hold_expires_at': null})
        .eq('id', inspection.bookingId);
  }

  @override
  Future<void> addPayment(String bookingId, PaymentRecord payment) async {
    await client.from('wesley_payments').insert({
      'booking_id': bookingId,
      'payment_type': payment.paymentType,
      'amount': payment.amount,
      'payment_method': payment.paymentMethod,
      'payment_reference': payment.paymentReference,
      'payment_date': payment.paymentDate.toIso8601String(),
      'notes': payment.notes,
    });
  }

  @override
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await client
        .from('wesley_bookings')
        .update({'status': status}).eq('id', bookingId);
  }

  @override
  Future<bool> hasBookingConflict({
    required String hallSpaceId,
    required DateTime accessStart,
    required DateTime vacateEnd,
    String? excludeBookingId,
  }) async {
    final result = await client.rpc('wesley_has_booking_conflict', params: {
      'p_hall_space_id': hallSpaceId,
      'p_access_start': accessStart.toIso8601String(),
      'p_vacate_end': vacateEnd.toIso8601String(),
      'p_exclude_booking_id': excludeBookingId,
    });
    return result == true;
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
