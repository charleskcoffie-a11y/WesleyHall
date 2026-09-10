import 'package:flutter/material.dart';

import '../models/wesley_models.dart';
import '../services/wesley_repository.dart';

class EditBookingPage extends StatefulWidget {
  const EditBookingPage({
    super.key,
    required this.repository,
    required this.booking,
  });

  final WesleyRepository repository;
  final Booking booking;

  @override
  State<EditBookingPage> createState() => _EditBookingPageState();
}

class _EditBookingPageState extends State<EditBookingPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _client;
  late final TextEditingController _churchGroup;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _details;
  late final TextEditingController _guests;
  late final TextEditingController _notes;
  late final TextEditingController _hallCharge;

  SettingsBundle? _settings;
  late String _hallId;
  late DateTime _eventDate;
  late TimeOfDay _start;
  late TimeOfDay _end;
  final Map<String, double> _selectedServices = {};
  bool _saving = false;
  bool? _available;

  bool get _isChurchUse => widget.booking.isChurchUse;

  @override
  void initState() {
    super.initState();
    final b = widget.booking;
    _client = TextEditingController(text: b.clientName);
    _churchGroup = TextEditingController(text: b.churchGroup);
    _address = TextEditingController(text: b.clientAddress);
    _phone = TextEditingController(text: b.phone);
    _email = TextEditingController(text: b.email);
    _details = TextEditingController(text: b.eventDetails);
    _guests = TextEditingController(
      text: b.guestCount == 0 ? '' : b.guestCount.toString(),
    );
    _notes = TextEditingController(text: b.notes);
    _hallCharge = TextEditingController(text: b.hallCharge.toStringAsFixed(2));
    _hallId = b.hallSpaceId;
    _eventDate = b.eventDate;
    _start = TimeOfDay.fromDateTime(b.eventStart);
    _end = TimeOfDay.fromDateTime(b.eventEnd);
    for (final extra in b.extras) {
      _selectedServices[extra.serviceId] = extra.quantity;
    }
    _load();
  }

  @override
  void dispose() {
    _client.dispose();
    _churchGroup.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _details.dispose();
    _guests.dispose();
    _notes.dispose();
    _hallCharge.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await widget.repository.loadSettings();
    if (!mounted) return;
    setState(() => _settings = settings);
    await _checkAvailability();
  }

  DateTime _combine(TimeOfDay time, {bool finish = false}) {
    var value = DateTime(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      time.hour,
      time.minute,
    );
    final startValue = DateTime(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      _start.hour,
      _start.minute,
    );
    if (finish && !value.isAfter(startValue)) {
      value = value.add(const Duration(days: 1));
    }
    return value;
  }

  DateTime get _eventStart => _combine(_start);
  DateTime get _eventEnd => _combine(_end, finish: true);
  DateTime get _accessStart => _eventStart.subtract(
        Duration(minutes: _settings?.rules.setupMinutesBefore ?? 0),
      );
  DateTime get _vacateEnd => _eventEnd.add(
        Duration(minutes: _settings?.rules.cleanupMinutesAfter ?? 0),
      );

  double get _hallValue => _isChurchUse
      ? 0
      : double.tryParse(_hallCharge.text.trim()) ?? 0;

  double get _extraTime {
    if (_isChurchUse || _settings == null) return 0;
    final rules = _settings!.rules;
    if (rules.extraHourRate <= 0) return 0;
    final extraMinutes =
        _eventEnd.difference(_eventStart).inMinutes - rules.standardRentalHours * 60;
    if (extraMinutes <= 0) return 0;
    return (extraMinutes / 60).ceil() * rules.extraHourRate;
  }

  Future<void> _checkAvailability() async {
    if (_settings == null) return;
    final conflict = await widget.repository.hasBookingConflict(
      hallSpaceId: _hallId,
      accessStart: _accessStart,
      vacateEnd: _vacateEnd,
      excludeBookingId: widget.booking.id,
    );
    if (mounted) setState(() => _available = !conflict);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _settings == null) return;
    await _checkAvailability();
    if (_available != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This change conflicts with another hall reservation.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final settings = _settings!;
      final hall = settings.spaces.firstWhere((e) => e.id == _hallId);
      final extras = _isChurchUse
          ? <BookingExtra>[]
          : settings.services
              .where((service) => (_selectedServices[service.id] ?? 0) > 0)
              .map((service) => BookingExtra(
                    serviceId: service.id,
                    name: service.name,
                    quantity: _selectedServices[service.id]!,
                    unitPrice: service.price,
                  ))
              .toList();

      final updated = Booking(
        id: widget.booking.id,
        referenceNumber: widget.booking.referenceNumber,
        clientName: _client.text.trim(),
        clientAddress: _isChurchUse ? '' : _address.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        eventDate: _eventDate,
        eventStart: _eventStart,
        eventEnd: _eventEnd,
        accessStart: _accessStart,
        vacateEnd: _vacateEnd,
        eventDetails: _details.text.trim(),
        guestCount: int.tryParse(_guests.text.trim()) ?? 0,
        hallSpaceId: hall.id,
        hallSpaceName: hall.name,
        hallCharge: _isChurchUse ? 0 : _hallValue,
        extraTimeCharge: _isChurchUse ? 0 : _extraTime,
        status: widget.booking.status,
        extras: extras,
        reservationType: widget.booking.reservationType,
        churchGroup: _isChurchUse ? _churchGroup.text.trim() : '',
        bookingDepositPercent: widget.booking.bookingDepositPercent,
        damageDepositRequired: widget.booking.damageDepositRequired,
        payments: widget.booking.payments,
        notes: _notes.text.trim(),
        clientSignaturePath: widget.booking.clientSignaturePath,
        clientSignedAt: widget.booking.clientSignedAt,
      );

      await widget.repository.updateBooking(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation updated successfully.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update reservation: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final spaces = settings.spaces
        .where((e) => e.active || e.id == widget.booking.hallSpaceId)
        .toList();
    final services = settings.services.where((e) => e.active).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.booking.referenceNumber}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Changes'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(
                            _isChurchUse
                                ? Icons.church_outlined
                                : Icons.payments_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isChurchUse
                                      ? 'Church Use Reservation'
                                      : 'External Rental',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                                Text(
                                  'Reference ${widget.booking.referenceNumber} • Reservation type cannot be changed after creation.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _section(
                    _isChurchUse
                        ? 'Church Activity Information'
                        : 'Client Information',
                    [
                      if (_isChurchUse) ...[
                        Row(children: [
                          Expanded(
                            child: _field(
                              _churchGroup,
                              'Church Group / Ministry',
                              required: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              _client,
                              'Person Responsible',
                              required: true,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _field(_phone, 'Telephone')),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_email, 'Email')),
                        ]),
                      ] else ...[
                        Row(children: [
                          Expanded(
                            child: _field(
                              _client,
                              'Client Name',
                              required: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_phone, 'Telephone')),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _field(_email, 'Email')),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_address, 'Address')),
                        ]),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  _section('Activity & Hall', [
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(_date(_eventDate)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _eventDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setState(() => _eventDate = picked);
                              await _checkAvailability();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _hallId,
                          decoration:
                              const InputDecoration(labelText: 'Hall Space'),
                          items: spaces
                              .map((e) => DropdownMenuItem(
                                    value: e.id,
                                    child: Text(e.name),
                                  ))
                              .toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            final hall = settings.spaces
                                .firstWhere((e) => e.id == value);
                            setState(() {
                              _hallId = value;
                              if (!_isChurchUse) {
                                _hallCharge.text =
                                    hall.baseRate.toStringAsFixed(2);
                              }
                            });
                            await _checkAvailability();
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _timeButton('Start', _start, (v) => _start = v)),
                      const SizedBox(width: 12),
                      Expanded(child: _timeButton('End', _end, (v) => _end = v)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _guests,
                          _isChurchUse
                              ? 'Expected Attendance'
                              : 'No. of Guests',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _field(
                      _details,
                      _isChurchUse
                          ? 'Church Activity / Program Name'
                          : 'Event Details',
                      required: true,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: _available == false
                            ? Theme.of(context).colorScheme.errorContainer
                            : const Color(0xFFE8F7EF),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        _available == false
                            ? 'Conflict: another reservation occupies this hall during the new access/vacate period.'
                            : 'Available. Hall will be blocked from ${_dateTime(_accessStart)} through ${_dateTime(_vacateEnd)}.',
                      ),
                    ),
                  ]),
                  if (!_isChurchUse) ...[
                    const SizedBox(height: 14),
                    _section('Charges & Services', [
                      TextFormField(
                        controller: _hallCharge,
                        decoration: const InputDecoration(
                          labelText: 'Hall Rental Charge (\$)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...services.map((service) {
                        final checked =
                            _selectedServices.containsKey(service.id);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Checkbox(
                              value: checked,
                              onChanged: (value) => setState(() {
                                if (value == true) {
                                  _selectedServices[service.id] = 1;
                                } else {
                                  _selectedServices.remove(service.id);
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
                                width: 100,
                                child: TextFormField(
                                  initialValue: (_selectedServices[service.id] ?? 1)
                                      .toStringAsFixed(1),
                                  decoration:
                                      const InputDecoration(labelText: 'Hours'),
                                  onChanged: (value) => _selectedServices[
                                          service.id] =
                                      double.tryParse(value) ?? 0,
                                ),
                              ),
                          ]),
                        );
                      }),
                    ]),
                  ],
                  const SizedBox(height: 14),
                  _section('Notes', [
                    TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
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

  Widget _field(
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

  Widget _timeButton(
    String label,
    TimeOfDay value,
    void Function(TimeOfDay) update,
  ) =>
      OutlinedButton(
        onPressed: () async {
          final picked =
              await showTimePicker(context: context, initialTime: value);
          if (picked != null) {
            setState(() => update(picked));
            await _checkAvailability();
          }
        },
        child: Text('$label: ${value.format(context)}'),
      );

  String _date(DateTime value) =>
      '${value.month}/${value.day}/${value.year}';

  String _dateTime(DateTime value) =>
      '${_date(value)} ${TimeOfDay.fromDateTime(value).format(context)}';
}
