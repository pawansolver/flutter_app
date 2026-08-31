import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/community_models.dart';

class CommunityGalleryView extends StatelessWidget {
  final List<CommunityMediaModel> mediaItems;
  final VoidCallback? onAddMedia;
  final Function(CommunityMediaModel media)? onDeleteMedia;
  final bool isMember;
  final bool canManage;

  const CommunityGalleryView({
    super.key,
    required this.mediaItems,
    this.onAddMedia,
    this.onDeleteMedia,
    this.isMember = false,
    this.canManage = false,
  });

  void _showMediaViewer(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (ctx) => _GallerySliderDialog(
        mediaItems: mediaItems,
        initialIndex: initialIndex,
        onDeleteMedia: onDeleteMedia,
        canDelete: isMember || canManage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);

    if (mediaItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 54,
                color: Colors.grey,
              ),
              const SizedBox(height: 14),
              const Text(
                'No Photos or Videos in Gallery',
                style: TextStyle(
                  color: darkText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Community members can share photos from events and matches here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              if ((isMember || canManage) && onAddMedia != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onAddMedia,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Upload Photo'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Top Action Header Bar for adding more gallery items
        if ((isMember || canManage) && onAddMedia != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF9FAFB),
            child: Row(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 18,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${mediaItems.length} ${mediaItems.length == 1 ? 'Item' : 'Items'} in Gallery',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onAddMedia,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                  label: const Text(
                    'Add Photo',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

        // Gallery Grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              itemCount: mediaItems.length,
              itemBuilder: (context, index) {
                final item = mediaItems[index];

                return GestureDetector(
                  onTap: () => _showMediaViewer(context, index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (item.mediaType == 'video')
                          Container(
                            color: Colors.black87,
                            child: const Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 48,
                            ),
                          )
                        else
                          Image.network(
                            item.mediaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                          ),
                        if (item.mediaType == 'video')
                          const Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        if (item.caption != null && item.caption!.isNotEmpty)
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: Text(
                              item.caption!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Fullscreen interactive gallery slider with pinch-zoom, swipe, thumbnails & navigation
class _GallerySliderDialog extends StatefulWidget {
  final List<CommunityMediaModel> mediaItems;
  final int initialIndex;
  final Function(CommunityMediaModel media)? onDeleteMedia;
  final bool canDelete;

  const _GallerySliderDialog({
    required this.mediaItems,
    required this.initialIndex,
    this.onDeleteMedia,
    this.canDelete = false,
  });

  @override
  State<_GallerySliderDialog> createState() => _GallerySliderDialogState();
}

class _GallerySliderDialogState extends State<_GallerySliderDialog> {
  late PageController _pageController;
  late int _currentIndex;
  final ScrollController _thumbScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.mediaItems.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (_thumbScrollController.hasClients) {
      _thumbScrollController.animateTo(
        (index * 64.0) - 100.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    if (_currentIndex < widget.mediaItems.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open video player')),
      );
    }
  }

  void _confirmDeleteMedia(CommunityMediaModel media) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Photo'),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove this photo from the community gallery?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx); // pop confirmation
              Navigator.pop(context); // close slider
              widget.onDeleteMedia?.call(media);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.mediaItems[_currentIndex];
    const primaryOrange = Color(0xFFFF6B00);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background dismiss on tap outside content
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.95)),
          ),

          // Main Swipeable PageView
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaItems.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final item = widget.mediaItems[index];

              if (item.mediaType == 'video') {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _openVideo(item.mediaUrl),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: primaryOrange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap to Play Video',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    item.mediaUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white54,
                          size: 64,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Image unavailable',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Top App Bar Controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(
                top: 44,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  // Index Indicator Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.mediaItems.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Uploader info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentItem.uploadedByName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(
                            currentItem.createdAt,
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Delete Button (if allowed)
                  if (widget.canDelete && widget.onDeleteMedia != null) ...[
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 18,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Delete Media',
                        onPressed: () => _confirmDeleteMedia(currentItem),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Close Button
                  CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 18,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Previous Navigation Arrow (for Web / Tablet / Desktop)
          if (_currentIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _prevPage,
                  ),
                ),
              ),
            ),

          // Next Navigation Arrow (for Web / Tablet / Desktop)
          if (_currentIndex < widget.mediaItems.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _nextPage,
                  ),
                ),
              ),
            ),

          // Bottom Caption & Thumbnail Strip
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 24,
                top: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Caption (if present)
                  if (currentItem.caption != null &&
                      currentItem.caption!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        currentItem.caption!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],

                  // Thumbnails Strip (if multiple items exist)
                  if (widget.mediaItems.length > 1)
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        controller: _thumbScrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.mediaItems.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final isSelected = idx == _currentIndex;
                          final thumb = widget.mediaItems[idx];

                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                idx,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryOrange
                                      : Colors.white24,
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: thumb.mediaType == 'video'
                                    ? Container(
                                        color: Colors.black87,
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      )
                                    : Image.network(
                                        thumb.mediaUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          color: Colors.grey.shade900,
                                          child: const Icon(
                                            Icons.image,
                                            color: Colors.white30,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


