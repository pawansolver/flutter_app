file_path = "c:/flutter/my_first_app/lib/modules/feed/home_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Find and replace the entire _PostCardState class (from "class _PostCardState" to the closing "}" before _initials)
import re

old_state = '''class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  // \u2500\u2500 Local like state \u2014 decoupled from parent \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
  late bool _isLiked;
  late int _likeCount;

  // \u2500\u2500 Guards \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
  bool _isPending = false; // block concurrent API calls

  // \u2500\u2500 Animation \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByMe;
    _likeCount = widget.post.likesCount;

    // Spring-like scale animation for like button
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.35,
    ).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  // \u2500\u2500 Enterprise like handler \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
  // Pattern: Optimistic update \u2192 API call \u2192 server-sync or rollback
  // Guard: _isPending prevents overlapping calls from rapid taps
  Future<void> _handleLike() async {
    if (_isPending) return; // \u2190 guard: ignore tap if call in-flight

    // 1. Snapshot current state BEFORE mutation (avoids same-ref bug)
    final wasLiked = _isLiked;
    final prevCount = _likeCount;
    final optimisticCount = wasLiked ? prevCount - 1 : prevCount + 1;

    // 2. Optimistic UI \u2014 update immediately with correct values
    setState(() {
      _isLiked = !wasLiked;
      _likeCount = optimisticCount;
      _isPending = true;
    });

    // 3. Spring animation: scale up then back
    await _scaleCtrl.forward();
    _scaleCtrl.reverse();

    // 4. API call \u2014 pass wasLiked so service picks correct endpoint (like vs unlike)
    final result = await widget.service.toggleLike(
      widget.post.id,
      isCurrentlyLiked: wasLiked,
    );
    if (!mounted) return;

    setState(() => _isPending = false);

    if (!result.isSuccess) {
      // 5a. Rollback to snapshot on failure
      setState(() {
        _isLiked = wasLiked;
        _likeCount = prevCount;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? \'Could not update like\'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // 5b. Server-sync: trust the DB-confirmed count (from post.reload())
      final serverCount = result.data?[\'likesCount\'];
      final serverIsLiked = result.data?[\'isLikedByMe\'] as bool?;
      setState(() {
        if (serverCount != null) {
          _likeCount = serverCount is int
              ? serverCount
              : int.tryParse(serverCount.toString()) ?? _likeCount;
        }
        if (serverIsLiked != null) _isLiked = serverIsLiked;
      });
      // Also sync parent model so refresh doesn\'t flicker
      widget.post.isLikedByMe = _isLiked;
      widget.post.likesCount = _likeCount;
    }
  }

  @override
  @override
  Widget build(BuildContext context) {'''

new_state = '''class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  // ── Per-post local state (enterprise: all counts tracked locally) ─
  late bool _isLiked;
  late int _likeCount;
  late int _commentCount;
  late int _shareCount;
  late bool _isSaved;

  // ── Guards: prevent overlapping API calls ─────────────────────────
  bool _likePending = false;
  bool _savePending = false;

  // ── Like button scale animation ───────────────────────────────────
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _syncFromPost();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.3)
        .animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_PostCard old) {
    super.didUpdateWidget(old);
    // Re-sync if parent refreshes feed (avoids stale counts)
    if (old.post.id != widget.post.id) _syncFromPost();
  }

  void _syncFromPost() {
    _isLiked = widget.post.isLikedByMe;
    _likeCount = widget.post.likesCount;
    _commentCount = widget.post.commentsCount;
    _shareCount = widget.post.shareCount;
    _isSaved = widget.post.isSaved;
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  // ── Enterprise Like: Optimistic → API → Server-sync / Rollback ────
  Future<void> _handleLike() async {
    if (_likePending) return;

    final wasLiked = _isLiked;
    final prevCount = _likeCount;
    final optimistic = wasLiked ? prevCount - 1 : prevCount + 1;

    // 1. Optimistic UI
    setState(() { _isLiked = !wasLiked; _likeCount = optimistic; _likePending = true; });

    // 2. Scale animation
    _scaleCtrl.forward().then((_) => _scaleCtrl.reverse());

    // 3. API
    final result = await widget.service.toggleLike(widget.post.id, isCurrentlyLiked: wasLiked);
    if (!mounted) return;

    setState(() => _likePending = false);

    if (!result.isSuccess) {
      // Rollback
      setState(() { _isLiked = wasLiked; _likeCount = prevCount; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? \'Could not update like\'),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      // Server-sync with confirmed count
      final serverCount = result.data?[\'likesCount\'];
      final serverIsLiked = result.data?[\'isLikedByMe\'];
      setState(() {
        if (serverCount != null) _likeCount = (serverCount is int) ? serverCount : int.tryParse(serverCount.toString()) ?? _likeCount;
        if (serverIsLiked is bool) _isLiked = serverIsLiked;
      });
      widget.post.isLikedByMe = _isLiked;
      widget.post.likesCount = _likeCount;
    }
  }

  // ── Enterprise Save: Optimistic toggle ────────────────────────────
  Future<void> _handleSave() async {
    if (_savePending) return;
    final wasSaved = _isSaved;
    setState(() { _isSaved = !wasSaved; _savePending = true; });
    widget.post.isSaved = _isSaved;

    final result = await widget.service.savePost(widget.post.id);
    if (!mounted) return;

    setState(() => _savePending = false);
    if (!result.isSuccess) {
      setState(() { _isSaved = wasSaved; });
      widget.post.isSaved = wasSaved;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? \'Could not save post\'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Comment count local increment ─────────────────────────────────
  void _onCommentAdded() {
    setState(() => _commentCount++);
    widget.post.commentsCount = _commentCount;
  }

  // ── Share count local increment ───────────────────────────────────
  void _onShared() {
    setState(() => _shareCount++);
    widget.post.shareCount = _shareCount;
  }

  @override
  Widget build(BuildContext context) {'''

if old_state in content:
    content = content.replace(old_state, new_state)
    print("SUCCESS: Replaced _PostCardState")
else:
    print("ERROR: Could not find old_state to replace")
    # Try to find partial match
    idx = content.find("class _PostCardState extends State<_PostCard>")
    print(f"Class found at index: {idx}")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
