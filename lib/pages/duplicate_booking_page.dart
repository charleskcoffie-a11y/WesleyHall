import 'package:flutter/material.dart';

import '../models/wesley_models.dart';
import '../services/wesley_repository.dart';

class DuplicateBookingPage extends StatefulWidget {
  const DuplicateBookingPage({
    super.key,
    required this.repository,
    required this.source,
  });

  final WesleyRepository repository;
  final Booking source;

  @override
  State<DuplicateBookingPage> createState() => _DuplicateBookingPageState();
}

class _DuplicateBookingPageState extends State<DuplicateBookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _client = TextEditingController();
  final _churchGroup = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _details = TextEditingController();
  final _guests = TextEditingController();
  final _notes = TextEditingController();
  final _hallCharge = TextEditingController();

  SettingsBundle? _settings;
  String? _hallId;
  late DateTime _eventDate;
  late TimeOfDay _start;
  late TimeOfDay _end;
  final Map<String, double> _selectedServices = {};
  bool _saving = false;
  bool? _available;

  bool get _isChurchUse => widget.source.isChurchUse;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _client.text = source.clientName;
    _churchGroup.text = source.churchGroup;
    _address.text = source.clientAddress;
    _phone.text = source.phone;
    _email.text = source.email;
    _details.text = source.eventDetails;
    _guests.text = source.guestCount == 0 ? '' : source.guestCount.toString();
    _notes.text = source.notes;
    _eventDate = _nextCopyDate(source.eventDate);
    _start = TimeOfDay.fromDateTime(source.eventStart);
    _end = TimeOfDay.fromDateTime(source.eventEnd);
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

  DateTime _nextCopyDate(DateTime sourceDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var candidate = DateTime(sourceDate.year, sourceDate.month, sourceDate.day)
        .add(const Duration(days: 7));
    while (candidate.isBefore(today)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  Future<void> _load() async {
    try {
      final settings = await widget.repository.loadSettings();
      final spaces = settings.spaces.where((e) => e.active).toList();
      if (spaces.isEmpty) throw Exception('No active hall spaces are configured.');

      final matchingSpaces =
          spaces.where((e) => e.id == widget.source.hallSpaceId).toList();
      final hall = matchingSpaces.isNotEmpty ? matchingSpaces.first : spaces.first;

      _selectedServices.clear();
      for (final extra in widget.source.extras) {
        final activeMatch = settings.services.any(
          (service) => service.active && service.id == extra.serviceId,
        );
        if (activeMatch) {
          _selectedServices[extra.serviceId] = extra.quantity;
        }
      }

      _hallCharge.text = _isChurchUse ? '0.00' : hall.baseRate.toStringAsFixed(2);

      if (!mounted) return;
      setState(() {
        _settings = settings;
        _hallId = hall.id;
      });
      await _checkAvailability();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to prepare copy: $e')),
      );
    }
  }

  DateTime _combineForDate(DateTime date, TimeOfDay value,
      {bool finish = false}) {
    var result = DateTime(
      date.year,
      date.month,
      date.day,
      value.hour,
      value.minute,
    );
    final startAt = DateTime(
      date.year,
      date.month,
      date.day,
      _start.hour,
      _start.minute,
    );
    if (finish && !result.isAfter(startAt)) {
      result = result.add(const Duration(days: 1));
    }
    return result;
  }

  DateTime get _eventStart => _combineForDate(_eventDate, _start);
  DateTime get _eventEnd =>
      _combineForDate(_eventDate, _end, finish: true);
  DateTime get _accessStart => _eventStart.subtract(
        Duration(minutes: _settings?.rules.setupMinutesBefore ?? 0),
      );
  DateTime get _vacateEnd => _eventEnd.add(
        Duration(minutes: _settings?.rules.cleanupMinutesAfter ?? 0),
      );

  double get _hallValue => _isChurchUse
      ? 0
      : double.tryParse(_hallCharge.text.trim()) ?? 0;

  double get _servicesTotal {
    final settings = _settings;
    if (_isChurchUse || settings == null) return 0;
    return settings.services.fold<double>(
      0,
      (sum, service) =>
          sum + (_selectedServices[service.id] ?? 0) * service.price,
    );
  }

  double get _extraTimeCharge {
    final settings = _settings;
    if (_isChurchUse || settings == null || settings.rules.extraHourRate <= 0) {
      return 0;
    }
    final extraMinutes = _eventEnd.difference(_eventStart).inMinutes -
        settings.rules.standardRentalHours * 60;
    if (extraMinutes <= 0) return 0;
    return (extraMinutes / 60).ceil() * settings.rules.extraHourRate;
  }

  double get _total =>
      _isChurchUse ? 0 : _hallValue + _servicesTotal + _extraTimeCharge;

  Future<void> _checkAvailability() async {
    if (_settings == null || _hallId == null) return;
    try {
      final conflict = await widget.repository.hasBookingConflict(
        hallSpaceId: _hallId!,
        accessStart: _accessStart,
        vacateEnd: _vacateEnd,
      );
      if (mounted) setState(() => _available = !conflict);
    } catch (_) {
      if (mounted) setState(() => _available = null);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (picked == null) return;
    setState(() => _eventDate = picked);
    await _checkAvailability();
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
    await _checkAvailability();
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null || _hallId == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      final conflict = await widget.repository.hasBookingConflict(
        hallSpaceId: _hallId!,
        accessStart: _accessStart,
        vacateEnd: _vacateEnd,
      );
      if (conflict) {
        if (!mounted) return;
        setState(() => _available = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This copied reservation conflicts with another hall booking. Choose a different date or time.'),
          ),
        );
        return;
      }

      final hall = settings.spaces.firstWhere((e) => e.id == _hallId);
      final services = _isChurchUse
          ? <BookingExtra>[]
          : settings.services
              .where((service) =>
                  service.active &&
                  (_selectedServices[service.id] ?? 0) > 0)
              .map(
                (service) => BookingExtra(
                  serviceId: service.id,
                  name: service.name,
                  quantity: _selectedServices[service.id]!,
                  unitPrice: service.price,
                ),
              )
              .toList();

      final booking = Booking(
        id: 'copy-${DateTime.now().microsecondsSinceEpoch}',
        referenceNumber: 'WH-${_eventDate.year}-PENDING',
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
        extraTimeCharge: _isChurchUse ? 0 : _extraTimeCharge,
        status: _isChurchUse ? 'reserved' : 'awaiting_deposit',
        extras: services,
        reservationType: widget.source.reservationType,
        churchGroup: _isChurchUse ? _churchGroup.text.trim() : '',
        bookingDepositPercent:
            _isChurchUse ? 0 : settings.rules.bookingDepositPercent,
        damageDepositRequired:
            _isChurchUse ? 0 : settings.rules.damageDepositAmount,
        notes: _notes.text.trim(),
      );

      await widget.repository.createBooking(booking);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create copied reservation: $e')),
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

    final spaces = settings.spaces.where((e) => e.active).toList();
    final services = settings.services.where((e) => e.active).toList();
    final deposit = _isChurchUse
        ? 0.0
        : _total * settings.rules.bookingDepositPercent / 100;

    return Scaffold(
      appBar: AppBar(
        title: Text('Copy ${widget.source.referenceNumber}'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: const Color(0xFFEAF4FF),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.content_copy_outlined),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'A new reservation will be created with a new reference number. Client/event details are copied, but payments, signatures, documents, damage inspections, holds, and recurring-series links are not copied. Current hall/service rates and current deposit rules are used.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isChurchUse ? 'Church Activity' : 'Client Information',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 14),
                          if (_isChurchUse) ...[
                            Row(
                              children: [
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
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _field(_client, 'Client Name', required: true),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: _field(_address, 'Address')),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _field(_phone, 'Telephone')),
                              const SizedBox(width: 12),
                              Expanded(child: _field(_email, 'Email')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'New Date & Hall',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 220,
                                child: OutlinedButton.icon(
                                  onPressed: _pickDate,
                                  icon: const Icon(Icons.calendar_today_outlined),
                                  label: Text(_date(_eventDate)),
                                ),
                              ),
                              SizedBox(
                                width: 210,
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickTime(true),
                                  icon: const Icon(Icons.schedule_outlined),
                                  label: Text('Start: ${_start.format(context)}'),
                                ),
                              ),
                              SizedBox(
                                width: 210,
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickTime(false),
                                  icon: const Icon(Icons.schedule_outlined),
                                  label: Text('End: ${_end.format(context)}'),
                                ),
                              ),
                              SizedBox(
                                width: 260,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _hallId,
                                  decoration: const InputDecoration(labelText: 'Hall Space'),
                                  items: spaces
                                      .map(
                                        (space) => DropdownMenuItem(
                                          value: space.id,
                                          child: Text(space.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) async {
                                    if (value == null) return;
                                    final hall = spaces.firstWhere((e) => e.id == value);
                                    setState(() {
                                      _hallId = value;
                                      _hallCharge.text = _isChurchUse
                                          ? '0.00'
                                          : hall.baseRate.toStringAsFixed(2);
                                    });
                                    await _checkAvailability();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _available == false
                                  ? Theme.of(context).colorScheme.errorContainer
                                  : const Color(0xFFE8F7EF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _available == false
                                  ? 'Conflict detected. Choose another date, time, or hall.'
                                  : 'Hall blocked from ${_dateTime(_accessStart)} through ${_dateTime(_vacateEnd)}.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  _details,
                                  _isChurchUse ? 'Activity / Program' : 'Event Details',
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 180,
                                child: _field(
                                  _guests,
                                  _isChurchUse ? 'Attendance' : 'Guests',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_isChurchUse) ...[
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Current Rates & Services',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 260,
                              child: TextField(
                                controller: _hallCharge,
                                decoration: const InputDecoration(
                                  labelText: 'Hall Rental Charge (CAD)',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...services.map((service) {
                              final checked = _selectedServices.containsKey(service.id);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
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
                                          key: ValueKey('${service.id}-${_selectedServices[service.id]}'),
                                          initialValue: (_selectedServices[service.id] ?? 1)
                                              .toStringAsFixed(0),
                                          decoration: const InputDecoration(labelText: 'Hours'),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (value) => setState(() {
                                            _selectedServices[service.id] =
                                                double.tryParse(value) ?? 0;
                                          }),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Notes & New Reservation Summary',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notes,
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: 'Notes'),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 18,
                            runSpacing: 8,
                            children: [
                              _summary('Hall', _isChurchUse ? 0 : _hallValue),
                              _summary('Services', _servicesTotal),
                              _summary('Extra Time', _extraTimeCharge),
                              _summary('Total', _total, strong: true),
                              _summary('Required Deposit', deposit, strong: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _saving || _available == false ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.copy_all_outlined),
                        label: const Text('Create New Reservation'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
              ? '$label is required'
              : null
          : null,
    );
  }

  Widget _summary(String label, double value, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: \$${value.toStringAsFixed(2)}',
        style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600),
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}';

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _dateTime(DateTime value) => '${_date(value)} ${_time(value)}';
}
