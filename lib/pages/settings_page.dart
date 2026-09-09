import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/wesley_models.dart';
import '../services/wesley_repository.dart';
import '../widgets/page_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.repository,
    required this.onSaved,
  });

  final WesleyRepository repository;
  final VoidCallback onSaved;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsBundle? bundle;
  bool saving = false;

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
  final earliest = TextEditingController();
  final latest = TextEditingController();
  final extraRate = TextEditingController();
  final deposit = TextEditingController();
  final damage = TextEditingController();

  bool autoSignature = true;
  Uint8List? signature;
  String? signaturePath;
  Uint8List? organizationLogo;
  String? organizationLogoPath;

  static const _green = Color(0xFF116149);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    hall.dispose();
    church.dispose();
    address.dispose();
    phone.dispose();
    email.dispose();
    manager.dispose();
    title.dispose();
    hours.dispose();
    setup.dispose();
    cleanup.dispose();
    earliest.dispose();
    latest.dispose();
    extraRate.dispose();
    deposit.dispose();
    damage.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final b = await widget.repository.loadSettings();
    final sig = await widget.repository
        .loadManagerSignature(b.organization.managerSignaturePath);
    final logo = await widget.repository
        .loadOrganizationLogo(b.organization.organizationLogoPath);
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
      organizationLogoPath = b.organization.organizationLogoPath;
      organizationLogo = logo;
      hours.text = '${b.rules.standardRentalHours}';
      setup.text = '${b.rules.setupMinutesBefore}';
      cleanup.text = '${b.rules.cleanupMinutesAfter}';
      earliest.text = b.rules.earliestAccess;
      latest.text = b.rules.latestVacate;
      extraRate.text = b.rules.extraHourRate.toStringAsFixed(2);
      deposit.text = b.rules.bookingDepositPercent.toStringAsFixed(0);
      damage.text = b.rules.damageDepositAmount.toStringAsFixed(2);
    });
  }

  Future<({Uint8List bytes, String extension})?> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.bytes == null) return null;
    var ext = (file.extension ?? 'png').toLowerCase();
    if (ext == 'jpeg') ext = 'jpg';
    return (bytes: file.bytes!, extension: ext);
  }

  Future<void> _pickLogo() async {
    final selected = await _pickImage();
    if (selected == null) return;
    final path = await widget.repository
        .uploadOrganizationLogo(selected.bytes, selected.extension);
    if (!mounted) return;
    setState(() {
      organizationLogo = selected.bytes;
      organizationLogoPath = path;
    });
  }

  Future<void> _pickSignature() async {
    final selected = await _pickImage();
    if (selected == null) return;
    final path = await widget.repository
        .uploadManagerSignature(selected.bytes, selected.extension);
    if (!mounted) return;
    setState(() {
      signature = selected.bytes;
      signaturePath = path;
    });
  }

  Future<void> _save() async {
    final b = bundle;
    if (b == null || saving) return;
    setState(() => saving = true);
    try {
      await widget.repository.saveOrganization(
        OrganizationSettings(
          churchName: church.text.trim(),
          hallName: hall.text.trim(),
          address: address.text.trim(),
          phone: phone.text.trim(),
          email: email.text.trim(),
          managerName: manager.text.trim(),
          managerTitle: title.text.trim(),
          organizationLogoPath: organizationLogoPath,
          managerSignaturePath: signaturePath,
          autoIncludeManagerSignature: autoSignature,
        ),
      );
      await widget.repository.saveRentalRules(
        RentalRules(
          standardRentalHours:
              int.tryParse(hours.text) ?? b.rules.standardRentalHours,
          setupMinutesBefore:
              int.tryParse(setup.text) ?? b.rules.setupMinutesBefore,
          cleanupMinutesAfter:
              int.tryParse(cleanup.text) ?? b.rules.cleanupMinutesAfter,
          earliestAccess: earliest.text.trim().isEmpty
              ? b.rules.earliestAccess
              : earliest.text.trim(),
          latestVacate: latest.text.trim().isEmpty
              ? b.rules.latestVacate
              : latest.text.trim(),
          extraHourRate: double.tryParse(extraRate.text) ?? 0,
          bookingDepositPercent: double.tryParse(deposit.text) ?? 50,
          damageDepositAmount: double.tryParse(damage.text) ?? 500,
          chargeSetupTime: b.rules.chargeSetupTime,
          chargeCleanupTime: b.rules.chargeCleanupTime,
        ),
      );
      await widget.repository.saveTerms(b.terms);
      await widget.repository.saveSpaces(b.spaces);
      await widget.repository.saveServices(b.services);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wesley Hall settings saved.')),
      );
      widget.onSaved();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save settings: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _editTerm({RentalTerm? existing}) async {
    final b = bundle!;
    final controller = TextEditingController(text: existing?.text ?? '');
    var active = existing?.active ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: Text(existing == null ? 'Add Rental Term' : 'Edit Rental Term'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Term / Condition'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active on rental contract'),
                  value: active,
                  onChanged: (v) => setModal(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;

    final items = [...b.terms];
    if (existing == null) {
      items.add(RentalTerm(
        id: 'term-${DateTime.now().microsecondsSinceEpoch}',
        text: controller.text.trim(),
        order: items.length + 1,
        active: active,
      ));
    } else {
      final i = items.indexWhere((e) => e.id == existing.id);
      items[i] = RentalTerm(
        id: existing.id,
        text: controller.text.trim(),
        order: existing.order,
        active: active,
      );
    }
    setState(() => bundle = b.copyWith(terms: items));
  }

  Future<void> _editSpace({HallSpace? existing}) async {
    final b = bundle!;
    final name = TextEditingController(text: existing?.name ?? '');
    final rate = TextEditingController(
        text: existing?.baseRate.toStringAsFixed(2) ?? '0.00');
    final capacity = TextEditingController(
        text: existing?.capacity?.toString() ?? '');
    var active = existing?.active ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: Text(existing == null ? 'Add Hall Space' : 'Edit Hall Space'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Space Name')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: rate, decoration: const InputDecoration(labelText: 'Base Rate (CAD)'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: capacity, decoration: const InputDecoration(labelText: 'Capacity'))),
                ]),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active / available for new bookings'),
                  value: active,
                  onChanged: (v) => setModal(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;

    final items = [...b.spaces];
    final item = HallSpace(
      id: existing?.id ?? 'space-${DateTime.now().microsecondsSinceEpoch}',
      name: name.text.trim(),
      baseRate: double.tryParse(rate.text) ?? 0,
      capacity: int.tryParse(capacity.text),
      active: active,
    );
    if (existing == null) {
      items.add(item);
    } else {
      items[items.indexWhere((e) => e.id == existing.id)] = item;
    }
    setState(() => bundle = b.copyWith(spaces: items));
  }

  Future<void> _editService({ServiceItem? existing}) async {
    final b = bundle!;
    final name = TextEditingController(text: existing?.name ?? '');
    final price = TextEditingController(
        text: existing?.price.toStringAsFixed(2) ?? '0.00');
    var pricing = existing?.pricingType ?? 'flat';
    var active = existing?.active ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: Text(existing == null ? 'Add Service' : 'Edit Service'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Service Name')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: pricing,
                      decoration: const InputDecoration(labelText: 'Pricing Type'),
                      items: const [
                        DropdownMenuItem(value: 'flat', child: Text('Flat Rate')),
                        DropdownMenuItem(value: 'hourly', child: Text('Per Hour')),
                      ],
                      onChanged: (v) => setModal(() => pricing = v ?? pricing),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: price, decoration: const InputDecoration(labelText: 'Price (CAD)'))),
                ]),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active / available for new bookings'),
                  value: active,
                  onChanged: (v) => setModal(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;

    final items = [...b.services];
    final item = ServiceItem(
      id: existing?.id ?? 'service-${DateTime.now().microsecondsSinceEpoch}',
      name: name.text.trim(),
      pricingType: pricing,
      price: double.tryParse(price.text) ?? 0,
      active: active,
    );
    if (existing == null) {
      items.add(item);
    } else {
      items[items.indexWhere((e) => e.id == existing.id)] = item;
    }
    setState(() => bundle = b.copyWith(services: items));
  }

  Future<bool> _confirmDelete(String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete $title?'),
            content: Text('This will permanently remove this $title from Wesley Hall settings.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteTerm(RentalTerm item) async {
    if (!await _confirmDelete('rental term')) return;
    try {
      await widget.repository.deleteTerm(item.id);
      final b = bundle!;
      final remaining = b.terms.where((e) => e.id != item.id).toList();
      final reordered = [
        for (var i = 0; i < remaining.length; i++)
          RentalTerm(
            id: remaining[i].id,
            text: remaining[i].text,
            order: i + 1,
            active: remaining[i].active,
          )
      ];
      setState(() => bundle = b.copyWith(terms: reordered));
    } catch (e) {
      _showError('This term could not be deleted: $e');
    }
  }

  Future<void> _deleteSpace(HallSpace item) async {
    if (!await _confirmDelete('hall space')) return;
    try {
      await widget.repository.deleteSpace(item.id);
      final b = bundle!;
      setState(() => bundle = b.copyWith(
          spaces: b.spaces.where((e) => e.id != item.id).toList()));
    } catch (_) {
      _showError('This hall space may already be used by a booking. Turn it off with the Active switch instead.');
    }
  }

  Future<void> _deleteService(ServiceItem item) async {
    if (!await _confirmDelete('service')) return;
    try {
      await widget.repository.deleteService(item.id);
      final b = bundle!;
      setState(() => bundle = b.copyWith(
          services: b.services.where((e) => e.id != item.id).toList()));
    } catch (_) {
      _showError('This service may already be used by a booking. Turn it off with the Active switch instead.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _moveTerm(int index, int delta) {
    final b = bundle!;
    final target = index + delta;
    if (target < 0 || target >= b.terms.length) return;
    final list = [...b.terms];
    final item = list.removeAt(index);
    list.insert(target, item);
    final reordered = [
      for (var i = 0; i < list.length; i++)
        RentalTerm(
          id: list[i].id,
          text: list[i].text,
          order: i + 1,
          active: list[i].active,
        )
    ];
    setState(() => bundle = b.copyWith(terms: reordered));
  }

  @override
  Widget build(BuildContext context) {
    final b = bundle;
    if (b == null) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Settings',
            subtitle:
                'Hall details, branding, manager signature, rental times, rates, and contract conditions.',
            trailing: FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Settings'),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 1040;
                  final left = Column(children: [
                    _organizationCard(),
                    const SizedBox(height: 14),
                    _rentalRulesCard(b),
                    const SizedBox(height: 14),
                    _hallSpacesCard(b),
                  ]);
                  final right = Column(children: [
                    _managerCard(),
                    const SizedBox(height: 14),
                    _termsCard(b),
                    const SizedBox(height: 14),
                    _servicesCard(b),
                  ]);
                  if (!twoColumns) {
                    return Column(children: [left, const SizedBox(height: 14), right]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 16),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _organizationCard() => _sectionCard(
        icon: Icons.church_outlined,
        title: 'Organization Branding',
        subtitle: 'Your church and hall information appears on bookings and contracts.',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 185,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Church Logo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  Container(
                    height: 125,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAF8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDDE5E0)),
                    ),
                    child: organizationLogo == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.church_outlined, size: 38, color: _green),
                              SizedBox(height: 5),
                              Text('WESLEY HALL', style: TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          )
                        : Image.memory(organizationLogo!, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.upload_outlined, size: 17),
                    label: Text(organizationLogo == null ? 'Upload Logo' : 'Replace Logo'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(children: [
                Row(children: [
                  Expanded(child: _field(church, 'Church Name')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(hall, 'Hall Name')),
                ]),
                const SizedBox(height: 10),
                _field(address, 'Address'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(phone, 'Phone')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(email, 'Email')),
                ]),
              ]),
            ),
          ],
        ),
      );

  Widget _managerCard() => _sectionCard(
        icon: Icons.person_outline,
        title: 'Authorized Manager',
        subtitle: 'Manager details and signature for contracts.',
        child: Column(children: [
          Row(children: [
            Expanded(child: _field(manager, 'Manager Name')),
            const SizedBox(width: 10),
            Expanded(child: _field(title, 'Title')),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Signature', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 7),
                Container(
                  height: 86,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAF9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDDE5E0)),
                  ),
                  child: signature == null
                      ? const Text('No signature uploaded')
                      : Image.memory(signature!, fit: BoxFit.contain),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickSignature,
                  icon: const Icon(Icons.upload_file_outlined, size: 17),
                  label: Text(signature == null ? 'Upload Signature' : 'Replace Signature'),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-include Signature', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Automatically include this signature on contracts.', style: TextStyle(fontSize: 12)),
                  value: autoSignature,
                  onChanged: (v) => setState(() => autoSignature = v),
                ),
              ),
            ),
          ]),
        ]),
      );

  Widget _rentalRulesCard(SettingsBundle b) => _sectionCard(
        icon: Icons.schedule_outlined,
        title: 'Rental Rules',
        subtitle: 'Default times, deposits, and other rental settings.',
        child: Column(children: [
          Row(children: [
            Expanded(child: _field(hours, 'Standard Rental Hours')),
            const SizedBox(width: 10),
            Expanded(child: _field(setup, 'Setup Time Before (minutes)')),
            const SizedBox(width: 10),
            Expanded(child: _field(cleanup, 'Cleanup Time After (minutes)')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(earliest, 'Earliest Access Time', hint: '08:00')),
            const SizedBox(width: 10),
            Expanded(child: _field(latest, 'Latest Vacate Time', hint: '00:00')),
            const SizedBox(width: 10),
            Expanded(child: _field(extraRate, 'Additional Hour Rate (CAD)')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(deposit, 'Booking Deposit Percentage')),
            const SizedBox(width: 10),
            Expanded(child: _field(damage, 'Damage Deposit Amount (CAD)')),
          ]),
        ]),
      );

  Widget _termsCard(SettingsBundle b) => _sectionCard(
        icon: Icons.description_outlined,
        title: 'Rental Terms & Conditions',
        subtitle: 'Edit the terms that appear in the rental agreement.',
        action: OutlinedButton.icon(
          onPressed: () => _editTerm(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Term'),
        ),
        child: Column(
          children: [
            for (var i = 0; i < b.terms.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE6ECE8)),
                ),
                child: Row(children: [
                  Column(children: [
                    InkWell(onTap: i == 0 ? null : () => _moveTerm(i, -1), child: const Icon(Icons.keyboard_arrow_up, size: 17)),
                    InkWell(onTap: i == b.terms.length - 1 ? null : () => _moveTerm(i, 1), child: const Icon(Icons.keyboard_arrow_down, size: 17)),
                  ]),
                  const SizedBox(width: 5),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFCAF3DE),
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 10, color: _green)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(b.terms[i].text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  Switch(
                    value: b.terms[i].active,
                    onChanged: (v) {
                      final list = [...b.terms];
                      final t = list[i];
                      list[i] = RentalTerm(id: t.id, text: t.text, order: t.order, active: v);
                      setState(() => bundle = b.copyWith(terms: list));
                    },
                  ),
                  IconButton(tooltip: 'Edit term', onPressed: () => _editTerm(existing: b.terms[i]), icon: const Icon(Icons.edit_outlined, size: 18, color: _green)),
                  IconButton(tooltip: 'Delete term', onPressed: () => _deleteTerm(b.terms[i]), icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFC54B4B))),
                ]),
              ),
          ],
        ),
      );

  Widget _hallSpacesCard(SettingsBundle b) => _sectionCard(
        icon: Icons.meeting_room_outlined,
        title: 'Hall Spaces',
        subtitle: 'Manage available hall spaces and their base rates.',
        action: OutlinedButton.icon(
          onPressed: () => _editSpace(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Space'),
        ),
        child: _responsiveTable(
          headings: const ['Name', 'Base Rate', 'Capacity', 'Active', 'Actions'],
          rows: b.spaces.map((h) => [
            Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('\$${h.baseRate.toStringAsFixed(2)}'),
            Text(h.capacity?.toString() ?? '—'),
            Switch(
              value: h.active,
              onChanged: (v) {
                final list = [...b.spaces];
                final i = list.indexWhere((e) => e.id == h.id);
                list[i] = HallSpace(id: h.id, name: h.name, baseRate: h.baseRate, capacity: h.capacity, active: v);
                setState(() => bundle = b.copyWith(spaces: list));
              },
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: () => _editSpace(existing: h), icon: const Icon(Icons.edit_outlined, color: _green)),
              IconButton(onPressed: () => _deleteSpace(h), icon: const Icon(Icons.delete_outline, color: Color(0xFFC54B4B))),
            ]),
          ]).toList(),
        ),
      );

  Widget _servicesCard(SettingsBundle b) => _sectionCard(
        icon: Icons.room_service_outlined,
        title: 'Service Rates',
        subtitle: 'Manage additional services and their pricing.',
        action: OutlinedButton.icon(
          onPressed: () => _editService(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Service'),
        ),
        child: _responsiveTable(
          headings: const ['Service Name', 'Pricing Type', 'Price', 'Active', 'Actions'],
          rows: b.services.map((s) => [
            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(s.pricingType == 'hourly' ? 'Per Hour' : 'Flat Rate'),
            Text('\$${s.price.toStringAsFixed(2)}'),
            Switch(
              value: s.active,
              onChanged: (v) {
                final list = [...b.services];
                final i = list.indexWhere((e) => e.id == s.id);
                list[i] = ServiceItem(id: s.id, name: s.name, pricingType: s.pricingType, price: s.price, active: v);
                setState(() => bundle = b.copyWith(services: list));
              },
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: () => _editService(existing: s), icon: const Icon(Icons.edit_outlined, color: _green)),
              IconButton(onPressed: () => _deleteService(s), icon: const Icon(Icons.delete_outline, color: Color(0xFFC54B4B))),
            ]),
          ]).toList(),
        ),
      );

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? action,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFDDF6E8),
                child: Icon(icon, color: _green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF708079))),
                ]),
              ),
              if (action != null) action,
            ]),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _responsiveTable({
    required List<String> headings,
    required List<List<Widget>> rows,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F5F2)),
        columns: headings.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)))).toList(),
        rows: rows.map((r) => DataRow(cells: r.map((w) => DataCell(w)).toList())).toList(),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {String? hint}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
