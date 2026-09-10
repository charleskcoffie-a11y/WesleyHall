import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/page_header.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> staff = const [];

  static const roles = <String, String>{
    'admin': 'Administrator',
    'manager': 'Manager',
    'booking_officer': 'Booking Officer',
    'finance': 'Finance',
    'viewer': 'Viewer',
  };

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await Supabase.instance.client.functions.invoke(
      'wesley-manage-staff',
      body: body,
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final message = data['error']?.toString();
    if (message != null && message.isNotEmpty) throw Exception(message);
    return data;
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await _invoke({'action': 'list'});
      final rows = (data['staff'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() => staff = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> createStaff() async {
    final username = TextEditingController();
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    var role = 'booking_officer';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: const Text('Add Wesley Hall Staff'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: username,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    helperText: 'Example: bookingofficer or mary.k',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    helperText: 'If blank, username@wesleyhall.local is used.',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: roles.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (value) => setModal(() => role = value ?? role),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Temporary Password',
                    helperText: 'At least 8 characters.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Create Staff User'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    try {
      await _invoke({
        'action': 'create',
        'username': username.text.trim(),
        'display_name': name.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'role': role,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff account created.')),
      );
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create staff user: $e')),
      );
    }
  }

  Future<void> editStaff(Map<String, dynamic> row) async {
    final name = TextEditingController(text: row['display_name']?.toString() ?? '');
    var role = row['role']?.toString() ?? 'viewer';
    var active = row['active'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: Text(row['username']?.toString() ?? 'Staff User'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: roles.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (value) => setModal(() => role = value ?? role),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active account'),
                  subtitle: const Text('Inactive users cannot use Wesley Hall.'),
                  value: active,
                  onChanged: (value) => setModal(() => active = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    try {
      await _invoke({
        'action': 'update',
        'user_id': row['user_id'],
        'display_name': name.text.trim(),
        'role': role,
        'active': active,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff permissions updated.')),
      );
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update staff user: $e')),
      );
    }
  }

  Future<void> resetPassword(Map<String, dynamic> row) async {
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Staff Password'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New Temporary Password',
              helperText: 'At least 8 characters.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _invoke({
        'action': 'reset_password',
        'user_id': row['user_id'],
        'password': password.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to reset password: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 28, 30, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Staff & Permissions',
            subtitle: 'Control who can book the hall, manage money, change settings, or only view information.',
            trailing: FilledButton.icon(
              onPressed: loading ? null : createStaff,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Staff'),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: roles.entries.map((entry) {
                  final description = switch (entry.key) {
                    'admin' => 'Everything + staff management',
                    'manager' => 'Bookings, finance, settings, documents',
                    'booking_officer' => 'Bookings, contracts, receipts, inspections',
                    'finance' => 'View bookings + payments and reports',
                    _ => 'Read-only planner and booking information',
                  };
                  return Chip(
                    avatar: const Icon(Icons.shield_outlined, size: 17),
                    label: Text('${entry.value}: $description'),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(child: Text(error!))
                      : staff.isEmpty
                          ? const Center(child: Text('No staff users found.'))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(14),
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('NAME')),
                                    DataColumn(label: Text('USERNAME')),
                                    DataColumn(label: Text('EMAIL')),
                                    DataColumn(label: Text('ROLE')),
                                    DataColumn(label: Text('STATUS')),
                                    DataColumn(label: Text('ACTIONS')),
                                  ],
                                  rows: staff.map((row) {
                                    final role = row['role']?.toString() ?? 'viewer';
                                    final active = row['active'] == true;
                                    return DataRow(cells: [
                                      DataCell(Text(row['display_name']?.toString() ?? '')),
                                      DataCell(Text(row['username']?.toString() ?? '')),
                                      DataCell(Text(row['email']?.toString() ?? '')),
                                      DataCell(Chip(label: Text(roles[role] ?? role))),
                                      DataCell(Chip(
                                        avatar: Icon(
                                          active ? Icons.check_circle_outline : Icons.block_outlined,
                                          size: 17,
                                        ),
                                        label: Text(active ? 'ACTIVE' : 'INACTIVE'),
                                      )),
                                      DataCell(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => editStaff(row),
                                            icon: const Icon(Icons.edit_outlined, size: 16),
                                            label: const Text('Edit'),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () => resetPassword(row),
                                            icon: const Icon(Icons.password_outlined, size: 16),
                                            label: const Text('Reset Password'),
                                          ),
                                        ],
                                      )),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
