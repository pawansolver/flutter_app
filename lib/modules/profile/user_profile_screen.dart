import 'package:flutter/material.dart';
import '../../core/api_config.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../chat/chat_window_screen.dart';
import 'follow_service.dart';

/// Screen to view another user's public profile.
/// Shown when tapping on a post author's name/avatar in the feed.
///
/// PRD Phase 8: Follow/Unfollow toggle with instant UI feedback.
/// Backend automatically sends FCM notification to target on follow.
class UserProfileScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String? fullName;
  final String? avatarUrl;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.fullName,
    this.avatarUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _followService = FollowService();

  bool _isFollowing = false;
  bool _isLoading = false;

  String get _displayName =>
      (widget.fullName?.isNotEmpty == true) ? widget.fullName! : widget.userName;

  // ── Follow / Unfollow toggle ─────────────────────────────────────────────
  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    if (_isFollowing) {
      // Unfollow
      final result = await _followService.unfollowUser(widget.userId);
      if (!mounted) return;
      if (result.isSuccess) {
        setState(() => _isFollowing = false);
        _showSnack('You unfollowed $_displayName.');
      } else {
        _showSnack(result.error ?? 'Unfollow failed.', isError: true);
      }
    } else {
      // Follow
      final result = await _followService.followUser(widget.userId);
      if (!mounted) return;
      if (result.isSuccess) {
        setState(() => _isFollowing = true);
        _showSnack(result.data ?? 'You are now following $_displayName.');
      } else {
        _showSnack(result.error ?? 'Follow failed.', isError: true);
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ── Start Chat ───────────────────────────────────────────────────────────
  Future<void> _startChat() async {
    final currentUserId = await AuthService().getUserId();
    if (currentUserId == null || !mounted) return;

    try {
      final chatModel = await ChatService().getOrCreateOneToOneChat(
        userId: currentUserId,
        targetUserId: widget.userId,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatWindowScreen(
            chatId: chatModel.id,
            chatName: _displayName,
            avatarUrl: widget.avatarUrl,
            isOnline: false,
            currentUserId: currentUserId,
            recipientUserId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      _showSnack('Could not start chat.', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showAvatarPopup(String avatarUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        elevation: 0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  avatarUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = ApiConfig.normalizeMediaUrl(widget.avatarUrl);

    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _displayName,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Avatar
            GestureDetector(
              onTap: () {
                if (avatarUrl != null && avatarUrl.isNotEmpty) {
                  _showAvatarPopup(avatarUrl);
                }
              },
              child: CircleAvatar(
                radius: 52,
                backgroundColor: const Color(0xFFE5E7EB),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? const Icon(Icons.person, size: 52, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              _displayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '@',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),

            // ── Action Buttons ──
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isFollowing
                          ? OutlinedButton.icon(
                              key: const ValueKey('unfollow'),
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF10B981),
                                      ),
                                    )
                                  : const Icon(Icons.person_remove_outlined,
                                      color: Color(0xFF10B981)),
                              label: Text(
                                _isLoading ? 'Wait...' : 'Following',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _toggleFollow,
                            )
                          : ElevatedButton.icon(
                              key: const ValueKey('follow'),
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_outlined,
                                      color: Colors.white),
                              label: Text(
                                _isLoading ? 'Wait...' : 'Follow',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _toggleFollow,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF374151)),
                      label: const Text(
                        'Message',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _startChat,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF9CA3AF), size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Public profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Follow $_displayName to see their posts in your feed.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
