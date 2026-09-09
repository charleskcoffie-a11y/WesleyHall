import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/wesley_models.dart';

class ContractService {
  Future<Uint8List> buildContract({
    required Booking booking,
    required SettingsBundle settings,
    Uint8List? managerSignature,
    Uint8List? organizationLogo,
  }) async {
    final pdf = pw.Document();
    final org = settings.organization;
    final rules = settings.rules;
    final signatureImage = managerSignature == null
        ? null
        : pw.MemoryImage(managerSignature);
    final logoImage = organizationLogo == null
        ? null
        : pw.MemoryImage(organizationLogo);

    final requiredDeposit = booking.requiredBookingDeposit;
    final rentalBalance = booking.remainingRentalBalance;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 58,
                    height: 58,
                    margin: const pw.EdgeInsets.only(right: 12),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: logoImage == null
                        ? pw.CrossAxisAlignment.center
                        : pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(org.hallName.toUpperCase(),
                          style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(org.churchName,
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(org.address,
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('${org.phone}  |  ${org.email}',
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.Text('HALL RENTAL AGREEMENT',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _twoColumn([
            ['Reference No.', booking.referenceNumber],
            ['Client', booking.clientName],
            ['Address', booking.clientAddress],
            ['Telephone', booking.phone],
            ['Email', booking.email],
            ['Hall', booking.hallSpaceName],
            ['Event', booking.eventDetails],
            ['Guests', booking.guestCount.toString()],
          ]),
          pw.SizedBox(height: 12),
          _sectionTitle('EVENT AND ACCESS TIMES'),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              _row('Event Date', _date(booking.eventDate)),
              _row('Setup / Hall Access', _dateTime(booking.accessStart)),
              _row('Event Time', '${_time(booking.eventStart)} - ${_time(booking.eventEnd)}'),
              _row('Hall Must Be Vacated By', _dateTime(booking.vacateEnd)),
            ],
          ),
          pw.SizedBox(height: 12),
          _sectionTitle('CHARGES'),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1.5),
            },
            children: [
              _moneyRow('Hall Rental', booking.hallCharge),
              ...booking.extras.map((e) => _moneyRow(
                  '${e.name}${e.quantity != 1 ? ' x ${e.quantity.toStringAsFixed(e.quantity % 1 == 0 ? 0 : 1)}' : ''}',
                  e.total)),
              if (booking.extraTimeCharge > 0)
                _moneyRow('Additional Time', booking.extraTimeCharge),
              _moneyRow('Total Amount Charged', booking.totalCharge, bold: true),
              _moneyRow('Required Non-Refundable Booking Deposit (${booking.bookingDepositPercent.toStringAsFixed(0)}%)', requiredDeposit),
              _moneyRow('Booking Deposit Received', booking.bookingDepositPaid),
              _moneyRow('Rental Balance Outstanding', rentalBalance, bold: true),
              _moneyRow('Separate Refundable Damage Deposit', booking.damageDepositRequired),
              _moneyRow('Damage Deposit Currently Held', booking.damageDepositHeld),
            ],
          ),
          pw.SizedBox(height: 12),
          _sectionTitle('RENTAL TIME CONDITIONS'),
          pw.Bullet(
            text: 'Standard rental period: ${rules.standardRentalHours} hours.',
            style: const pw.TextStyle(fontSize: 9.5),
          ),
          pw.Bullet(
            text: 'Normal setup access allowance: ${_duration(rules.setupMinutesBefore)} before the event.',
            style: const pw.TextStyle(fontSize: 9.5),
          ),
          pw.Bullet(
            text: 'Normal cleanup/vacate allowance: ${_duration(rules.cleanupMinutesAfter)} after the event.',
            style: const pw.TextStyle(fontSize: 9.5),
          ),
          if (rules.extraHourRate > 0)
            pw.Bullet(
              text: 'Additional approved rental time is charged at \$${rules.extraHourRate.toStringAsFixed(2)} per hour.',
              style: const pw.TextStyle(fontSize: 9.5),
            ),
          pw.SizedBox(height: 8),
          _sectionTitle('TERMS AND CONDITIONS'),
          ...settings.terms.where((t) => t.active).map(
                (term) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('${term.order}. ${term.text}',
                      style: const pw.TextStyle(fontSize: 9.5)),
                ),
              ),
          pw.SizedBox(height: 14),
          pw.Text(
            'I, ${booking.clientName}, have read and agree to the terms and conditions of this contract.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 28),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Client Signature', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Date: ____________________', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.SizedBox(width: 36),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (org.autoIncludeManagerSignature && signatureImage != null)
                      pw.Container(
                        height: 40,
                        alignment: pw.Alignment.bottomLeft,
                        child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                      )
                    else
                      pw.SizedBox(height: 40),
                    pw.Container(height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text(org.managerName.isEmpty ? 'Authorized Manager' : org.managerName,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text(org.managerTitle, style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _sectionTitle(String text) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 7),
        color: PdfColors.grey200,
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _twoColumn(List<List<String>> values) => pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.3),
          1: pw.FlexColumnWidth(3.7),
        },
        children: values.map((r) => _row(r[0], r[1])).toList(),
      );

  pw.TableRow _row(String label, String value) => pw.TableRow(children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(label,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ),
      ]);

  pw.TableRow _moneyRow(String label, double value, {bool bold = false}) => pw.TableRow(children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(label,
              style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text('\$${value.toStringAsFixed(2)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      ]);

  String _date(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
  String _dateTime(DateTime d) => '${_date(d)} ${_time(d)}';
  String _duration(int minutes) {
    if (minutes % 60 == 0) return '${minutes ~/ 60} hour${minutes == 60 ? '' : 's'}';
    return '$minutes minutes';
  }
}
