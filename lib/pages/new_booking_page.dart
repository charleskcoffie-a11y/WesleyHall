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
    final value = await widget.repository.loadSettings();
    if (!mounted) return;
    final spaces = value.spaces.where((e) => e.active).toList();
    setState(() {
      settings = value;
      if (spaces.isNotEmpty) {
        hallId = spaces.first.id;
        hallCharge.text = spaces.first.baseRate.toStringAsFixed(2);
      }
    });
    await checkAvailability();
  }

  void setReservationType(String type) {
    final s = settings;
    if (s == null) return;
    setState(() {
      reservationType = type;
      selected.clear();
      if (isChurchUse) {
        hallCharge.text = '0.00';
      } else if (hallId != null) {
        hallCharge.text = s.spaces
            .firstWhere((e) => e.id == hallId)
            .baseRate
            .toStringAsFixed(2);
      }
    });
  }

  DateTime combine(TimeOfDay value, {bool finish = false}) {
    var result = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      value.hour,
      value.minute,
    );
    final startValue = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      start.hour,
      start.minute,
    );
    if (finish && !result.isAfter(startValue)) {
      result = result.add(const Duration(days: 1));
    }
    return result;
  }

  DateTime get eventStart => combine(start);
  DateTime get eventEnd => combine(end, finish: true);
  DateTime get accessStart => eventStart.subtract(
        Duration(minutes: settings?.rules.setupMinutesBefore ?? 0),
      );
  DateTime get vacateEnd => eventEnd.add(
        Duration(minutes: settings?.rules.cleanupMinutesAfter ?? 0),
      );

  double get hallValue => isChurchUse
      ? 0.0
      : double.tryParse(hallCharge.text.trim()) ?? 0.0;

  double get extrasTotal {
    if (isChurchUse || settings == null) return 0.0;
    return settings!.services.fold<double>(
      0.0,
      (sum, item) => sum + (selected[item.id] ?? 0.0) * item.price,
    );
  }

  double get extraTime {
    if (isChurchUse) return 0.0;
    final rules = settings?.rules;
    if (rules == null || rules.extraHourRate <= 0) return 0.0;
    final extraMinutes = eventEnd.difference(eventStart).inMinutes -
        rules.standardRentalHours * 60;
    if (extraMinutes <= 0) return 0.0;
    return (extraMinutes / 60).ceil() * rules.extraHourRate;
  }

  double get total => isChurchUse ? 0.0 : hallValue + extrasTotal + extraTime;

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
      final s = settings!;
      final hall = s.spaces.firstWhere((e) => e.id == hallId);
      final extras = isChurchUse
          ? <BookingExtra>[]
          : s.services
              .where((e) => (selected[e.id] ?? 0.0) > 0)
              .map((e) => BookingExtra(
                    serviceId: e.id,
                    name: e.name,
                    quantity: selected[e.id]!,
                    unitPrice: e.price,
                  ))
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
        guestCount: int.tryParse(guests.text.trim()) ?? 0,
        hallSpaceId: hall.id,
        hallSpaceName: hall.name,
        hallCharge: isChurchUse ? 0.0 : hallValue,
        extraTimeCharge: isChurchUse ? 0.0 : extraTime,
        status: isChurchUse ? 'reserved' : 'awaiting_deposit',
        extras: extras,
        reservationType: reservationType,
        churchGroup: isChurchUse ? churchGroup.text.trim() : '',
        bookingDepositPercent:
            isChurchUse ? 0.0 : s.rules.bookingDepositPercent,
        damageDepositRequired:
            isChurchUse ? 0.0 : s.rules.damageDepositAmount,
        notes: notes.text.trim(),
      );

      await widget.repository.createBooking(booking);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChurchUse
              ? 'Church use reservation saved. No payment required.'
              : 'Rental booking saved. Status: Awaiting Deposit.'),
        ),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save reservation: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    if (s == null) return const Center(child: CircularProgressIndicator());

    final spaces = s.spaces.where((e) => e.active).toList();
    final services = s.services.where((e) => e.active).toList();
    final double deposit = isChurchUse
        ? 0.0
        : total * s.rules.bookingDepositPercent / 100.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 28, 30, 26),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'New Reservation',
              subtitle: 'Choose rental or church use, then reserve Wesley Hall.',
            ),
            const SizedBox(height: 14),
            _reservationSelector(),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _section(
                            isChurchUse
                                ? 'Church Activity Information'
                                : 'Client Information',
                            [
                              if (isChurchUse) ...[
                                Row(children: [
                                  Expanded(
                                    child: _field(churchGroup,
                                        'Church Group / Ministry',
                                        required: true),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _field(client, 'Person Responsible',
                                        required: true),
                                  ),
                                ]),
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(child: _field(phone, 'Telephone')),
                                  const SizedBox(width: 12),
                                  Expanded(child: _field(email, 'Email')),
                                ]),
                              ] else ...[
                                Row(children: [
                                  Expanded(
                                    child: _field(client, 'Client Name',
                                        required: true),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: _field(phone, 'Telephone')),
                                ]),
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(child: _field(email, 'Email')),
                                  const SizedBox(width: 12),
                                  Expanded(child: _field(address, 'Address')),
                                ]),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          _section('Activity & Hall', [
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(_date(eventDate)),
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
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: hallId,
                                  decoration: const InputDecoration(
                                      labelText: 'Hall Space'),
                                  items: spaces
                                      .map((e) => DropdownMenuItem(
                                            value: e.id,
                                            child: Text(e.name),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    final hall = s.spaces
                                        .firstWhere((e) => e.id == value);
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
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: _timeButton('Start', start,
                                  (value) => start = value)),
                              const SizedBox(width: 12),
                              Expanded(child: _timeButton('End', end,
                                  (value) => end = value)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  guests,
                                  isChurchUse
                                      ? 'Expected Attendance'
                                      : 'No. of Guests',
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            _field(
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
                              child: Text(
                                available == false
                                    ? 'Conflict: the hall is already reserved during this period.'
                                    : 'Hall blocked from ${_dateTime(accessStart)} through ${_dateTime(vacateEnd)}.',
                              ),
                            ),
                          ]),
                          if (!isChurchUse) ...[
                            const SizedBox(height: 14),
                            _section(
                              'Extra Facilities / Services',
                              services.map((service) {
                                final checked = selected.containsKey(service.id);
                                return Row(children: [
                                  Checkbox(
                                    value: checked,
                                    onChanged: (value) => setState(() {
                                      if (value == true) {
                                        selected[service.id] = 1.0;
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
                                  if (checked && service.pricingType == 'hourly')
                                    SizedBox(
                                      width: 90,
                                      child: TextFormField(
                                        initialValue: '1',
                                        decoration: const InputDecoration(
                                            labelText: 'Hours'),
                                        onChanged: (value) => setState(() =>
                                            selected[service.id] =
                                                double.tryParse(value) ?? 0.0),
                                      ),
                                    ),
                                ]);
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _section('Notes', [
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
                              Text(
                                isChurchUse
                                    ? 'Church Use Summary'
                                    : 'Booking Summary',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 16),
                              if (isChurchUse) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF3FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'NO PAYMENT REQUIRED\nThe hall is reserved and protected from double-booking.',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _moneyLine('Hall Charge', 0.0),
                                _moneyLine('Deposit', 0.0),
                                _moneyLine('Total Due', 0.0, strong: true),
                              ] else ...[
                                TextField(
                                  controller: hallCharge,
                                  decoration: const InputDecoration(
                                      labelText: 'Hall Rental Charge (\$)'),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                _moneyLine('Services', extrasTotal),
                                _moneyLine('Extra Time', extraTime),
                                const Divider(),
                                _moneyLine('Total', total, strong: true),
                                _moneyLine(
                                  'Required ${s.rules.bookingDepositPercent.toStringAsFixed(0)}% Deposit',
                                  deposit,
                                ),
                                _moneyLine(
                                    'Balance After Deposit', total - deposit),
                                const Divider(),
                                _moneyLine('Refundable Damage Deposit',
                                    s.rules.damageDepositAmount),
                              ],
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: saving ? null : save,
                                icon: Icon(isChurchUse
                                    ? Icons.event_available_outlined
                                    : Icons.save_outlined),
                                label: Text(isChurchUse
                                    ? 'Reserve for Church Use'
                                    : 'Save Rental Booking'),
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

  Widget _reservationSelector() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reservation Type',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Select one before entering the booking details.'),
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
                onSelectionChanged: (value) =>
                    setReservationType(value.first),
              ),
            ],
          ),
        ),
      );

  Widget _section(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );

  Widget _field(TextEditingController controller, String label,
          {bool required = false}) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null
            : null,
      );

  Widget _timeButton(
          String label, TimeOfDay value, void Function(TimeOfDay) update) =>
      OutlinedButton(
        onPressed: () async {
          final picked =
              await showTimePicker(context: context, initialTime: value);
          if (picked != null) {
            setState(() => update(picked));
            checkAvailability();
          }
        },
        child: Text('$label: ${value.format(context)}'),
      );

  Widget _moneyLine(String label, double value, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: strong ? FontWeight.w700 : null)),
            ),
            Text('\$${value.toStringAsFixed(2)}',
                style: TextStyle(
                    fontWeight: strong ? FontWeight.w800 : null)),
          ],
        ),
      );

  String _date(DateTime value) =>
      '${value.month}/${value.day}/${value.year}';

  String _dateTime(DateTime value) =>
      '${_date(value)} ${TimeOfDay.fromDateTime(value).format(context)}';
}
