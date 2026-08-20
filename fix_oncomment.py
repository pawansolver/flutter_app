file_path = "c:/flutter/my_first_app/lib/modules/feed/home_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Fix onComment type to be Future<void> Function()
content = content.replace(
    "  final VoidCallback onComment;\n  final VoidCallback onShare;",
    "  final Future<void> Function() onComment;\n  final VoidCallback onShare;"
)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Fixed onComment type")
