import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wesley_models.dart';
import '../services/application_scan_service.dart';
import '../services/paper_application_service.dart';
import '../services/wesley_repository.dart';

class ScanApplicationPage extends StatefulWidget {
  const ScanApplicationPage({super.key, required this.repository});

  final WesleyRepository repository;

  @override
  State<ScanApplicationPage> createState() => _ScanApplicationPageState();
}

class _ScanApplicationPageState extends State<ScanApplicationPage> {
  final _picker = ImagePicker();
  SettingsBundle? _settings;
  Uint8List? _scanBytes;
  String _scanExtension = 'jpg';
  bool _extracting = false;
  bool _saving = false;
  String? _error;

  final _client = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _eventName = TextEditingController();
  final _guests = TextEditingController();
  final _notes = TextEditingController();

  DateTime? _eventDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _hallId;
  final Set<String> _selectedServiceIds = {};
  Map<String, dynamic> _confidence = const {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _client.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _eventName.dispose();
    _guests.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await widget.repository.loadSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      if (settings.spaces.isNotEmpty) _hallId = settings.spaces.first.id;
    });
  }

  Future<void> _capture(ImageSource source) async {
    setState(() => _error = null);
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2200,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final lower = file.name.toLowerCase();
      final ext = lower.endsWith('.png') ? 'png' : 'jpg';
      setState(() {
        _scanBytes = bytes;
        _scanExtension = ext;
      });
      await _extract();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Unable to open the camera/image: $e');
    }
  }

  Future<void> _extract() async {
    final bytes = _scanBytes;
    final settings = _settings;
    if (bytes == null || settings == null) return;

    setState(() {
      _extracting = true;
      _error = null;
    });

    try {
      final extracted = await ApplicationScanService(
        Supabase.instance.client,
      ).extractImage(
        bytes: bytes,
        mimeType: _scanExtension == 'png' ? 'image/png' : 'image/jpeg',
      );

      _client.text = extracted.clientName;
      _address.text = extracted.address;
      _phone.text = extracted.phone;
      _email.text = extracted.email;
      _eventName.text = extracted.eventName;
      _guests.text = extracted.guestCount?.toString() ?? '';
      _notes.text = extracted.notes;
      _eventDate = DateTime.tryParse(extracted.eventDate);
      _startTime = _parseTime(extracted.startTime);
      _endTime = _parseTime(extracted.endTime);
      _confidence = extracted.confidence;

      final hall = settings.spaces.where((s) => s.active).cast<HallSpace?>().firstWhere(
            (s) => s!.name.trim().toLowerCase() ==
                extracted.hallSpaceName.trim().toLowerCase(),
            orElse: () => null,
          );
      if (hall != null) _hallId = hall.id;

      _selectedServiceIds.clear();
      for (final serviceName in extracted.selectedServices) {
        for (final service in settings.services.where((s) => s.active)) {
          if (service.name.trim().toLowerCase() == serviceName.trim().toLowerCase()) {
            _selectedServiceIds.add(service.id);
          }
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  DateTime _combine(DateTime date, TimeOfDay time) => DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

  Future<void> _save() async {
    final settings = _settings;
    final bytes = _scanBytes;
    if (settings == null || bytes == null) return;
    if (_client.text.trim().isEmpty ||
        _eventName.text.trim().isEmpty ||
        _eventDate == null ||
        _startTime == null ||
        _endTime == null ||
        _hallId == null) {
      setState(() => _error =
          'Please confirm the client, event, date, start time, end time, and hall before saving.');
      return;
    }

    final hall = settings.spaces.firstWhere((s) => s.id == _hallId);
    final start = _combine(_eventDate!, _startTime!);
    var end = _combine(_eventDate!, _endTime!);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    final accessStart = start.subtract(
      Duration(minutes: settings.rules.setupMinutesBefore),
    );
    final vacateEnd = end.add(
      Duration(minutes: settings.rules.cleanupMinutesAfter),
    );

    final conflict = await widget.repository.hasBookingConflict(
      hallSpaceId: hall.id,
      accessStart: accessStart,
      vacateEnd: vacateEnd,
    );
    if (conflict) {
      setState(() => _error =
          'This date/time conflicts with an existing reservation. Please correct it before adding it to the planner.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final extras = settings.services
          .where((s) => _selectedServiceIds.contains(s.id))
          .map((s) => BookingExtra(
                serviceId: s.id,
                name: s.name,
                quantity: 1,
                unitPrice: s.price,
              ))
          .toList();

      final extraTotal = extras.fold<double>(0, (sum, e) => sum + e.total);
      final eventMinutes = end.difference(start).inMinutes;
      final extraMinutes = eventMinutes - settings.rules.standardRentalHours * 60;
      final extraTimeCharge = settings.rules.extraHourRate > 0 && extraMinutes > 0
          ? (extraMinutes / 60).ceil() * settings.rules.extraHourRate
          : 0.0;

      final booking = Booking(
        id: 'scan-${DateTime.now().microsecondsSinceEpoch}',
        referenceNumber: 'WH-${_eventDate!.year}-PENDING',
        clientName: _client.text.trim(),
        clientAddress: _address.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        eventDate: _eventDate!,
        eventStart: start,
        eventEnd: end,
        accessStart: accessStart,
        vacateEnd: vacateEnd,
        eventDetails: _eventName.text.trim(),
        guestCount: int.tryParse(_guests.text.trim()) ?? 0,
        hallSpaceId: hall.id,
        hallSpaceName: hall.name,
        hallCharge: hall.baseRate,
        extraTimeCharge: extraTimeCharge,
        status: 'awaiting_deposit',
        extras: extras,
        bookingDepositPercent: settings.rules.bookingDepositPercent,
        damageDepositRequired: settings.rules.damageDepositAmount,
        notes: _notes.text.trim(),
      );

      await widget.repository.createBooking(booking);

      final created = (await widget.repository.listBookings())
          .where((b) =>
              b.clientName == booking.clientName &&
              b.eventDetails == booking.eventDetails &&
              b.eventStart == booking.eventStart)
          .toList();
      if (created.isNotEmpty) {
        created.sort((a, b) => b.referenceNumber.compareTo(a.referenceNumber));
        await PaperApplicationService(Supabase.instance.client).uploadForBooking(
          bookingId: created.first.id,
          bytes: bytes,
          extension: _scanExtension,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanned application added to the Hall Planner.'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Unable to save the application: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Paper Application')),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const SizedBox(
                                width: 430,
                                child: Text(
                                  'Photograph the completed application. Wesley Hall will extract the details, but nothing is added to the calendar until you review and confirm it.',
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _extracting
                                    ? null
                                    : () => _capture(ImageSource.camera),
                                icon: const Icon(Icons.document_scanner_outlined),
                                label: const Text('Scan with Camera'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _extracting
                                    ? null
                                    : () => _capture(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('Choose Photo'),
                              ),
                              if (_scanBytes != null)
                                const Chip(
                                  avatar: Icon(Icons.check_circle_outline, size: 18),
                                  label: Text('Image captured'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_extracting) ...[
                        const SizedBox(height: 14),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 7),
                        const Text('Reading handwriting and checked boxes...'),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_error!),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text('Review Extracted Application',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              )),
                      const SizedBox(height: 6),
                      const Text(
                          'Correct any handwriting the system misread before adding the reservation to the planner.'),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Row(children: [
                                Expanded(child: _field(_client, 'Client Name', 'client_name')),
                                const SizedBox(width: 12),
                                Expanded(child: _field(_phone, 'Telephone', null)),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: _field(_email, 'Email', null)),
                                const SizedBox(width: 12),
                                Expanded(child: _field(_address, 'Address', null)),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: _field(_eventName, 'Event / Function', null)),
                                const SizedBox(width: 12),
                                SizedBox(width: 180, child: _field(_guests, 'Guests', null)),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: _dateButton()),
                                const SizedBox(width: 12),
                                Expanded(child: _timeButton('Start Time', true)),
                                const SizedBox(width: 12),
                                Expanded(child: _timeButton('End Time', false)),
                              ]),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _hallId,
                                decoration: InputDecoration(
                                  labelText: _labelWithConfidence(
                                      'Hall Space', 'hall_space_name'),
                                ),
                                items: settings.spaces
                                    .where((s) => s.active)
                                    .map((s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Text('${s.name}  •  \$${s.baseRate.toStringAsFixed(2)}'),
                                        ))
                                    .toList(),
                                onChanged: (value) => setState(() => _hallId = value),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Services / Facilities',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(height: 6),
                              ...settings.services.where((s) => s.active).map(
                                    (service) => CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      value: _selectedServiceIds.contains(service.id),
                                      title: Text(
                                        '${service.name} - \$${service.price.toStringAsFixed(2)}${service.pricingType == 'hourly' ? '/hr' : ''}',
                                      ),
                                      onChanged: (checked) => setState(() {
                                        if (checked == true) {
                                          _selectedServiceIds.add(service.id);
                                        } else {
                                          _selectedServiceIds.remove(service.id);
                                        }
                                      }),
                                    ),
                                  ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _notes,
                                maxLines: 3,
                                decoration: const InputDecoration(labelText: 'Notes'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _saving || _scanBytes == null ? null : _save,
                          icon: const Icon(Icons.event_available_outlined),
                          label: const Text('Confirm & Add to Planner'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _field(
      TextEditingController controller, String label, String? confidenceKey) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: _labelWithConfidence(label, confidenceKey),
      ),
    );
  }

  String _labelWithConfidence(String label, String? key) {
    if (key == null) return label;
    final value = _confidence[key];
    if (value is num && value < .75) return '$label - CHECK';
    return label;
  }

  Widget _dateButton() => OutlinedButton.icon(
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _eventDate ?? DateTime.now(),
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
          );
          if (picked != null) setState(() => _eventDate = picked);
        },
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text(_eventDate == null
            ? 'Event Date - CHECK'
            : '${_eventDate!.month}/${_eventDate!.day}/${_eventDate!.year}'),
      );

  Widget _timeButton(String label, bool start) => OutlinedButton.icon(
        onPressed: () async {
          final current = start ? _startTime : _endTime;
          final picked = await showTimePicker(
            context: context,
            initialTime: current ?? const TimeOfDay(hour: 18, minute: 0),
          );
          if (picked != null) {
            setState(() {
              if (start) {
                _startTime = picked;
              } else {
                _endTime = picked;
              }
            });
          }
        },
        icon: const Icon(Icons.schedule_outlined),
        label: Text(
          (start ? _startTime : _endTime)?.format(context) ?? '$label - CHECK',
        ),
      );
}
