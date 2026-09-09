import 'dart:typed_data';

import '../models/wesley_models.dart';
import 'wesley_repository.dart';

class DemoWesleyRepository implements WesleyRepository {
  DemoWesleyRepository()
      : settings = SettingsBundle(
          organization: const OrganizationSettings(
            churchName: 'THE METHODIST CHURCH GHANA',
            hallName: 'WESLEY HALL',
            address: '69 Milvan Dr., North York, Ontario M9L 1Y8',
            phone: '(416) 901-5900',
            email: 'info@gmct-ca.org',
            managerName: '',
            managerTitle: 'Hall Manager / Authorized Officer',
          ),
          rules: const RentalRules(
            standardRentalHours: 6,
            setupMinutesBefore: 120,
            cleanupMinutesAfter: 60,
            earliestAccess: '08:00',
            latestVacate: '00:00',
            extraHourRate: 0,
            bookingDepositPercent: 50,
            damageDepositAmount: 500,
            chargeSetupTime: false,
            chargeCleanupTime: false,
          ),
          spaces: const [
            HallSpace(id: 'full-hall', name: 'Full Hall', baseRate: 1500, capacity: 180),
            HallSpace(id: 'half-hall', name: 'Half Hall', baseRate: 800, capacity: 90),
          ],
          services: const [
            ServiceItem(id: 'kitchen-cooking', name: 'Kitchen - Cooking', pricingType: 'flat', price: 500),
            ServiceItem(id: 'warming-only', name: 'Warming of Food Only', pricingType: 'flat', price: 150),
            ServiceItem(id: 'projector', name: 'Projector', pricingType: 'flat', price: 150),
            ServiceItem(id: 'waiter', name: 'Waiter / Waitress', pricingType: 'hourly', price: 14),
          ],
          terms: const [
            RentalTerm(id: '1', order: 1, text: 'By signing this agreement and making the required 50% non-refundable booking deposit, the booking date is guaranteed. No reimbursement of the booking deposit shall be made if the client cancels.'),
            RentalTerm(id: '2', order: 2, text: 'A refundable damage deposit of $500.00 is required and will be refunded if no damage is caused.'),
            RentalTerm(id: '3', order: 3, text: 'The balance owing must be paid before the event date.'),
            RentalTerm(id: '4', order: 4, text: 'The building is non-smoking. No smoking is permitted inside the hall, kitchen, or washrooms.'),
            RentalTerm(id: '5', order: 5, text: 'Decorations must not be attached using nails, staples, tacks, or tape.'),
            RentalTerm(id: '6', order: 6, text: 'The venue shall not accept responsibility for property damage or injury.'),
            RentalTerm(id: '7', order: 7, text: 'If a false alarm call occurs, the client will reimburse the venue.'),
            RentalTerm(id: '8', order: 8, text: 'Security is required for events where alcohol is served.'),
            RentalTerm(id: '9', order: 9, text: 'No illegal activities are permitted.'),
          ],
        );

  SettingsBundle settings;
  final List<Booking> bookings = [];
  Uint8List? signature;
  Uint8List? organizationLogo;
  final Map<String, Uint8List> clientSignatures = {};

  @override
  bool get isDemoMode => true;

  @override
  Future<SettingsBundle> loadSettings() async => settings;

  @override
  Future<void> saveOrganization(OrganizationSettings value) async =>
      settings = settings.copyWith(organization: value);

  @override
  Future<void> saveRentalRules(RentalRules value) async =>
      settings = settings.copyWith(rules: value);

  @override
  Future<void> saveTerms(List<RentalTerm> value) async =>
      settings = settings.copyWith(terms: [...value]);

  @override
  Future<void> saveSpaces(List<HallSpace> value) async =>
      settings = settings.copyWith(spaces: [...value]);

  @override
  Future<void> saveServices(List<ServiceItem> value) async =>
      settings = settings.copyWith(services: [...value]);

  @override
  Future<void> deleteTerm(String id) async => settings = settings.copyWith(
        terms: settings.terms.where((e) => e.id != id).toList(),
      );

  @override
  Future<void> deleteSpace(String id) async => settings = settings.copyWith(
        spaces: settings.spaces.where((e) => e.id != id).toList(),
      );

  @override
  Future<void> deleteService(String id) async => settings = settings.copyWith(
        services: settings.services.where((e) => e.id != id).toList(),
      );

