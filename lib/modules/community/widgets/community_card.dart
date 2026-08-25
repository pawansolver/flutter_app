import 'package:flutter/material.dart';
import '../../../models/community_models.dart';

class CommunityCard extends StatelessWidget {
  final CommunityModel community;
  final VoidCallback onTap;
  final VoidCallback? onJoinToggle;
  final bool isJoining;

  const CommunityCard({
    super.key,
    required this.community,
    required this.onTap,
    this.onJoinToggle,
    this.isJoining = false,
  });

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category tag + Privacy badge + Unread dot
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryOrange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        community.category ?? 'General',
                        style: const TextStyle(
                          color: primaryOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (community.isPrivate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.lock_outline, size: 12, color: greySubtext),
                            SizedBox(width: 4),
                            Text(
                              'Private',
                              style: TextStyle(
                                color: greySubtext,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    if (community.hasUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: primaryOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Middle Row: Avatar / Icon + Title & Description
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5EE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: primaryOrange.withOpacity(0.2)),
                      ),
                      child: Center(
                        child: community.iconUrl != null && community.iconUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  community.iconUrl!,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.group_work_rounded,
                                    color: primaryOrange,
                                    size: 28,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.groups_rounded,
                                color: primaryOrange,
                                size: 30,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            community.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: darkText,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            community.description ?? 'Join this community to discuss and share.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: greySubtext,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 12),

                // Bottom Row: Member stats + Join / Joined Action CTA
                Row(
                  children: [
                    // Member avatar stack imitation
                    Row(
                      children: [
                        ...List.generate(3, (index) {
                          return Align(
                            widthFactor: 0.65,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.primaries[(community.id + index) % Colors.primaries.length].withOpacity(0.2),
                              child: Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.primaries[(community.id + index) % Colors.primaries.length],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 10),
                        Text(
                          '${community.membersCount} members',
                          style: const TextStyle(
                            color: greySubtext,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Action Button
                    if (onJoinToggle != null)
                      SizedBox(
                        height: 34,
                        child: community.isMember
                            ? OutlinedButton.icon(
                                onPressed: isJoining ? null : onJoinToggle,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF10B981),
                                  side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                icon: const Icon(Icons.check, size: 14),
                                label: const Text(
                                  'Joined',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: isJoining ? null : onJoinToggle,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryOrange,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                child: isJoining
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        community.isPrivate ? 'Request' : 'Join',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
