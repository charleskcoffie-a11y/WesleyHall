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

  static const _green = Color(0xFF116149);
  static const _mint = Color(0xFFE7F7F0);
  static const _gold = Color(0xFFB57A13);
  static const _rose = Color(0xFFB63A3A);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 26),
      child: FutureBuilder<List<Booking>>(
        future: repository.listBookings(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rows = snapshot.data!;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final weekEnd = today.add(const Duration(days: 7));
          final active = rows.where((b) => b.status != 'cancelled').toList();
          final todayCount =
              active.where((b) => _sameDay(b.eventDate, today)).length;
          final weekCount = active
              .where((b) =>
                  !b.eventDate.isBefore(today) && b.eventDate.isBefore(weekEnd))
              .length;
          final outstanding = active.fold<double>(
              0, (t, b) => t + b.remainingRentalBalance);
          final depositsDue = active.fold<double>(
            0,
            (t, b) =>
                t +
                (b.requiredBookingDeposit - b.bookingDepositPaid)
                    .clamp(0.0, double.infinity)
                    .toDouble(),
          );
          final unsigned = active
              .where((b) =>
                  !b.eventDate.isBefore(today) && b.clientSignaturePath == null)
              .length;
          final upcoming = active
              .where((b) => !b.eventDate.isBefore(today))
              .take(5)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: PageHeader(
                      title: 'Dashboard',
                      subtitle:
                          "Today's activity, upcoming bookings, and payments that need attention.",
                    ),
                  ),
                  _greeting(context, now),
                ],
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1000;
                  final cardWidth = compact
                      ? (constraints.maxWidth - 12) / 2
                      : (constraints.maxWidth - 36) / 4;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _metricCard(
                        context,
                        width: cardWidth,
                        title: "Today's Events",
                        value: '$todayCount',
                        subtitle: 'Scheduled for today',
                        icon: Icons.calendar_today_outlined,
                        tint: _mint,
                        iconColor: _green,
                      ),
                      _metricCard(
                        context,
                        width: cardWidth,
                        title: 'Events This Week',
                        value: '$weekCount',
                        subtitle: 'Total bookings',
                        icon: Icons.date_range_outlined,
                        tint: const Color(0xFFF0F8F4),
                        iconColor: _green,
                      ),
                      _metricCard(
                        context,
                        width: cardWidth,
                        title: 'Outstanding Balances',
                        value: _money(outstanding),
                        subtitle: 'Across active bookings',
                        icon: Icons.receipt_long_outlined,
                        tint: const Color(0xFFFFF4DA),
                        iconColor: _gold,
                      ),
                      _metricCard(
                        context,
                        width: cardWidth,
                        title: 'Deposits Due',
                        value: _money(depositsDue),
                        subtitle: 'Awaiting payment',
                        icon: Icons.account_balance_wallet_outlined,
                        tint: const Color(0xFFFFEAEA),
                        iconColor: _rose,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 1000;
                    if (narrow) {
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            _upcomingCard(context, upcoming),
                            const SizedBox(height: 16),
                            _quickActions(context),
                            const SizedBox(height: 16),
                            _attentionCard(
                              context,
                              depositsDue,
                              outstanding,
                              unsigned,
                              active.length,
                            ),
                          ],
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _upcomingCard(context, upcoming),
                        ),
                        const SizedBox(width: 18),
                        SizedBox(
                          width: 330,
                          child: Column(
                            children: [
                              _quickActions(context),
                              const SizedBox(height: 16),
                              Expanded(
                                child: _attentionCard(
                                  context,
                                  depositsDue,
                                  outstanding,
                                  unsigned,
                                  active.length,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _greeting(BuildContext context, DateTime now) {
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning!'
        : hour < 17
            ? 'Good afternoon!'
            : 'Good evening!';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EAE6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wb_sunny_outlined, color: Color(0xFFD59A26)),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                _longDate(now),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color tint,
    required Color iconColor,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF17211E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF718079),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: Color(0xFF799087)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upcomingCard(BuildContext context, List<Booking> upcoming) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: _green),
                const SizedBox(width: 10),
                Text('Upcoming Events',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: onBookings,
                  label: const Text('View All'),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (upcoming.isEmpty)
              const Expanded(
                child: Center(child: Text('No upcoming events.')),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: upcoming.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _eventRow(context, upcoming[index]),
                ),
              ),
            if (upcoming.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8F7F0), Color(0xFFF7FAF7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFFB8F1D4),
                      child: Icon(Icons.eco_outlined, color: _green),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Building Stronger Communities',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Wesley Hall is a place where people gather, celebrate, and belong.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _eventRow(BuildContext context, Booking b) {
    final dateColor = b.status == 'confirmed'
        ? const Color(0xFFE3F7ED)
        : const Color(0xFFFFF2D5);
    return InkWell(
      onTap: onBookings,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE1E8E4)),
        ),
        child: Row(
          children: [
            Container(
              width: 82,
              height: 88,
              decoration: BoxDecoration(
                color: dateColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_weekday(b.eventDate),
                      style: const TextStyle(fontSize: 11)),
                  Text(
                    '${b.eventDate.day}',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _shortMonth(b.eventDate).toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${b.eventDetails} • ${b.clientName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _statusChip(b.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 18,
                    runSpacing: 6,
                    children: [
                      _mini(Icons.person_outline, b.clientName),
                      _mini(Icons.meeting_room_outlined, b.hallSpaceName),
                    ],
                  ),
                  const Divider(height: 18),
                  Wrap(
                    spacing: 24,
                    runSpacing: 7,
                    children: [
                      _timeInfo(Icons.login_outlined, 'Access',
                          _time(b.accessStart)),
                      _timeInfo(Icons.schedule_outlined, 'Event Time',
                          _time(b.eventStart)),
                      _timeInfo(Icons.logout_outlined, 'Vacate',
                          _timeWithDay(b.vacateEnd, b.eventDate)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_outlined, color: _green),
                const SizedBox(width: 8),
                Text('Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onNewBooking,
              icon: const Icon(Icons.add),
              label: const Text('New Booking'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onPlanner,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Hall Planner'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onBookings,
              icon: const Icon(Icons.event_note_outlined),
              label: const Text('All Bookings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attentionCard(
    BuildContext context,
    double depositsDue,
    double outstanding,
    int unsigned,
    int activeCount,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: _rose),
                const SizedBox(width: 8),
                Text('Needs Attention',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 14),
            _attentionRow(
              icon: Icons.account_balance_wallet_outlined,
              tint: const Color(0xFFFFEAEA),
              iconColor: _rose,
              title: 'Deposits Due',
              subtitle: '${_money(depositsDue)} outstanding',
            ),
            const Divider(),
            _attentionRow(
              icon: Icons.attach_money,
              tint: const Color(0xFFFFF2D5),
              iconColor: _gold,
              title: 'Outstanding Balances',
              subtitle: '${_money(outstanding)} across $activeCount bookings',
            ),
            const Divider(),
            _attentionRow(
              icon: Icons.description_outlined,
              tint: const Color(0xFFF1EFE8),
              iconColor: const Color(0xFF725E32),
              title: 'Unsigned Contracts',
              subtitle: '$unsigned booking${unsigned == 1 ? '' : 's'} awaiting signature',
            ),
          ],
        ),
      ),
    );
  }

  Widget _attentionRow({
    required IconData icon,
    required Color tint,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: tint,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF718079))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              size: 18, color: Color(0xFF799087)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'confirmed':
        bg = const Color(0xFFDDF6E8);
        fg = const Color(0xFF176445);
        break;
      case 'completed':
        bg = const Color(0xFFE8EEF1);
        fg = const Color(0xFF50656F);
        break;
      case 'cancelled':
        bg = const Color(0xFFFFE5E8);
        fg = const Color(0xFFAD3340);
        break;
      default:
        bg = const Color(0xFFFFEFC6);
        fg = const Color(0xFF76500C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _mini(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF536860)),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF536860))),
        ],
      );

  Widget _timeInfo(IconData icon, String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF536860)),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF83918B))),
              Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      );

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _money(double v) => '\$${v.toStringAsFixed(2)}';

  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _timeWithDay(DateTime d, DateTime eventDate) {
    final suffix = _sameDay(d, eventDate) ? '' : ' (${_weekday(d)})';
    return '${_time(d)}$suffix';
  }

  static String _statusLabel(String status) {
    return status
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String _weekday(DateTime d) => const [
        'MON',
        'TUE',
        'WED',
        'THU',
        'FRI',
        'SAT',
        'SUN',
      ][d.weekday - 1];

  static String _shortMonth(DateTime d) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][d.month - 1];

  static String _longDate(DateTime d) =>
      '${_weekday(d)[0]}${_weekday(d).substring(1).toLowerCase()}, ${_shortMonth(d)} ${d.day}, ${d.year}';
}
