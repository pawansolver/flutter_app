import 'dart:io' as dart_io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../models/event_model.dart';
import '../../../services/event_service.dart';

class EditEventSheet extends StatefulWidget {
  final EventModel event;
  final ValueChanged<EventModel> onEventUpdated;

  const EditEventSheet({
    super.key,
    required this.event,
    required this.onEventUpdated,
  });

  static void show(
    BuildContext context, {
    required EventModel event,
    required ValueChanged<EventModel> onEventUpdated,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => EditEventSheet(event: event, onEventUpdated: onEventUpdated),
    );
  }

  @override
  State<EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends State<EditEventSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _venueController;
  late final TextEditingController _addressController;
  late final TextEditingController _capacityController;

  final EventService _eventService = EventService();
  final ImagePicker _picker = ImagePicker();

  XFile? _pickedFile;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late String _eventType;
  int? _selectedCategoryId;
  List<EventCategoryModel> _categories = [];
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleController = TextEditingController(text: e.title);
    _descController = TextEditingController(text: e.description ?? '');
    _venueController = TextEditingController(text: e.locationName ?? e.location ?? '');
    _addressController = TextEditingController(text: e.address ?? '');
    _capacityController = TextEditingController(
      text: e.maxParticipants != null ? e.maxParticipants.toString() : '',
    );
    _startDate = e.startAt ?? DateTime.now().add(const Duration(days: 1));
    _startTime = e.startAt != null
        ? TimeOfDay(hour: e.startAt!.hour, minute: e.startAt!.minute)
        : const TimeOfDay(hour: 18, minute: 0);
    _eventType = e.eventType;
    _selectedCategoryId = e.categoryId;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _eventService.getEventCategories();
      if (mounted) setState(() { _categories = cats; _isLoadingCategories = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (picked != null && mounted) setState(() => _pickedFile = picked);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _startDate,
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final startAt = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute);

    int? maxParts;
    if (_capacityController.text.trim().isNotEmpty) {
      maxParts = int.tryParse(_capacityController.text.trim());
      if (maxParts == null || maxParts <= 0) {
        setState(() => _errorMessage = 'Max capacity must be a positive integer.');
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final updated = await _eventService.updateEvent(
        widget.event.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        categoryId: _selectedCategoryId,
        eventType: _eventType,
        startAt: startAt,
        location: _venueController.text.trim().isEmpty ? null : _venueController.text.trim(),
        locationName: _venueController.text.trim().isEmpty ? null : _venueController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        maxParticipants: maxParts,
        coverImageFile: (!kIsWeb && _pickedFile != null) ? dart_io.File(_pickedFile!.path) : null,
      );
      if (mounted) {
        widget.onEventUpdated(updated);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully!'), backgroundColor: Color(0xFF059669)),
        );
      }
    } catch (e) {
      if (mounted) setState(() { _isSubmitting = false; _errorMessage = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Edit Event', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                    IconButton(icon: const Icon(Icons.close, color: Color(0xFF6B7280)), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),

                // Cover image
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 130, width: double.infinity,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD1D5DB))),
                    clipBehavior: Clip.antiAlias,
                    child: _pickedFile != null
                        ? (!kIsWeb ? Image.file(dart_io.File(_pickedFile!.path), fit: BoxFit.cover) : Image.network(_pickedFile!.path, fit: BoxFit.cover))
                        : widget.event.coverImage != null
                            ? Stack(fit: StackFit.expand, children: [
                                Image.network(widget.event.coverImage!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40, color: Color(0xFF6B7280))),
                                Container(color: Colors.black26, child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit, color: Colors.white, size: 28), SizedBox(height: 4), Text('Tap to change cover', style: TextStyle(color: Colors.white, fontSize: 12))]))),
                              ])
                            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined, size: 36, color: Color(0xFF6B7280)), SizedBox(height: 6), Text('Add Cover Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)))]),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Event Title *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                  validator: (val) => (val == null || val.trim().length < 3) ? 'Title must be at least 3 characters' : null,
                ),
                const SizedBox(height: 12),

                // Category
                if (_isLoadingCategories)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
                else if (_categories.isNotEmpty)
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                    items: _categories.map((c) {
                      final icon = c.icon != null && c.icon!.isNotEmpty ? '${c.icon} ' : '';
                      return DropdownMenuItem<int>(value: c.id, child: Text('$icon${c.name}'.trim()));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                  ),
                const SizedBox(height: 12),

                // Event type
                const Text('Event Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                const SizedBox(height: 6),
                Row(children: [
                  _chip('offline', '📍 Offline'), const SizedBox(width: 8),
                  _chip('online', '💻 Online'), const SizedBox(width: 8),
                  _chip('hybrid', '🌐 Hybrid'),
                ]),
                const SizedBox(height: 16),

                // Date & Time
                Row(children: [
                  Expanded(child: InkWell(onTap: _pickDate, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: Color(0xFF2563EB)), const SizedBox(width: 8), Text(DateFormat('MMM dd, yyyy').format(_startDate), style: const TextStyle(fontWeight: FontWeight.w600))])))),
                  const SizedBox(width: 12),
                  Expanded(child: InkWell(onTap: _pickTime, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.access_time, size: 16, color: Color(0xFF2563EB)), const SizedBox(width: 8), Text(_startTime.format(context), style: const TextStyle(fontWeight: FontWeight.w600))])))),
                ]),
                const SizedBox(height: 12),

                // Venue
                TextFormField(
                  controller: _venueController,
                  decoration: InputDecoration(labelText: _eventType == 'online' ? 'Meeting Link / Platform' : 'Venue / Location Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                ),
                const SizedBox(height: 12),

                // Address
                if (_eventType != 'online') ...[
                  TextFormField(controller: _addressController, decoration: InputDecoration(labelText: 'Address Details (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white)),
                  const SizedBox(height: 12),
                ],

                // Capacity
                TextFormField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Max Capacity (optional)', hintText: 'Leave blank for unlimited', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descController, maxLines: 3,
                  decoration: InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                ),
                const SizedBox(height: 16),

                // Error
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFCA5A5))),
                    child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20), const SizedBox(width: 8), Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w600)))]),
                  ),

                // Save
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String type, String label) {
    final isSelected = _eventType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _eventType = type),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB)),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF4B5563)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
