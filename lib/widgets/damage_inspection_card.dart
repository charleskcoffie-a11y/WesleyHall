import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/wesley_models.dart';
import '../services/wesley_repository.dart';

class DamageInspectionCard extends StatefulWidget {
  const DamageInspectionCard({
    super.key,
    required this.booking,
    required this.repository,
    required this.onChanged,
  });

  final Booking booking;
  final WesleyRepository repository;
  final Future<void> Function() onChanged;

  @override
  State<DamageInspectionCard> createState() => _DamageInspectionCardState();
}

class _DamageInspectionCardState extends State<DamageInspectionCard> {
  late TextEditingController _notes;
  late TextEditingController _deduction;
  late String _outcome;
  late List<String> _photoPaths;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _syncFromBooking();
  }

  @override
  void didUpdateWidget(covariant DamageInspectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking.inspection?.id != widget.booking.inspection?.id ||
        oldWidget.booking.inspection?.completedAt !=
            widget.booking.inspection?.completedAt ||
        oldWidget.booking.status != widget.booking.status) {
      _notes.dispose();
      _deduction.dispose();
      _syncFromBooking();
    }
  }

  void _syncFromBooking() {
    final inspection = widget.booking.inspection;
    _outcome = inspection?.outcome ?? 'no_damage';
    _notes = TextEditingController(text: inspection?.notes ?? '');
    _deduction = TextEditingController(
      text: (inspection?.damageDeduction ?? 0).toStringAsFixed(2),
    );
    _photoPaths = List<String>.from(inspection?.photoPaths ?? const []);
  }

  @override
  void dispose() {
    _notes.dispose();
    _deduction.dispose();
    super.dispose();
  }

  double get _deductionValue {
    if (_outcome == 'no_damage') return 0;
    return double.tryParse(_deduction.text.trim()) ?? 0;
  }

  double get _availableDamageDeposit {
    final inspection = widget.booking.inspection;
    if (inspection?.isCompleted == true) {
      return inspection!.refundAmount + inspection.damageDeduction;
    }
    return widget.booking.damageDepositHeld;
  }

  double get _refundPreview {
    final value = _availableDamageDeposit - _deductionValue;
    return value > 0 ? value : 0;
  }

  DamageInspection _draftInspection({DateTime? completedAt}) {
    final current = widget.booking.inspection;
    return DamageInspection(
      id: current?.id ?? 'temp-${DateTime.now().microsecondsSinceEpoch}',
      bookingId: widget.booking.id,
      outcome: _outcome,
      notes: _notes.text.trim(),
      damageDeduction: _deductionValue,
      refundAmount: completedAt == null ? _refundPreview : _refundPreview,
      photoPaths: List<String>.from(_photoPaths),
      inspectedAt: current?.inspectedAt ?? DateTime.now(),
      completedAt: completedAt,
    );
  }

  Future<void> _saveDraft({bool showMessage = true}) async {
    if (_deductionValue < 0 || _deductionValue > _availableDamageDeposit) {
      _show('Damage deduction cannot be more than the damage deposit held.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.saveDamageInspection(_draftInspection());
      await widget.onChanged();
      if (mounted && showMessage) {
        _show('Inspection saved.');
      }
    } catch (e) {
      if (mounted) _show('Unable to save inspection: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeInspection() async {
    if (_deductionValue < 0 || _deductionValue > _availableDamageDeposit) {
      _show('Damage deduction cannot be more than the damage deposit held.');
      return;
    }
    if (_outcome == 'damage_found' && _notes.text.trim().isEmpty) {
      _show('Please describe the damage before completing the inspection.');
      return;
    }

    final refund = _refundPreview;
    final deduction = _deductionValue;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Booking?'),
        content: Text(
          _outcome == 'no_damage'
              ? 'No damage is recorded. A damage deposit refund of ${_money(refund)} will be recorded and the booking will be marked Completed.'
              : 'Damage deduction: ${_money(deduction)}\nRefund to client: ${_money(refund)}\n\nThe booking will be marked Completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete Booking'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await widget.repository.completeDamageInspection(
        inspection: _draftInspection(completedAt: DateTime.now()),
        refundAmount: refund,
      );
      await widget.onChanged();
      if (mounted) {
        _show('Inspection completed and booking marked Completed.');
      }
    } catch (e) {
      if (mounted) _show('Unable to complete booking: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markChurchUseCompleted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Church Activity?'),
        content: const Text(
          'This will mark the church-use reservation as Completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await widget.repository.updateBookingStatus(
        widget.booking.id,
        'completed',
      );
      await widget.onChanged();
      if (mounted) _show('Church activity marked Completed.');
    } catch (e) {
      if (mounted) _show('Unable to complete activity: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_busy || widget.booking.inspection?.isCompleted == true) return;
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2200,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final extension = _extensionFromName(file.name);
      await _uploadPhoto(bytes, extension);
    } catch (e) {
      if (mounted) {
        _show('Camera is not available here. Use Upload Photo instead.');
      }
    }
  }

  Future<void> _pickPhoto() async {
    if (_busy || widget.booking.inspection?.isCompleted == true) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        _show('Unable to read the selected photo.');
        return;
      }
      await _uploadPhoto(bytes, file.extension ?? 'jpg');
    } catch (e) {
      if (mounted) _show('Unable to upload photo: $e');
    }
  }

  Future<void> _uploadPhoto(Uint8List bytes, String extension) async {
    setState(() => _busy = true);
    try {
      final path = await widget.repository.uploadInspectionPhoto(
        widget.booking.id,
        bytes,
        extension,
      );
      _photoPaths.add(path);
      await widget.repository.saveDamageInspection(_draftInspection());
      await widget.onChanged();
      if (mounted) _show('Inspection photo attached.');
    } catch (e) {
      if (mounted) _show('Unable to attach photo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _extensionFromName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'jpg';
    final value = name.substring(dot + 1).toLowerCase();
    return value == 'jpeg' ? 'jpg' : value;
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    if (booking.isChurchUse) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.task_alt_outlined, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity Completion',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text('Close the church-use reservation after the activity.'),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _busy || booking.status == 'completed'
                    ? null
                    : _markChurchUseCompleted,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  booking.status == 'completed'
                      ? 'Completed'
                      : 'Mark Completed',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final inspection = booking.inspection;
    final completed = inspection?.isCompleted == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  completed
                      ? Icons.verified_outlined
                      : Icons.fact_check_outlined,
                  color: completed
                      ? const Color(0xFF16724F)
                      : Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Completion / Damage Inspection',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        completed
                            ? 'Inspection completed ${_dateTime(inspection!.completedAt!)}.'
                            : 'Inspect the hall, attach photos if needed, record any deduction, and close the booking.',
                      ),
                    ],
                  ),
                ),
                if (completed)
                  const Chip(
                    avatar: Icon(Icons.check, size: 17),
                    label: Text('COMPLETED'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('Damage Deposit Held', _availableDamageDeposit),
                _metric('Damage Deduction', _deductionValue),
                _metric(
                  completed ? 'Refund Recorded' : 'Refund Preview',
                  completed ? inspection!.refundAmount : _refundPreview,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'no_damage',
                  icon: Icon(Icons.check_circle_outline),
                  label: Text('No Damage'),
                ),
                ButtonSegment(
                  value: 'damage_found',
                  icon: Icon(Icons.warning_amber_outlined),
                  label: Text('Damage Found'),
                ),
              ],
              selected: {_outcome},
              onSelectionChanged: completed || _busy
                  ? null
                  : (value) {
                      setState(() {
                        _outcome = value.first;
                        if (_outcome == 'no_damage') {
                          _deduction.text = '0.00';
                        }
                      });
                    },
            ),
            const SizedBox(height: 14),
            if (_outcome == 'damage_found') ...[
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _deduction,
                  enabled: !completed && !_busy,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Damage Deduction (CAD)',
                    helperText:
                        'Maximum ${_money(_availableDamageDeposit)} currently held.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _notes,
              enabled: !completed && !_busy,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _outcome == 'damage_found'
                    ? 'Damage / Inspection Notes'
                    : 'Inspection Notes',
                hintText: _outcome == 'damage_found'
                    ? 'Describe the damage, location, and any action required.'
                    : 'Optional notes about the post-event inspection.',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Inspection Photos',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (!completed) ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _takePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Take Photo'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickPhoto,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload Photo'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (_photoPaths.isEmpty)
              const Text('No inspection photos attached.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(
                  _photoPaths.length,
                  (index) => _photoPreview(_photoPaths[index], index + 1),
                ),
              ),
            if (!completed) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _saveDraft,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Inspection'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _completeInspection,
                    icon: const Icon(Icons.task_alt_outlined),
                    label: Text(
                      _refundPreview > 0
                          ? 'Complete & Refund ${_money(_refundPreview)}'
                          : 'Complete Booking',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, double value) => Container(
        width: 205,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF8),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE2E9E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              _money(value),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );

  Widget _photoPreview(String path, int number) => FutureBuilder<Uint8List?>(
        future: widget.repository.loadInspectionPhoto(path),
        builder: (context, snapshot) {
          return Container(
            width: 150,
            height: 110,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDE5E1)),
            ),
            child: snapshot.hasData && snapshot.data != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(snapshot.data!, fit: BoxFit.cover),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 4),
                          color: Colors.black54,
                          child: Text(
                            'Photo $number',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator()),
          );
        },
      );

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  String _dateTime(DateTime value) {
    final h = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final ampm = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.month}/${value.day}/${value.year} $h:$minute $ampm';
  }
}
