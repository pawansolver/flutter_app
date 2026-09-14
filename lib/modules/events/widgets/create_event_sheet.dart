import 'dart:io' as dart_io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../models/event_model.dart';
import '../../../services/event_service.dart';

class CreateEventSheet extends StatefulWidget {
  final int? communityId;
  final int? societyId;
  final ValueChanged<EventModel> onEventCreated;

  const CreateEventSheet({
    super.key,
    this.communityId,
    this.societyId,
    required this.onEventCreated,
  });

  static void show(
    BuildContext context, {
    int? communityId,
    int? societyId,
    required ValueChanged<EventModel> onEventCreated,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CreateEventSheet(
        communityId: communityId,
        societyId: societyId,
        onEventCreated: onEventCreated,
      ),
    );
  }

  @override
  State<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<CreateEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _venueController = TextEditingController();
  final _addressController = TextEditingController();
  final _capacityController = TextEditingController();
  final _speakerController = TextEditingController();

  final EventService _eventService = EventService();
  final ImagePicker _picker = ImagePicker();

  XFile? _pickedFile;  // Cross-platform: works on both web and native
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);
  String _eventType = 'offline'; // offline, online, hybrid
  String _visibility = 'public'; // public, community, private
  bool _registrationRequired = false;
  int? _selectedCategoryId;
  List<EventCategoryModel> _categories = [];
  final List<SubEventModel> _subEvents = [];
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.societyId != null || widget.communityId != null) {
      _visibility = 'community';
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _eventService.getEventCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _isLoadingCategories = false;
          if (cats.isNotEmpty) {
            _selectedCategoryId = cats.first.id;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    _speakerController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _pickedFile = picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final startAt = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endAt = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (startAt.isBefore(DateTime.now())) {
      setState(() => _errorMessage = 'Start date/time must be in the future.');
      return;
    }

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
      final created = await _eventService.createEvent(
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        categoryId: _selectedCategoryId,
        communityId: widget.communityId,
        societyId: widget.societyId,
        eventType: _eventType,
        visibility: _visibility,
        startAt: startAt,
        endAt: endAt.isAfter(startAt) ? endAt : null,
        location: _eventType == 'online'
            ? (_venueController.text.trim().isEmpty ? 'Online' : _venueController.text.trim())
            : (_venueController.text.trim().isEmpty ? null : _venueController.text.trim()),
        locationName: _eventType == 'online'
            ? (_venueController.text.trim().isEmpty ? 'Online Event' : _venueController.text.trim())
            : (_venueController.text.trim().isEmpty ? null : _venueController.text.trim()),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        maxParticipants: maxParts,
        speakerOrHost: _speakerController.text.trim().isEmpty ? null : _speakerController.text.trim(),
        isRegistrationRequired: _registrationRequired,
        subEvents: _subEvents.isEmpty ? null : _subEvents,
        // On web: no dart:io File support — skip image upload.
        // On native: convert XFile path to dart:io File.
        coverImageFile: (!kIsWeb && _pickedFile != null)
            ? dart_io.File(_pickedFile!.path)
            : null,
      );

      if (mounted) {
        widget.onEventCreated(created);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Event created successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? 'Failed to create event'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create New Event',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Cover Image Picker
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _pickedFile == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 36, color: Color(0xFF6B7280)),
                              SizedBox(height: 6),
                              Text(
                                'Add Event Cover Image',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          )
                        : kIsWeb
                            // Web: use Image.network with XFile's network URL
                            ? Image.network(
                                _pickedFile!.path,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 140,
                                errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, size: 40, color: Color(0xFF6B7280)),
                              )
                            // Native (Android / iOS): use dart:io FileImage
                            : Image.file(
                                dart_io.File(_pickedFile!.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 140,
                              ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Event Title *',
                    hintText: 'e.g. Weekend Badminton Tournament',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 3) {
                      return 'Please enter a valid title (min 3 characters)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Category Dropdown
                if (_isLoadingCategories)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (_categories.isNotEmpty)
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _categories.map((c) {
                      final iconText = c.icon != null && c.icon!.isNotEmpty ? '${c.icon} ' : '';
                      return DropdownMenuItem<int>(
                        value: c.id,
                        child: Text('$iconText${c.name}'.trim()),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                  ),
                const SizedBox(height: 12),

                // Event Type Selector
                const Text('Event Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildTypeChip('offline', '📍 Offline / In-person'),
                    const SizedBox(width: 8),
                    _buildTypeChip('online', '💻 Online'),
                    const SizedBox(width: 8),
                    _buildTypeChip('hybrid', '🌐 Hybrid'),
                  ],
                ),
                const SizedBox(height: 16),

                // Visibility Selector
                const Text('Visibility', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildVisibilityChip('public', '🌐 Public'),
                    const SizedBox(width: 8),
                    _buildVisibilityChip('community', '👥 Community/Society'),
                    const SizedBox(width: 8),
                    _buildVisibilityChip('private', '🔒 Private'),
                  ],
                ),
                const SizedBox(height: 16),

                // Date & Time Pickers (Start & End Time)
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFD1D5DB)),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 15, color: Color(0xFFF18D38)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  DateFormat('MMM dd, yyyy').format(_startDate),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFD1D5DB)),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 15, color: Color(0xFFF18D38)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _startTime.format(context),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _pickEndTime,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFD1D5DB)),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_filled, size: 15, color: Color(0xFF6B7280)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _endTime.format(context),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Venue & Host / Speaker (Same as Sub-Event)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _venueController,
                        decoration: InputDecoration(
                          labelText: _eventType == 'online' ? 'Meeting Link / Platform *' : 'Venue / Location *',
                          hintText: _eventType == 'online' ? 'e.g. Zoom / Meet Link' : 'e.g. Club House',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter venue / location';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _speakerController,
                        decoration: InputDecoration(
                          labelText: 'Host / Speaker (optional)',
                          hintText: 'e.g. Dr. Sharma, Coach',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Address Details (if not online)
                if (_eventType != 'online') ...[
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Address Details (optional)',
                      hintText: 'e.g. Sector 62, Block B Ground',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Capacity & Registration Required Toggle (Same as Sub-Event)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _capacityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Capacity (spots)',
                          hintText: 'e.g. 100 (optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final n = int.tryParse(val.trim());
                            if (n == null || n <= 0) {
                              return 'Please enter a valid positive number';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Registration\nRequired',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                            ),
                            Switch(
                              value: _registrationRequired,
                              activeThumbColor: const Color(0xFFF18D38),
                              onChanged: (v) => setState(() => _registrationRequired = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description / Guidelines (optional)',
                    hintText: 'Details, agenda, requirements...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Enterprise Event Schedule & Sub-Events Builder ──
                _buildSubEventsSection(),
                const SizedBox(height: 8),

                // Inline Error Banner
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF18D38),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Publish Event',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
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

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _eventType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _eventType = type),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF4EC) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFF18D38) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFFF18D38) : const Color(0xFF4B5563),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityChip(String vis, String label) {
    final isSelected = _visibility == vis;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _visibility = vis),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF4EC) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFF18D38) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFFF18D38) : const Color(0xFF4B5563),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  void _openSubEventDialog([int? editIndex]) {
    final isEditing = editIndex != null;
    final existing = isEditing ? _subEvents[editIndex] : null;

    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final venueCtrl = TextEditingController(text: existing?.venue ?? _venueController.text.trim());
    final addressCtrl = TextEditingController(text: existing?.address ?? _addressController.text.trim());
    final speakerCtrl = TextEditingController(text: existing?.speakerOrHost ?? _speakerController.text.trim());
    final capacityCtrl = TextEditingController(text: existing?.capacity != null ? existing!.capacity.toString() : '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String selectedType = existing?.activityType ?? 'general';
    String subEventType = existing?.eventType ?? _eventType;
    bool registrationRequired = existing?.isRegistrationRequired ?? false;
    String selectedDate = existing?.date ??
        '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
    String startTime = existing?.startTime ?? _startTime.format(context);
    String endTime = existing?.endTime ?? _endTime.format(context);
    XFile? pickedSubFile;
    String? existingCoverImage = existing?.coverImage;
    String? localImagePath = existing?.localImagePath;

    final activityTypes = const [
      {'key': 'general', 'label': 'General', 'icon': Icons.stars_outlined},
      {'key': 'sports', 'label': 'Sports', 'icon': Icons.sports_soccer_outlined},
      {'key': 'competition', 'label': 'Competition', 'icon': Icons.emoji_events_outlined},
      {'key': 'ceremony', 'label': 'Ceremony', 'icon': Icons.military_tech_outlined},
      {'key': 'cultural', 'label': 'Cultural', 'icon': Icons.theater_comedy_outlined},
      {'key': 'dining', 'label': 'Food / Dining', 'icon': Icons.restaurant_outlined},
      {'key': 'workshop', 'label': 'Workshop', 'icon': Icons.psychology_outlined},
      {'key': 'meeting', 'label': 'Meeting', 'icon': Icons.groups_outlined},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Enterprise Activity' : 'Add Enterprise Activity',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Activity Banner / Poster Picker (Optional) ──
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (picked != null) {
                      setModalState(() {
                        pickedSubFile = picked;
                        localImagePath = picked.path;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (pickedSubFile != null || (localImagePath != null && localImagePath!.isNotEmpty))
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              kIsWeb
                                  ? Image.network(localImagePath ?? pickedSubFile!.path, fit: BoxFit.cover)
                                  : Image.file(dart_io.File(localImagePath ?? pickedSubFile!.path), fit: BoxFit.cover),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => setModalState(() {
                                    pickedSubFile = null;
                                    localImagePath = null;
                                    existingCoverImage = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : (existingCoverImage != null && existingCoverImage!.isNotEmpty)
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    existingCoverImage!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () => setModalState(() {
                                        existingCoverImage = null;
                                        localImagePath = null;
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 22, color: Color(0xFFF18D38)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add Activity Banner / Poster (Optional)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 12),

                // 1. Activity Title
                TextFormField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Activity / Session Title *',
                    hintText: 'e.g. Cricket Finals, Lamp Lighting, Grand Dinner',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Activity Type Chips
                const Text(
                  'Activity Type',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: activityTypes.map((t) {
                      final isSelected = selectedType == t['key'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(
                            t['icon'] as IconData,
                            size: 14,
                            color: isSelected ? Colors.white : const Color(0xFFF18D38),
                          ),
                          label: Text(t['label'] as String),
                          selected: isSelected,
                          selectedColor: const Color(0xFFF18D38),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF374151),
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => selectedType = t['key'] as String);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Event Mode (Same as Main Event)
                const Text(
                  'Event Mode',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildModeChip('offline', '📍 Offline', subEventType, (v) => setModalState(() => subEventType = v)),
                    const SizedBox(width: 8),
                    _buildModeChip('online', '💻 Online', subEventType, (v) => setModalState(() => subEventType = v)),
                    const SizedBox(width: 8),
                    _buildModeChip('hybrid', '🌐 Hybrid', subEventType, (v) => setModalState(() => subEventType = v)),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. Timings (Start & End Time)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: modalCtx,
                            initialTime: const TimeOfDay(hour: 10, minute: 0),
                          );
                          if (t != null) {
                            setModalState(() => startTime = t.format(modalCtx));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFD1D5DB)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 18, color: Color(0xFFF18D38)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  startTime.isEmpty ? 'Start Time' : startTime,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: modalCtx,
                            initialTime: const TimeOfDay(hour: 12, minute: 0),
                          );
                          if (t != null) {
                            setModalState(() => endTime = t.format(modalCtx));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFD1D5DB)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_filled, size: 18, color: Color(0xFF6B7280)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  endTime.isEmpty ? 'End Time' : endTime,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. Venue & Host / Speaker (Same as Main Event)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: venueCtrl,
                        decoration: InputDecoration(
                          labelText: subEventType == 'online' ? 'Link / Platform *' : 'Venue / Stage *',
                          hintText: subEventType == 'online' ? 'e.g. Zoom Link' : 'e.g. Auditorium',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: speakerCtrl,
                        decoration: InputDecoration(
                          labelText: 'Host / Speaker (optional)',
                          hintText: 'e.g. Dr. Sharma',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 6. Address / Location Details (if not online)
                if (subEventType != 'online') ...[
                  TextFormField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Address / Location Details (optional)',
                      hintText: 'e.g. Ground Floor, Block A',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 7. Capacity & Registration Toggle (Same as Main Event)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: capacityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Capacity (spots)',
                          hintText: 'e.g. 50 (optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Registration\nRequired',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                            ),
                            Switch(
                              value: registrationRequired,
                              activeThumbColor: const Color(0xFFF18D38),
                              onChanged: (v) => setModalState(() => registrationRequired = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 8. Description / Rules / Guidelines
                TextFormField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description / Guidelines / Rules',
                    hintText: 'Details, requirements, or schedule sequence',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF18D38),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty) return;
                      final sub = SubEventModel(
                        id: isEditing ? existing!.id : 'sub_${DateTime.now().millisecondsSinceEpoch}',
                        title: titleCtrl.text.trim(),
                        date: selectedDate,
                        startTime: startTime.isEmpty ? null : startTime,
                        endTime: endTime.isEmpty ? null : endTime,
                        venue: venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim(),
                        location: venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim(),
                        address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                        eventType: subEventType,
                        speakerOrHost: speakerCtrl.text.trim().isEmpty ? null : speakerCtrl.text.trim(),
                        activityType: selectedType,
                        capacity: int.tryParse(capacityCtrl.text.trim()),
                        isRegistrationRequired: registrationRequired,
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        coverImage: existingCoverImage,
                        localImagePath: localImagePath,
                      );
                      setState(() {
                        if (isEditing) {
                          _subEvents[editIndex] = sub;
                        } else {
                          _subEvents.add(sub);
                        }
                      });
                      Navigator.pop(modalCtx);
                    },
                    label: Text(
                      isEditing ? 'Update Activity' : 'Save Activity',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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

  Widget _buildModeChip(String type, String label, String currentType, ValueChanged<String> onSelected) {
    final isSelected = currentType == type;
    return InkWell(
      onTap: () => onSelected(type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF18D38) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildSubEventsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.format_list_bulleted, color: Color(0xFFF18D38), size: 18),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'Schedule & Sub-Events',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_subEvents.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4EC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFCB99)),
                        ),
                        child: Text(
                          '${_subEvents.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openSubEventDialog(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4EC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF18D38)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 15, color: Color(0xFFF18D38)),
                      SizedBox(width: 3),
                      Text(
                        'Add Activity',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFF18D38)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Schedule multiple sessions, matches, ceremonies or performances inside this event.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          if (_subEvents.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._subEvents.asMap().entries.map((entry) {
              final idx = entry.key;
              final sub = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sub.localImagePath != null && sub.localImagePath!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: kIsWeb
                            ? Image.network(sub.localImagePath!, width: 42, height: 42, fit: BoxFit.cover)
                            : Image.file(dart_io.File(sub.localImagePath!), width: 42, height: 42, fit: BoxFit.cover),
                      )
                    else if (sub.coverImage != null && sub.coverImage!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          sub.coverImage!,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFFF18D38),
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFFF18D38),
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sub.title,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                                ),
                              ),
                              if (sub.activityType.isNotEmpty && sub.activityType != 'general')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    sub.activityType.toUpperCase(),
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (sub.startTime != null && sub.startTime!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFD1D5DB)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time, size: 11, color: Color(0xFFF18D38)),
                                      const SizedBox(width: 3),
                                      Text(
                                        sub.endTime != null && sub.endTime!.isNotEmpty
                                            ? '${sub.startTime} - ${sub.endTime}'
                                            : sub.startTime!,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                                      ),
                                    ],
                                  ),
                                ),
                              if (sub.venue != null && sub.venue!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFD1D5DB)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF6B7280)),
                                      const SizedBox(width: 3),
                                      Text(
                                        sub.venue!,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                                      ),
                                    ],
                                  ),
                                ),
                              if (sub.speakerOrHost != null && sub.speakerOrHost!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFD1D5DB)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_outline, size: 11, color: Color(0xFF059669)),
                                      const SizedBox(width: 3),
                                      Text(
                                        sub.speakerOrHost!,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF059669)),
                                      ),
                                    ],
                                  ),
                                ),
                              if (sub.isRegistrationRequired)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Text(
                                    'Reg. Required',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                                  ),
                                ),
                              if (sub.capacity != null && sub.capacity! > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFD1D5DB)),
                                  ),
                                  child: Text(
                                    '${sub.capacity} Spots',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF4B5563)),
                                  ),
                                ),
                            ],
                          ),
                          if (sub.description != null && sub.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              sub.description!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6B7280)),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      onPressed: () => _openSubEventDialog(idx),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      onPressed: () => setState(() => _subEvents.removeAt(idx)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
