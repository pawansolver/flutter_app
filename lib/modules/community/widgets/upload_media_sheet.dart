import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/community_models.dart';
import '../../../services/community_service.dart';

class UploadMediaSheet extends StatefulWidget {
  final int communityId;
  final Function(CommunityMediaModel newMedia) onMediaUploaded;

  const UploadMediaSheet({
    super.key,
    required this.communityId,
    required this.onMediaUploaded,
  });

  static void show(
    BuildContext context, {
    required int communityId,
    required Function(CommunityMediaModel newMedia) onMediaUploaded,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UploadMediaSheet(
        communityId: communityId,
        onMediaUploaded: onMediaUploaded,
      ),
    );
  }

  @override
  State<UploadMediaSheet> createState() => _UploadMediaSheetState();
}

class _UploadMediaSheetState extends State<UploadMediaSheet> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final CommunityService _service = CommunityService();
  XFile? _selectedFile;
  String _mediaType = 'image';
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file != null) {
        setState(() {
          _selectedFile = file;
          _mediaType = 'image';
        });
      }
    } catch (_) {}
  }

  Future<void> _pickVideo() async {
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (file != null) {
        setState(() {
          _selectedFile = file;
          _mediaType = 'video';
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select video: $error')),
        );
      }
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a photo or video first')),
      );
      return;
    }
    setState(() => _isUploading = true);
    try {
      // Web-compatible upload: use readAsBytes() which works on ALL platforms.
      // MultipartFile.fromFile(path) throws on Flutter Web (no dart:io).
      final fileBytes = await _selectedFile!.readAsBytes();
      final fileName = _selectedFile!.name.isNotEmpty
          ? _selectedFile!.name
          : (_mediaType == 'video' ? 'media.mp4' : 'image.jpg');

      final newMedia = await _service.uploadMediaBytes(
        widget.communityId,
        fileBytes: fileBytes,
        fileName: fileName,
        caption: _captionController.text.trim(),
        mediaType: _mediaType,
      );
      widget.onMediaUploaded(newMedia);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Media added to community gallery!'),
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
                  Icons.add_photo_alternate_rounded,
                  color: primaryOrange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Upload to Community Gallery',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Media Picker Box
          GestureDetector(
            onTap: () => _pickImage(ImageSource.gallery),
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
              ),
              child: _selectedFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const Center(
                            child: Icon(
                              Icons.perm_media_rounded,
                              size: 48,
                              color: primaryOrange,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                onPressed: () =>
                                    setState(() => _selectedFile = null),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          size: 36,
                          color: primaryOrange,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap to choose a photo from gallery',
                          style: TextStyle(
                            color: darkText,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'JPG, PNG, WebP or video',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickVideo,
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Video'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Caption Field
          TextField(
            controller: _captionController,
            decoration: InputDecoration(
              hintText: 'Add a short caption or match description...',
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
          const SizedBox(height: 20),

          // Upload Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _upload,
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
                      'Post to Gallery',
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
}
