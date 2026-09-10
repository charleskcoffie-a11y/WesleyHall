import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wesley_models.dart';
import '../services/contract_service.dart';
import '../services/payment_receipt_service.dart';
import '../services/wesley_repository.dart';
import '../widgets/damage_inspection_card.dart';
import 'booking_documents_page.dart';

class BookingDetailPage extends StatefulWidget {
  const BookingDetailPage({
    super.key,
    required this.repository,
    required this.bookingId,
  });

  final WesleyRepository repository;
  final String bookingId;

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  Booking? booking;
  SettingsBundle? settings;
  List<AuditEvent> auditEvents = const [];
  String role = 'viewer';
  bool busy = true;

  bool get canManageBooking =>
      role == 'admin' || role == 'manager' || role == 'booking_officer';
  bool get canRecordPayments => canManageBooking || role == 'finance';
  bool get canPrintFinancialDocuments => canRecordPayments;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final s = await widget.repository.loadSettings();
    final rows = await widget.repository.listBookings();
    final audit = await widget.repository.listAuditLog(widget.bookingId);
    var loadedRole = 'viewer';
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('wesley_staff_users')
            .select('role')
            .eq('user_id', user.id)
            .single();
        loadedRole = profile['role']?.toString() ?? 'viewer';
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      settings = s;
      booking = rows.where((b) => b.id == widget.bookingId).firstOrNull;
      auditEvents = audit;
      role = loadedRole;
      busy = false;
    });
  }

  Future<void> recordPayment() async {
    if (!canRecordPayments) return;
    final b = booking!;
    var type = b.bookingDepositPaid < b.requiredBookingDeposit
        ? 'booking_deposit'
        : b.remainingRentalBalance > 0
            ? 'rental_balance'
            : 'damage_deposit';
    var method = 'E-Transfer';
    final amount = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();

    double suggestion() {
      if (type == 'booking_deposit') {
        return (b.requiredBookingDeposit - b.bookingDepositPaid)
            .clamp(0.0, double.infinity)
            .toDouble();
      }
      if (type == 'rental_balance') return b.remainingRentalBalance;
      if (type == 'damage_deposit') {
        final received = b.payments
            .where((p) => p.paymentType == 'damage_deposit')
            .fold<double>(0, (total, p) => total + p.amount);
        return (b.damageDepositRequired - received)
            .clamp(0.0, double.infinity)
            .toDouble();
      }
      if (type == 'damage_refund') return b.damageDepositHeld;
      return 0;
    }

    amount.text = suggestion().toStringAsFixed(2);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: const Text('Record Payment'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Payment Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'booking_deposit', child: Text('Booking Deposit')),
                    DropdownMenuItem(
                        value: 'rental_balance', child: Text('Rental Balance')),
                    DropdownMenuItem(
                        value: 'damage_deposit', child: Text('Damage Deposit')),
                    DropdownMenuItem(
                        value: 'damage_refund',
                        child: Text('Damage Deposit Refund')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setModal(() {
                    type = v!;
                    amount.text = suggestion().toStringAsFixed(2);
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: amount,
                    decoration: const InputDecoration(labelText: 'Amount (CAD)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: const [
                    DropdownMenuItem(
                        value: 'E-Transfer', child: Text('E-Transfer')),
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                    DropdownMenuItem(
                        value: 'Debit / Credit', child: Text('Debit / Credit')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => method = v ?? method,
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: reference,
                    decoration:
                        const InputDecoration(labelText: 'Reference / Receipt No.')),
                const SizedBox(height: 12),
                TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Record')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final value = double.tryParse(amount.text) ?? 0;
    if (value <= 0) return;

    setState(() => busy = true);
    await widget.repository.addPayment(
      b.id,
      PaymentRecord(
        id: 'temp-${DateTime.now().microsecondsSinceEpoch}',
        paymentType: type,
        amount: value,
        paymentDate: DateTime.now(),
        paymentMethod: method,
        paymentReference: reference.text.trim(),
        notes: notes.text.trim(),
      ),
    );
    await load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(booking?.status == 'confirmed'
            ? 'Payment recorded. Booking is CONFIRMED.'
            : 'Payment recorded.'),
      ),
    );
  }

  Future<void> printPaymentReceipt(PaymentRecord payment) async {
    if (!canPrintFinancialDocuments) return;
    final b = booking!;
    final s = settings!;
    try {
      final logo = await widget.repository.loadOrganizationLogo(
        s.organization.organizationLogoPath,
      );
      final bytes = await PaymentReceiptService().build(
        booking: b,
        payment: payment,
        settings: s,
        organizationLogo: logo,
      );
      await Printing.layoutPdf(
        name: _receiptFileName(b, payment),
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print receipt: $e')),
      );
    }
  }

  Future<void> signContract() async {
    if (!canManageBooking) return;
    final b = booking!;
    final boundaryKey = GlobalKey();
    final strokes = <List<Offset>>[];

    final signed = await showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setModal) {
            Future<void> saveSignature() async {
              if (strokes.isEmpty || strokes.every((s) => s.length < 2)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please sign before saving.')),
                );
                return;
              }
              final boundary = boundaryKey.currentContext?.findRenderObject()
                  as RenderRepaintBoundary?;
              if (boundary == null) return;
              final image = await boundary.toImage(pixelRatio: 2.5);
              final data = await image.toByteData(format: ui.ImageByteFormat.png);
              if (data == null || !dialogContext.mounted) return;
              Navigator.pop(dialogContext, data.buffer.asUint8List());
            }

            return AlertDialog(
              title: Text('Client Signature - ${b.clientName}'),
              content: SizedBox(
                width: 720,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                        'Please review the contract terms, then sign inside the box using your finger or stylus.'),
                    const SizedBox(height: 14),
                    RepaintBoundary(
                      key: boundaryKey,
                      child: Container(
                        height: 260,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black54),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (details) {
                              setModal(() {
                                strokes.add([details.localPosition]);
                              });
                            },
                            onPanUpdate: (details) {
                              setModal(() {
                                if (strokes.isEmpty) {
                                  strokes.add([details.localPosition]);
                                } else {
                                  strokes.last.add(details.localPosition);
                                }
                              });
                            },
                            child: CustomPaint(
                              painter: _SignaturePainter(strokes),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'By saving this signature, the client confirms agreement to the rental terms.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => setModal(strokes.clear),
                    child: const Text('Clear')),
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton.icon(
                    onPressed: saveSignature,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Signature')),
              ],
            );
          },
        );
      },
    );

    if (signed == null) return;
    setState(() => busy = true);
    await widget.repository.saveClientSignature(b.id, signed);
    await load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Client signature saved. The signed contract is ready to print.')),
    );
  }

  Future<void> printContract() async {
    if (!canManageBooking) return;
    final b = booking!;
    final s = settings!;
    try {
      final managerSignature = await widget.repository
          .loadManagerSignature(s.organization.managerSignaturePath);
      final logo = await widget.repository
          .loadOrganizationLogo(s.organization.organizationLogoPath);
      final clientSignature = await widget.repository
          .loadClientSignature(b.clientSignaturePath);
      final bytes = await ContractService().buildContract(
        booking: b,
        settings: s,
        managerSignature: managerSignature,
        organizationLogo: logo,
        clientSignature: clientSignature,
      );
      await Printing.layoutPdf(
        name: _contractFileName(b),
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print contract: $e')),
      );
    }
  }

  Future<void> openDocuments() async {
    final b = booking;
    if (b == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingDocumentsPage(booking: b)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (busy && booking == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final b = booking;
    if (b == null) {
      return const Scaffold(body: Center(child: Text('Booking not found.')));
    }

    final depositDue = (b.requiredBookingDeposit - b.bookingDepositPaid)
        .clamp(0.0, double.infinity)
        .toDouble();
    final damageReceived = b.payments
        .where((p) => p.paymentType == 'damage_deposit')
        .fold<double>(0, (total, p) => total + p.amount);
    final damageDue = b.status == 'completed'
        ? 0.0
        : (b.damageDepositRequired - damageReceived)
            .clamp(0.0, double.infinity)
            .toDouble();

    return Scaffold(
      appBar: AppBar(title: Text('${b.referenceNumber} - ${b.clientName}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: openDocuments,
                      icon: const Icon(Icons.folder_outlined),
                      label: const Text('Document Centre'),
                    ),
                    if (canManageBooking) ...[
                      FilledButton.icon(
                        onPressed: busy ? null : signContract,
                        icon: const Icon(Icons.draw_outlined),
                        label: Text(b.clientSignaturePath == null
                            ? 'Sign Contract on Tablet'
                            : 'Replace Client Signature'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: busy ? null : printContract,
                        icon: const Icon(Icons.print_outlined),
                        label: Text(b.clientSignaturePath == null
                            ? 'Print Contract for Signature'
                            : 'Print Signed Contract'),
                      ),
                    ],
                    if (b.clientSignaturePath != null)
                      const Chip(
                          avatar: Icon(Icons.verified_outlined, size: 17),
                          label: Text('CLIENT SIGNED')),
                    Chip(
                      avatar: const Icon(Icons.shield_outlined, size: 17),
                      label: Text(_roleLabel(role)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                metric('Total Rental', b.totalCharge),
                metric('Required Deposit', b.requiredBookingDeposit),
                metric('Deposit Due', depositDue),
                metric('Rental Balance', b.remainingRentalBalance),
                metric('Damage Deposit Held', b.damageDepositHeld),
                metric('Damage Deposit Due', damageDue),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${b.eventDetails} • ${b.hallSpaceName}',
                            style: Theme.of(context).textTheme.titleLarge),
                        Chip(
                            label: Text(b.status
                                .replaceAll('_', ' ')
                                .toUpperCase())),
                        if (b.isRecurring)
                          Chip(
                            avatar: const Icon(Icons.repeat_outlined, size: 17),
                            label: Text(
                              '${b.seriesRule == 'monthly' ? 'MONTHLY' : 'WEEKLY'} ${b.seriesIndex ?? '?'} / ${b.seriesCount ?? '?'}',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Event: ${date(b.eventDate)}  ${time(b.eventStart)} - ${time(b.eventEnd)}'),
                    Text('Hall access: ${dateTime(b.accessStart)}'),
                    Text('Vacate by: ${dateTime(b.vacateEnd)}'),
                    Text('Phone: ${b.phone}   Email: ${b.email}'),
                    if (b.holdExpiresAt != null && b.isHold)
                      Text(
                          'Hold expires: ${dateTime(b.holdExpiresAt!.toLocal())}'),
                    if (b.clientSignedAt != null)
                      Text('Client signed: ${dateTime(b.clientSignedAt!)}'),
                  ],
                ),
              ),
            ),
            if (canManageBooking &&
                !b.isHold &&
                b.status != 'cancelled') ...[
              const SizedBox(height: 16),
              DamageInspectionCard(
                booking: b,
                repository: widget.repository,
                onChanged: load,
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history_outlined,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Booking File / Timeline',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                        'A running history of changes, signatures, payments, inspections, and status updates for this reservation.'),
                    const SizedBox(height: 14),
                    if (auditEvents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                            'No timeline entries yet. New activity will appear here automatically.'),
                      )
                    else
                      ...auditEvents.map(_timelineEvent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('Payments',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (canRecordPayments)
                          FilledButton.icon(
                              onPressed: busy ? null : recordPayment,
                              icon: const Icon(Icons.add_card),
                              label: const Text('Record Payment')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (b.payments.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child:
                              Center(child: Text('No payments recorded yet.')))
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('DATE')),
                            DataColumn(label: Text('TYPE')),
                            DataColumn(label: Text('METHOD')),
                            DataColumn(label: Text('REFERENCE')),
                            DataColumn(label: Text('AMOUNT')),
                            DataColumn(label: Text('RECEIPT')),
                          ],
                          rows: b.payments
                              .map((p) => DataRow(cells: [
                                    DataCell(Text(date(p.paymentDate))),
                                    DataCell(Text(
                                        p.paymentType.replaceAll('_', ' '))),
                                    DataCell(Text(p.paymentMethod)),
                                    DataCell(Text(p.paymentReference)),
                                    DataCell(Text(money(p.amount))),
                                    DataCell(canPrintFinancialDocuments
                                        ? OutlinedButton.icon(
                                            onPressed: () =>
                                                printPaymentReceipt(p),
                                            icon: const Icon(
                                                Icons.receipt_long_outlined,
                                                size: 17),
                                            label:
                                                const Text('Print Receipt'),
                                          )
                                        : const Text('View only')),
                                  ]))
                              .toList(),
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

  Widget _timelineEvent(AuditEvent event) {
    final icon = switch (event.action) {
      'created' => Icons.add_circle_outline,
      'payment_recorded' => Icons.payments_outlined,
      'signed' => Icons.draw_outlined,
      'status_changed' => Icons.swap_horiz_outlined,
      'inspection_started' => Icons.fact_check_outlined,
      'inspection_completed' => Icons.task_alt_outlined,
      _ => Icons.edit_outlined,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 18, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.summary,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  dateTime(event.createdAt.toLocal()),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget metric(String label, double value) => SizedBox(
        width: 210,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 6),
                Text(money(value),
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );

  String _roleLabel(String value) => switch (value) {
        'admin' => 'Administrator',
        'manager' => 'Manager',
        'booking_officer' => 'Booking Officer',
        'finance' => 'Finance',
        _ => 'Viewer',
      };

  String _contractFileName(Booking b) {
    final rawName = b.clientName.trim().isEmpty
        ? (b.churchGroup.trim().isEmpty ? 'Client' : b.churchGroup)
        : b.clientName;
    final safeName = _safeName(rawName);
    return '${b.referenceNumber} - $safeName';
  }

  String _receiptFileName(Booking b, PaymentRecord p) {
    final rawName = b.clientName.trim().isEmpty
        ? (b.churchGroup.trim().isEmpty ? 'Client' : b.churchGroup)
        : b.clientName;
    final safeName = _safeName(rawName);
    final type = p.paymentType
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    return '${b.referenceNumber} - $safeName - $type Receipt';
  }

  String _safeName(String value) => value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String money(double v) => '\$${v.toStringAsFixed(2)}';
  String date(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  String time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  String dateTime(DateTime d) => '${date(d)} ${time(d)}';
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
