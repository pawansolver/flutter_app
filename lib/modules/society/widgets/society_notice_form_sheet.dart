import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/society_models.dart';
import '../../../services/society_service.dart';

class _C {
  static const text = Color(0xFF111827);
  static const sub = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const orange = Color(0xFFFF6B00);
}

class SocietyNoticeFormSheet extends StatefulWidget {
  final int societyId;
  final SocietyAnnouncementModel? initialAnnouncement;
  final void Function(SocietyAnnouncementModel) onSuccess;

  const SocietyNoticeFormSheet({
    super.key,
    required this.societyId,
    this.initialAnnouncement,
    required this.onSuccess,
  });

  static Future<void> show({
    required BuildContext context,
    required int societyId,
    SocietyAnnouncementModel? initialAnnouncement,
    required void Function(SocietyAnnouncementModel) onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SocietyNoticeFormSheet(
        societyId: societyId,
        initialAnnouncement: initialAnnouncement,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<SocietyNoticeFormSheet> createState() => _SocietyNoticeFormSheetState();
}

class _SocietyNoticeFormSheetState extends State<SocietyNoticeFormSheet> {
  final SocietyService _societyService = SocietyService();

  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _messageController;
  late final TextEditingController _actionTextController;

  late String _category;
  late String _priority;
  late String _audience;
  late bool _isPinned;

  bool _isScheduled = false;
  DateTime? _publishDate;
  TimeOfDay? _publishTime;

  bool _hasExpiry = false;
  DateTime? _expiryDate;
  TimeOfDay? _expiryTime;

  List<Map<String, dynamic>> _uploadedAttachments = [];
  bool _isUploadingFile = false;
  bool _isSaving = false;

  bool get _isEditMode => widget.initialAnnouncement != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initialAnnouncement;

    _titleController = TextEditingController(text: init?.title ?? '');
    _summaryController = TextEditingController(text: init?.summary ?? '');
    _messageController = TextEditingController(text: init?.message ?? '');
    _actionTextController = TextEditingController(text: init?.actionText ?? '');

    _category = init?.category ?? 'general';
    _priority = init?.priority ?? 'medium';
    _audience = init?.audience ?? 'entire_society';
    _isPinned = init?.isPinned ?? false;

    if (init?.publishAt != null) {
      _isScheduled = true;
      _publishDate = init!.publishAt;
      _publishTime = TimeOfDay.fromDateTime(init.publishAt!);
    }

    if (init?.expiresAt != null) {
      _hasExpiry = true;
      _expiryDate = init!.expiresAt;
      _expiryTime = TimeOfDay.fromDateTime(init.expiresAt!);
    }

    if (init?.attachments != null && init!.attachments.isNotEmpty) {
      _uploadedAttachments = init.attachments.map((a) => a.toJson()).toList();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _messageController.dispose();
    _actionTextController.dispose();
    super.dispose();
  }

  Future<void> _handleAttachFile() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Add Notice Attachment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _C.text),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _C.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: _C.orange),
                ),
                title: const Text('Choose Photo / Image', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Upload PNG, JPG, JPEG from gallery', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(sheetCtx, 'gallery'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Colors.blue),
                ),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Capture notice photo using camera', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(sheetCtx, 'camera'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.purple),
                ),
                title: const Text('Upload Document / PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Official circular, PDF, DOCX, XLS', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(sheetCtx, 'document'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null) return;

    try {
      List<int>? fileBytes;
      String? filePath;
      String? fileName;

      if (choice == 'gallery' || choice == 'camera') {
        final picker = ImagePicker();
        final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
        final xfile = await picker.pickImage(source: source, imageQuality: 85);
        if (xfile == null) return;
        fileBytes = await xfile.readAsBytes();
        filePath = xfile.path;
        fileName = xfile.name.isNotEmpty ? xfile.name : 'notice_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else if (choice == 'document') {
        final res = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'png', 'jpg', 'jpeg'],
        );
        final file = res.firstOrNull;
        if (file == null) return;
        fileBytes = await file.readAsBytes();
        filePath = file.path;
        fileName = file.name;
      }

      if (fileBytes == null && filePath == null) return;

      setState(() => _isUploadingFile = true);

      final uploaded = await _societyService.uploadAnnouncementAttachment(
        widget.societyId,
        fileBytes: fileBytes,
        filePath: filePath,
        fileName: fileName,
      );

      if (mounted) {
        setState(() {
          _uploadedAttachments.add(uploaded.toJson());
          _isUploadingFile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attached "$fileName" successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingFile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  DateTime? _resolvePublishAt() {
    if (_isScheduled && _publishDate != null) {
      return DateTime(
        _publishDate!.year,
        _publishDate!.month,
        _publishDate!.day,
        _publishTime?.hour ?? 0,
        _publishTime?.minute ?? 0,
      );
    }
    return null;
  }

  DateTime? _resolveExpiresAt() {
    if (_hasExpiry && _expiryDate != null) {
      return DateTime(
        _expiryDate!.year,
        _expiryDate!.month,
        _expiryDate!.day,
        _expiryTime?.hour ?? 23,
        _expiryTime?.minute ?? 59,
      );
    }
    return null;
  }

  Future<void> _submitEdit() async {
    final title = _titleController.text.trim();
    final msg = _messageController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a notice title.')));
      return;
    }
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter notice message.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'title': title,
        'summary': _summaryController.text.trim().isNotEmpty ? _summaryController.text.trim() : null,
        'message': msg,
        'action_text': _actionTextController.text.trim().isNotEmpty ? _actionTextController.text.trim() : null,
        'category': _category,
        'priority': _priority,
        'audience': _audience,
        'is_pinned': _isPinned,
        'publish_at': _resolvePublishAt()?.toIso8601String(),
        'expires_at': _resolveExpiresAt()?.toIso8601String(),
        'attachments': _uploadedAttachments,
      };

      final updated = await _societyService.updateAnnouncement(
        widget.initialAnnouncement!.id,
        widget.societyId,
        payload,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice updated successfully!'), backgroundColor: Color(0xFF10B981)),
        );
        widget.onSuccess(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openPreviewDialog() {
    final title = _titleController.text.trim();
    final msg = _messageController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a notice title.')));
      return;
    }
    if (title.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notice title must be at least 3 characters.')));
      return;
    }
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter notice body message.')));
      return;
    }

    final resolvedPublishAt = _resolvePublishAt();
    final resolvedExpiresAt = _resolveExpiresAt();

    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.campaign, color: _C.orange, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('OFFICIAL SOCIETY NOTICE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _C.orange)),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _C.text)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                          child: Text(_category.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _C.sub)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                          child: Text(_priority.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                        ),
                        if (_isPinned) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.push_pin, size: 14, color: _C.orange),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(msg, style: const TextStyle(fontSize: 13, height: 1.5, color: _C.text)),
                    if (_actionTextController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _actionTextController.text.trim(),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_uploadedAttachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('${_uploadedAttachments.length} file attachment${_uploadedAttachments.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _C.sub)),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      resolvedPublishAt != null
                          ? 'Publish Schedule: ${resolvedPublishAt.day}/${resolvedPublishAt.month}/${resolvedPublishAt.year}'
                          : 'Publish Mode: Immediate',
                      style: const TextStyle(fontSize: 11, color: _C.sub),
                    ),
                    if (resolvedExpiresAt != null)
                      Text(
                        'Expires: ${resolvedExpiresAt.day}/${resolvedExpiresAt.month}/${resolvedExpiresAt.year}',
                        style: const TextStyle(fontSize: 11, color: _C.sub),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Back to Edit'),
              ),
              OutlinedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          final created = await _societyService.createAnnouncement(
                            widget.societyId,
                            title: title,
                            summary: _summaryController.text.trim().isNotEmpty ? _summaryController.text.trim() : null,
                            message: msg,
                            actionText: _actionTextController.text.trim().isNotEmpty ? _actionTextController.text.trim() : null,
                            category: _category,
                            priority: _priority,
                            audience: _audience,
                            isPinned: _isPinned,
                            status: 'draft',
                            publishAt: resolvedPublishAt,
                            expiresAt: resolvedExpiresAt,
                            attachments: _uploadedAttachments.isNotEmpty ? _uploadedAttachments : null,
                          );
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Notice saved as draft!'), backgroundColor: Color(0xFF10B981)),
                            );
                            widget.onSuccess(created);
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(SnackBar(content: Text('Failed to save draft: ${e.toString()}'), backgroundColor: Colors.red));
                          }
                        }
                      },
                child: const Text('Save Draft'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _C.orange),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          final created = await _societyService.createAnnouncement(
                            widget.societyId,
                            title: title,
                            summary: _summaryController.text.trim().isNotEmpty ? _summaryController.text.trim() : null,
                            message: msg,
                            actionText: _actionTextController.text.trim().isNotEmpty ? _actionTextController.text.trim() : null,
                            category: _category,
                            priority: _priority,
                            audience: _audience,
                            isPinned: _isPinned,
                            status: 'published',
                            publishAt: resolvedPublishAt,
                            expiresAt: resolvedExpiresAt,
                            attachments: _uploadedAttachments.isNotEmpty ? _uploadedAttachments : null,
                          );
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Notice published successfully!'), backgroundColor: Color(0xFF10B981)),
                            );
                            widget.onSuccess(created);
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(SnackBar(content: Text('Publish failed: ${e.toString()}'), backgroundColor: Colors.red));
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Publish Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditMode ? 'Edit Society Notice' : 'Create Society Notice',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _C.text),
                    ),
                    Text(
                      _isEditMode
                          ? (widget.initialAnnouncement?.announcementNumber.isNotEmpty == true
                              ? widget.initialAnnouncement!.announcementNumber
                              : 'Update Official Notice')
                          : 'Enterprise Notice Management',
                      style: const TextStyle(fontSize: 11, color: _C.sub),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Scrollable Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NOTICE DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _C.sub, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Notice Title *',
                      hintText: 'e.g., Annual General Body Meeting 2026',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _summaryController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Short Summary / Overview (Optional)',
                      hintText: 'Appears on notice cards and mobile push previews...',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category & Priority
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: InputDecoration(
                            labelText: 'Category *',
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'general', child: Text('General')),
                            DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                            DropdownMenuItem(value: 'security', child: Text('Security')),
                            DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
                            DropdownMenuItem(value: 'event', child: Text('Event')),
                            DropdownMenuItem(value: 'finance', child: Text('Finance')),
                            DropdownMenuItem(value: 'rules_notice', child: Text('Rules & Notice')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _category = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _priority,
                          decoration: InputDecoration(
                            labelText: 'Priority *',
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'high', child: Text('High')),
                            DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _priority = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Content & Action Text
                  const Text('NOTICE CONTENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _C.sub, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Full Notice Message *',
                      hintText: 'Detailed announcement text for society members...',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _actionTextController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Important Instructions / Action Text (Optional)',
                      hintText: 'e.g., Please submit the nomination form before 5 PM...',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Audience
                  const Text('VISIBILITY & AUDIENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _C.sub, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _audience,
                    decoration: InputDecoration(
                      labelText: 'Target Audience',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'entire_society', child: Text('Entire Society (All Members)')),
                      DropdownMenuItem(value: 'committee', child: Text('Management Committee Only')),
                      DropdownMenuItem(value: 'block', child: Text('Block / Wing Specific')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _audience = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Publishing & Expiry
                  const Text('PUBLISHING & EXPIRY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _C.sub, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: _C.orange,
                    title: const Text('Schedule for Later', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _isScheduled && _publishDate != null
                          ? 'Publish on ${_publishDate!.day}/${_publishDate!.month}/${_publishDate!.year} at ${_publishTime?.format(context) ?? '00:00'}'
                          : 'Publish immediately upon submit',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _isScheduled,
                    onChanged: (val) async {
                      if (val) {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(hours: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null && context.mounted) {
                          final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          setState(() {
                            _isScheduled = true;
                            _publishDate = picked;
                            _publishTime = time;
                          });
                        }
                      } else {
                        setState(() {
                          _isScheduled = false;
                          _publishDate = null;
                          _publishTime = null;
                        });
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: _C.orange,
                    title: const Text('Set Expiry Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _hasExpiry && _expiryDate != null
                          ? 'Notice expires on ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                          : 'Notice will remain indefinitely in the active feed',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _hasExpiry,
                    onChanged: (val) async {
                      if (val) {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked != null && context.mounted) {
                          final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 23, minute: 59));
                          setState(() {
                            _hasExpiry = true;
                            _expiryDate = picked;
                            _expiryTime = time;
                          });
                        }
                      } else {
                        setState(() {
                          _hasExpiry = false;
                          _expiryDate = null;
                          _expiryTime = null;
                        });
                      }
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: _C.orange,
                    title: const Text('Pin this notice to top of feed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    value: _isPinned,
                    onChanged: (val) => setState(() => _isPinned = val ?? false),
                  ),
                  const SizedBox(height: 16),

                  // Attachments Section
                  const Text('ATTACHMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _C.sub, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isUploadingFile ? null : _handleAttachFile,
                    icon: _isUploadingFile
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.attach_file),
                    label: Text(_isUploadingFile ? 'Uploading attachment...' : 'Attach PDF / Image / Document'),
                  ),
                  if (_uploadedAttachments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._uploadedAttachments.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final att = entry.value;
                      final name = att['file_name']?.toString() ?? 'Attachment';
                      final isImg = name.toLowerCase().endsWith('.png') ||
                          name.toLowerCase().endsWith('.jpg') ||
                          name.toLowerCase().endsWith('.jpeg') ||
                          name.toLowerCase().endsWith('.webp') ||
                          (att['file_type']?.toString().contains('image') ?? false);
                      final size = att['file_size'];
                      String sizeStr = '';
                      if (size is int && size > 0) {
                        if (size < 1024) {
                          sizeStr = '$size B';
                        } else if (size < 1024 * 1024) {
                          sizeStr = '${(size / 1024).toStringAsFixed(1)} KB';
                        } else {
                          sizeStr = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _C.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isImg ? _C.orange.withValues(alpha: 0.1) : Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                isImg ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
                                size: 20,
                                color: isImg ? _C.orange : Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.text),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (sizeStr.isNotEmpty)
                                    Text(
                                      sizeStr,
                                      style: const TextStyle(fontSize: 11, color: _C.sub),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              tooltip: 'Remove',
                              onPressed: () {
                                setState(() => _uploadedAttachments.removeAt(idx));
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _C.border)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_isEditMode ? Icons.check_circle_outline : Icons.visibility_outlined, color: Colors.white),
                label: Text(
                  _isEditMode
                      ? (_isSaving ? 'Saving Changes...' : 'Save Notice Changes')
                      : 'Preview Official Notice',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: _isSaving ? null : (_isEditMode ? _submitEdit : _openPreviewDialog),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
