import 'package:flutter/material.dart';

import '../models/wesley_models.dart';
import '../services/wesley_repository.dart';
import '../widgets/page_header.dart';

class NewBookingPage extends StatefulWidget {
  const NewBookingPage({
    super.key,
    required this.repository,
    required this.onSaved,
  });

  final WesleyRepository repository;
  final VoidCallback onSaved;

  @override
  State<NewBookingPage> createState() => _NewBookingPageState();
}

class _NewBookingPageState extends State<NewBookingPage> {
  final formKey = GlobalKey<FormState>();
  final client = TextEditingController();
  final churchGroup = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final details = TextEditingController();
  final guests = TextEditingController();
  final notes = TextEditingController();
  final hallCharge = TextEditingController();

  SettingsBundle? settings;
  String? hallId;
  String reservationType = 'external_rental';
  DateTime eventDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay start = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 23, minute: 0);
  final Map<String, double> selected = {};
  bool saving = false;
  bool? available;

  bool get isChurchUse => reservationType == 'church_use';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    client.dispose();
    churchGroup.dispose();
    address.dispose();
    phone.dispose();
    email.dispose();
    details.dispose();
    guests.dispose();
    notes.dispose();
    hallCharge.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final s = await widget.repository.loadSettings();
    if (!mounted) return;
    setState(() {
      settings = s;
      final activeSpaces = s.spaces.where((space) => space.active).toList();
      if (activeSpaces.isNotEmpty) {
        hallId = activeSpaces.first.id;
        hallCharge.text = activeSpaces.first.baseRate.toStringAsFixed(2);
      }
    });
    checkAvailability();
  }

  void changeReservationType(String type) {
    final s = settings;
    if (s == null) return;
    setState(() {
      reservationType = type;
      selected.clear();
      if (type == 'church_use') {
        hallCharge.text = '0.00';
      } else if (hallId != null) {
        final hall = s.spaces.firstWhere((space) => space.id == hallId);
        hallCharge.text = hall.baseRate.toStringAsFixed(2);
      }
    });
  }

  DateTime combine(TimeOfDay time, {bool finish = false}) {
    var value = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      time.hour,
      time.minute,
    );
    final startValue = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      start.hour,
      start.minute,
    );
    if (finish && !value.isAfter(startValue)) {
      value = value.add(const Duration(days: 1));
    }
    return value;
  }

  DateTime get eventStart => combine(start);
  DateTime get eventEnd => combine(end, finish: true);
  DateTime get accessStart => eventStart.subtract(
        Duration(minutes: settings?.rules.setupMinutesBefore ?? 0),
      );
  DateTime get vacateEnd => eventEnd.add(
        Duration(minutes: settings?.rules.cleanupMinutesAfter ?? 0),
      );

  double get hallValue => isChurchUse ? 0 : double.tryParse(hallCharge.text) ?? 0;

  double get extrasTotal {
    if (isChurchUse || settings == null) return 0;
    return settings!.services.fold<double>(
      0,
      (total, service) => total + (selected[service.id] ?? 0) * service.price,
    );
  }

  double get extraTime {
    if (isChurchUse) return 0;
    final rules = settings?.rules;
    if (rules == null || rules.extraHourRate <= 0) return 0;
    final extraMinutes = eventEnd.difference(eventStart).inMinutes -
        rules.standardRentalHours * 60;
    return extraMinutes > 0
        ? (extraMinutes / 60).ceil() * rules.extraHourRate
        : 0;
  }

  double get total => isChurchUse ? 0 : hallValue + extrasTotal + extraTime;

  Future<void> checkAvailability() async {
    if (settings == null || hallId == null) return;
    final conflict = await widget.repository.hasBookingConflict(
      hallSpaceId: hallId!,
      accessStart: accessStart,
      vacateEnd: vacateEnd,
    );
    if (mounted) setState(() => available = !conflict);
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || settings == null || hallId == null) {
      return;
    }
    await checkAvailability();
    if (available != true) return;

    setState(() => saving = true);
    try {
      final hall = settings!.spaces.firstWhere((space) => space.id == hallId);
      final extras = isChurchUse
          ? <BookingExtra>[]
          : settings!.services
              .where((service) => (selected[service.id] ?? 0) > 0)
              .map(
                (service) => BookingExtra(
                  serviceId: service.id,
                  name: service.name,
                  quantity: selected[service.id]!,
                  unitPrice: service.price,
                ),
              )
              .toList();

      final booking = Booking(
        id: 'temp-${DateTime.now().microsecondsSinceEpoch}',
        referenceNumber: 'WH-${eventDate.year}-PENDING',
        clientName: client.text.trim(),
        clientAddress: isChurchUse ? '' : address.text.trim(),
        phone: phone.text.trim(),
        email: email.text.trim(),
        eventDate: eventDate,
        eventStart: eventStart,
        eventEnd: eventEnd,
        accessStart: accessStart,
        vacateEnd: vacateEnd,
        eventDetails: details.text.trim(),
        guestCount: int.tryParse(guests.text) ?? 0,
        hallSpaceId: hall.id,
        hallSpaceName: hall.name,
        hallCharge: isChurchUse ? 0 : hallValue,
        extraTimeCharge: isChurchUse ? 0 : extraTime,
        status: isChurchUse ? 'reserved' : 'awaiting_deposit',
        reservationType: reservationType,
        churchGroup: isChurchUse ? churchGroup.text.trim() : '',
        extras: extras,
        bookingDepositPercent:
            isChurchUse ? 0 : settings!.rules.bookingDepositPercent,
        damageDepositRequired:
            isChurchUse ? 0 : settings!.rules.damageDepositAmount,
        notes: notes.text.trim(),
      );

      await widget.repository.createBooking(booking);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isChurchUse
                ? 'Church activity reserved. No payment required.'
                : 'Booking saved. Status: Awaiting Deposit.',
          ),
        ),
      );
      widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save reservation: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    if (s == null) return const Center(child: CircularProgressIndicator());

    final activeSpaces = s.spaces.where((space) => space.active).toList();
    final activeServices = s.services.where((service) => service.active).toList();
    final deposit = isChurchUse ? 0 : total * s.rules.bookingDepositPercent / 100;

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 28, 30, 26),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'New Reservation',
              subtitle:
                  'Reserve Wesley Hall for a paid rental or a church activity.',
            ),
            const SizedBox(height: 18),
            _reservationTypeSelector(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          section(
                            isChurchUse
                                ? 'Church Activity Information'
                                : 'Client Information',
                            [
                              if (isChurchUse) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: field(
                                        churchGroup,
                                        'Church Group / Ministry',
                                        required: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: field(
                                        client,
                                        'Person Responsible',
                                        required: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: field(phone, 'Telephone')),
                                    const SizedBox(width: 12),
                                    Expanded(child: field(email, 'Email')),
                                  ],
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: field(
                                        client,
                                        'Client Name',
                                        required: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: field(phone, 'Telephone')),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: field(email, 'Email')),
                                    const SizedBox(width: 12),
                                    Expanded(child: field(address, 'Address')),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          section('Activity & Hall', [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: eventDate,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now()
                                            .add(const Duration(days: 1825)),
                                      );
                                      if (picked != null) {
                                        setState(() => eventDate = picked);
                                        checkAvailability();
                                      }
                                    },
                                    icon: const Icon(Icons.calendar_today),
                                    label: Text(date(eventDate)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: hallId,
                                    decoration: const InputDecoration(
                                      labelText: 'Hall Space',
                                    ),
                                    items: activeSpaces
                                        .map(
                                          (hall) => DropdownMenuItem(
                                            value: hall.id,
                                            child: Text(hall.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      final hall = s.spaces.firstWhere(
                                        (space) => space.id == value,
                                      );
                                      setState(() {
                                        hallId = value;
                                        hallCharge.text = isChurchUse
                                            ? '0.00'
                                            : hall.baseRate.toStringAsFixed(2);
                                      });
                                      checkAvailability();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: timeButton(
                                    'Start',
                                    start,
                                    (value) => start = value,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: timeButton(
                                    'End',
                                    end,
                                    (value) => end = value,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: field(
                                    guests,
                                    isChurchUse
                                        ? 'Expected Attendance'
                                        : 'No. of Guests',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            field(
                              details,
                              isChurchUse
                                  ? 'Church Activity / Program Name'
                                  : 'Event Details',
                              required: true,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: available == false
                                    ? Theme.of(context)
                                        .colorScheme
                                        .errorContainer
                                    : const Color(0xFFE8F7EF),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    available == false
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle_outline,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      available == false
                                          ? 'Conflict: the hall is already reserved during this access/event/vacate period.'
                                          : 'Hall blocked from ${dateTime(accessStart)} through ${dateTime(vacateEnd)}.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                          if (!isChurchUse) ...[
                            const SizedBox(height: 14),
                            section(
                              'Extra Facilities / Services',
                              activeServices.map((service) {
                                final checked = selected.containsKey(service.id);
                                return Row(
                                  children: [
                                    Checkbox(
                                      value: checked,
                                      onChanged: (value) => setState(() {
                                        if (value == true) {
                                          selected[service.id] = 1;
                                        } else {
                                          selected.remove(service.id);
                                        }
                                      }),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${service.name} - \$${service.price.toStringAsFixed(2)}${service.pricingType == 'hourly' ? '/hr' : ''}',
                                      ),
                                    ),
                                    if (checked &&
                                        service.pricingType == 'hourly')
                                      SizedBox(
                                        width: 90,
                                        child: TextFormField(
                                          initialValue: '1',
                                          decoration: const InputDecoration(
                                            labelText: 'Hours',
                                          ),
                                          onChanged: (value) => setState(
                                            () => selected[service.id] =
                                                double.tryParse(value) ?? 0,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 14),
                          section('Notes', [
                            TextField(
                              controller: notes,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: isChurchUse
                                    ? 'Activity / Setup Notes'
                                    : 'Booking Notes',
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: 340,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isChurchUse
                                        ? const Color(0xFFE6F0FF)
                                        : const Color(0xFFDDF6E8),
                                    child: Icon(
                                      isChurchUse
                                          ? Icons.church_outlined
                                          : Icons.receipt_long_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isChurchUse
                                          ? 'Church Use Summary'
                                          : 'Booking Summary',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              if (isChurchUse) ...[
                                Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF3FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'NO PAYMENT REQUIRED',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF235A92),
                                        ),
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        'Internal church use reserves the hall and prevents double-booking, but rental and deposit charges are not applied.',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                moneyLine('Hall Charge', 0),
                                moneyLine('Services', 0),
                                moneyLine('Deposit', 0),
                                const Divider(),
                                moneyLine('Total Due', 0, strong: true),
                              ] else ...[
                                TextField(
                                  controller: hallCharge,
                                  decoration: const InputDecoration(
                                    labelText: 'Hall Rental Charge (\$)',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                moneyLine('Services', extrasTotal),
                                moneyLine('Extra Time', extraTime),
                                const Divider(),
                                moneyLine('Total', total, strong: true),
                                moneyLine(
                                  'Required ${s.rules.bookingDepositPercent.toStringAsFixed(0)}% Deposit',
                                  deposit,
                                ),
                                moneyLine(
                                  'Balance After Deposit',
                                  total - deposit,
                                ),
                                const Divider(),
                                moneyLine(
                                  'Refundable Damage Deposit',
                                  s.rules.damageDepositAmount,
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: saving ? null : save,
                                icon: Icon(
                                  isChurchUse
                                      ? Icons.event_available_outlined
                                      : Icons.save_outlined,
                                ),
                                label: Text(
                                  isChurchUse
                                      ? 'Reserve for Church Use'
                                      : 'Save Rental Booking',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reservationTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reservation Type',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Choose whether this is an external paid rental or an internal church activity.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'external_rental',
                  icon: Icon(Icons.payments_outlined),
                  label: Text('External Rental'),
                ),
                ButtonSegment(
                  value: 'church_use',
                  icon: Icon(Icons.church_outlined),
                  label: Text('Church Use - No Payment'),
                ),
              ],
              selected: {reservationType},
              onSelectionChanged: (values) =>
                  changeReservationType(values.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget section(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );

  Widget field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null
            : null,
      );

  Widget timeButton(
    String label,
    TimeOfDay value,
    void Function(TimeOfDay) update,
  ) =>
      OutlinedButton(
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: value,
          );
          if (picked != null) {
            setState(() => update(picked));
            checkAvailability();
          }
        },
        child: Text('$label: ${value.format(context)}'),
      );

  Widget moneyLine(String label, double value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: strong ? FontWeight.w700 : null,
                ),
              ),
            ),
            Text(
              '\$${value.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: strong ? FontWeight.w800 : null,
              ),
            ),
          ],
        ),
      );

  String date(DateTime value) =>
      '${value.month}/${value.day}/${value.year}';

  String dateTime(DateTime value) =>
      '${date(value)} ${TimeOfDay.fromDateTime(value).format(context)}';
}
