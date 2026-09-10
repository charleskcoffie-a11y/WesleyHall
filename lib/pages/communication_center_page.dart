import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wesley_models.dart';
import '../services/communication_service.dart';
import '../services/contract_service.dart';
import '../services/payment_receipt_service.dart';
import '../services/wesley_repository.dart';

class CommunicationCenterPage extends StatefulWidget {
  const CommunicationCenterPage({
    super.key,
    required this.repository,
    required this.booking,
  });

  final WesleyRepository repository;
  final Booking booking;

  @override
  State<CommunicationCenterPage> createState() =>
      _CommunicationCenterPageState();
}

class _CommunicationCenterPageState extends State<CommunicationCenterPage> {
  final recipientController = TextEditingController();
  final subjectController = TextEditingController();
  final bodyController = TextEditingController();

  SettingsBundle? settings;
  List<CommunicationEntry> history = const [];
  String role = 'viewer';
  String messageType = 'confirmation';
  String? selectedPaymentId;
  bool loading = true;
  bool sending = false;

  bool get canSend =>
      role == 'admin' ||
      role == 'manager' ||
      role == 'booking_officer' ||
      role == 'finance';

  WesleyCommunicationService get communicationService =>
      WesleyCommunicationService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    recipientController.text = widget.booking.email;
    selectedPaymentId =
        widget.booking.payments.isEmpty ? null : widget.booking.payments.first.id;
    _load();
  }

  @override
  void dispose() {
    recipientController.dispose();
    subjectController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await widget.repository.loadSettings();
      var loadedRole = 'viewer';
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('wesley_staff_users')
            .select('role')
            .eq('user_id', user.id)
            .single();
        loadedRole = profile['role']?.toString() ?? 'viewer';
      }
      final rows = await communicationService.listForBooking(widget.booking.id);
      if (!mounted) return;
      setState(() {
        settings = s;
        role = loadedRole;
        history = rows;
        loading = false;
      });
      _applyTemplate();
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load Communication Centre: $e')),
      );
    }
  }

  void _applyTemplate() {
    final s = settings;
    if (s == null) return;
    final b = widget.booking;
    final org = s.organization;
    final name = b.clientName.trim().isEmpty ? b.churchGroup : b.clientName;
    final greetingName = name.trim().isEmpty ? 'Client' : name.trim();
    final hall = b.hallSpaceName;
    final eventDate = _date(b.eventDate);
    final eventTime = '${_time(b.eventStart)} - ${_time(b.eventEnd)}';
    final accessTime = _time(b.accessStart);
    final vacateTime = _time(b.vacateEnd);
    final closing =
        '\n\nRegards,\nWesley Hall Booking Office\nGHANA METHODIST CHURCH OF TORONTO\n${org.phone}\n${org.email}';

    switch (messageType) {
      case 'confirmation':
        subjectController.text =
            'Wesley Hall Booking Confirmation - ${b.referenceNumber}';
        if (b.isChurchUse) {
          bodyController.text =
              'Dear $greetingName,\n\nYour Wesley Hall church-use reservation has been recorded.\n\nBooking reference: ${b.referenceNumber}\nActivity: ${b.eventDetails}\nDate: $eventDate\nTime: $eventTime\nHall: $hall\nAccess from: $accessTime\nVacate by: $vacateTime\n\nPlease quote the booking reference if any changes are required.$closing';
        } else {
          bodyController.text =
              'Dear $greetingName,\n\nThank you for choosing Wesley Hall. Your reservation details are shown below.\n\nBooking reference: ${b.referenceNumber}\nEvent: ${b.eventDetails}\nDate: $eventDate\nRental time: $eventTime\nHall: $hall\nTotal rental charges: ${_money(b.totalCharge)}\nBooking deposit required: ${_money(b.requiredBookingDeposit)}\nCurrent rental balance: ${_money(b.remainingRentalBalance)}\nRefundable damage deposit: ${_money(b.damageDepositRequired)}\n\nPlease keep your booking reference for future correspondence.$closing';
        }
        break;
      case 'contract':
        subjectController.text =
            'Wesley Hall Rental Contract - ${b.referenceNumber}';
        bodyController.text =
            'Dear $greetingName,\n\nAttached is the Wesley Hall rental contract for booking ${b.referenceNumber}.\n\nEvent: ${b.eventDetails}\nDate: $eventDate\nTime: $eventTime\nHall: $hall\n\nPlease review the contract and keep a copy for your records.$closing';
        break;
      case 'balance_reminder':
        subjectController.text =
            'Wesley Hall Balance Reminder - ${b.referenceNumber}';
        bodyController.text =
            'Dear $greetingName,\n\nThis is a reminder regarding the outstanding balance for your Wesley Hall booking.\n\nBooking reference: ${b.referenceNumber}\nEvent: ${b.eventDetails}\nEvent date: $eventDate\nOutstanding rental balance: ${_money(b.remainingRentalBalance)}\n\nPlease include your booking reference when making or discussing payment.$closing';
        break;
      case 'event_reminder':
        subjectController.text =
            'Wesley Hall Event Reminder - ${b.referenceNumber}';
        bodyController.text =
            'Dear $greetingName,\n\nThis is a reminder of your upcoming Wesley Hall reservation.\n\nBooking reference: ${b.referenceNumber}\nEvent: ${b.eventDetails}\nDate: $eventDate\nEvent time: $eventTime\nHall access from: $accessTime\nVacate by: $vacateTime\nHall: $hall\n\nPlease contact the booking office if there has been any change to your arrangements.$closing';
        break;
      case 'receipt':
        final payment = _selectedPayment;
        subjectController.text =
            'Wesley Hall Payment Receipt - ${b.referenceNumber}';
        bodyController.text = payment == null
            ? 'Dear $greetingName,\n\nPlease find your Wesley Hall payment receipt attached.$closing'
            : 'Dear $greetingName,\n\nThank you. Attached is your Wesley Hall payment receipt.\n\nBooking reference: ${b.referenceNumber}\nPayment: ${_title(payment.paymentType)}\nAmount: ${_money(payment.amount)}\nPayment date: ${_date(payment.paymentDate)}\n\nPlease keep this receipt for your records.$closing';
        break;
      case 'custom':
        subjectController.text = 'Wesley Hall - ${b.referenceNumber}';
        bodyController.text = 'Dear $greetingName,\n\n$closing';
        break;
    }
    if (mounted) setState(() {});
  }

  PaymentRecord? get _selectedPayment {
    final id = selectedPaymentId;
    if (id == null) return null;
    for (final payment in widget.booking.payments) {
      if (payment.id == id) return payment;
    }
    return null;
  }

  Future<void> _send() async {
    if (!canSend || sending) return;
    final recipient = recipientController.text.trim();
    final subject = subjectController.text.trim();
    final body = bodyController.text.trim();
    if (recipient.isEmpty || subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipient, subject and message are required.')),
      );
      return;
    }

    if (messageType == 'balance_reminder' && widget.booking.isChurchUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Church-use reservations do not have a rental balance.')),
      );
      return;
    }
    if (messageType == 'receipt' && _selectedPayment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a payment receipt first.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send Email?'),
        content: Text(
          'Send "$subject" to $recipient? The message will be recorded in this booking history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => sending = true);
    try {
      Uint8List? attachment;
      String? attachmentName;
      if (messageType == 'contract') {
        final s = settings!;
        final managerSignature = await widget.repository.loadManagerSignature(
          s.organization.managerSignaturePath,
        );
        final logo = await widget.repository.loadOrganizationLogo(
          s.organization.organizationLogoPath,
        );
        final clientSignature = await widget.repository.loadClientSignature(
          widget.booking.clientSignaturePath,
        );
        attachment = await ContractService().buildContract(
          booking: widget.booking,
          settings: s,
          managerSignature: managerSignature,
          organizationLogo: logo,
          clientSignature: clientSignature,
        );
        attachmentName = '${_safeFile(widget.booking.referenceNumber)} - Contract.pdf';
      } else if (messageType == 'receipt') {
        final payment = _selectedPayment!;
        final s = settings!;
        final logo = await widget.repository.loadOrganizationLogo(
          s.organization.organizationLogoPath,
        );
        attachment = await PaymentReceiptService().build(
          booking: widget.booking,
          payment: payment,
          settings: s,
          organizationLogo: logo,
        );
        attachmentName =
            '${_safeFile(widget.booking.referenceNumber)} - ${_safeFile(_title(payment.paymentType))} Receipt.pdf';
      }

      await communicationService.sendEmail(
        bookingId: widget.booking.id,
        communicationType: messageType,
        recipientEmail: recipient,
        subject: subject,
        body: body,
        attachmentBytes: attachment,
        attachmentName: attachmentName,
      );

      final rows = await communicationService.listForBooking(widget.booking.id);
      if (!mounted) return;
      setState(() => history = rows);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email sent to $recipient.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to send email: ${_cleanError(e)}')),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return Scaffold(
      appBar: AppBar(
        title: Text('Communication Centre - ${b.referenceNumber}'),
      ),
      body: loading
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
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.mark_email_read_outlined, size: 30),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.clientName.isEmpty ? b.churchGroup : b.clientName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 3),
                                    Text('${b.eventDetails} • ${_date(b.eventDate)} • ${b.hallSpaceName}'),
                                    Text('Booking reference: ${b.referenceNumber}'),
                                  ],
                                ),
                              ),
                              Chip(
                                avatar: Icon(
                                  canSend ? Icons.lock_open_outlined : Icons.visibility_outlined,
                                  size: 17,
                                ),
                                label: Text(canSend ? 'CAN SEND' : 'VIEW ONLY'),
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
                                'Prepare Message',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Choose a prepared message, review it, make any changes, then send. Contract and receipt messages automatically attach the matching PDF.',
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _typeChip('confirmation', 'Confirmation', Icons.check_circle_outline),
                                  if (!b.isChurchUse)
                                    _typeChip('contract', 'Contract', Icons.description_outlined),
                                  if (!b.isChurchUse)
                                    _typeChip('balance_reminder', 'Balance Reminder', Icons.payments_outlined),
                                  _typeChip('event_reminder', 'Event Reminder', Icons.event_available_outlined),
                                  if (b.payments.isNotEmpty)
                                    _typeChip('receipt', 'Payment Receipt', Icons.receipt_long_outlined),
                                  _typeChip('custom', 'Custom', Icons.edit_note_outlined),
                                ],
                              ),
                              if (messageType == 'receipt' && b.payments.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  key: ValueKey('payment-$selectedPaymentId'),
                                  initialValue: selectedPaymentId,
                                  decoration: const InputDecoration(labelText: 'Receipt to Attach'),
                                  items: b.payments
                                      .map(
                                        (p) => DropdownMenuItem(
                                          value: p.id,
                                          child: Text(
                                            '${_date(p.paymentDate)} • ${_title(p.paymentType)} • ${_money(p.amount)}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    selectedPaymentId = value;
                                    _applyTemplate();
                                  },
                                ),
                              ],
                              if (messageType == 'contract' || messageType == 'receipt') ...[
                                const SizedBox(height: 12),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Chip(
                                    avatar: Icon(Icons.attach_file, size: 17),
                                    label: Text('PDF ATTACHMENT WILL BE INCLUDED'),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              TextField(
                                controller: recipientController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'To',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: subjectController,
                                decoration: const InputDecoration(labelText: 'Subject'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: bodyController,
                                minLines: 12,
                                maxLines: 22,
                                decoration: const InputDecoration(
                                  labelText: 'Message',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _applyTemplate,
                                    icon: const Icon(Icons.restart_alt),
                                    label: const Text('Reset Template'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: canSend && !sending ? _send : null,
                                    icon: sending
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.send_outlined),
                                    label: Text(sending ? 'Sending...' : 'Send Email'),
                                  ),
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
                              Row(
                                children: [
                                  Text(
                                    'Communication History',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Refresh history',
                                    onPressed: _load,
                                    icon: const Icon(Icons.refresh),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (history.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(child: Text('No email history for this booking yet.')),
                                )
                              else
                                ...history.map(_historyTile),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _typeChip(String value, String label, IconData icon) {
    final selected = messageType == value;
    return ChoiceChip(
      selected: selected,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) {
        setState(() => messageType = value);
        _applyTemplate();
      },
    );
  }

  Widget _historyTile(CommunicationEntry entry) {
    final sent = entry.status == 'sent';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        child: Icon(sent ? Icons.mark_email_read_outlined : Icons.error_outline),
      ),
      title: Text(entry.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_title(entry.type)} • ${entry.recipientEmail} • ${_dateTime(entry.createdAt.toLocal())}'
        '${entry.attachmentName == null ? '' : '\nAttachment: ${entry.attachmentName}'}',
      ),
      trailing: Chip(label: Text(sent ? 'SENT' : 'FAILED')),
    );
  }

  String _cleanError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  String _safeFile(String value) => value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  String _title(String value) => value
      .split('_')
      .map((part) => part.isEmpty
          ? part
          : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  String _date(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  String _time(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$hour:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _dateTime(DateTime d) => '${_date(d)} ${_time(d)}';
}
