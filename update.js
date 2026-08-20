const fs = require('fs');
const file = 'c:/flutter/my_first_app/lib/modules/feed/home_screen.dart';
let content = fs.readFileSync(file, 'utf8');

// 1. Replace _openCreatePost
const openRegex = /void _openCreatePost\(\) \{[\s\S]*?showModalBottomSheet\([\s\S]*?\}\),[\s\S]*?\);[\s\S]*?\}/;
const newOpen = `void _openCreatePost() {
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
  }`;
content = content.replace(openRegex, newOpen);

// 2. Replace _sharePost
const shareRegex = /void _sharePost\(FeedPost post\) \{[\s\S]*?SharePlus\.instance\.share\(ShareParams\(text: text\)\);[\s\S]*?\}/;
const newShare = `void _sharePost(FeedPost post) async {
    final text = '📍 ${post.authorName} on smartgali:\n"${post.content}"\n\nJoin smartgali for hyperlocal updates!';
    await SharePlus.instance.share(ShareParams(text: text));
    await _service.shareToFeed(post.id);
    setState(() {
      post.shareCount++;
    });
  }`;
content = content.replace(shareRegex, newShare);

// 3. Add import
if (!content.includes("import 'post_composer_screen.dart';")) {
  content = "import 'post_composer_screen.dart';\n" + content;
}

// 4. Update PostCard UI
const cardContentRegex = /\/\/ Content[\s\S]*?Padding\([\s\S]*?child: Text\([\s\S]*?widget\.post\.content,[\s\S]*?style: const TextStyle\([\s\S]*?color: Color\(0xFF374151\),[\s\S]*?fontSize: 14\.5,[\s\S]*?height: 1\.55,[\s\S]*?\),[\s\S]*?\),[\s\S]*?\),/;
const newCardContent = `// Content
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
          ],`;
if (!content.includes('// Image')) {
    content = content.replace(cardContentRegex, newCardContent);
}

// 5. Update Action Row (Save & Share)
const actionRowRegex = /_ActionBtn\([\s\S]*?icon: Icons\.ios_share_outlined,[\s\S]*?label: 'Share',[\s\S]*?color: const Color\(0xFF9CA3AF\),[\s\S]*?onTap: widget\.onShare,[\s\S]*?\),[\s\S]*?\]/;
const newActionRow = `Row(
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
                      label: \`\${widget.post.shareCount}\`,
                      color: const Color(0xFF9CA3AF),
                      onTap: widget.onShare,
                    ),
                  ],
                ),
              ]`;
content = content.replace(actionRowRegex, newActionRow);

fs.writeFileSync(file, content);
console.log('Successfully updated home_screen.dart');
