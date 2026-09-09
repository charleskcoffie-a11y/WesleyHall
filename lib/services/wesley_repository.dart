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

  Future<String?> uploadOrganizationLogo(Uint8List bytes, String extension);
  Future<Uint8List?> loadOrganizationLogo(String? path);
  Future<String?> uploadManagerSignature(Uint8List bytes, String extension);
  Future<Uint8List?> loadManagerSignature(String? path);

  Future<List<Booking>> listBookings();
  Future<void> createBooking(Booking booking);
  Future<void> addPayment(String bookingId, PaymentRecord payment);
  Future<void> updateBookingStatus(String bookingId, String status);
  Future<bool> hasBookingConflict({
    required String hallSpaceId,
    required DateTime accessStart,
    required DateTime vacateEnd,
    String? excludeBookingId,
  });
}
