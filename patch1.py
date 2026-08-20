file_path = "c:/flutter/my_first_app/lib/modules/feed/home_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add video_player import after existing imports
import_to_add = "import 'package:video_player/video_player.dart';\n"
# Find place to insert - after the last import
last_import_idx = content.rfind("import '")
end_of_last_import = content.index(";\n", last_import_idx) + 2
content = content[:end_of_last_import] + import_to_add + content[end_of_last_import:]

# 2. Add currentUserId field and _loadCurrentUser to _HomeScreenState
old_state_fields = "  final _service = FeedService();\n  final _notificationService = NotificationService();"
new_state_fields = """  final _service = FeedService();\n  final _notificationService = NotificationService();
  int? _currentUserId; // For author vs viewer context in PostCard"""
content = content.replace(old_state_fields, new_state_fields)

# 3. Load current userId in initState from JWT token
old_init = "    WidgetsBinding.instance.addObserver(this);\n    _loadFeed();"
new_init = """    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUser();
    _loadFeed();"""
content = content.replace(old_init, new_init)

# 4. Add _loadCurrentUser method after initState
old_start_feed = "  void _startFeedSync() {"
new_start_feed = """  Future<void> _loadCurrentUser() async {
    // Read userId from JWT stored in secure storage
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');
    if (token == null) return;
    try {
      // Decode JWT payload (no verification needed - just reading our own value)
      final parts = token.split('.');
      if (parts.length != 3) return;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> map = json.decode(decoded);
      final uid = map['id'] ?? map['userId'] ?? map['sub'];
      if (uid != null && mounted) setState(() => _currentUserId = int.tryParse(uid.toString()));
    } catch (_) {}
  }

  void _startFeedSync() {"""
content = content.replace(old_start_feed, new_start_feed)

# 5. Pass currentUserId to _PostCard
old_post_card = """                        child: _PostCard(
                          post: post,
                          service: _service,
                          formatTime: _formatTime,
                          onComment: () async => _openComments(post),
                          onShare: () => _sharePost(post),
                        ),"""
new_post_card = """                        child: _PostCard(
                          post: post,
                          service: _service,
                          formatTime: _formatTime,
                          currentUserId: _currentUserId,
                          onComment: () async => _openComments(post),
                          onShare: () => _sharePost(post),
                          onDeleted: () => setState(() => _posts.removeWhere((p) => p.id == post.id)),
                        ),"""
content = content.replace(old_post_card, new_post_card)

count = content.count("_currentUserId")
print(f"currentUserId references: {count}")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Step 1 done: added imports, currentUserId, loadCurrentUser")
