import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wesley_models.dart';
import 'booking_detail_page.dart';
import 'booking_documents_page.dart';
import 'edit_booking_page.dart';
import 'scan_application_page.dart';
import '../services/blank_application_service.dart';
import '../services/contract_service.dart';
import '../services/paper_application_service.dart';
import '../services/wesley_repository.dart';
import '../widgets/page_header.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key, required this.repository});

  final WesleyRepository repository;

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  late Future<List<Booking>> _future;
  String _search = '';
  String _status = 'all';
  String _role = 'viewer';

  bool get _canBook =>
      _role == 'admin' || _role == 'manager' || _role == 'booking_officer';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.listBookings();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final row = await Supabase.instance.client
          .from('wesley_staff_users')
          .select('role')
          .eq('user_id', user.id)
          .single();
      if (mounted) setState(() => _role = row['role']?.toString() ?? 'viewer');
    } catch (_) {}
  }

  Future<void> _scanApplication() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScanApplicationPage(repository: widget.repository),
      ),
    );
    if (changed == true && mounted) {
      setState(() => _future = widget.repository.listBookings());
    }
  }

  Future<void> _printBlankApplication() async {
    try {
      final settings = await widget.repository.loadSettings();
      final logo = await widget.repository.loadOrganizationLogo(
        settings.organization.organizationLogoPath,
      );
      final bytes = await BlankApplicationService().build(
        settings: settings,
        organizationLogo: logo,
      );
      await Printing.layoutPdf(
        name: 'Wesley Hall - Blank Rental Application',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print blank application: $e')),
      );
    }
  }

  Future<void> _uploadPaperApplication(Booking booking) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Unable to read the selected file.');

      var extension = (file.extension ?? 'pdf').toLowerCase();
      if (extension == 'jpeg') extension = 'jpg';

      await PaperApplicationService(Supabase.instance.client).uploadForBooking(
        bookingId: booking.id,
        bytes: bytes,
        extension: extension,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Filled application attached to ${booking.referenceNumber}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to upload application: $e')),
      );
    }
  }

  Future<void> _printContract(Booking booking) async {
    try {
      final settings = await widget.repository.loadSettings();
      final signature = await widget.repository.loadManagerSignature(
        settings.organization.managerSignaturePath,
      );
      final logo = await widget.repository.loadOrganizationLogo(
        settings.organization.organizationLogoPath,
      );
      final clientSignature = await widget.repository
          .loadClientSignature(booking.clientSignaturePath);
      final bytes = await ContractService().buildContract(
        booking: booking,
        settings: settings,
        managerSignature: signature,
        organizationLogo: logo,
        clientSignature: clientSignature,
      );
      await Printing.layoutPdf(
        name: _contractFileName(booking),
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print contract: $e')),
      );
    }
  }

  Future<void> _openBooking(Booking booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingDetailPage(
          repository: widget.repository,
          bookingId: booking.id,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _future = widget.repository.listBookings());
  }

  Future<void> _openDocuments(Booking booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingDocumentsPage(booking: booking),
      ),
    );
  }

  Future<void> _editBooking(Booking booking) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditBookingPage(
          repository: widget.repository,
          booking: booking,
        ),
      ),
    );
    if (changed == true && mounted) {
      setState(() => _future = widget.repository.listBookings());
    }
  }

  Future<void> _manageHold(Booking booking) async {
    if (!booking.isHold || !_canBook) return;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Manage Hold - ${booking.referenceNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(booking.clientName),
            const SizedBox(height: 6),
            Text('Event: ${_date(booking.eventDate)}'),
            if (booking.holdExpiresAt != null)
              Text('Current expiry: ${_dateTime(booking.holdExpiresAt!.toLocal())}'),
            const SizedBox(height: 12),
            const Text(
              'Convert the hold when the client proceeds, extend it when more time is approved, or release it if the client no longer needs the date.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'release'),
            icon: const Icon(Icons.event_busy_outlined),
            label: const Text('Release Hold'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'extend'),
            icon: const Icon(Icons.more_time_outlined),
            label: const Text('Extend'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'convert'),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Convert to Booking'),
          ),
        ],
      ),
    );
    if (action == null) return;

    try {
      final client = Supabase.instance.client;
      if (action == 'convert') {
        await client.from('wesley_bookings').update({
          'status': 'awaiting_deposit',
          'hold_expires_at': null,
        }).eq('id', booking.id);
      } else if (action == 'release') {
        await client.from('wesley_bookings').update({
          'status': 'cancelled',
          'hold_expires_at': null,
        }).eq('id', booking.id);
      } else if (action == 'extend') {
        final hours = await showDialog<int>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: const Text('Extend Hold By'),
            children: [24, 48, 72]
                .map((h) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(dialogContext, h),
                      child: Text('$h hours'),
                    ))
                .toList(),
          ),
        );
        if (hours == null) return;
        final base = booking.holdExpiresAt != null &&
                booking.holdExpiresAt!.isAfter(DateTime.now())
            ? booking.holdExpiresAt!
            : DateTime.now();
        await client.from('wesley_bookings').update({
          'hold_expires_at': base.add(Duration(hours: hours)).toIso8601String(),
        }).eq('id', booking.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'convert'
                ? 'Hold converted to Awaiting Deposit.'
                : action == 'release'
                    ? 'Hold released.'
                    : 'Hold expiry extended.',
          ),
        ),
      );
      setState(() => _future = widget.repository.listBookings());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update hold: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Bookings',
            subtitle:
                'Manage reservations, paper applications, documents, and printable contracts.',
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_canBook)
                    FilledButton.icon(
                      onPressed: _scanApplication,
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Scan / Upload Filled Application'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _printBlankApplication,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Print Blank Application'),
                  ),
                  const Text(
                    'Paper applications and other files can also be stored in each booking Document Centre.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search client, event, or reference...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'hold', child: Text('On Hold')),
                    DropdownMenuItem(
                        value: 'awaiting_deposit',
                        child: Text('Awaiting Deposit')),
                    DropdownMenuItem(
                        value: 'confirmed', child: Text('Confirmed')),
                    DropdownMenuItem(
                        value: 'reserved', child: Text('Church Use')),
                    DropdownMenuItem(
                        value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(
                        value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'all'),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () =>
                    setState(() => _future = widget.repository.listBookings()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<List<Booking>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Unable to load bookings: ${snapshot.error}'),
                    );
                  }

                  final rows = (snapshot.data ?? const <Booking>[]).where((b) {
                    final matchesStatus =
                        _status == 'all' || b.status == _status;
                    if (!matchesStatus) return false;
                    if (_search.isEmpty) return true;
                    return b.clientName.toLowerCase().contains(_search) ||
                        b.eventDetails.toLowerCase().contains(_search) ||
                        b.referenceNumber.toLowerCase().contains(_search) ||
                        b.churchGroup.toLowerCase().contains(_search) ||
                        b.phone.toLowerCase().contains(_search);
                  }).toList();

                  if (rows.isEmpty) {
                    return const Center(child: Text('No bookings found.'));
                  }

                  return Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(14),
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 18,
                          dataRowMinHeight: 68,
                          dataRowMaxHeight: 86,
                          columns: const [
                            DataColumn(label: Text('REF')),
                            DataColumn(label: Text('EVENT DATE')),
                            DataColumn(label: Text('CLIENT / EVENT')),
                            DataColumn(label: Text('HALL')),
                            DataColumn(label: Text('ACCESS / VACATE')),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('TOTAL')),
                            DataColumn(label: Text('ACTIONS')),
                          ],
                          rows: rows.map((b) {
                            final displayName =
                                b.isChurchUse && b.churchGroup.isNotEmpty
                                    ? b.churchGroup
                                    : b.clientName;
                            return DataRow(cells: [
                              DataCell(
                                Text(
                                  b.referenceNumber,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                onTap: () => _openBooking(b),
                              ),
                              DataCell(Text(_date(b.eventDate))),
                              DataCell(
                                SizedBox(
                                  width: 205,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        b.eventDetails,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(Text(b.hallSpaceName)),
                              DataCell(
                                SizedBox(
                                  width: 170,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Access  ${_time(b.accessStart)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      Text('Vacate  ${_time(b.vacateEnd)}'),
                                      if (b.isHold && b.holdExpiresAt != null)
                                        Text(
                                          'Expires ${_shortDateTime(b.holdExpiresAt!.toLocal())}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                Chip(
                                  label: Text(
                                    b.isExpiredHold
                                        ? 'HOLD EXPIRED'
                                        : b.status
                                            .replaceAll('_', ' ')
                                            .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(
                                  '\$${b.totalCharge.toStringAsFixed(2)}')),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _openBooking(b),
                                      icon: const Icon(Icons.open_in_new,
                                          size: 16),
                                      label: const Text('Open'),
                                    ),
                                    const SizedBox(width: 6),
                                    OutlinedButton.icon(
                                      onPressed: () => _openDocuments(b),
                                      icon: const Icon(Icons.folder_outlined,
                                          size: 16),
                                      label: const Text('Documents'),
                                    ),
                                    if (_canBook) ...[
                                      const SizedBox(width: 6),
                                      OutlinedButton.icon(
                                        onPressed: () => _editBooking(b),
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 16),
                                        label: const Text('Edit'),
                                      ),
                                      if (b.isHold) ...[
                                        const SizedBox(width: 6),
                                        FilledButton.tonalIcon(
                                          onPressed: () => _manageHold(b),
                                          icon: const Icon(
                                              Icons.hourglass_top_outlined,
                                              size: 16),
                                          label: const Text('Manage Hold'),
                                        ),
                                      ],
                                      const SizedBox(width: 6),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _uploadPaperApplication(b),
                                        icon: const Icon(
                                            Icons.upload_file_outlined,
                                            size: 16),
                                        label: const Text('Attach Application'),
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                    FilledButton.tonalIcon(
                                      onPressed: () => _printContract(b),
                                      icon: const Icon(Icons.print_outlined,
                                          size: 16),
                                      label: const Text('Print Contract'),
                                    ),
                                  ],
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _contractFileName(Booking booking) {
    final rawName = booking.clientName.trim().isEmpty
        ? (booking.churchGroup.trim().isEmpty ? 'Client' : booking.churchGroup)
        : booking.clientName;
    final safeName = rawName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${booking.referenceNumber} - $safeName';
  }

  String _date(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _dateTime(DateTime d) => '${_date(d)} ${_time(d)}';

  String _shortDateTime(DateTime d) =>
      '${d.month}/${d.day} ${_time(d)}';
}
