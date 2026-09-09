import 'package:flutter/material.dart';

import '../models/wesley_models.dart';
import '../services/wesley_repository.dart';
import '../widgets/page_header.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({
    super.key,
    required this.repository,
    required this.onNewBooking,
  });

  final WesleyRepository repository;
  final VoidCallback onNewBooking;

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String statusFilter = 'all';

  static const _green = Color(0xFF116149);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 26),
      child: FutureBuilder<List<Booking>>(
        future: widget.repository.listBookings(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var bookings = snapshot.data!;
          if (statusFilter != 'all') {
            bookings = bookings.where((b) => b.status == statusFilter).toList();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Hall Planner',
                subtitle:
                    'Availability includes setup time, event time, and cleanup/vacate time.',
                trailing: FilledButton.icon(
                  onPressed: widget.onNewBooking,
                  icon: const Icon(Icons.add),
                  label: const Text('New Booking'),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  _navButton(
                    Icons.chevron_left,
                    () => setState(
                      () => month = DateTime(month.year, month.month - 1),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFFE3E9E5)),
                    ),
                    child: Text(
                      _monthName(month),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _navButton(
                    Icons.chevron_right,
                    () => setState(
                      () => month = DateTime(month.year, month.month + 1),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      final now = DateTime.now();
                      month = DateTime(now.year, now.month);
                    }),
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('Today'),
                  ),
                  const SizedBox(width: 8),
                  _filterChip('all', 'All'),
                  _filterChip('confirmed', 'Confirmed'),
                  _filterChip('awaiting_deposit', 'Awaiting Deposit'),
                  _filterChip('completed', 'Completed'),
                  _filterChip('cancelled', 'Cancelled'),
                ],
              ),
              const SizedBox(height: 16),
              _legend(),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _calendar(context, bookings),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => statusFilter = value),
      selectedColor: const Color(0xFFDDF6E8),
      checkmarkColor: _green,
      labelStyle: TextStyle(
        color: selected ? _green : const Color(0xFF53645D),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF9ED9BE) : const Color(0xFFE2E8E4),
      ),
    );
  }

  Widget _legend() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE4EAE6)),
        ),
        child: const Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            _LegendItem(Color(0xFF56BF88), 'Confirmed'),
            _LegendItem(Color(0xFFF3B84A), 'Awaiting Deposit'),
            _LegendItem(Color(0xFFB7CDD8), 'Completed'),
            _LegendItem(Color(0xFFE96773), 'Cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: Color(0xFFE3E9E5)),
      ),
      child: IconButton(onPressed: onPressed, icon: Icon(icon)),
    );
  }

  Widget _calendar(BuildContext context, List<Booking> bookings) {
    final first = DateTime(month.year, month.month, 1);
    final firstVisible = first.subtract(Duration(days: first.weekday % 7));
    final days = List.generate(
      42,
      (i) => firstVisible.add(Duration(days: i)),
    );
    const headers = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: headers
                .map(
                  (h) => Expanded(
                    child: Center(
                      child: Text(
                        h,
                        style: const TextStyle(
                          color: Color(0xFF66766F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              childAspectRatio: 1.12,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final day = days[index];
              final inMonth = day.month == month.month;
              final events = bookings
                  .where((b) => _sameDay(b.eventDate, day))
                  .toList();
              final isToday = _sameDay(day, DateTime.now());

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: inMonth
                      ? Colors.white
                      : const Color(0xFFF4F6F4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isToday
                        ? const Color(0xFF86CDB0)
                        : const Color(0xFFE0E7E2),
                    width: isToday ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: inMonth
                                ? const Color(0xFF17211E)
                                : const Color(0xFFACB8B2),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isToday) ...[
                          const Spacer(),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: _green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...events.take(2).map((b) => _eventTile(b)),
                    if (events.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '+${events.length - 2} more',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF6F7E78),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _eventTile(Booking b) {
    final colors = _statusColors(b.status);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_eventIcon(b.eventDetails), size: 12, color: colors.$2),
              const SizedBox(width: 4),
              Text(
                _time(b.eventStart),
                style: TextStyle(
                  fontSize: 9,
                  color: colors.$2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            b.eventDetails,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: colors.$2,
            ),
          ),
          Text(
            b.clientName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: colors.$2),
          ),
        ],
      ),
    );
  }

  (Color, Color) _statusColors(String status) {
    switch (status) {
      case 'confirmed':
        return (const Color(0xFFD9F5E7), const Color(0xFF176445));
      case 'completed':
        return (const Color(0xFFE8EEF1), const Color(0xFF50656F));
      case 'cancelled':
        return (const Color(0xFFFFE5E8), const Color(0xFFAD3340));
      default:
        return (const Color(0xFFFFEFC6), const Color(0xFF76500C));
    }
  }

  IconData _eventIcon(String details) {
    final text = details.toLowerCase();
    if (text.contains('wedding')) return Icons.favorite_outline;
    if (text.contains('cook') || text.contains('food')) {
      return Icons.restaurant_outlined;
    }
    if (text.contains('meeting')) return Icons.groups_outlined;
    return Icons.event_outlined;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _monthName(DateTime d) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[d.month - 1]} ${d.year}';
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
