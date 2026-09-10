import 'dart:typed_data';

class OrganizationSettings {
  const OrganizationSettings({
    required this.churchName,
    required this.hallName,
    required this.address,
    required this.phone,
    required this.email,
    required this.managerName,
    required this.managerTitle,
    this.organizationLogoPath,
    this.organizationLogoBytes,
    this.managerSignaturePath,
    this.managerSignatureBytes,
    this.autoIncludeManagerSignature = true,
  });

  final String churchName;
  final String hallName;
  final String address;
  final String phone;
  final String email;
  final String managerName;
  final String managerTitle;
  final String? organizationLogoPath;
  final Uint8List? organizationLogoBytes;
  final String? managerSignaturePath;
  final Uint8List? managerSignatureBytes;
  final bool autoIncludeManagerSignature;

  OrganizationSettings copyWith({
    String? churchName,
    String? hallName,
    String? address,
    String? phone,
    String? email,
    String? managerName,
    String? managerTitle,
    String? organizationLogoPath,
    Uint8List? organizationLogoBytes,
    String? managerSignaturePath,
    Uint8List? managerSignatureBytes,
    bool? autoIncludeManagerSignature,
  }) {
    return OrganizationSettings(
      churchName: churchName ?? this.churchName,
      hallName: hallName ?? this.hallName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      managerName: managerName ?? this.managerName,
      managerTitle: managerTitle ?? this.managerTitle,
      organizationLogoPath: organizationLogoPath ?? this.organizationLogoPath,
      organizationLogoBytes:
          organizationLogoBytes ?? this.organizationLogoBytes,
      managerSignaturePath: managerSignaturePath ?? this.managerSignaturePath,
      managerSignatureBytes:
          managerSignatureBytes ?? this.managerSignatureBytes,
      autoIncludeManagerSignature:
          autoIncludeManagerSignature ?? this.autoIncludeManagerSignature,
    );
  }
}

class RentalRules {
  const RentalRules({
    required this.standardRentalHours,
    required this.setupMinutesBefore,
    required this.cleanupMinutesAfter,
    required this.earliestAccess,
    required this.latestVacate,
    required this.extraHourRate,
    required this.bookingDepositPercent,
    required this.damageDepositAmount,
    required this.chargeSetupTime,
    required this.chargeCleanupTime,
    this.holdHours = 48,
  });

  final int standardRentalHours;
  final int setupMinutesBefore;
  final int cleanupMinutesAfter;
  final String earliestAccess;
  final String latestVacate;
  final double extraHourRate;
  final double bookingDepositPercent;
  final double damageDepositAmount;
  final bool chargeSetupTime;
  final bool chargeCleanupTime;
  final int holdHours;
}

class HallSpace {
  const HallSpace({
    required this.id,
    required this.name,
    required this.baseRate,
    required this.capacity,
    this.active = true,
  });

  final String id;
  final String name;
  final double baseRate;
  final int? capacity;
  final bool active;
}

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.pricingType,
    required this.price,
    this.active = true,
  });

  final String id;
  final String name;
  final String pricingType;
  final double price;
  final bool active;
}

class RentalTerm {
  const RentalTerm({
    required this.id,
    required this.text,
    required this.order,
    this.active = true,
  });

  final String id;
  final String text;
  final int order;
  final bool active;
}

class BookingExtra {
  const BookingExtra({
    required this.serviceId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String serviceId;
  final String name;
  final double quantity;
  final double unitPrice;

  double get total => quantity * unitPrice;
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.paymentType,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod = '',
    this.paymentReference = '',
    this.notes = '',
  });

  final String id;
  final String paymentType;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String paymentReference;
  final String notes;
}

class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.entityType,
    required this.action,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String entityType;
  final String action;
  final String summary;
  final DateTime createdAt;
}

class DamageInspection {
  const DamageInspection({
    required this.id,
    required this.bookingId,
    required this.outcome,
    required this.notes,
    required this.damageDeduction,
    required this.refundAmount,
    required this.photoPaths,
    required this.inspectedAt,
    this.completedAt,
  });

  final String id;
  final String bookingId;
  final String outcome;
  final String notes;
  final double damageDeduction;
  final double refundAmount;
  final List<String> photoPaths;
  final DateTime inspectedAt;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;
  bool get hasDamage => outcome == 'damage_found';
}

class Booking {
  const Booking({
    required this.id,
    required this.referenceNumber,
    required this.clientName,
    required this.clientAddress,
    required this.phone,
    required this.email,
    required this.eventDate,
    required this.eventStart,
    required this.eventEnd,
    required this.accessStart,
    required this.vacateEnd,
    required this.eventDetails,
    required this.guestCount,
    required this.hallSpaceId,
    required this.hallSpaceName,
    required this.hallCharge,
    required this.extraTimeCharge,
    required this.status,
    required this.extras,
    this.reservationType = 'external_rental',
    this.churchGroup = '',
    this.bookingDepositPercent = 50,
    this.damageDepositRequired = 500,
    this.payments = const [],
    this.notes = '',
    this.clientSignaturePath,
    this.clientSignedAt,
    this.holdExpiresAt,
    this.inspection,
    this.seriesKey,
    this.seriesRule,
    this.seriesIndex,
    this.seriesCount,
  });

