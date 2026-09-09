import 'package:flutter/material.dart';

import '../models/wesley_models.dart';
import '../services/wesley_repository.dart';
import '../widgets/page_header.dart';

class NewBookingPage extends StatefulWidget {
  const NewBookingPage({super.key, required this.repository, required this.onSaved});
  final WesleyRepository repository;
  final VoidCallback onSaved;

  @override
  State<NewBookingPage> createState() => _NewBookingPageState();
}

class _NewBookingPageState extends State<NewBookingPage> {
  final formKey = GlobalKey<FormState>();
  final client = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final details = TextEditingController();
  final guests = TextEditingController();
  final notes = TextEditingController();
  final hallCharge = TextEditingController();
  SettingsBundle? settings;
  String? hallId;
  DateTime eventDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay start = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 23, minute: 0);
  final Map<String, double> selected = {};
  bool saving = false;
  bool? available;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final s = await widget.repository.loadSettings();
    if (!mounted) return;
    setState(() {
      settings = s;
      if (s.spaces.isNotEmpty) {
        hallId = s.spaces.first.id;
        hallCharge.text = s.spaces.first.baseRate.toStringAsFixed(2);
      }
    });
    checkAvailability();
  }

  DateTime combine(TimeOfDay t, {bool finish = false}) {
    var d = DateTime(eventDate.year, eventDate.month, eventDate.day, t.hour, t.minute);
    final s = DateTime(eventDate.year, eventDate.month, eventDate.day, start.hour, start.minute);
    if (finish && !d.isAfter(s)) d = d.add(const Duration(days: 1));
    return d;
  }
  DateTime get eventStart => combine(start);
  DateTime get eventEnd => combine(end, finish: true);
  DateTime get accessStart => eventStart.subtract(Duration(minutes: settings?.rules.setupMinutesBefore ?? 0));
  DateTime get vacateEnd => eventEnd.add(Duration(minutes: settings?.rules.cleanupMinutesAfter ?? 0));
  double get hallValue => double.tryParse(hallCharge.text) ?? 0;
  double get extrasTotal => settings == null ? 0 : settings!.services.fold<double>(0, (t, s) => t + (selected[s.id] ?? 0) * s.price);
  double get extraTime {
    final r = settings?.rules;
    if (r == null || r.extraHourRate <= 0) return 0;
    final extra = eventEnd.difference(eventStart).inMinutes - r.standardRentalHours * 60;
    return extra > 0 ? (extra / 60).ceil() * r.extraHourRate : 0;
  }
  double get total => hallValue + extrasTotal + extraTime;

  Future<void> checkAvailability() async {
    if (settings == null || hallId == null) return;
    final conflict = await widget.repository.hasBookingConflict(hallSpaceId: hallId!, accessStart: accessStart, vacateEnd: vacateEnd);
    if (mounted) setState(() => available = !conflict);
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || settings == null || hallId == null) return;
    await checkAvailability();
    if (available != true) return;
    setState(() => saving = true);
    final hall = settings!.spaces.firstWhere((s) => s.id == hallId);
    final extras = settings!.services.where((s) => (selected[s.id] ?? 0) > 0).map((s) => BookingExtra(serviceId: s.id, name: s.name, quantity: selected[s.id]!, unitPrice: s.price)).toList();
    final b = Booking(
      id: 'temp-${DateTime.now().microsecondsSinceEpoch}',
      referenceNumber: 'WH-${eventDate.year}-PENDING',
      clientName: client.text.trim(), clientAddress: address.text.trim(), phone: phone.text.trim(), email: email.text.trim(),
      eventDate: eventDate, eventStart: eventStart, eventEnd: eventEnd, accessStart: accessStart, vacateEnd: vacateEnd,
      eventDetails: details.text.trim(), guestCount: int.tryParse(guests.text) ?? 0,
      hallSpaceId: hall.id, hallSpaceName: hall.name, hallCharge: hallValue, extraTimeCharge: extraTime,
      status: 'awaiting_deposit', extras: extras,
      bookingDepositPercent: settings!.rules.bookingDepositPercent,
      damageDepositRequired: settings!.rules.damageDepositAmount,
      notes: notes.text.trim(),
    );
    await widget.repository.createBooking(b);
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking saved. Status: Awaiting Deposit.')));
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    if (s == null) return const Center(child: CircularProgressIndicator());
    final deposit = total * s.rules.bookingDepositPercent / 100;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Form(key: formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(title: 'New Booking', subtitle: 'Create the client agreement, reserve the hall, and calculate charges.'),
        const SizedBox(height: 18),
        Expanded(child: SingleChildScrollView(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: Column(children: [
            section('Client Information', [
              Row(children: [Expanded(child: field(client, 'Client Name', required: true)), const SizedBox(width: 12), Expanded(child: field(phone, 'Telephone'))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: field(email, 'Email')), const SizedBox(width: 12), Expanded(child: field(address, 'Address'))]),
            ]),
            const SizedBox(height: 14),
            section('Event & Hall', [
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: eventDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 1825))); if (d != null) { setState(() => eventDate = d); checkAvailability(); } }, icon: const Icon(Icons.calendar_today), label: Text(date(eventDate)))),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(initialValue: hallId, decoration: const InputDecoration(labelText: 'Hall Space'), items: s.spaces.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))).toList(), onChanged: (v) { if (v == null) return; final h = s.spaces.firstWhere((x) => x.id == v); setState(() { hallId = v; hallCharge.text = h.baseRate.toStringAsFixed(2); }); checkAvailability(); })),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: timeButton('Event Start', start, (v) => start = v)),
                const SizedBox(width: 12),
                Expanded(child: timeButton('Event End', end, (v) => end = v)),
                const SizedBox(width: 12),
                Expanded(child: field(guests, 'No. of Guests')),
              ]),
              const SizedBox(height: 12), field(details, 'Event Details', required: true),
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: available == false ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Text(available == false ? 'Conflict: hall is occupied during setup/event/cleanup time.' : 'Hall occupancy: ${dateTime(accessStart)} to ${dateTime(vacateEnd)}')),
            ]),
            const SizedBox(height: 14),
            section('Extra Facilities / Services', s.services.map((service) {
              final checked = selected.containsKey(service.id);
              return Row(children: [
                Checkbox(value: checked, onChanged: (v) => setState(() { if (v == true) { selected[service.id] = 1; } else { selected.remove(service.id); } })),
                Expanded(child: Text('${service.name} - \$${service.price.toStringAsFixed(2)}${service.pricingType == 'hourly' ? '/hr' : ''}')),
                if (checked && service.pricingType == 'hourly') SizedBox(width: 90, child: TextFormField(initialValue: '1', decoration: const InputDecoration(labelText: 'Hours'), onChanged: (v) => setState(() => selected[service.id] = double.tryParse(v) ?? 0))),
              ]);
            }).toList()),
            const SizedBox(height: 14), section('Notes', [TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Booking Notes'))]),
          ])),
          const SizedBox(width: 18),
          SizedBox(width: 330, child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Booking Summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16), TextField(controller: hallCharge, decoration: const InputDecoration(labelText: 'Hall Rental Charge (\$)'), onChanged: (_) => setState(() {})),
            const SizedBox(height: 16), moneyLine('Services', extrasTotal), moneyLine('Extra Time', extraTime), const Divider(), moneyLine('Total', total, strong: true), moneyLine('Required ${s.rules.bookingDepositPercent.toStringAsFixed(0)}% Deposit', deposit), moneyLine('Balance After Deposit', total - deposit), const Divider(), moneyLine('Refundable Damage Deposit', s.rules.damageDepositAmount),
            const SizedBox(height: 20), FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save_outlined), label: const Text('Save Booking')),
          ])))),
        ]))),
      ])),
    );
  }

  Widget section(String title, List<Widget> children) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(height: 12), ...children])));
  Widget field(TextEditingController c, String label, {bool required = false}) => TextFormField(controller: c, decoration: InputDecoration(labelText: label), validator: required ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null : null);
  Widget timeButton(String label, TimeOfDay value, void Function(TimeOfDay) update) => OutlinedButton(onPressed: () async { final t = await showTimePicker(context: context, initialTime: value); if (t != null) { setState(() => update(t)); checkAvailability(); } }, child: Text('$label: ${value.format(context)}'));
  Widget moneyLine(String label, double v, {bool strong = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w700 : null))), Text('\$${v.toStringAsFixed(2)}', style: TextStyle(fontWeight: strong ? FontWeight.w800 : null))]));
  String date(DateTime d) => '${d.month}/${d.day}/${d.year}';
  String dateTime(DateTime d) => '${date(d)} ${TimeOfDay.fromDateTime(d).format(context)}';
}
