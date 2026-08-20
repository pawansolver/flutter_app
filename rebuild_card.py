file_path = "c:/flutter/my_first_app/lib/modules/feed/home_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Find the start (Widget build) of _PostCardState and its closing }
start_line = None
end_line = None

for i, line in enumerate(lines):
    if "Widget build(BuildContext context)" in line and i > 700 and i < 760:
        start_line = i
        break

# Find where _initials starts (that's the end of the build method)
for i, line in enumerate(lines):
    if "// ── Safe initial letter for avatar" in line and i > 700:
        end_line = i - 1
        break

print(f"Build method: lines {start_line} to {end_line}")

# The new build method for _PostCardState
new_build = '''  @override
  Widget build(BuildContext context) {
    final hasMedia = widget.post.mediaUrl != null && widget.post.mediaUrl!.isNotEmpty;
    final isVideo = widget.post.postType == 'video';
    final hasText = widget.post.content.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author Header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.post.authorUserId != null
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: widget.post.authorUserId!, userName: widget.post.authorUserName ?? widget.post.authorName, fullName: widget.post.authorName, avatarUrl: widget.post.authorAvatarUrl)))
                      : null,
                  child: CircleAvatar(
                    radius: 21,
                    backgroundColor: _avatarColor(widget.post.authorName),
                    backgroundImage: widget.post.authorAvatarUrl != null && widget.post.authorAvatarUrl!.isNotEmpty
                        ? NetworkImage(widget.post.authorAvatarUrl!) : null,
                    child: widget.post.authorAvatarUrl == null || widget.post.authorAvatarUrl!.isEmpty
                        ? Text(_initials(widget.post.authorName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.post.authorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Color(0xFF111827))),
                      Row(children: [
                        Text(widget.formatTime(widget.post.createdAt), style: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF))),
                        const SizedBox(width: 4),
                        const Icon(Icons.public, size: 11, color: Color(0xFF9CA3AF)),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Color(0xFF9CA3AF)),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // ── Text Content ──────────────────────────────────────────
          if (hasText)
            Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, hasMedia ? 8 : 0),
              child: Text(
                widget.post.content,
                style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15, height: 1.5),
                maxLines: hasMedia ? 3 : null,
                overflow: hasMedia ? TextOverflow.ellipsis : TextOverflow.visible,
              ),
            ),

          // ── Media ─────────────────────────────────────────────────
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
            ),

          // ── Counts row (Facebook-style mini counts) ────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                if (_likeCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
                    child: const Icon(Icons.thumb_up, size: 9, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Text('$_likeCount', style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
                ],
                const Spacer(),
                if (widget.post.commentsCount > 0)
                  Text('${widget.post.commentsCount} comments', style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
                if (widget.post.commentsCount > 0 && widget.post.shareCount > 0)
                  const Text('  ·  ', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
                if (widget.post.shareCount > 0)
                  Text('${widget.post.shareCount} shares', style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
              ],
            ),
          ),

          // ── Divider ────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),

          // ── Action Buttons (Facebook-style full-width row) ──────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                // Like
                Expanded(
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: TextButton.icon(
                      onPressed: _isPending ? null : _handleLike,
                      icon: Icon(
                        _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                        size: 18,
                        color: _isLiked ? const Color(0xFF6366F1) : const Color(0xFF6B7280),
                      ),
                      label: Text(
                        'Like',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isLiked ? const Color(0xFF6366F1) : const Color(0xFF6B7280),
                        ),
                      ),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                    ),
                  ),
                ),
                // Comment
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.onComment,
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF6B7280)),
                    label: const Text('Comment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                  ),
                ),
                // Save
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      setState(() => widget.post.isSaved = !widget.post.isSaved);
                      if (widget.post.isSaved) await widget.service.savePost(widget.post.id);
                    },
                    icon: Icon(
                      widget.post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                      color: widget.post.isSaved ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                    ),
                    label: Text(
                      widget.post.isSaved ? 'Saved' : 'Save',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.post.isSaved ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                      ),
                    ),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                  ),
                ),
                // Share
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.onShare,
                    icon: const Icon(Icons.reply_rounded, size: 18, color: Color(0xFF6B7280)),
                    label: const Text('Share', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

'''

# Replace lines start_line to end_line with new_build
new_lines = lines[:start_line] + [new_build] + lines[end_line:]
with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print(f"Replaced PostCard build (lines {start_line}-{end_line}) with Facebook-style UI")
