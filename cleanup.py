file_path = "c:/flutter/my_first_app/lib/modules/feed/home_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

import re

# Remove _ActionBtn class (unused)
content = re.sub(
    r"// ── Action Button ─+\nclass _ActionBtn[\s\S]*?(?=\n// ──|\nclass (?!_ActionBtn|_LikeButton)|\Z)",
    "",
    content
)

# Remove _LikeButton class (unused)
content = re.sub(
    r"// ── Like Button[\s\S]*?(?=\n// ──|\nclass (?!_LikeButton)|\Z)",
    "",
    content
)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Removed unused _ActionBtn and _LikeButton classes")
