import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wesley_models.dart';
import '../services/blank_application_service.dart';
import '../services/contract_service.dart';
import '../services/paper_application_service.dart';
import '../services/wesley_repository.dart';
import '../widgets/page_header.dart';
import 'booking_detail_page.dart';
import 'booking_documents_page.dart';
import 'duplicate_booking_page.dart';
import 'edit_booking_page.dart';
import 'scan_application_page.dart';

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
      if (mounted) {
        setState(() => _role = row['role']?.toString() ?? 'viewer');
      }
    } catch (_) {}
  }

  void _refresh() {
    if (mounted) setState(() => _future = widget.repository.listBookings());
  }

  Future<void> _scanApplication() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScanApplicationPage(repository: widget.repository),
      ),
    );
    if (changed == true) _refresh();
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
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
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
    _refresh();
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
    if (changed == true) _refresh();
  }

  Future<void> _duplicateBooking(Booking booking) async {
    if (!_canBook) return;
    final copied = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DuplicateBookingPage(
          repository: widget.repository,
          source: booking,
        ),
      ),
    );
    if (copied == true && mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'New reservation created from ${booking.referenceNumber}. A new reference number was assigned.',
          ),
        ),
      );
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
              Text(
                'Current expiry: ${_dateTime(booking.holdExpiresAt!.toLocal())}',
              ),
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
      final table = Supabase.instance.client.from('wesley_bookings');
      if (action == 'convert') {
        await table.update({
          'status': 'awaiting_deposit',
          'hold_expires_at': null,
        }).eq('id', booking.id);
      } else if (action == 'release') {
        await table.update({
          'status': 'cancelled',
          'hold_expires_at': null,
        }).eq('id', booking.id);
      } else if (action == 'extend') {
        final hours = await showDialog<int>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: const Text('Extend Hold By'),
            children: [24, 48, 72]
                .map(
                  (hours) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(dialogContext, hours),
                    child: Text('$hours hours'),
                  ),
                )
                .toList(),
          ),
        );
        if (hours == null) return;
        final now = DateTime.now();
        final base = booking.holdExpiresAt != null &&
                booking.holdExpiresAt!.isAfter(now)
            ? booking.holdExpiresAt!
            : now;
        await table.update({
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
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update hold: $e')),
      );
    }
  }

  Future<void> _manageSeries(Booking booking) async {
    if (!booking.isRecurring || !_canBook) return;
    final currentIndex = booking.seriesIndex ?? 1;
    final total = booking.seriesCount ?? 0;
    final rule = booking.seriesRule == 'monthly' ? 'Monthly' : 'Weekly';

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Manage Recurring Series'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.eventDetails,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$rule series - Occurrence $currentIndex${total > 0 ? ' of $total' : ''}',
              ),
              const SizedBox(height: 12),
              const Text(
                'Edit changes only this occurrence. Updating future details copies the group, responsible person, contact details, activity name, attendance and notes. Dates, times and hall remain unchanged for safety.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'future_details'),
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Update Future Details'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'cancel_this'),
            icon: const Icon(Icons.event_busy_outlined),
            label: const Text('Cancel This Event'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'cancel_future'),
            icon: const Icon(Icons.next_plan_outlined),
            label: const Text('Cancel This & Future'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(dialogContext, 'cancel_series'),
            icon: const Icon(Icons.cancel_schedule_send_outlined),
            label: const Text('Cancel Entire Series'),
          ),
        ],
      ),
    );
    if (action == null) return;

    final key = booking.seriesKey!;
    try {
      final table = Supabase.instance.client.from('wesley_bookings');
      if (action == 'future_details') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Update Future Occurrences?'),
            content: Text(
              'Copy the current details to occurrences after #$currentIndex? Scheduling fields will not be changed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Update Future'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        await table
            .update({
              'client_name': booking.clientName,
              'phone': booking.phone,
              'email': booking.email,
              'event_details': booking.eventDetails,
              'guest_count': booking.guestCount,
              'church_group': booking.churchGroup,
              'notes': booking.notes,
            })
            .eq('series_key', key)
            .gt('series_index', currentIndex)
            .neq('status', 'completed');
      } else if (action == 'cancel_this') {
        await table.update({'status': 'cancelled'}).eq('id', booking.id);
      } else if (action == 'cancel_future') {
        await table
            .update({'status': 'cancelled'})
            .eq('series_key', key)
            .gte('series_index', currentIndex)
            .neq('status', 'completed');
      } else if (action == 'cancel_series') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Cancel Entire Series?'),
            content: const Text(
              'All occurrences in this series that are not already completed will be cancelled. Completed history will be kept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep Series'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Cancel Series'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        await table
            .update({'status': 'cancelled'})
            .eq('series_key', key)
            .neq('status', 'completed');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'future_details'
                ? 'Future series details updated.'
                : action == 'cancel_this'
                    ? 'This occurrence was cancelled.'
                    : action == 'cancel_future'
                        ? 'This and future occurrences were cancelled.'
                        : 'Recurring series cancelled.',
          ),
        ),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to manage recurring series: $e')),
      );
    }
  }

  Future<void> _handleMoreAction(String action, Booking booking) async {
    switch (action) {
      case 'edit':
        await _editBooking(booking);
        break;
      case 'hold':
        await _manageHold(booking);
        break;
      case 'series':
        await _manageSeries(booking);
        break;
      case 'attach':
        await _uploadPaperApplication(booking);
        break;
      case 'print':
        await _printContract(booking);
        break;
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
                'Manage reservations, copies, documents, holds, recurring activities, paper applications, and contracts.',
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
                    'Use Copy to create a fresh reservation from an existing booking without copying payments or documents.',
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
                    hintText: 'Search client, phone, event, or reference...',
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
                      child: Text('Awaiting Deposit'),
                    ),
                    DropdownMenuItem(
                      value: 'confirmed',
                      child: Text('Confirmed'),
                    ),
                    DropdownMenuItem(
                      value: 'reserved',
                      child: Text('Church Use'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Cancelled'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'all'),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
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
                          dataRowMaxHeight: 90,
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
                          rows: rows.map(_bookingRow).toList(),
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

  DataRow _bookingRow(Booking booking) {
    final displayName = booking.isChurchUse && booking.churchGroup.isNotEmpty
        ? booking.churchGroup
        : booking.clientName;

    return DataRow(
      cells: [
        DataCell(
          Text(
            booking.referenceNumber,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => _openBooking(booking),
        ),
        DataCell(Text(_date(booking.eventDate))),
        DataCell(
          SizedBox(
            width: 215,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  booking.eventDetails,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                if (booking.isRecurring)
                  Text(
                    '${booking.seriesRule == 'monthly' ? 'Monthly' : 'Weekly'} series - ${booking.seriesIndex ?? '?'} of ${booking.seriesCount ?? '?'}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5A6E66),
                    ),
                  ),
              ],
            ),
          ),
        ),
        DataCell(Text(booking.hallSpaceName)),
        DataCell(
          SizedBox(
            width: 170,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Access  ${_time(booking.accessStart)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('Vacate  ${_time(booking.vacateEnd)}'),
                if (booking.isHold && booking.holdExpiresAt != null)
                  Text(
                    'Expires ${_shortDateTime(booking.holdExpiresAt!.toLocal())}',
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
              booking.isExpiredHold
                  ? 'HOLD EXPIRED'
                  : booking.status.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        DataCell(Text('\$${booking.totalCharge.toStringAsFixed(2)}')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openBooking(booking),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open'),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () => _openDocuments(booking),
                icon: const Icon(Icons.folder_outlined, size: 16),
                label: const Text('Documents'),
              ),
              if (_canBook) ...[
                const SizedBox(width: 6),
                FilledButton.tonalIcon(
                  onPressed: () => _duplicateBooking(booking),
                  icon: const Icon(Icons.content_copy_outlined, size: 16),
                  label: const Text('Copy'),
                ),
              ],
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'More actions',
                onSelected: (action) => _handleMoreAction(action, booking),
                itemBuilder: (context) => [
                  if (_canBook)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit Reservation'),
                      ),
                    ),
                  if (_canBook && booking.isHold)
                    const PopupMenuItem(
                      value: 'hold',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.hourglass_top_outlined),
                        title: Text('Manage Hold'),
                      ),
                    ),
                  if (_canBook && booking.isRecurring)
                    const PopupMenuItem(
                      value: 'series',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.repeat_outlined),
                        title: Text('Manage Series'),
                      ),
                    ),
                  if (_canBook)
                    const PopupMenuItem(
                      value: 'attach',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.upload_file_outlined),
                        title: Text('Attach Application'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'print',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.print_outlined),
                      title: Text('Print Contract'),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ],
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
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$hour:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _dateTime(DateTime d) => '${_date(d)} ${_time(d)}';
  String _shortDateTime(DateTime d) => '${d.month}/${d.day} ${_time(d)}';
}
