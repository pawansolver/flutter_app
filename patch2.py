file_path = "c:/flutter/my_first_app/lib/modules/feed/home_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Fix _PostCard widget definition - add currentUserId, onDeleted params
old_postcard_widget = """class _PostCard extends StatefulWidget {
  final FeedPost post;
  final FeedService service;
  final String Function(String?) formatTime;
  final Future<void> Function() onComment;
  final VoidCallback onShare;

  const _PostCard({
    required this.post,
    required this.service,
    required this.formatTime,
    required this.onComment,
    required this.onShare,
  });"""

new_postcard_widget = """class _PostCard extends StatefulWidget {
  final FeedPost post;
  final FeedService service;
  final String Function(String?) formatTime;
  final int? currentUserId;
  final Future<void> Function() onComment;
  final VoidCallback onShare;
  final VoidCallback? onDeleted;

  const _PostCard({
    required this.post,
    required this.service,
    required this.formatTime,
    this.currentUserId,
    required this.onComment,
    required this.onShare,
    this.onDeleted,
  });"""

content = content.replace(old_postcard_widget, new_postcard_widget)

print("Old found:", old_postcard_widget[:50] in content or "FAILED (old already replaced)")
print("New applied:", new_postcard_widget[:50] in content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Step 2 done: updated _PostCard widget definition")
