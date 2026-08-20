file_path = "c:/flutter/my_first_app/lib/modules/feed/home_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace(
    "    final hasMedia = widget.post.hasMedia;\n    final isVideo = widget.post.isVideo;\n    final hasText = widget.post.content.trim().isNotEmpty;",
    "    final hasMedia = widget.post.hasMedia;\n    final hasText = widget.post.content.trim().isNotEmpty;"
)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Removed unused isVideo variable")
