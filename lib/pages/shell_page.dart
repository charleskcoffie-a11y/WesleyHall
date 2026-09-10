import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/wesley_repository.dart';
import '../utils/favicon.dart';
import 'bookings_page.dart';
import 'dashboard_page.dart';
import 'new_booking_page.dart';
import 'planner_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import 'staff_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key, required this.repository});

  final WesleyRepository repository;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  String _pageKey = 'dashboard';
  int _refreshToken = 0;
  int _newBookingToken = 0;
  Uint8List? _logoBytes;
  String? _role;
  String _displayName = '';
  bool _profileLoading = true;

  static const _sidebar = Color(0xFF0C4A39);
  static const _sidebarDark = Color(0xFF093F31);
  static const _mintText = Color(0xFFC8DDD5);

  bool get _canBook =>
      _role == 'admin' || _role == 'manager' || _role == 'booking_officer';
  bool get _canViewReports =>
      _role == 'admin' || _role == 'manager' || _role == 'finance';
  bool get _canManageSettings => _role == 'admin' || _role == 'manager';
  bool get _canManageStaff => _role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBranding();
  }

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final row = await Supabase.instance.client
          .from('wesley_staff_users')
          .select('role, active, display_name, username')
          .eq('user_id', user.id)
          .single();
      if (!mounted) return;
      if (row['active'] != true) {
        await Supabase.instance.client.auth.signOut();
        return;
      }
      setState(() {
        _role = row['role']?.toString() ?? 'viewer';
        _displayName = row['display_name']?.toString().trim().isNotEmpty == true
            ? row['display_name'].toString()
            : row['username']?.toString() ?? 'Wesley Hall Staff';
        _profileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _role = 'viewer';
        _profileLoading = false;
      });
    }
  }

  Future<void> _loadBranding() async {
    try {
      final settings = await widget.repository.loadSettings();
      final bytes = await widget.repository
          .loadOrganizationLogo(settings.organization.organizationLogoPath);
      if (bytes != null) setBrowserFavicon(bytes);
      if (mounted) setState(() => _logoBytes = bytes);
    } catch (_) {
      // Keep the fallback icon if branding cannot be loaded.
    }
  }

  void _goToNewBooking() {
    if (!_canBook) return;
    setState(() {
      _newBookingToken++;
      _pageKey = 'new';
    });
  }

  void _goToPlanner() => setState(() => _pageKey = 'planner');
  void _goToBookings() => setState(() => _pageKey = 'bookings');

  void _refresh() {
    setState(() => _refreshToken++);
    _loadBranding();
    _loadProfile();
  }

  List<_ShellDestination> _destinations() {
    final items = <_ShellDestination>[
      _ShellDestination(
        keyName: 'dashboard',
        icon: Icons.home_outlined,
        label: 'Dashboard',
        page: DashboardPage(
          key: ValueKey('dashboard-$_refreshToken'),
          repository: widget.repository,
          onNewBooking: _goToNewBooking,
          onPlanner: _goToPlanner,
          onBookings: _goToBookings,
        ),
      ),
      _ShellDestination(
        keyName: 'planner',
        icon: Icons.calendar_month_outlined,
        label: 'Hall Planner',
        page: PlannerPage(
          key: ValueKey('planner-$_refreshToken'),
          repository: widget.repository,
          onNewBooking: _goToNewBooking,
        ),
      ),
    ];

    if (_canBook) {
      items.add(
        _ShellDestination(
          keyName: 'new',
          icon: Icons.add_circle_outline,
          label: 'New Booking',
          page: NewBookingPage(
            key: ValueKey('new-booking-$_newBookingToken'),
            repository: widget.repository,
            onSaved: () {
              _refresh();
              setState(() => _pageKey = 'bookings');
            },
          ),
        ),
      );
    }

    items.add(
      _ShellDestination(
        keyName: 'bookings',
        icon: Icons.event_note_outlined,
        label: 'Bookings',
        page: BookingsPage(
          key: ValueKey('bookings-$_refreshToken'),
          repository: widget.repository,
        ),
      ),
    );

    if (_canViewReports) {
      items.add(
        _ShellDestination(
          keyName: 'reports',
          icon: Icons.bar_chart_outlined,
          label: 'Reports',
          page: ReportsPage(
            key: ValueKey('reports-$_refreshToken'),
            repository: widget.repository,
          ),
        ),
      );
    }

    if (_canManageSettings) {
      items.add(
        _ShellDestination(
          keyName: 'settings',
          icon: Icons.settings_outlined,
          label: 'Settings',
          page: SettingsPage(
            key: ValueKey('settings-$_refreshToken'),
            repository: widget.repository,
            onSaved: _refresh,
          ),
        ),
      );
    }

    if (_canManageStaff) {
      items.add(
        const _ShellDestination(
          keyName: 'staff',
          icon: Icons.admin_panel_settings_outlined,
          label: 'Staff & Permissions',
          page: StaffPage(),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (_profileLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final destinations = _destinations();
    var selectedIndex = destinations.indexWhere((d) => d.keyName == _pageKey);
    if (selectedIndex < 0) {
      selectedIndex = 0;
      _pageKey = destinations.first.keyName;
    }

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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 18, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_logoBytes != null)
                          Container(
                            width: 64,
                            height: 64,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Image.memory(_logoBytes!, fit: BoxFit.contain),
                          )
                        else
                          const Icon(Icons.church_outlined,
                              color: Colors.white, size: 42),
                        const SizedBox(height: 12),
                        const Text(
                          'WESLEY HALL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'GMCT Booking & Planning',
                          style: TextStyle(color: _mintText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(
                    destinations.length,
                    (index) => _navItem(
                      destinations[index],
                      selected: index == selectedIndex,
                    ),
                  ),
                  const Spacer(),
                  if (!widget.repository.isDemoMode) ...[
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName.isEmpty ? 'Wesley Hall Staff' : _displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _roleLabel(_role ?? 'viewer'),
                            style: const TextStyle(
                              color: Color(0xFF9CC8B7),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(color: Colors.white24, height: 1),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextButton.icon(
                        onPressed: () => Supabase.instance.client.auth.signOut(),
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
                      padding: EdgeInsets.fromLTRB(28, 4, 24, 18),
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
            child: IndexedStack(
              index: selectedIndex,
              children: destinations.map((d) => d.page).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(_ShellDestination item, {required bool selected}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: .14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _pageKey = item.keyName),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? const Border(
                      left: BorderSide(color: Color(0xFF54D69A), width: 3),
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: selected ? Colors.white : _mintText,
                  size: 21,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? Colors.white : _mintText,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) => switch (role) {
        'admin' => 'Administrator',
        'manager' => 'Manager',
        'booking_officer' => 'Booking Officer',
        'finance' => 'Finance',
        _ => 'Viewer',
      };
}

class _ShellDestination {
  const _ShellDestination({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.page,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final Widget page;
}
