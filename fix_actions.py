file_path = "c:/flutter/my_first_app/lib/modules/feed/home_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Fix 1: counts row - use local state vars instead of widget.post.*
content = content.replace(
    "                if (widget.post.commentsCount > 0)\n                  Text('${widget.post.commentsCount} comments', style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),\n                if (widget.post.commentsCount > 0 && widget.post.shareCount > 0)\n                  const Text('  \u00b7  ', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),\n                if (widget.post.shareCount > 0)\n                  Text('${widget.post.shareCount} shares', style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),",
    "                if (_commentCount > 0)\n                  Text('$_commentCount comment${_commentCount == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),\n                if (_commentCount > 0 && _shareCount > 0)\n                  const Text('  \u00b7  ', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),\n                if (_shareCount > 0)\n                  Text('$_shareCount share${_shareCount == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),"
)

# Fix 2: _isPending -> _likePending
content = content.replace("onPressed: _isPending ? null : _handleLike,", "onPressed: _likePending ? null : _handleLike,")

# Fix 3: Save button - use _handleSave and _isSaved
content = content.replace(
    "                // Save\n                Expanded(\n                  child: TextButton.icon(\n                    onPressed: () async {\n                      setState(() => widget.post.isSaved = !widget.post.isSaved);\n                      if (widget.post.isSaved) await widget.service.savePost(widget.post.id);\n                    },\n                    icon: Icon(\n                      widget.post.isSaved ? Icons.bookmark : Icons.bookmark_border,\n                      size: 18,\n                      color: widget.post.isSaved ? const Color(0xFF10B981) : const Color(0xFF6B7280),\n                    ),\n                    label: Text(\n                      widget.post.isSaved ? 'Saved' : 'Save',\n                      style: TextStyle(\n                        fontSize: 13,\n                        fontWeight: FontWeight.w600,\n                        color: widget.post.isSaved ? const Color(0xFF10B981) : const Color(0xFF6B7280),\n                      ),\n                    ),\n                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),\n                  ),\n                ),",
    "                // Save\n                Expanded(\n                  child: TextButton.icon(\n                    onPressed: _savePending ? null : _handleSave,\n                    icon: Icon(\n                      _isSaved ? Icons.bookmark : Icons.bookmark_border,\n                      size: 18,\n                      color: _isSaved ? const Color(0xFF10B981) : const Color(0xFF6B7280),\n                    ),\n                    label: Text(\n                      _isSaved ? 'Saved' : 'Save',\n                      style: TextStyle(\n                        fontSize: 13,\n                        fontWeight: FontWeight.w600,\n                        color: _isSaved ? const Color(0xFF10B981) : const Color(0xFF6B7280),\n                      ),\n                    ),\n                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),\n                  ),\n                ),"
)

# Fix 4: Share button - call _onShared after share action
content = content.replace(
    "                // Share\n                Expanded(\n                  child: TextButton.icon(\n                    onPressed: widget.onShare,\n                    icon: const Icon(Icons.reply_rounded, size: 18, color: Color(0xFF6B7280)),\n                    label: const Text('Share', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),\n                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),\n                  ),\n                ),",
    "                // Share\n                Expanded(\n                  child: TextButton.icon(\n                    onPressed: () { widget.onShare(); _onShared(); },\n                    icon: const Icon(Icons.reply_rounded, size: 18, color: Color(0xFF6B7280)),\n                    label: const Text('Share', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),\n                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),\n                  ),\n                ),"
)

# Fix 5: Comment button - open comment + _onCommentAdded callback
# The onComment callback in widget needs to notify when comment added
content = content.replace(
    "                // Comment\n                Expanded(\n                  child: TextButton.icon(\n                    onPressed: widget.onComment,\n                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF6B7280)),\n                    label: const Text('Comment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),\n                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),\n                  ),\n                ),",
    "                // Comment\n                Expanded(\n                  child: TextButton.icon(\n                    onPressed: () async {\n                      await widget.onComment();\n                      // count is updated via _onCommentAdded from comment sheet callback\n                    },\n                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF6B7280)),\n                    label: const Text('Comment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),\n                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),\n                  ),\n                ),"
)

count_a = content.count("_isSaved")
count_b = content.count("_likePending") 
count_c = content.count("_commentCount")
print(f"Verification: _isSaved={count_a}, _likePending={count_b}, _commentCount={count_c}")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Done applying action button fixes")
