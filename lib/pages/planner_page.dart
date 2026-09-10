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
  static const _deepGreen = Color(0xFF0C4A39);
  static const _ink = Color(0xFF17211E);
  static const _muted = Color(0xFF66766F);
  static const _line = Color(0xFFE3EAE6);

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

          final allBookings = snapshot.data!;
          var bookings = allBookings;
          if (statusFilter != 'all') {
            bookings = bookings.where((b) => b.status == statusFilter).toList();
          }

          final monthBookings = allBookings
              .where((b) =>
                  b.eventDate.year == month.year &&
                  b.eventDate.month == month.month)
              .toList();
          final rentalCount =
              monthBookings.where((b) => !b.isChurchUse).length;
          final churchCount = monthBookings.where((b) => b.isChurchUse).length;
          final occupiedDays = monthBookings
              .where((b) => b.status != 'cancelled')
              .map((b) =>
                  '${b.eventDate.year}-${b.eventDate.month}-${b.eventDate.day}')
              .toSet()
              .length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Hall Planner',
                subtitle:
                    'A clear view of rentals, church activities, setup time, and hall availability.',
                trailing: FilledButton.icon(
                  onPressed: widget.onNewBooking,
                  icon: const Icon(Icons.add),
                  label: const Text('New Reservation'),
                ),
              ),
              const SizedBox(height: 18),
              _toolbar(),
              const SizedBox(height: 14),
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _calendarSummary(
                        total: monthBookings.length,
                        rentalCount: rentalCount,
                        churchCount: churchCount,
                        occupiedDays: occupiedDays,
                      ),
                      const Divider(height: 1),
                      Expanded(child: _calendar(context, bookings)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toolbar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1050;
            final monthControls = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _navButton(
                  Icons.chevron_left,
                  () => setState(
                    () => month = DateTime(month.year, month.month - 1),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 205),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF8FBF9), Color(0xFFF1F7F4)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          color: _green, size: 20),
                      const SizedBox(width: 9),
                      Text(
                        _monthName(month),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _navButton(
                  Icons.chevron_right,
                  () => setState(
                    () => month = DateTime(month.year, month.month + 1),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    final now = DateTime.now();
                    month = DateTime(now.year, now.month);
                  }),
                  icon: const Icon(Icons.today_outlined, size: 18),
                  label: const Text('Today'),
                ),
              ],
            );

            final filters = Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _filterChip('all', 'All'),
                _filterChip('confirmed', 'Confirmed'),
                _filterChip('awaiting_deposit', 'Awaiting Deposit'),
                _filterChip('reserved', 'Church Use'),
                _filterChip('completed', 'Completed'),
                _filterChip('cancelled', 'Cancelled'),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: monthControls,
                  ),
                  const SizedBox(height: 12),
                  filters,
                ],
              );
            }

            return Row(
              children: [
                monthControls,
                const Spacer(),
                Flexible(child: filters),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _calendarSummary({
    required int total,
    required int rentalCount,
    required int churchCount,
    required int occupiedDays,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 13),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFAFCFA), Color(0xFFF4F9F6)],
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _monthName(month),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$total reservation${total == 1 ? '' : 's'} this month',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
          const SizedBox(width: 24),
          _summaryPill(Icons.event_available_outlined, '$rentalCount', 'Rentals'),
          const SizedBox(width: 8),
          _summaryPill(Icons.church_outlined, '$churchCount', 'Church Use'),
          const SizedBox(width: 8),
          _summaryPill(Icons.calendar_view_month_outlined, '$occupiedDays', 'Days Used'),
          const Spacer(),
          _legend(),
        ],
      ),
    );
  }

  Widget _summaryPill(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _green),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: _ink, fontSize: 13)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: _muted, fontSize: 11)),
        ],
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
      backgroundColor: Colors.white,
      checkmarkColor: _green,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      labelStyle: TextStyle(
        color: selected ? _deepGreen : const Color(0xFF53645D),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF8ED3B3) : _line,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _legend() {
    return const Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _LegendItem(Color(0xFF41B97A), 'Confirmed'),
        _LegendItem(Color(0xFFF2B43C), 'Awaiting Deposit'),
        _LegendItem(Color(0xFF6F8FD6), 'Church Use'),
        _LegendItem(Color(0xFFAEC2CC), 'Completed'),
        _LegendItem(Color(0xFFE45C69), 'Cancelled'),
      ],
    );
  }

  Widget _navButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: const BorderSide(color: _line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: _deepGreen),
        ),
      ),
    );
  }

  Widget _calendar(BuildContext context, List<Booking> bookings) {
    final first = DateTime(month.year, month.month, 1);
    final firstVisible = first.subtract(Duration(days: first.weekday % 7));
    final days = List.generate(
      42,
      (i) => firstVisible.add(Duration(days: i)),
    );
    const headers = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Column(
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: List.generate(headers.length, (index) {
                final weekend = index == 0 || index == 6;
                return Expanded(
                  child: Center(
                    child: Text(
                      headers[index],
                      style: TextStyle(
                        color: weekend
                            ? const Color(0xFF8A6D3B)
                            : const Color(0xFF64756E),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 7.0;
                final cellWidth =
                    (constraints.maxWidth - spacing * 6) / 7;
                final cellHeight =
                    (constraints.maxHeight - spacing * 5) / 6;
                final ratio = cellWidth / cellHeight;

                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: ratio,
                  ),
                  itemCount: 42,
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final inMonth = day.month == month.month;
                    final isToday = _sameDay(day, DateTime.now());
                    final weekend = day.weekday == DateTime.saturday ||
                        day.weekday == DateTime.sunday;
                    final events = bookings
                        .where((b) => _sameDay(b.eventDate, day))
                        .toList()
                      ..sort((a, b) => a.eventStart.compareTo(b.eventStart));

                    return _dayCell(
                      day: day,
                      inMonth: inMonth,
                      isToday: isToday,
                      weekend: weekend,
                      events: events,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCell({
    required DateTime day,
    required bool inMonth,
    required bool isToday,
    required bool weekend,
    required List<Booking> events,
  }) {
    final Color background;
    if (!inMonth) {
      background = const Color(0xFFF7F8F7);
    } else if (weekend) {
      background = const Color(0xFFFFFCF6);
    } else {
      background = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday ? const Color(0xFF5FC493) : _line,
          width: isToday ? 1.7 : 1,
        ),
        boxShadow: isToday
            ? const [
                BoxShadow(
                  color: Color(0x1A116149),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 27,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? _green : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: isToday
                        ? Colors.white
                        : inMonth
                            ? _ink
                            : const Color(0xFFAAB6B0),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (events.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F5F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${events.length}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          ...events.take(2).map(_eventTile),
          if (events.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F3),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '+${events.length - 2} more',
                  style: const TextStyle(
                    fontSize: 9,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _eventTile(Booking b) {
    final colors = _statusColors(b.status);
    final subtitle = b.isChurchUse
        ? (b.churchGroup.trim().isNotEmpty ? b.churchGroup : 'Church Use')
        : b.clientName;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colors.$3.withValues(alpha: .28)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: colors.$3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_eventIcon(b), size: 11, color: colors.$2),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _time(b.eventStart),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8.5,
                              color: colors.$2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.$3,
                            shape: BoxShape.circle,
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
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: colors.$2,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: colors.$2.withValues(alpha: .82),
                        fontWeight: FontWeight.w500,
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

  (Color, Color, Color) _statusColors(String status) {
    switch (status) {
      case 'confirmed':
        return (
          const Color(0xFFE2F6EC),
          const Color(0xFF155D42),
          const Color(0xFF41B97A),
        );
      case 'reserved':
        return (
          const Color(0xFFEAF0FF),
          const Color(0xFF36548C),
          const Color(0xFF6F8FD6),
        );
      case 'completed':
        return (
          const Color(0xFFEEF3F5),
          const Color(0xFF50656F),
          const Color(0xFFAEC2CC),
        );
      case 'cancelled':
        return (
          const Color(0xFFFFE8EA),
          const Color(0xFFA1323D),
          const Color(0xFFE45C69),
        );
      default:
        return (
          const Color(0xFFFFF2CF),
          const Color(0xFF6F4B0B),
          const Color(0xFFF2B43C),
        );
    }
  }

  IconData _eventIcon(Booking booking) {
    if (booking.isChurchUse) return Icons.church_outlined;
    final text = booking.eventDetails.toLowerCase();
    if (text.contains('wedding')) return Icons.favorite_outline;
    if (text.contains('cook') || text.contains('food')) {
      return Icons.restaurant_outlined;
    }
    if (text.contains('meeting')) return Icons.groups_outlined;
    if (text.contains('funeral') || text.contains('memorial')) {
      return Icons.local_florist_outlined;
    }
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: Color(0xFF60716A),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
