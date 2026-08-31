import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/community_models.dart';
import '../../../services/community_service.dart';

class UploadDocumentSheet extends StatefulWidget {
  final int communityId;
  final Function(CommunityDocumentModel newDoc) onDocumentUploaded;

  const UploadDocumentSheet({
    super.key,
    required this.communityId,
    required this.onDocumentUploaded,
  });

  static void show(
    BuildContext context, {
    required int communityId,
    required Function(CommunityDocumentModel newDoc) onDocumentUploaded,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UploadDocumentSheet(
        communityId: communityId,
        onDocumentUploaded: onDocumentUploaded,
      ),
    );
  }

  @override
  State<UploadDocumentSheet> createState() => _UploadDocumentSheetState();
}

class _UploadDocumentSheetState extends State<UploadDocumentSheet> {
  final TextEditingController _titleController = TextEditingController();
  String _fileType = 'pdf';
  // Enterprise fix: Store bytes instead of path for cross-platform compatibility.
  // On Flutter Web, dart:io is unavailable and file paths are blob URLs.
  // FilePicker provides `bytes` field which works on ALL platforms.
  List<int>? _fileBytes;
  String? _fileName;
  int? _fileSizeBytes;
  bool _isUploading = false;
  final CommunityService _service = CommunityService();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    // file_picker v12: use FilePicker.pickFiles() static method directly.
    // PlatformFile.readAsBytes() works on ALL platforms (web + mobile + desktop).
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
    );
    final file = files.firstOrNull;
    if (file == null) return;

    // readAsBytes() is the v12 recommended cross-platform approach
    final bytes = await file.readAsBytes();
    // PlatformFile.length() returns file size in bytes (async in v12)
    final sizeInBytes = await file.length();

    if (mounted) {
      setState(() {
        _fileBytes = bytes;
        _fileName = file.name;
        _fileSizeBytes = sizeInBytes;
        _fileType = file.extension?.toLowerCase() ?? 'pdf';
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = file.name;
        }
      });
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a document title')),
      );
      return;
    }
    if (_fileBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please choose a document')));
      return;
    }

    setState(() => _isUploading = true);
    try {
      final sizeMB = _fileSizeBytes != null
          ? '${(_fileSizeBytes! / 1048576).toStringAsFixed(2)} MB'
          : '0 MB';
      final newDoc = await _service.uploadDocumentBytes(
        widget.communityId,
        title: title,
        fileBytes: _fileBytes!,
        fileName: _fileName ?? 'document',
        fileType: _fileType,
        fileSize: sizeMB,
      );
      widget.onDocumentUploaded(newDoc);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document published to community files!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  color: primaryOrange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Upload Community Document',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title Field
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'e.g. Society_Bylaws_2026 or Match_Rules',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryOrange),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isUploading ? null : _pickDocument,
            icon: const Icon(Icons.attach_file),
            label: Text(_fileName ?? 'Choose document'),
          ),
          const SizedBox(height: 16),

          // File Type Chips
          const Text(
            'DOCUMENT TYPE',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTypeChip(
                'pdf',
                'PDF Document',
                Icons.picture_as_pdf_rounded,
                const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              _buildTypeChip(
                'doc',
                'Word Doc',
                Icons.description_rounded,
                const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              _buildTypeChip(
                'xls',
                'Excel Sheet',
                Icons.table_chart_rounded,
                const Color(0xFF10B981),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Upload Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Publish Document',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon, Color color) {
    final isSelected = _fileType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _fileType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE5E7EB),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : const Color(0xFF4B5563),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
