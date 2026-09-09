import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/wesley_models.dart';
import '../services/wesley_repository.dart';
import '../widgets/page_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.repository, required this.onSaved});
  final WesleyRepository repository;
  final VoidCallback onSaved;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsBundle? bundle;
  final hall = TextEditingController();
  final church = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final manager = TextEditingController();
  final title = TextEditingController();
  final hours = TextEditingController();
  final setup = TextEditingController();
  final cleanup = TextEditingController();
  final extraRate = TextEditingController();
  final deposit = TextEditingController();
  final damage = TextEditingController();
  bool autoSignature = true;
  Uint8List? signature;
  String? signaturePath;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final b = await widget.repository.loadSettings();
    final sig = await widget.repository.loadManagerSignature(b.organization.managerSignaturePath);
    if (!mounted) return;
    setState(() {
      bundle = b;
      hall.text = b.organization.hallName;
      church.text = b.organization.churchName;
      address.text = b.organization.address;
      phone.text = b.organization.phone;
      email.text = b.organization.email;
      manager.text = b.organization.managerName;
      title.text = b.organization.managerTitle;
      autoSignature = b.organization.autoIncludeManagerSignature;
      signaturePath = b.organization.managerSignaturePath;
      signature = sig;
      hours.text = '${b.rules.standardRentalHours}';
      setup.text = '${b.rules.setupMinutesBefore}';
      cleanup.text = '${b.rules.cleanupMinutesAfter}';
      extraRate.text = b.rules.extraHourRate.toStringAsFixed(2);
      deposit.text = b.rules.bookingDepositPercent.toStringAsFixed(0);
      damage.text = b.rules.damageDepositAmount.toStringAsFixed(2);
    });
  }

  Future<void> pickSignature() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png','jpg','jpeg'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    final ext = (file.extension ?? 'png').toLowerCase() == 'jpeg' ? 'jpg' : (file.extension ?? 'png').toLowerCase();
    final path = await widget.repository.uploadManagerSignature(file.bytes!, ext);
    setState(() {
      signature = file.bytes;
      signaturePath = path;
    });
  }

  Future<void> save() async {
    final b = bundle!;
    final org = OrganizationSettings(
      churchName: church.text.trim(), hallName: hall.text.trim(), address: address.text.trim(), phone: phone.text.trim(), email: email.text.trim(),
      managerName: manager.text.trim(), managerTitle: title.text.trim(), managerSignaturePath: signaturePath,
      autoIncludeManagerSignature: autoSignature,
    );
    final rules = RentalRules(
      standardRentalHours: int.tryParse(hours.text) ?? b.rules.standardRentalHours,
      setupMinutesBefore: int.tryParse(setup.text) ?? b.rules.setupMinutesBefore,
      cleanupMinutesAfter: int.tryParse(cleanup.text) ?? b.rules.cleanupMinutesAfter,
      earliestAccess: b.rules.earliestAccess,
      latestVacate: b.rules.latestVacate,
      extraHourRate: double.tryParse(extraRate.text) ?? 0,
      bookingDepositPercent: double.tryParse(deposit.text) ?? 50,
      damageDepositAmount: double.tryParse(damage.text) ?? 500,
      chargeSetupTime: b.rules.chargeSetupTime,
      chargeCleanupTime: b.rules.chargeCleanupTime,
    );
    await widget.repository.saveOrganization(org);
    await widget.repository.saveRentalRules(rules);
    await widget.repository.saveTerms(b.terms);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wesley Hall settings saved.')));
    widget.onSaved();
    load();
  }

  Future<void> addTerm() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Add Rental Condition'),
      content: TextField(controller: c, maxLines: 4, decoration: const InputDecoration(labelText: 'Condition')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add'))],
    ));
    if (ok != true || c.text.trim().isEmpty) return;
    final terms = [...bundle!.terms, RentalTerm(id: 'term-${DateTime.now().microsecondsSinceEpoch}', text: c.text.trim(), order: bundle!.terms.length + 1)];
    await widget.repository.saveTerms(terms);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final b = bundle;
    if (b == null) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(title: 'Settings', subtitle: 'Hall details, manager signature, rental times, rates, and contract conditions.', trailing: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Save Settings'))),
        const SizedBox(height: 18),
        Expanded(child: SingleChildScrollView(child: Column(children: [
          card('Organization & Authorized Manager', [
            Row(children: [Expanded(child: field(hall, 'Hall Name')), const SizedBox(width: 12), Expanded(child: field(church, 'Church / Organization'))]),
            const SizedBox(height: 12), field(address, 'Address'), const SizedBox(height: 12),
            Row(children: [Expanded(child: field(phone, 'Telephone')), const SizedBox(width: 12), Expanded(child: field(email, 'Email'))]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: [field(manager, 'Manager / Authorized Officer'), const SizedBox(height: 12), field(title, 'Position / Title'), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Automatically print manager signature on contracts'), value: autoSignature, onChanged: (v) => setState(() => autoSignature = v))])),
              const SizedBox(width: 18),
              SizedBox(width: 300, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(height: 100, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)), child: signature == null ? const Text('No signature uploaded') : Image.memory(signature!, fit: BoxFit.contain)),
                const SizedBox(height: 8), OutlinedButton.icon(onPressed: pickSignature, icon: const Icon(Icons.upload_file), label: Text(signature == null ? 'Upload Signature' : 'Replace Signature')),
              ])),
            ]),
          ]),
          const SizedBox(height: 14),
          card('Rental Time & Deposit Rules', [
            Row(children: [Expanded(child: field(hours, 'Standard Rental Hours')), const SizedBox(width: 12), Expanded(child: field(setup, 'Setup Minutes Before')), const SizedBox(width: 12), Expanded(child: field(cleanup, 'Cleanup Minutes After'))]),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: field(extraRate, 'Additional Hour Rate (\$)')), const SizedBox(width: 12), Expanded(child: field(deposit, 'Booking Deposit (%)')), const SizedBox(width: 12), Expanded(child: field(damage, 'Refundable Damage Deposit (\$)'))]),
            const SizedBox(height: 8),
            Text('The planner blocks the hall from setup/access time until cleanup/vacate time. Existing bookings keep the deposit terms that applied when they were created.', style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 14),
          card('Rental Terms & Conditions', [
            Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(onPressed: addTerm, icon: const Icon(Icons.add), label: const Text('Add Condition'))),
            ...b.terms.map((t) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 15, child: Text('${t.order}', style: const TextStyle(fontSize: 11))), title: Text(t.text))),
          ]),
          const SizedBox(height: 14),
          card('Hall Spaces & Service Rates', [
            ...b.spaces.map((h) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.meeting_room_outlined), title: Text(h.name), trailing: Text('\$${h.baseRate.toStringAsFixed(2)}'))),
            const Divider(),
            ...b.services.map((s) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.room_service_outlined), title: Text(s.name), trailing: Text('\$${s.price.toStringAsFixed(2)}${s.pricingType == 'hourly' ? '/hr' : ''}'))),
          ]),
        ])),
      ]),
    );
  }

  Widget card(String titleText, List<Widget> children) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(titleText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 14), ...children])));
  Widget field(TextEditingController c, String label) => TextField(controller: c, decoration: InputDecoration(labelText: label));
}
