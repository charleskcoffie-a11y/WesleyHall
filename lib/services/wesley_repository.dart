import 'dart:typed_data';

import '../models/wesley_models.dart';

abstract class WesleyRepository {
  bool get isDemoMode;

  Future<SettingsBundle> loadSettings();
  Future<void> saveOrganization(OrganizationSettings settings);
  Future<void> saveRentalRules(RentalRules rules);
  Future<void> saveTerms(List<RentalTerm> terms);
  Future<void> saveSpaces(List<HallSpace> spaces);
  Future<void> saveServices(List<ServiceItem> services);
  Future<void> deleteTerm(String id);
  Future<void> deleteSpace(String id);
  Future<void> deleteService(String id);

  Future<String?> uploadOrganizationLogo(Uint8List bytes, String extension);
  Future<Uint8List?> loadOrganizationLogo(String? path);
  Future<String?> uploadManagerSignature(Uint8List bytes, String extension);
  Future<Uint8List?> loadManagerSignature(String? path);
  Future<String?> saveClientSignature(String bookingId, Uint8List bytes);
  Future<Uint8List?> loadClientSignature(String? path);
  Future<String> uploadInspectionPhoto(
    String bookingId,
    Uint8List bytes,
    String extension,
  );
  Future<Uint8List?> loadInspectionPhoto(String path);

  Future<List<Booking>> listBookings();
  Future<List<AuditEvent>> listAuditLog(String bookingId);
  Future<void> createBooking(Booking booking);
  Future<void> updateBooking(Booking booking);
  Future<DamageInspection> saveDamageInspection(DamageInspection inspection);
  Future<void> completeDamageInspection({
    required DamageInspection inspection,
    required double refundAmount,
  });
  Future<void> addPayment(String bookingId, PaymentRecord payment);
  Future<void> updateBookingStatus(String bookingId, String status);
  Future<bool> hasBookingConflict({
    required String hallSpaceId,
    required DateTime accessStart,
    required DateTime vacateEnd,
    String? excludeBookingId,
  });
}
