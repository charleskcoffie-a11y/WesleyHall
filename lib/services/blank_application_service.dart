import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/wesley_models.dart';

class BlankApplicationService {
  Future<Uint8List> build({
    required SettingsBundle settings,
    Uint8List? organizationLogo,
  }) async {
    final pdf = pw.Document();
    final org = settings.organization;
    final rules = settings.rules;
    final logo = organizationLogo == null
        ? null
        : pw.MemoryImage(organizationLogo);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(34),
        header: (_) => pw.Column(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 58,
                    height: 58,
                    margin: const pw.EdgeInsets.only(right: 12),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: logo == null
                        ? pw.CrossAxisAlignment.center
                        : pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'GHANA METHODIST CHURCH OF TORONTO',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        org.hallName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(org.address,
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('${org.phone}  |  ${org.email}',
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 7),
            pw.Divider(),
          ],
        ),
        build: (_) => [
          pw.Text(
            'HALL RENTAL APPLICATION',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Please complete this form clearly. Hall availability is not guaranteed until the booking is entered and confirmed by the booking office.',
            style: const pw.TextStyle(fontSize: 9.5),
          ),
          pw.SizedBox(height: 12),
          _section('APPLICANT INFORMATION'),
          _fieldTable([
            ['Date', ''],
            ['Client Name', ''],
            ['Address', ''],
            ['Telephone', ''],
            ['Email', ''],
          ]),
          pw.SizedBox(height: 10),
          _section('EVENT INFORMATION'),
          _fieldTable([
            ['Event Date', ''],
            ['Event / Function', ''],
            ['Number of Guests', ''],
            ['Event Start Time', ''],
            ['Event End Time', ''],
          ]),
          pw.SizedBox(height: 10),
          _section('HALL SPACE - CHECK ONE'),
          ...settings.spaces.where((s) => s.active).map(
                (space) => _checkLine(
                  space.name,
                  space.baseRate > 0
                      ? '\$${space.baseRate.toStringAsFixed(2)}'
                      : 'Rate to be confirmed',
                ),
              ),
          pw.SizedBox(height: 10),
          _section('OPTIONAL FACILITIES / SERVICES - CHECK ALL REQUIRED'),
          ...settings.services.where((s) => s.active).map(
                (service) => _checkLine(
                  service.name,
                  '\$${service.price.toStringAsFixed(2)}${service.pricingType == 'hourly' ? ' / hr' : ''}',
                  trailingBlank: service.pricingType == 'hourly'
                      ? 'Hours: ________'
                      : null,
                ),
              ),
          pw.SizedBox(height: 10),
          _section('PAYMENT INFORMATION'),
          _fieldTable([
            ['Hall / Rental Charge', '\$________________'],
            ['Services', '\$________________'],
            ['Total Rental Amount', '\$________________'],
            [
              'Required Non-Refundable Booking Deposit (${rules.bookingDepositPercent.toStringAsFixed(0)}%)',
              '\$________________'
            ],
            ['Rental Balance', '\$________________'],
            [
              'Separate Refundable Damage Deposit',
              '\$${rules.damageDepositAmount.toStringAsFixed(2)}'
            ],
          ]),
          pw.SizedBox(height: 10),
          pw.Text(
            'Standard rental period: ${rules.standardRentalHours} hours. Normal setup access: ${_duration(rules.setupMinutesBefore)} before event. Normal cleanup/vacate allowance: ${_duration(rules.cleanupMinutesAfter)} after event.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          if (rules.extraHourRate > 0)
            pw.Text(
              'Additional approved rental time: \$${rules.extraHourRate.toStringAsFixed(2)} per hour.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          pw.SizedBox(height: 12),
          _section('TERMS AND CONDITIONS'),
          ...settings.terms.where((t) => t.active).map(
                (term) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    '${term.order}. ${term.text}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ),
          pw.SizedBox(height: 16),
          pw.Text(
            'I have read and agree to the terms and conditions above.',
            style: const pw.TextStyle(fontSize: 9.5),
          ),
          pw.SizedBox(height: 22),
          pw.Row(
            children: [
              pw.Expanded(child: _signatureLine('Client Signature')),
              pw.SizedBox(width: 28),
              pw.Expanded(child: _signatureLine('Date')),
            ],
          ),
          pw.SizedBox(height: 18),
          _section('OFFICE USE ONLY'),
          _fieldTable([
            ['Booking Reference No.', ''],
            ['Entered Into Hall Planner By', ''],
            ['Date Entered', ''],
            ['Booking Officer', ''],
          ]),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _section(String title) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        color: PdfColors.grey200,
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      );

  pw.Widget _fieldTable(List<List<String>> rows) => pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.7),
          1: pw.FlexColumnWidth(4.3),
        },
        children: rows
            .map(
              (r) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      r[0],
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      r[1].isEmpty ? ' ' : r[1],
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      );

  pw.Widget _checkLine(
    String label,
    String price, {
    String? trailingBlank,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          children: [
            pw.Container(
              width: 11,
              height: 11,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: .8),
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: pw.Text(label, style: const pw.TextStyle(fontSize: 9.5)),
            ),
            if (trailingBlank != null) ...[
              pw.Text(trailingBlank,
                  style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 16),
            ],
            pw.Text(
              price,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  pw.Widget _signatureLine(String label) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(height: 1, color: PdfColors.black),
          pw.SizedBox(height: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        ],
      );

  String _duration(int minutes) {
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return '$hours hour${hours == 1 ? '' : 's'}';
    }
    return '$minutes minutes';
  }
}
