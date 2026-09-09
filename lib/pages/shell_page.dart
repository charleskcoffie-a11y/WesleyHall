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

  void _goToNewBooking() => setState(() => _index = 2);
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
            width: 238,
            color: const Color(0xFF153D31),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 24, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WESLEY HALL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .4,
                            )),
                        SizedBox(height: 4),
                        Text('GMCT Booking & Planning',
                            style: TextStyle(color: Color(0xFFB9D2C8), fontSize: 12)),
                      ],
                    ),
                  ),
                  _navItem(0, Icons.dashboard_outlined, 'Dashboard'),
                  _navItem(1, Icons.calendar_month_outlined, 'Hall Planner'),
                  _navItem(2, Icons.add_circle_outline, 'New Booking'),
                  _navItem(3, Icons.event_note_outlined, 'Bookings'),
                  _navItem(4, Icons.settings_outlined, 'Settings'),
                  const Spacer(),
                  if (widget.repository.isDemoMode)
                    Container(
                      margin: const EdgeInsets.all(14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'DEMO MODE\nSupabase is not connected yet.',
                        style: TextStyle(color: Color(0xFFD8E7E1), fontSize: 11, height: 1.4),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: TextButton.icon(
                        onPressed: () => Supabase.instance.client.auth.signOut(),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                      ),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: .13) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _index = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: selected ? Colors.white : const Color(0xFFB9D2C8), size: 21),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFB9D2C8),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