  final String id;
  final String referenceNumber;
  final String clientName;
  final String clientAddress;
  final String phone;
  final String email;
  final DateTime eventDate;
  final DateTime eventStart;
  final DateTime eventEnd;
  final DateTime accessStart;
  final DateTime vacateEnd;
  final String eventDetails;
  final int guestCount;
  final String hallSpaceId;
  final String hallSpaceName;
  final double hallCharge;
  final double extraTimeCharge;
  final String status;
  final List<BookingExtra> extras;
  final String reservationType;
  final String churchGroup;
  final double bookingDepositPercent;
  final double damageDepositRequired;
  final List<PaymentRecord> payments;
  final String notes;
  final String? clientSignaturePath;
  final DateTime? clientSignedAt;
  final DateTime? holdExpiresAt;
  final DamageInspection? inspection;
  final String? seriesKey;
  final String? seriesRule;
  final int? seriesIndex;
  final int? seriesCount;

  bool get isChurchUse => reservationType == 'church_use';
  bool get isHold => status == 'hold';
  bool get isExpiredHold =>
      isHold && holdExpiresAt != null && holdExpiresAt!.isBefore(DateTime.now());
  bool get isRecurring => seriesKey != null && seriesKey!.isNotEmpty;

  double get extrasTotal => isChurchUse
      ? 0
      : extras.fold<double>(0, (total, item) => total + item.total);
  double get totalCharge =>
      isChurchUse ? 0 : hallCharge + extraTimeCharge + extrasTotal;
  double get requiredBookingDeposit =>
      isChurchUse ? 0 : totalCharge * bookingDepositPercent / 100;

  double get rentalPaymentsTotal => payments
      .where((p) =>
          p.paymentType == 'booking_deposit' ||
          p.paymentType == 'rental_balance')
      .fold<double>(0, (total, p) => total + p.amount);

  double get bookingDepositPaid => payments
      .where((p) => p.paymentType == 'booking_deposit')
      .fold<double>(0, (total, p) => total + p.amount);

  double get remainingRentalBalance {
    if (isChurchUse) return 0;
    final remaining = totalCharge - rentalPaymentsTotal;
    return remaining > 0 ? remaining : 0;
  }

  double get damageDepositHeld {
    if (isChurchUse) return 0;
    final received = payments
        .where((p) => p.paymentType == 'damage_deposit')
        .fold<double>(0, (total, p) => total + p.amount);
    final refunded = payments
        .where((p) => p.paymentType == 'damage_refund')
        .fold<double>(0, (total, p) => total + p.amount);
    final deduction = inspection?.isCompleted == true
        ? inspection!.damageDeduction
        : 0.0;
    final held = received - refunded - deduction;
    return held > 0 ? held : 0;
  }

  Booking copyWith({
    String? status,
    List<PaymentRecord>? payments,
    String? clientSignaturePath,
    DateTime? clientSignedAt,
    DateTime? holdExpiresAt,
    DamageInspection? inspection,
    String? seriesKey,
    String? seriesRule,
    int? seriesIndex,
    int? seriesCount,
  }) {
    return Booking(
      id: id,
      referenceNumber: referenceNumber,
      clientName: clientName,
      clientAddress: clientAddress,
      phone: phone,
      email: email,
      eventDate: eventDate,
      eventStart: eventStart,
      eventEnd: eventEnd,
      accessStart: accessStart,
      vacateEnd: vacateEnd,
      eventDetails: eventDetails,
      guestCount: guestCount,
      hallSpaceId: hallSpaceId,
      hallSpaceName: hallSpaceName,
      hallCharge: hallCharge,
      extraTimeCharge: extraTimeCharge,
      status: status ?? this.status,
      extras: extras,
      reservationType: reservationType,
      churchGroup: churchGroup,
      bookingDepositPercent: bookingDepositPercent,
      damageDepositRequired: damageDepositRequired,
      payments: payments ?? this.payments,
      notes: notes,
      clientSignaturePath: clientSignaturePath ?? this.clientSignaturePath,
      clientSignedAt: clientSignedAt ?? this.clientSignedAt,
      holdExpiresAt: holdExpiresAt ?? this.holdExpiresAt,
      inspection: inspection ?? this.inspection,
      seriesKey: seriesKey ?? this.seriesKey,
      seriesRule: seriesRule ?? this.seriesRule,
      seriesIndex: seriesIndex ?? this.seriesIndex,
      seriesCount: seriesCount ?? this.seriesCount,
    );
  }
}

class SettingsBundle {
  const SettingsBundle({
    required this.organization,
    required this.rules,
    required this.spaces,
    required this.services,
    required this.terms,
  });

  final OrganizationSettings organization;
  final RentalRules rules;
  final List<HallSpace> spaces;
  final List<ServiceItem> services;
  final List<RentalTerm> terms;

  SettingsBundle copyWith({
    OrganizationSettings? organization,
    RentalRules? rules,
    List<HallSpace>? spaces,
    List<ServiceItem>? services,
    List<RentalTerm>? terms,
  }) {
    return SettingsBundle(
      organization: organization ?? this.organization,
      rules: rules ?? this.rules,
      spaces: spaces ?? this.spaces,
      services: services ?? this.services,
      terms: terms ?? this.terms,
    );
  }
}
