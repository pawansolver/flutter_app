import 'package:flutter/material.dart';
import '../../../models/community_models.dart';

class MemberActionSheet extends StatelessWidget {
  final CommunityMemberModel member;
  final CommunityRole myRole;
  final Function(CommunityRole newRole) onUpdateRole;
  final VoidCallback onRemove;
  final VoidCallback onBan;
  final VoidCallback onMessage;

  const MemberActionSheet({
    super.key,
    required this.member,
    required this.myRole,
    required this.onUpdateRole,
    required this.onRemove,
    required this.onBan,
    required this.onMessage,
  });

  static void show(
    BuildContext context, {
    required CommunityMemberModel member,
    required CommunityRole myRole,
    required Function(CommunityRole newRole) onUpdateRole,
    required VoidCallback onRemove,
    required VoidCallback onBan,
    required VoidCallback onMessage,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MemberActionSheet(
        member: member,
        myRole: myRole,
        onUpdateRole: onUpdateRole,
        onRemove: onRemove,
        onBan: onBan,
        onMessage: onMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);
    final isAdmin = myRole == CommunityRole.admin;
    final isTargetAdmin = member.role == CommunityRole.admin;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Member Info Header
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: primaryOrange.withValues(alpha: 0.1),
                  backgroundImage: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                      ? NetworkImage(member.avatarUrl!)
                      : null,
                  child: member.avatarUrl == null || member.avatarUrl!.isEmpty
                      ? Text(
                          member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: primaryOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                      Text(
                        '${member.userName ?? ''} • ${member.role.displayName}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 8),

            // Option 1: Direct Message
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2563EB)),
              title: const Text('Send Direct Message', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                onMessage();
              },
            ),

            // Admin Options: Promote / Demote Moderator
            if (isAdmin && !isTargetAdmin) ...[
              if (member.role == CommunityRole.moderator)
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: Colors.amber),
                  title: const Text('Dismiss as Moderator'),
                  onTap: () {
                    Navigator.pop(context);
                    onUpdateRole(CommunityRole.member);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined, color: Color(0xFF10B981)),
                  title: const Text('Make Community Moderator'),
                  onTap: () {
                    Navigator.pop(context);
                    onUpdateRole(CommunityRole.moderator);
                  },
                ),
            ],

            // Remove Option: Allowed for Admin and Moderator (non-admin target)
            if ((isAdmin || myRole == CommunityRole.moderator) && !isTargetAdmin) ...[
              ListTile(
                leading: const Icon(Icons.person_remove_outlined, color: Color(0xFFEF4444)),
                title: const Text('Remove from Community', style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAction(
                    context,
                    title: 'Remove Member?',
                    content: 'Are you sure you want to remove ${member.fullName} from this community?',
                    confirmText: 'Remove',
                    isDanger: true,
                    onConfirm: onRemove,
                  );
                },
              ),
            ],

            // Ban Option: Strictly restricted to Admin/Owner only
            if (isAdmin && !isTargetAdmin) ...[
              ListTile(
                leading: const Icon(Icons.block_rounded, color: Colors.red),
                title: const Text('Ban Member Permanently', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAction(
                    context,
                    title: 'Ban Member?',
                    content: 'Banning will immediately remove ${member.fullName} and prevent them from rejoining.',
                    confirmText: 'Ban Permanently',
                    isDanger: true,
                    onConfirm: onBan,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmText,
    required bool isDanger,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDanger ? const Color(0xFFEF4444) : const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}
