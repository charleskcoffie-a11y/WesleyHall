import 'package:flutter/material.dart';

import '../models/wesley_models.dart';
import '../services/wesley_repository.dart';
import '../widgets/page_header.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.repository});

  final WesleyRepository repository;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 28, 30, 26),
      child: FutureBuilder<List<Booking>>(
        future: widget.repository.listBookings(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bookings = snapshot.data!
              .where((b) =>
                  b.eventDate.year == month.year &&
                  b.eventDate.month == month.month)
              .toList();
          final rentals = bookings.where((b) => !b.isChurchUse).toList();
          final church = bookings.where((b) => b.isChurchUse).toList();
          final totalRentalValue =
              rentals.fold<double>(0, (sum, b) => sum + b.totalCharge);
          final received = rentals.fold<double>(
            0,
            (sum, b) =>
                sum +
                b.payments
                    .where((p) => p.paymentType != 'damage_refund')
                    .fold<double>(0, (s, p) => s + p.amount),
          );
          final outstanding =
              rentals.fold<double>(0, (sum, b) => sum + b.remainingRentalBalance);
          final damageHeld =
              rentals.fold<double>(0, (sum, b) => sum + b.damageDepositHeld);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Reports',
                subtitle:
                    'Monthly hall activity, rental income, balances, and deposits.',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => setState(() {
                        month = DateTime(month.year, month.month - 1);
                      }),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F7F4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _monthName(month),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () => setState(() {
                        month = DateTime(month.year, month.month + 1);
                      }),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metric('Total Reservations', bookings.length.toString(),
                      Icons.event_note_outlined),
                  _metric('External Rentals', rentals.length.toString(),
                      Icons.payments_outlined),
                  _metric('Church Use', church.length.toString(),
                      Icons.church_outlined),
                  _metric('Rental Value', _money(totalRentalValue),
                      Icons.receipt_long_outlined),
                  _metric('Payments Received', _money(received),
                      Icons.account_balance_wallet_outlined),
                  _metric('Outstanding Balance', _money(outstanding),
                      Icons.warning_amber_outlined),
                  _metric('Damage Deposits Held', _money(damageHeld),
                      Icons.shield_outlined),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Card(
                  child: bookings.isEmpty
                      ? const Center(
                          child: Text('No reservations for this month.'))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('REF')),
                                DataColumn(label: Text('DATE')),
                                DataColumn(label: Text('CLIENT / GROUP')),
                                DataColumn(label: Text('EVENT')),
                                DataColumn(label: Text('TYPE')),
                                DataColumn(label: Text('TOTAL')),
                                DataColumn(label: Text('BALANCE')),
                                DataColumn(label: Text('DAMAGE HELD')),
                              ],
                              rows: bookings.map((b) {
                                final name = b.isChurchUse && b.churchGroup.isNotEmpty
                                    ? b.churchGroup
                                    : b.clientName;
                                return DataRow(cells: [
                                  DataCell(Text(b.referenceNumber)),
                                  DataCell(Text(_date(b.eventDate))),
                                  DataCell(Text(name)),
                                  DataCell(Text(b.eventDetails)),
                                  DataCell(Text(
                                      b.isChurchUse ? 'Church Use' : 'Rental')),
                                  DataCell(Text(_money(b.totalCharge))),
                                  DataCell(Text(_money(b.remainingRentalBalance))),
                                  DataCell(Text(_money(b.damageDepositHeld))),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => SizedBox(
        width: 220,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F5ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF116149)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF66766F))),
                      const SizedBox(height: 3),
                      Text(value,
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
  String _date(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
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
