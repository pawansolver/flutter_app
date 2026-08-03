import 'package:flutter/material.dart';

class MessageActionsSheet extends StatefulWidget {
  const MessageActionsSheet({
    super.key,
    required this.isPinned,
    required this.onDeleteForMe,
    this.onReply,
    this.onEdit,
    this.onCopy,
    this.onForward,
    this.onPin,
    this.onUnsend,
    this.onRetry,
    this.initiallyShowMore = false,
    this.deleteLabel = 'Delete for me',
  });

  final bool isPinned;
  final VoidCallback? onReply;
  final VoidCallback onDeleteForMe;
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onForward;
  final VoidCallback? onPin;
  final VoidCallback? onUnsend;
  final VoidCallback? onRetry;
  final bool initiallyShowMore;
  final String deleteLabel;

  @override
  State<MessageActionsSheet> createState() => _MessageActionsSheetState();
}

class _MessageActionsSheetState extends State<MessageActionsSheet> {
  late bool _showMore;

  @override
  void initState() {
    super.initState();
    _showMore = widget.initiallyShowMore;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ActionButton(
                    icon: Icons.reply_rounded,
                    label: 'Reply',
                    onTap: widget.onReply,
                  ),
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    onTap: widget.onEdit,
                  ),
                  _ActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    onTap: widget.onCopy,
                  ),
                  _ActionButton(
                    icon: _showMore ? Icons.expand_less : Icons.more_horiz,
                    label: 'More',
                    onTap: () => setState(() => _showMore = !_showMore),
                  ),
                ],
              ),
              if (_showMore) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                if (widget.onRetry != null)
                  _MoreAction(
                    icon: Icons.refresh_rounded,
                    label: 'Retry send',
                    onTap: widget.onRetry,
                  ),
                _MoreAction(
                  icon: Icons.forward_rounded,
                  label: 'Forward',
                  onTap: widget.onForward,
                ),
                _MoreAction(
                  icon: widget.isPinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                  label: widget.isPinned ? 'Unpin message' : 'Pin message',
                  onTap: widget.onPin,
                ),
                _MoreAction(
                  icon: Icons.delete_outline,
                  label: widget.deleteLabel,
                  onTap: widget.onDeleteForMe,
                ),
                if (widget.onUnsend != null)
                  _MoreAction(
                    icon: Icons.undo_rounded,
                    label: 'Unsend for everyone',
                    color: Colors.redAccent,
                    onTap: widget.onUnsend,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: enabled ? 1 : .35,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 23),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreAction extends StatelessWidget {
  const _MoreAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      enabled: onTap != null,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}
