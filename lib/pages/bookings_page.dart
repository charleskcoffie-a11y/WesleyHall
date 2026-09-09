import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/wesley_models.dart';
import 'booking_detail_page.dart';
import '../services/contract_service.dart';
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

  @override
  void initState() {
    super.initState();
    _future = widget.repository.listBookings();
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
      final bytes = await ContractService().buildContract(
        booking: booking,
        settings: settings,
        managerSignature: signature,
        organizationLogo: logo,
      );
      await Printing.layoutPdf(
        name: '${booking.referenceNumber} - Wesley Hall Agreement',
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
                'Search bookings, review hall access times, and print agreements for signature.',
          ),
          const SizedBox(height: 18),
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
                    DropdownMenuItem(
                        value: 'awaiting_deposit',
                        child: Text('Awaiting Deposit')),
                    DropdownMenuItem(
                        value: 'confirmed', child: Text('Confirmed')),
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
                        b.referenceNumber.toLowerCase().contains(_search);
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
                          columnSpacing: 22,
                          dataRowMinHeight: 66,
                          dataRowMaxHeight: 78,
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
                                  width: 220,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.clientName,
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
                                      const SizedBox(height: 4),
                                      Text('Vacate  ${_time(b.vacateEnd)}'),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                Chip(
                                  label: Text(
                                    b.status
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
                                          size: 17),
                                      label: const Text('Open'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.tonalIcon(
                                      onPressed: () => _printContract(b),
                                      icon: const Icon(Icons.print_outlined,
                                          size: 17),
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

  String _date(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}
