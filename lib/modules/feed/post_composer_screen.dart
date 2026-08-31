import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'feed_service.dart';
import 'models/feed_post_model.dart';
import 'services/upload_service.dart';

class PostComposerScreen extends StatefulWidget {
  final FeedService service;
  final Function(FeedPost) onPosted;
  final int? communityId;
  final String? communityName;

  const PostComposerScreen({
    super.key,
    required this.service,
    required this.onPosted,
    this.communityId,
    this.communityName,
  });

  @override
  State<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends State<PostComposerScreen> {
  final _ctrl = TextEditingController();
  final _picker = ImagePicker();
  final _uploadService = UploadService();

  // Store XFiles (web + mobile compatible) and their preview bytes
  final List<XFile> _mediaFiles = [];
  final List<Uint8List> _previews = [];
  final List<bool> _isVideo = [];

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  String _visibility = 'public';
  String _postType = 'text';
  int _charCount = 0;
  static const int _maxChars = 5000;

  static const _primaryColor = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _charCount = _ctrl.text.length));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_mediaFiles.length >= 5) {
      _showSnack('Maximum 5 media files allowed');
      return;
    }
    final List<XFile> picked = await _picker.pickMultiImage(imageQuality: 85);
    for (final xfile in picked) {
      if (_mediaFiles.length >= 5) break;
      final bytes = await xfile.readAsBytes();
      setState(() {
        _mediaFiles.add(xfile);
        _previews.add(bytes);
        _isVideo.add(false);
        _postType = _mediaFiles.length > 1 ? 'mixed' : 'image';
      });
    }
  }

  Future<void> _pickVideo() async {
    if (_mediaFiles.length >= 5) {
      _showSnack('Maximum 5 media files allowed');
      return;
    }
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (video != null) {
      final bytes = await video.readAsBytes();
      final sizeMB = bytes.lengthInBytes / (1024 * 1024);
      if (sizeMB > 100) {
        _showSnack('Video must be under 100MB');
        return;
      }
      setState(() {
        _mediaFiles.add(video);
        _previews.add(bytes);
        _isVideo.add(true);
        _postType = 'video';
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaFiles.removeAt(index);
      _previews.removeAt(index);
      _isVideo.removeAt(index);
      if (_mediaFiles.isEmpty) {
        _postType = 'text';
      } else if (_mediaFiles.length == 1) {
        _postType = _isVideo[0] ? 'video' : 'image';
      }
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _mediaFiles.isEmpty) {
      _showSnack('Please add some text or media before posting');
      return;
    }
    if (text.length > _maxChars) {
      _showSnack('Post too long. Maximum $_maxChars characters.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing...';
    });

    if (_mediaFiles.isEmpty) {
      await _createPost(text, []);
      return;
    }

    final List<int> mediaIds = [];
    for (int i = 0; i < _mediaFiles.length; i++) {
      if (!mounted) return;
      setState(() {
        _uploadStatus = 'Uploading ${i + 1} of ${_mediaFiles.length}...';
        _uploadProgress = i / _mediaFiles.length;
      });

      final res = await _uploadService.uploadXFile(
        _mediaFiles[i],
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() {
            _uploadProgress =
                (i / _mediaFiles.length) +
                ((sent / total) / _mediaFiles.length);
          });
        },
      );

      if (res == null) {
        if (!mounted) return;
        setState(() => _isUploading = false);
        _showSnack(
          'Upload failed for item ${i + 1}. Check connection and try again.',
        );
        return;
      }

      if (res['mediaId'] != null) {
        mediaIds.add(res['mediaId'] as int);
      } else if (res['id'] != null) {
        mediaIds.add(res['id'] as int);
      }
    }

    await _createPost(text, mediaIds);
  }

  Future<void> _createPost(String text, List<int> mediaIds) async {
    if (!mounted) return;
    setState(() {
      _uploadStatus = 'Publishing post...';
      _uploadProgress = 0.95;
    });

    final result = await widget.service.createPost(
      content: text,
      mediaIds: mediaIds.isNotEmpty ? mediaIds : null,
      type: _postType,
      visibility: _visibility,
      communityId: widget.communityId,
    );

    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      widget.onPosted(result.data!);
      Navigator.pop(context);
    } else {
      setState(() => _isUploading = false);
      _showSnack(result.error ?? 'Failed to create post. Please try again.');
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_ctrl.text.trim().isEmpty && _mediaFiles.isEmpty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Discard Post?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Your draft will be lost. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showVisibilitySheet() {
    final data = {
      'public': (Icons.public, 'Public'),
      'followers': (Icons.people, 'Followers'),
      'private': (Icons.lock, 'Only Me'),
    };
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Who can see this?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...data.entries.map(
              (e) => ListTile(
                leading: Icon(e.value.$1, color: _primaryColor),
                title: Text(e.value.$2),
                trailing: _visibility == e.key
                    ? const Icon(Icons.check, color: _primaryColor)
                    : null,
                onTap: () {
                  setState(() => _visibility = e.key);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityPill() {
    final labels = {
      'public': 'Public',
      'followers': 'Followers',
      'private': 'Only Me',
    };
    final icons = {
      'public': Icons.public,
      'followers': Icons.people,
      'private': Icons.lock,
    };
    return GestureDetector(
      onTap: _showVisibilitySheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icons[_visibility], size: 14, color: _primaryColor),
            const SizedBox(width: 4),
            Text(
              labels[_visibility]!,
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 16, color: _primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(int idx) {
    final isVid = _isVideo[idx];
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: _mediaFiles.length == 1 ? double.infinity : 100,
          height: _mediaFiles.length == 1 ? 220 : 100,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              _mediaFiles.length == 1 ? 12 : 8,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                isVid
                    ? Container(
                        color: Colors.black,
                        child: const Center(
                          child: Icon(
                            Icons.videocam,
                            color: Colors.white70,
                            size: 40,
                          ),
                        ),
                      )
                    : Image.memory(
                        _previews[idx],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                if (isVid)
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          right: _mediaFiles.length == 1 ? 8 : 0,
          top: 0,
          child: GestureDetector(
            onTap: () => _removeMedia(idx),
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
    );
  }

  Widget _buildMediaSection() {
    if (_previews.isEmpty) return const SizedBox.shrink();
    if (_previews.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _buildPreview(0),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _previews.length,
        itemBuilder: (_, idx) => _buildPreview(idx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPost =
        !_isUploading &&
        (_ctrl.text.trim().isNotEmpty || _mediaFiles.isNotEmpty) &&
        _charCount <= _maxChars;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (!context.mounted) return;
        if (discard) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1F2937)),
            onPressed: () async {
              final discard = await _confirmDiscard();
              if (!context.mounted) return;
              if (discard) Navigator.pop(context);
            },
          ),
          title: const Text(
            'Create Post',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              child: AnimatedOpacity(
                opacity: canPost ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: canPost ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    elevation: 0,
                  ),
                  child: const Text(
                    'POST',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: _isUploading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _uploadProgress > 0 ? _uploadProgress : null,
                            strokeWidth: 6,
                            color: _primaryColor,
                            backgroundColor: const Color(0xFFE0E7FF),
                          ),
                          if (_uploadProgress > 0)
                            Text(
                              '${(_uploadProgress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _uploadStatus,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please wait...',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.communityId == null)
                      _buildVisibilityPill()
                    else
                      Text(
                        'Posting to ${widget.communityName ?? 'community'}',
                        style: const TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ctrl,
                      maxLines: null,
                      minLines: 5,
                      decoration: const InputDecoration(
                        hintText: "What's on your mind?",
                        hintStyle: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    _buildMediaSection(),
                  ],
                ),
              ),
        bottomNavigationBar: _isUploading
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      _ToolbarBtn(
                        icon: Icons.image_rounded,
                        label: 'Photo',
                        color: const Color(0xFF10B981),
                        onTap: _pickImages,
                      ),
                      const SizedBox(width: 4),
                      _ToolbarBtn(
                        icon: Icons.videocam_rounded,
                        label: 'Video',
                        color: const Color(0xFF6366F1),
                        onTap: _pickVideo,
                      ),
                      const Spacer(),
                      Text(
                        '$_charCount/$_maxChars',
                        style: TextStyle(
                          fontSize: 12,
                          color: _charCount > _maxChars
                              ? Colors.red
                              : Colors.grey.shade500,
                          fontWeight: _charCount > _maxChars * 0.9
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolbarBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
