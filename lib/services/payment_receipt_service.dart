import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/wesley_models.dart';

class PaymentReceiptService {
  Future<Uint8List> build({
    required Booking booking,
    required PaymentRecord payment,
    required SettingsBundle settings,
    Uint8List? organizationLogo,
  }) async {
    final pdf = pw.Document();
    final org = settings.organization;
    final logo = organizationLogo == null ? null : pw.MemoryImage(organizationLogo);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(42),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 64,
                    height: 64,
                    margin: const pw.EdgeInsets.only(right: 14),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'GHANA METHODIST CHURCH OF TORONTO',
                        style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(org.hallName.toUpperCase(),
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text(org.address, style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('${org.phone}  |  ${org.email}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Text('PAYMENT RECEIPT',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 18),
            _row('Booking Reference', booking.referenceNumber),
            _row('Received From', booking.clientName.isEmpty ? booking.churchGroup : booking.clientName),
            _row('Event / Function', booking.eventDetails),
            _row('Event Date', _date(booking.eventDate)),
            _row('Payment Date', _date(payment.paymentDate)),
            _row('Payment Type', _title(payment.paymentType)),
            _row('Payment Method', payment.paymentMethod.isEmpty ? 'Not specified' : payment.paymentMethod),
            _row('Reference / Receipt No.', payment.paymentReference.isEmpty ? '—' : payment.paymentReference),
            pw.SizedBox(height: 18),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500),
                color: PdfColors.grey100,
              ),
              child: pw.Row(
                children: [
                  pw.Text('AMOUNT RECEIVED', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Spacer(),
                  pw.Text('\$${payment.amount.toStringAsFixed(2)} CAD',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            if (payment.notes.trim().isNotEmpty) ...[
              pw.SizedBox(height: 14),
              _row('Notes', payment.notes.trim()),
            ],
            pw.SizedBox(height: 28),
            pw.Text(
              'Thank you. This receipt forms part of the Wesley Hall booking record.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _row(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 7),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .5)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 155,
              child: pw.Text(label,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
          ],
        ),
      );

  String _date(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  String _title(String value) => value
      .split('_')
      .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}