  @override
  Future<String?> uploadOrganizationLogo(Uint8List bytes, String extension) async {
    organizationLogo = bytes;
    return 'demo/church-logo.$extension';
  }

  @override
  Future<Uint8List?> loadOrganizationLogo(String? path) async => organizationLogo;

  @override
  Future<String?> uploadManagerSignature(Uint8List bytes, String extension) async {
    signature = bytes;
    return 'demo/manager-signature.$extension';
  }

  @override
  Future<Uint8List?> loadManagerSignature(String? path) async => signature;

  @override
  Future<String?> saveClientSignature(String bookingId, Uint8List bytes) async {
    clientSignatures[bookingId] = bytes;
    final i = bookings.indexWhere((b) => b.id == bookingId);
    if (i >= 0) {
      bookings[i] = bookings[i].copyWith(
        clientSignaturePath: 'demo/contracts/$bookingId/client-signature.png',
        clientSignedAt: DateTime.now(),
      );
    }
    return 'demo/contracts/$bookingId/client-signature.png';
  }

  @override
  Future<Uint8List?> loadClientSignature(String? path) async {
    if (path == null) return null;
    final parts = path.split('/');
    if (parts.length < 3) return null;
    return clientSignatures[parts[2]];
  }

  void seed() {
    if (bookings.isNotEmpty) return;
    final now = DateTime.now();
    DateTime day(int n) => DateTime(now.year, now.month, now.day + n);
    DateTime at(DateTime d, int h) => DateTime(d.year, d.month, d.day, h);
    final event = day(3);
    bookings.add(Booking(
      id: 'demo-1',
      referenceNumber: 'WH-${now.year}-000001',
      clientName: 'Ama Mensah',
      clientAddress: 'Toronto, ON',
      phone: '(416) 555-0198',
      email: 'ama@example.com',
      eventDate: event,
      eventStart: at(event, 17),
      eventEnd: at(event, 22),
      accessStart: at(event, 15),
      vacateEnd: at(event, 23),
      eventDetails: 'Wedding Reception',
      guestCount: 180,
      hallSpaceId: 'full-hall',
      hallSpaceName: 'Full Hall',
      hallCharge: 1500,
      extraTimeCharge: 0,
      status: 'confirmed',
      extras: const [BookingExtra(serviceId: 'projector', name: 'Projector', quantity: 1, unitPrice: 150)],
      bookingDepositPercent: 50,
      damageDepositRequired: 500,
      payments: [PaymentRecord(id: 'demo-pay-1', paymentType: 'booking_deposit', amount: 825, paymentDate: now, paymentMethod: 'E-Transfer')],
    ));
  }

  @override
  Future<List<Booking>> listBookings() async {
    seed();
    return [...bookings]..sort((a, b) => a.eventStart.compareTo(b.eventStart));
  }

  @override
  Future<void> createBooking(Booking booking) async => bookings.add(booking);

  @override
  Future<void> addPayment(String bookingId, PaymentRecord payment) async {
    final i = bookings.indexWhere((b) => b.id == bookingId);
    if (i < 0) return;
    final b = bookings[i];
    final payments = [...b.payments, payment];
    final deposit = payments
        .where((p) => p.paymentType == 'booking_deposit')
        .fold<double>(0, (t, p) => t + p.amount);
    final status = deposit >= b.requiredBookingDeposit
        ? 'confirmed'
        : 'awaiting_deposit';
    bookings[i] = b.copyWith(payments: payments, status: status);
  }

  @override
  Future<void> updateBookingStatus(String bookingId, String status) async {
    final i = bookings.indexWhere((b) => b.id == bookingId);
    if (i >= 0) bookings[i] = bookings[i].copyWith(status: status);
  }

  @override
  Future<bool> hasBookingConflict({
    required String hallSpaceId,
    required DateTime accessStart,
    required DateTime vacateEnd,
    String? excludeBookingId,
  }) async {
    seed();
    return bookings.any((b) {
      if (b.id == excludeBookingId || b.status == 'cancelled') return false;
      final sameResource = b.hallSpaceId == hallSpaceId ||
          b.hallSpaceId == 'full-hall' ||
          hallSpaceId == 'full-hall';
      return sameResource &&
          accessStart.isBefore(b.vacateEnd) &&
          vacateEnd.isAfter(b.accessStart);
    });
  }
}
