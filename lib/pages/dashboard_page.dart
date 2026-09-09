import 'package:flutter/material.dart';

import '../models/wesley_models.dart';
import '../services/wesley_repository.dart';
import '../widgets/page_header.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.repository,
    required this.onNewBooking,
    required this.onPlanner,
    required this.onBookings,
  });

  final WesleyRepository repository;
  final VoidCallback onNewBooking;
  final VoidCallback onPlanner;
  final VoidCallback onBookings;

  Future<List<Booking>> get data => repository.listBookings();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: FutureBuilder<List<Booking>>(
        future: data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final weekEnd = today.add(const Duration(days: 7));
          final active = rows.where((b) => b.status != 'cancelled').toList();
          final todayCount = active.where((b) => _sameDay(b.eventDate, today)).length;
          final weekCount = active.where((b) => !b.eventDate.isBefore(today) && b.eventDate.isBefore(weekEnd)).length;
          final outstanding = active.fold<double>(0, (t, b) => t + b.remainingRentalBalance);
          final depositsDue = active.fold<double>(0, (t, b) => t + (b.requiredBookingDeposit - b.bookingDepositPaid).clamp(0.0, double.infinity).toDouble());
          final upcoming = active.where((b) => !b.eventDate.isBefore(today)).take(8).toList();

          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHeader(title: 'Dashboard', subtitle: "Today's activity, upcoming bookings, and payments that need attention."),
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _metric(context, "Today's Events", '$todayCount', Icons.today_outlined),
              _metric(context, 'Events This Week', '$weekCount', Icons.date_range_outlined),
              _metric(context, 'Outstanding Balances', _money(outstanding), Icons.receipt_long_outlined),
              _metric(context, 'Deposits Due', _money(depositsDue), Icons.account_balance_wallet_outlined),
            ]),
            const SizedBox(height: 18),
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 3, child: Card(child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Upcoming Events', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Expanded(child: upcoming.isEmpty
                      ? const Center(child: Text('No upcoming events.'))
                      : ListView.separated(
                          itemCount: upcoming.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (_, i) {
                            final b = upcoming[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(child: Icon(Icons.event_outlined)),
                              title: Text('${b.eventDetails} • ${b.clientName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${_date(b.eventDate)} • ${_time(b.accessStart)} access • ${_time(b.vacateEnd)} vacate'),
                              trailing: Chip(label: Text(b.status.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 9))),
                            );
                          },
                        )),
                ]),
              ))),
              const SizedBox(width: 16),
              SizedBox(width: 290, child: Card(child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  FilledButton.icon(onPressed: onNewBooking, icon: const Icon(Icons.add), label: const Text('New Booking')),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: onPlanner, icon: const Icon(Icons.calendar_month), label: const Text('Hall Planner')),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: onBookings, icon: const Icon(Icons.event_note), label: const Text('All Bookings')),
                  const Spacer(),
                  Text('Booking deposits and damage deposits are tracked separately.', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ))),
            ])),
          ]);
        },
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value, IconData icon) => SizedBox(
    width: 225,
    child: Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        CircleAvatar(child: Icon(icon)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ])),
      ]),
    )),
  );

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  static String _money(double v) => '\$${v.toStringAsFixed(2)}';
  static String _date(DateTime d) => '${d.month}/${d.day}/${d.year}';
  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}
