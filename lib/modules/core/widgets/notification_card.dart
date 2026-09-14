import 'package:flutter/material.dart';
import '../../../core/api_config.dart';
import '../notification_service.dart';

/// Reusable Notification Card widget complying with PRD specifications.
/// Supports distinct icons, sender avatar, thumbnail, unread state,
/// relative timestamps, invitation action buttons, and swipe-to-delete.
class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleRead;
  final VoidCallback? onLongPress;
  final VoidCallback? onAcceptInvitation;
  final VoidCallback? onDeclineInvitation;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectChanged;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    this.onDelete,
    this.onToggleRead,
    this.onLongPress,
    this.onAcceptInvitation,
    this.onDeclineInvitation,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectChanged,
  });

  static const Color _orange = Color(0xFFFF6B00);
  static const Color _dark = Color(0xFF111827);
  static const Color _grey = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final visuals = _getVisuals(notification.type, notification.data);
    final avatarUrl = _extractAvatarUrl(notification.data);
    final thumbnailUrl = _extractThumbnailUrl(notification.data);
    final isRead = notification.isRead;

    Color bgColor = Colors.white;
    if (isSelected) {
      bgColor = const Color(0xFFFFF7ED);
    } else if (!isRead) {
      bgColor = const Color(0xFFFFFBF7);
    }

    Widget cardContent = Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Selection Checkbox (if in selection mode) ────────────────────
          if (isSelectionMode) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isSelected,
                  activeColor: _orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: onSelectChanged,
                ),
              ),
            ),
          ],

          // ── Left: Avatar or Type Icon Badge ──────────────────────────────
          _buildLeadingVisual(visuals, avatarUrl),
          const SizedBox(width: 12),

          // ── Center: Title, Message, Timestamp, Action Buttons ───────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notification.title.isNotEmpty)
                  Text(
                    notification.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _dark,
                      fontSize: 14,
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                if (notification.message.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    notification.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF374151),
                      fontSize: 13,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 6),

                // ── Footer row: Timestamp & Deep-Link Badge ─────────────────
                Row(
                  children: [
                    Text(
                      _formatRelativeTime(notification.createdAt),
                      style: TextStyle(
                        color: isRead ? _grey : _orange,
                        fontSize: 11,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                    if (notification.deepLinkTarget != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Tap to view',
                          style: TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // ── Optional Community Invitation Action Buttons ───────────
                if (notification.data?['invitationId'] != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (onDeclineInvitation != null)
                        OutlinedButton(
                          onPressed: onDeclineInvitation,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Decline',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (onAcceptInvitation != null)
                        FilledButton(
                          onPressed: onAcceptInvitation,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Right: Thumbnail, Unread Dot, 3-dots Menu ──────────────────
          if (thumbnailUrl != null) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                thumbnailUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (!isRead && !isSelectionMode) ...[
            const SizedBox(width: 6),
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _orange,
                shape: BoxShape.circle,
              ),
            ),
          ],
          if (!isSelectionMode) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: _grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (action) {
                if (action == 'toggle_read' && onToggleRead != null) {
                  onToggleRead!();
                } else if (action == 'delete' && onDelete != null) {
                  onDelete!();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'toggle_read',
                  child: Row(
                    children: [
                      Icon(
                        isRead
                            ? Icons.mark_email_unread_outlined
                            : Icons.mark_email_read_outlined,
                        size: 18,
                        color: _dark,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isRead ? 'Mark as unread' : 'Mark as read',
                        style: const TextStyle(fontSize: 13, color: _dark),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: const [
                        Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text(
                          'Delete',
                          style: TextStyle(fontSize: 13, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    Widget tapWrapper = InkWell(
      onTap: isSelectionMode
          ? () => onSelectChanged?.call(!isSelected)
          : onTap,
      onLongPress: onLongPress,
      child: cardContent,
    );

    if (onDelete != null && !isSelectionMode) {
      return Dismissible(
        key: ValueKey('notif_${notification.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.redAccent.withValues(alpha: 0.9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.delete_outline, color: Colors.white, size: 22),
              SizedBox(height: 4),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        onDismissed: (_) => onDelete!(),
        child: tapWrapper,
      );
    }

    return tapWrapper;
  }

  // ── Leading Visual Builder ───────────────────────────────────────────────
  Widget _buildLeadingVisual(_NotificationVisuals visuals, String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFF3F4F6),
            backgroundImage: NetworkImage(avatarUrl),
            onBackgroundImageError: (exception, stackTrace) {},
            child: null,
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: visuals.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(visuals.icon, size: 10, color: Colors.white),
            ),
          ),
        ],
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: visuals.color.withValues(alpha: 0.12),
      child: Icon(visuals.icon, color: visuals.color, size: 20),
    );
  }

  // ── Visual Mapping by PRD Notification Types ─────────────────────────────
  _NotificationVisuals _getVisuals(String type, Map<String, dynamic>? data) {
    final t = type.toLowerCase().trim();

    // 1. Social Likes & Comments
    if (t == 'like' || t == 'post_like') {
      return const _NotificationVisuals(
        icon: Icons.favorite_rounded,
        color: Color(0xFFF43F5E), // Rose pink
      );
    }
    if (t == 'comment' || t == 'post_comment') {
      return const _NotificationVisuals(
        icon: Icons.chat_bubble_outline_rounded,
        color: Color(0xFF8B5CF6), // Violet
      );
    }

    // 2. Follow Requests & Followers
    if (t.contains('follow')) {
      return const _NotificationVisuals(
        icon: Icons.person_add_rounded,
        color: Color(0xFF10B981), // Emerald
      );
    }

    // 3. Events & Reminders
    if (t.contains('event') || t == 'reminder') {
      return const _NotificationVisuals(
        icon: Icons.event_outlined,
        color: Color(0xFFF59E0B), // Amber
      );
    }

    // 4. Communities & Groups
    if (t.contains('community') || t == 'announcement') {
      return const _NotificationVisuals(
        icon: Icons.campaign_outlined,
        color: Color(0xFF0284C7), // Sky blue
      );
    }

    // 5. Chat & Messaging
    if (t == 'chat' || t == 'message' || t == 'chat_message') {
      return const _NotificationVisuals(
        icon: Icons.chat_outlined,
        color: Color(0xFF3B82F6), // Blue
      );
    }

    // 6. Services & Bookings (Provider & Resident)
    if (t == 'booking_request' || t == 'new_booking') {
      return const _NotificationVisuals(
        icon: Icons.calendar_month_outlined,
        color: Color(0xFFD97706), // Warm Amber
      );
    }
    if (t == 'booking_accepted') {
      return const _NotificationVisuals(
        icon: Icons.check_circle_outline_rounded,
        color: Color(0xFF10B981), // Green
      );
    }
    if (t == 'booking_rejected' || t == 'booking_cancelled') {
      return const _NotificationVisuals(
        icon: Icons.cancel_outlined,
        color: Color(0xFFEF4444), // Red
      );
    }
    if (t == 'booking_completed') {
      return const _NotificationVisuals(
        icon: Icons.task_alt_rounded,
        color: Color(0xFF059669), // Deep Green
      );
    }
    if (t == 'payment_received') {
      return const _NotificationVisuals(
        icon: Icons.verified_outlined,
        color: Color(0xFF10B981), // Green
      );
    }
    if (t == 'service_review' || t == 'review') {
      return const _NotificationVisuals(
        icon: Icons.star_rounded,
        color: Color(0xFFEAB308), // Gold
      );
    }

    // 7. Promotions & Offers
    if (t == 'promotion' || t == 'offer') {
      return const _NotificationVisuals(
        icon: Icons.local_offer_outlined,
        color: Color(0xFFFF6B00), // Brand Orange
      );
    }

    // 8. Society Operations (Complaints, Visitors, Parking)
    if (t.contains('complaint') || t.contains('visitor') || t.contains('parking') || t.contains('society')) {
      return const _NotificationVisuals(
        icon: Icons.apartment_rounded,
        color: Color(0xFF475569), // Slate
      );
    }

    // 9. Emergency / Alerts
    if (t == 'alert' || t == 'emergency') {
      return const _NotificationVisuals(
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFDC2626), // Crimson
      );
    }

    // Default / System Fallback
    return const _NotificationVisuals(
      icon: Icons.notifications_active_outlined,
      color: Color(0xFF6B7280), // Slate grey
    );
  }

  String? _extractAvatarUrl(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['senderAvatar'] ?? data['avatarUrl'] ?? data['userAvatar'];
    if (raw == null || raw.toString().isEmpty) return null;
    return ApiConfig.normalizeMediaUrl(raw.toString());
  }

  String? _extractThumbnailUrl(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['thumbnail'] ?? data['mediaUrl'] ?? data['imageUrl'];
    if (raw == null || raw.toString().isEmpty) return null;
    return ApiConfig.normalizeMediaUrl(raw.toString());
  }

  String _formatRelativeTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _NotificationVisuals {
  final IconData icon;
  final Color color;
  const _NotificationVisuals({required this.icon, required this.color});
}
