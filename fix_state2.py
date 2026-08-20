file_path = "c:/flutter/my_first_app/lib/modules/feed/home_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Find start line (class _PostCardState) 
start = None
for i, line in enumerate(lines):
    if "class _PostCardState extends State<_PostCard>" in line:
        start = i
        break

# Find the duplicate @override @override Widget build (the double @override is our marker for the end of old state code)
end = None
for i, line in enumerate(lines):
    if i > start and "@override" in line and i+1 < len(lines) and "@override" in lines[i+1]:
        end = i  # replace up to and including the double @override
        break

print(f"Replacing lines {start} to {end}")

new_state_lines = [
    "class _PostCardState extends State<_PostCard>\n",
    "    with SingleTickerProviderStateMixin {\n",
    "  // Enterprise: all counters tracked locally with optimistic updates\n",
    "  late bool _isLiked;\n",
    "  late int _likeCount;\n",
    "  late int _commentCount;\n",
    "  late int _shareCount;\n",
    "  late bool _isSaved;\n",
    "\n",
    "  bool _likePending = false;\n",
    "  bool _savePending = false;\n",
    "\n",
    "  late AnimationController _scaleCtrl;\n",
    "  late Animation<double> _scaleAnim;\n",
    "\n",
    "  @override\n",
    "  void initState() {\n",
    "    super.initState();\n",
    "    _syncFromPost();\n",
    "    _scaleCtrl = AnimationController(\n",
    "      vsync: this,\n",
    "      duration: const Duration(milliseconds: 150),\n",
    "      reverseDuration: const Duration(milliseconds: 100),\n",
    "    );\n",
    "    _scaleAnim = Tween<double>(begin: 1.0, end: 1.3)\n",
    "        .animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));\n",
    "  }\n",
    "\n",
    "  @override\n",
    "  void didUpdateWidget(_PostCard old) {\n",
    "    super.didUpdateWidget(old);\n",
    "    if (old.post.id != widget.post.id) _syncFromPost();\n",
    "  }\n",
    "\n",
    "  void _syncFromPost() {\n",
    "    _isLiked = widget.post.isLikedByMe;\n",
    "    _likeCount = widget.post.likesCount;\n",
    "    _commentCount = widget.post.commentsCount;\n",
    "    _shareCount = widget.post.shareCount;\n",
    "    _isSaved = widget.post.isSaved;\n",
    "  }\n",
    "\n",
    "  @override\n",
    "  void dispose() {\n",
    "    _scaleCtrl.dispose();\n",
    "    super.dispose();\n",
    "  }\n",
    "\n",
    "  // Enterprise Like: Optimistic UI -> API -> Server-sync / Rollback\n",
    "  Future<void> _handleLike() async {\n",
    "    if (_likePending) return;\n",
    "    final wasLiked = _isLiked;\n",
    "    final prevCount = _likeCount;\n",
    "    setState(() { _isLiked = !wasLiked; _likeCount = wasLiked ? prevCount - 1 : prevCount + 1; _likePending = true; });\n",
    "    _scaleCtrl.forward().then((_) => _scaleCtrl.reverse());\n",
    "    final result = await widget.service.toggleLike(widget.post.id, isCurrentlyLiked: wasLiked);\n",
    "    if (!mounted) return;\n",
    "    setState(() => _likePending = false);\n",
    "    if (!result.isSuccess) {\n",
    "      setState(() { _isLiked = wasLiked; _likeCount = prevCount; });\n",
    "      ScaffoldMessenger.of(context).showSnackBar(SnackBar(\n",
    "        content: Text(result.error ?? 'Could not like post'),\n",
    "        backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating,\n",
    "      ));\n",
    "    } else {\n",
    "      final sc = result.data?['likesCount'];\n",
    "      final sl = result.data?['isLikedByMe'];\n",
    "      setState(() {\n",
    "        if (sc != null) _likeCount = sc is int ? sc : int.tryParse(sc.toString()) ?? _likeCount;\n",
    "        if (sl is bool) _isLiked = sl;\n",
    "      });\n",
    "      widget.post.isLikedByMe = _isLiked;\n",
    "      widget.post.likesCount = _likeCount;\n",
    "    }\n",
    "  }\n",
    "\n",
    "  // Enterprise Save: Optimistic toggle\n",
    "  Future<void> _handleSave() async {\n",
    "    if (_savePending) return;\n",
    "    final wasSaved = _isSaved;\n",
    "    setState(() { _isSaved = !wasSaved; _savePending = true; });\n",
    "    widget.post.isSaved = _isSaved;\n",
    "    final result = await widget.service.savePost(widget.post.id);\n",
    "    if (!mounted) return;\n",
    "    setState(() => _savePending = false);\n",
    "    if (!result.isSuccess) {\n",
    "      setState(() { _isSaved = wasSaved; });\n",
    "      widget.post.isSaved = wasSaved;\n",
    "      ScaffoldMessenger.of(context).showSnackBar(SnackBar(\n",
    "        content: Text(result.error ?? 'Could not save post'),\n",
    "        behavior: SnackBarBehavior.floating,\n",
    "      ));\n",
    "    }\n",
    "  }\n",
    "\n",
    "  // Called by comment sheet when a comment is added\n",
    "  void _onCommentAdded() {\n",
    "    setState(() { _commentCount++; widget.post.commentsCount = _commentCount; });\n",
    "  }\n",
    "\n",
    "  // Called after share action\n",
    "  void _onShared() {\n",
    "    setState(() { _shareCount++; widget.post.shareCount = _shareCount; });\n",
    "  }\n",
    "\n",
    "  @override\n",
    "  Widget build(BuildContext context) {\n",
]

new_lines = lines[:start] + new_state_lines + lines[end+2:]  # skip old double @override lines
with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print(f"Done. File now has {len(new_lines)} lines.")
