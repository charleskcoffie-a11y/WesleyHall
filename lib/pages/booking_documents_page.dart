import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wesley_models.dart';

class BookingDocumentsPage extends StatefulWidget {
  const BookingDocumentsPage({super.key, required this.booking});

  final Booking booking;

  @override
  State<BookingDocumentsPage> createState() => _BookingDocumentsPageState();
}

class _BookingDocumentsPageState extends State<BookingDocumentsPage> {
  bool loading = true;
  String role = 'viewer';
  List<Map<String, dynamic>> documents = const [];

  bool get canUpload =>
      role == 'admin' || role == 'manager' || role == 'booking_officer';
  bool get canDelete => role == 'admin' || role == 'manager';

  static const documentTypes = <String, String>{
    'paper_application': 'Paper Application',
    'signed_contract': 'Signed Contract',
    'receipt': 'Receipt',
    'damage_report': 'Damage / Inspection Report',
    'correspondence': 'Correspondence',
    'other': 'Other Document',
  };

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final profile = await client
            .from('wesley_staff_users')
            .select('role')
            .eq('user_id', user.id)
            .single();
        role = profile['role']?.toString() ?? 'viewer';
      }
      final rows = await client
          .from('wesley_contract_records')
          .select('id, storage_path, document_type, display_name, mime_type, file_size, uploaded_at, generated_at')
          .eq('booking_id', widget.booking.id)
          .order('uploaded_at', ascending: false);
      if (!mounted) return;
      setState(() {
        documents = rows
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load documents: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> uploadDocument() async {
    var type = 'other';
    final nameController = TextEditingController();

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: const Text('Add Booking Document'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Document Type'),
                  items: documentTypes.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (value) => setModal(() => type = value ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Document Name (optional)',
                    hintText: 'Example: Signed Rental Agreement',
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
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Choose File'),
            ),
          ],
        ),
      ),
    );
    if (proceed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Unable to read the selected file.');

      var extension = (file.extension ?? 'pdf').toLowerCase();
      if (extension == 'jpeg') extension = 'jpg';
      final contentType = switch (extension) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        _ => 'image/jpeg',
      };
      final displayName = nameController.text.trim().isNotEmpty
          ? nameController.text.trim()
          : file.name;
      final safeName = file.name
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final path =
          'contracts/${widget.booking.id}/documents/${DateTime.now().millisecondsSinceEpoch}-$safeName';

      final client = Supabase.instance.client;
      await client.storage.from('wesley-hall-private').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      await client.from('wesley_contract_records').insert({
        'booking_id': widget.booking.id,
        'storage_path': path,
        'document_type': type,
        'display_name': displayName,
        'mime_type': contentType,
        'file_size': bytes.length,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document added to the booking file.')),
      );
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to upload document: $e')),
      );
    }
  }

  Future<void> viewOrPrint(Map<String, dynamic> document) async {
    try {
      final path = document['storage_path']?.toString() ?? '';
      if (path.isEmpty) return;
      final bytes = await Supabase.instance.client.storage
          .from('wesley-hall-private')
          .download(path);
      final mime = document['mime_type']?.toString() ?? _mimeFromPath(path);
      final name = document['display_name']?.toString() ?? 'Booking Document';

      if (mime == 'application/pdf' || path.toLowerCase().endsWith('.pdf')) {
        await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
        return;
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(name),
          content: SizedBox(
            width: 760,
            height: 520,
            child: InteractiveViewer(
              child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final pdfBytes = await _imageAsPdf(bytes);
                await Printing.layoutPdf(name: name, onLayout: (_) async => pdfBytes);
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print / Save PDF'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open document: $e')),
      );
    }
  }

  Future<Uint8List> _imageAsPdf(Uint8List bytes) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(bytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
    return doc.save();
  }

  Future<void> deleteDocument(Map<String, dynamic> document) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Document?'),
        content: Text(
          'Remove "${document['display_name'] ?? 'this document'}" from this booking file?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final client = Supabase.instance.client;
      final path = document['storage_path']?.toString();
      if (path != null && path.isNotEmpty) {
        await client.storage.from('wesley-hall-private').remove([path]);
      }
      await client
          .from('wesley_contract_records')
          .delete()
          .eq('id', document['id']);
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to remove document: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return Scaffold(
      appBar: AppBar(title: Text('${b.referenceNumber} - Documents')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Document Centre',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${b.clientName} • ${b.eventDetails}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (canUpload)
                  FilledButton.icon(
                    onPressed: loading ? null : uploadDocument,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Add Document'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : documents.isEmpty
                        ? const Center(
                            child: Text(
                              'No documents attached yet.\nAdd the application, signed contract, receipts, or correspondence here.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(14),
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('TYPE')),
                                DataColumn(label: Text('DOCUMENT')),
                                DataColumn(label: Text('DATE ADDED')),
                                DataColumn(label: Text('SIZE')),
                                DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: documents.map((doc) {
                                final type = doc['document_type']?.toString() ?? 'other';
                                return DataRow(cells: [
                                  DataCell(Chip(label: Text(documentTypes[type] ?? 'Document'))),
                                  DataCell(Text(doc['display_name']?.toString() ?? 'Document')),
                                  DataCell(Text(_dateTime(doc['uploaded_at'] ?? doc['generated_at']))),
                                  DataCell(Text(_size(doc['file_size']))),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => viewOrPrint(doc),
                                        icon: const Icon(Icons.visibility_outlined, size: 16),
                                        label: const Text('View / Print'),
                                      ),
                                      if (canDelete) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          tooltip: 'Remove document',
                                          onPressed: () => deleteDocument(doc),
                                          icon: const Icon(Icons.delete_outline),
                                        ),
                                      ],
                                    ],
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  String _dateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${date.month}/${date.day}/${date.year} $hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _size(dynamic value) {
    final bytes = (value as num?)?.toInt();
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
