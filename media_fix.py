file_path = "c:/flutter/my_first_app/lib/modules/feed/home_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the old media block that uses widget.post.mediaUrl directly
old_media_block = """          // ── Media ─────────────────────────────────────────────────
          if (hasMedia)
            GestureDetector(
              onTap: () {}, // future: open full screen
              child: Stack(
                children: [
                  Image.network(
                    widget.post.mediaUrl!,
                    width: double.infinity,
                    height: 260,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 260,
                        color: const Color(0xFFF3F4F6),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: const Color(0xFFF3F4F6),
                      child: const Center(child: Icon(Icons.broken_image_outlined, color: Color(0xFFD1D5DB), size: 48)),
                    ),
                  ),
                  if (isVideo)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black26,
                        child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 60)),
                      ),
                    ),
                ],
              ),
            ),"""

new_media_block = """          // ── Media Section (Facebook-style) ─────────────────────
          if (hasMedia) _MediaSection(post: widget.post),"""

content = content.replace(old_media_block, new_media_block)

# Also fix the hasMedia and isVideo variables to use effectiveMediaUrl
old_vars = """    final hasMedia = widget.post.mediaUrl != null && widget.post.mediaUrl!.isNotEmpty;
    final isVideo = widget.post.postType == 'video';"""
new_vars = """    final hasMedia = widget.post.hasMedia;
    final isVideo = widget.post.isVideo;"""

content = content.replace(old_vars, new_vars)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated home_screen.dart to use _MediaSection widget and effectiveMediaUrl")
