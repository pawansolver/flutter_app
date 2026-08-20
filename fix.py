import re

file_path = 'c:/flutter/my_first_app/lib/modules/feed/home_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix _sharePost string
bad_share_str = """void _sharePost(FeedPost post) async {
    final text = '📍 ${post.authorName} on smartgali:
  "${post.content}"
  
  Join smartgali for hyperlocal updates!';
    await SharePlus.instance.share(ShareParams(text: text));
    await _service.shareToFeed(post.id);
    setState(() {
      post.shareCount++;
    });
  }"""

fixed_share_str = """void _sharePost(FeedPost post) async {
    final text = '📍 ${post.authorName} on smartgali:\\n"${post.content}"\\n\\nJoin smartgali for hyperlocal updates!';
    await SharePlus.instance.share(ShareParams(text: text));
    await _service.shareToFeed(post.id);
    setState(() {
      post.shareCount++;
    });
  }"""

content = content.replace(bad_share_str, fixed_share_str)

# 2. Fix the Action Row
bad_action_row = """                    Row(
                  children: [
                    _ActionBtn(
                      icon: widget.post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      label: widget.post.isSaved ? 'Saved' : 'Save',
                      color: widget.post.isSaved ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                      onTap: () async {
                        setState(() => widget.post.isSaved = !widget.post.isSaved);
                        if (widget.post.isSaved) {
                          await widget.service.savePost(widget.post.id);
                        } else {
                          // unsave if service supports it
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    _ActionBtn(
                      icon: Icons.ios_share_outlined,
                      label: '${widget.post.shareCount}',
                      color: const Color(0xFF9CA3AF),
                      onTap: widget.onShare,
                    ),
                  ],
                ),
              ],
            ),"""

fixed_action_row = """                    _ActionBtn(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: '${widget.post.commentsCount}',
                      color: const Color(0xFF9CA3AF),
                      onTap: widget.onComment,
                    ),
                  ],
                ),
                Row(
                  children: [
                    _ActionBtn(
                      icon: widget.post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      label: widget.post.isSaved ? 'Saved' : 'Save',
                      color: widget.post.isSaved ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                      onTap: () async {
                        setState(() => widget.post.isSaved = !widget.post.isSaved);
                        if (widget.post.isSaved) {
                          await widget.service.savePost(widget.post.id);
                        } else {
                          // unsave if service supports it
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    _ActionBtn(
                      icon: Icons.ios_share_outlined,
                      label: '${widget.post.shareCount}',
                      color: const Color(0xFF9CA3AF),
                      onTap: widget.onShare,
                    ),
                  ],
                ),
              ],
            ),"""

content = content.replace(bad_action_row, fixed_action_row)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed syntax errors in home_screen.dart")
