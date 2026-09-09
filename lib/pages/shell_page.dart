import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/wesley_repository.dart';
import 'bookings_page.dart';
import 'dashboard_page.dart';
import 'new_booking_page.dart';
import 'planner_page.dart';
import 'settings_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key, required this.repository});

  final WesleyRepository repository;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;
  int _refreshToken = 0;
  int _newBookingToken = 0;

  static const _sidebar = Color(0xFF0C4A39);
  static const _sidebarDark = Color(0xFF093F31);
  static const _mintText = Color(0xFFC8DDD5);

  void _goToNewBooking() => setState(() {
        _newBookingToken++;
        _index = 2;
      });

  void _goToPlanner() => setState(() => _index = 1);
  void _goToBookings() => setState(() => _index = 3);
  void _refresh() => setState(() => _refreshToken++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        key: ValueKey('dashboard-$_refreshToken'),
        repository: widget.repository,
        onNewBooking: _goToNewBooking,
        onPlanner: _goToPlanner,
        onBookings: _goToBookings,
      ),
      PlannerPage(
        key: ValueKey('planner-$_refreshToken'),
        repository: widget.repository,
        onNewBooking: _goToNewBooking,
      ),
      NewBookingPage(
        key: ValueKey('new-booking-$_newBookingToken'),
        repository: widget.repository,
        onSaved: () {
          _refresh();
          setState(() => _index = 3);
        },
      ),
      BookingsPage(
        key: ValueKey('bookings-$_refreshToken'),
        repository: widget.repository,
      ),
      SettingsPage(
        key: ValueKey('settings-$_refreshToken'),
        repository: widget.repository,
        onSaved: _refresh,
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 244,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_sidebarDark, _sidebar],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 26, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.church_outlined,
                            color: Colors.white, size: 42),
                        SizedBox(height: 10),
                        Text(
                          'WESLEY HALL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'GMCT Booking & Planning',
                          style: TextStyle(
                            color: _mintText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _navItem(0, Icons.home_outlined, 'Dashboard'),
                  _navItem(1, Icons.calendar_month_outlined, 'Hall Planner'),
                  _navItem(2, Icons.add_circle_outline, 'New Booking'),
                  _navItem(3, Icons.event_note_outlined, 'Bookings'),
                  _navItem(4, Icons.settings_outlined, 'Settings'),
                  const Spacer(),
                  if (widget.repository.isDemoMode)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'DEMO MODE\nSupabase is not connected yet.',
                        style: TextStyle(
                          color: Color(0xFFD8E7E1),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    )
                  else ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(color: Colors.white24, height: 1),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextButton.icon(
                        onPressed: () =>
                            Supabase.instance.client.auth.signOut(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        icon: const Icon(Icons.logout_outlined, size: 20),
                        label: const Text('Sign Out'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(28, 8, 24, 22),
                      child: Row(
                        children: [
                          Icon(Icons.eco_outlined,
                              color: Color(0xFF9CC8B7), size: 24),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Serving our community\ntogether.',
                              style: TextStyle(
                                color: Color(0xFF9CC8B7),
                                fontSize: 10,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _index == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: .14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: index == 2
              ? _goToNewBooking
              : () => setState(() => _index = index),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? const Border(
                      left: BorderSide(color: Color(0xFF54D69A), width: 3),
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : _mintText,
                  size: 22,
                ),
                const SizedBox(width: 13),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _mintText,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
