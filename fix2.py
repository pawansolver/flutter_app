import base64
import os

file_path = "c:/flutter/my_first_app/lib/modules/feed/home_screen.dart"

b64_content = b"dm9pZCBfc2hhcmVQb3N0KEZlZWRQb3N0IHBvc3QpIGFzeW5jIHsKICAgIGZpbmFsIHRleHQgPSAn8J+TjCAke3Bvc3QuYXV0aG9yTmFtZX0gb24gc21hcnRnYWxpOlxuIiR7cG9zdC5jb250ZW50fSJcblxuSm9pbiBzbWFydGdhbGkgZm9yIGh5cGVybG9jYWwgdXBkYXRlcyEnOwogICAgYXdhaXQgU2hhcmVQbHVzLmluc3RhbmNlLnNoYXJlKFNoYXJlUGFyYW1zKHRleHQ6IHRleHQpKTsKICAgIGF3YWl0IF9zZXJ2aWNlLnNoYXJlVG9GZWVkKHBvc3QuaWQpOwogICAgc2V0U3RhdGUoKCkgewogICAgICBwb3N0LnNoYXJlQ291bnQrKzsKICAgIH0pOwogIH0="

new_share_post = base64.b64decode(b64_content).decode('utf-8')

with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if "void _sharePost(FeedPost post)" in line:
        skip = True
        new_lines.append(new_share_post + "\n")
        continue
    
    if skip:
        if line.strip() == "}":
            skip = False
        continue
    
    new_lines.append(line)

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)
    
print("Fixed _sharePost using python base64 injected code!")
