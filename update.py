import re

file_path = 'c:/flutter/my_first_app/lib/modules/feed/home_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace _openCreatePost
open_regex = re.compile(r'void _openCreatePost\(\) \{.*?showModalBottomSheet\(.*?\},\n\s*\),\n\s*\);\n\s*\}', re.DOTALL)
new_open = '''void _openCreatePost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostComposerScreen(
          service: _service,
          onPosted: (newPost) {
            setState(() => _posts.insert(0, newPost));
          },
        ),
      ),
    );
  }'''
content = open_regex.sub(new_open, content)

# 2. Replace _sharePost
share_regex = re.compile(r'void _sharePost\(FeedPost post\) \{.*?SharePlus\.instance\.share\(ShareParams\(text: text\)\);\n\s*\}', re.DOTALL)
new_share = '''void _sharePost(FeedPost post) async {
    final text = '📍 ${post.authorName} on smartgali:\\n"${post.content}"\\n\\nJoin smartgali for hyperlocal updates!';
    await SharePlus.instance.share(ShareParams(text: text));
    await _service.shareToFeed(post.id);
    setState(() {
      post.shareCount++;
    });
  }'''
content = share_regex.sub(new_share, content)

# 3. Add import
if "import 'post_composer_screen.dart';" not in content:
    content = "import 'post_composer_screen.dart';\n" + content

# 4. Update PostCard UI
card_content_regex = re.compile(r'// Content.*?Padding\(.*?child: Text\(.*?widget\.post\.content,.*?style: const TextStyle\(.*?color: Color\(0xFF374151\),.*?fontSize: 14\.5,.*?height: 1\.55,.*?\),.*?\),.*?\),', re.DOTALL)
new_card_content = '''// Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              widget.post.content,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 14.5,
                height: 1.55,
              ),
            ),
          ),
          // Image
          if (widget.post.mediaUrl != null &&
              widget.post.mediaUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.zero),
              child: Image.network(
                widget.post.mediaUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  height: 120,
                  color: const Color(0xFFF3F4F6),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: Color(0xFFD1D5DB),
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ],'''
if '// Image' not in content:
    content = card_content_regex.sub(new_card_content, content)

# 5. Update Action Row (Save & Share)
action_row_regex = re.compile(r'_ActionBtn\(.*?icon: Icons\.ios_share_outlined,.*?label: \'Share\',.*?color: const Color\(0xFF9CA3AF\),.*?onTap: widget\.onShare,.*?\),.*?\]', re.DOTALL)
new_action_row = '''Row(
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
              ]'''
content = action_row_regex.sub(new_action_row, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Successfully updated home_screen.dart using Python")
