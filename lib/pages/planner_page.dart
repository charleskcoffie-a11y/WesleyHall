import 'package:flutter/material.dart';

import '../models/wesley_models.dart';
import '../services/wesley_repository.dart';
import '../widgets/page_header.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key, required this.repository, required this.onNewBooking});
  final WesleyRepository repository;
  final VoidCallback onNewBooking;

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: FutureBuilder<List<Booking>>(
        future: widget.repository.listBookings(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final bookings = snapshot.data!.where((b) => b.status != 'cancelled').toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PageHeader(
              title: 'Hall Planner',
              subtitle: 'Availability includes setup time, event time, and cleanup/vacate time.',
              trailing: FilledButton.icon(onPressed: widget.onNewBooking, icon: const Icon(Icons.add), label: const Text('New Booking')),
            ),
            const SizedBox(height: 18),
            Row(children: [
              IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
              Text(_monthName(month), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
              const Spacer(),
              const Text('Hall is blocked from setup/access through final vacate time.'),
            ]),
            const SizedBox(height: 10),
            Expanded(child: Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: _calendar(context, bookings),
            ))),
          ]);
        },
      ),
    );
  }

  Widget _calendar(BuildContext context, List<Booking> bookings) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final blanks = first.weekday % 7;
    const headers = ['SUN','MON','TUE','WED','THU','FRI','SAT'];
    final cells = <Widget>[
      ...headers.map((h) => Center(child: Text(h, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)))),
      ...List.generate(blanks, (_) => const SizedBox()),
      ...List.generate(days, (i) {
        final day = DateTime(month.year, month.month, i + 1);
        final events = bookings.where((b) => _sameDay(b.eventDate, day)).toList();
        return Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ...events.take(3).map((b) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(6)),
              child: Text('${_time(b.accessStart)} ${b.eventDetails}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            )),
          ]),
        );
      }),
    ];
    final rows = ((blanks + days + 6) / 7).floor() + 1;
    return GridView.count(crossAxisCount: 7, childAspectRatio: 1.08, children: cells.take(rows * 7).toList());
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')}${d.hour >= 12 ? 'p' : 'a'}';
  }
  String _monthName(DateTime d) {
    const names = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return '${names[d.month - 1]} ${d.year}';
  }
}
