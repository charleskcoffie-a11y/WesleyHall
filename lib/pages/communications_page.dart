import 'package:flutter/material.dart';

import '../models/wesley_models.dart';
import '../services/wesley_repository.dart';
import '../widgets/page_header.dart';
import 'communication_center_page.dart';

class CommunicationsPage extends StatefulWidget {
  const CommunicationsPage({super.key, required this.repository});

  final WesleyRepository repository;

  @override
  State<CommunicationsPage> createState() => _CommunicationsPageState();
}

class _CommunicationsPageState extends State<CommunicationsPage> {
  late Future<List<Booking>> future;
  String search = '';
  String filter = 'active';

  @override
  void initState() {
    super.initState();
    future = widget.repository.listBookings();
  }

  void refresh() => setState(() => future = widget.repository.listBookings());

  Future<void> openBooking(Booking booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunicationCenterPage(
          repository: widget.repository,
          booking: booking,
        ),
      ),
    );
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Communication Centre',
            subtitle:
                'Send booking confirmations, contracts, payment receipts, balance reminders, and event reminders.',
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 360,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search client, email, event, or reference...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) =>
                          setState(() => search = value.trim().toLowerCase()),
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      initialValue: filter,
                      decoration: const InputDecoration(labelText: 'Show'),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Active Bookings')),
                        DropdownMenuItem(value: 'upcoming', child: Text('Upcoming Events')),
                        DropdownMenuItem(value: 'balance', child: Text('Balance Outstanding')),
                        DropdownMenuItem(value: 'all', child: Text('All Bookings')),
                      ],
                      onChanged: (value) =>
                          setState(() => filter = value ?? 'active'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<List<Booking>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Unable to load bookings: ${snapshot.error}'),
                    );
                  }

                  final now = DateTime.now();
                  final rows = (snapshot.data ?? const <Booking>[])
                      .where((booking) {
                        if (filter == 'active' &&
                            (booking.status == 'cancelled' ||
                                booking.status == 'completed')) {
                          return false;
                        }
                        if (filter == 'upcoming' &&
                            booking.eventDate.isBefore(
                              DateTime(now.year, now.month, now.day),
                            )) {
                          return false;
                        }
                        if (filter == 'balance' &&
                            (booking.isChurchUse ||
                                booking.remainingRentalBalance <= 0)) {
                          return false;
                        }
                        if (search.isEmpty) return true;
                        return booking.clientName.toLowerCase().contains(search) ||
                            booking.email.toLowerCase().contains(search) ||
                            booking.eventDetails.toLowerCase().contains(search) ||
                            booking.referenceNumber.toLowerCase().contains(search) ||
                            booking.churchGroup.toLowerCase().contains(search);
                      })
                      .toList()
                    ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

                  if (rows.isEmpty) {
                    return const Center(
                      child: Text('No bookings match this communication view.'),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: rows.map(_bookingCard).toList(),
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

  Widget _bookingCard(Booking booking) {
    final name = booking.clientName.trim().isEmpty
        ? booking.churchGroup
        : booking.clientName;
    final hasEmail = booking.email.trim().isNotEmpty;

    return SizedBox(
      width: 340,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.referenceNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Chip(
                    label: Text(
                      booking.status.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Text(
                name.isEmpty ? 'No client/group name' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                booking.eventDetails,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text('${_date(booking.eventDate)} • ${booking.hallSpaceName}'),
              Text(
                hasEmail ? booking.email : 'EMAIL ADDRESS NEEDED',
                style: TextStyle(
                  fontWeight: hasEmail ? FontWeight.w500 : FontWeight.w800,
                  color: hasEmail ? null : Theme.of(context).colorScheme.error,
                ),
              ),
              if (!booking.isChurchUse && booking.remainingRentalBalance > 0) ...[
                const SizedBox(height: 5),
                Text(
                  'Balance: ${_money(booking.remainingRentalBalance)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => openBooking(booking),
                icon: const Icon(Icons.mark_email_read_outlined),
                label: Text(hasEmail ? 'Open Communication' : 'Add / Enter Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  String _date(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
}
