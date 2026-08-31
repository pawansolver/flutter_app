import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/community_models.dart';

class CommunityPollCard extends StatefulWidget {
  final CommunityPollModel poll;
  final Future<void> Function(int pollId, int optionId) onVote;
  final Function(CommunityPollModel poll)? onDeletePoll;
  final bool canDelete;

  const CommunityPollCard({
    super.key,
    required this.poll,
    required this.onVote,
    this.onDeletePoll,
    this.canDelete = false,
  });

  @override
  State<CommunityPollCard> createState() => _CommunityPollCardState();
}

class _CommunityPollCardState extends State<CommunityPollCard> {
  int? _optimisticSelectedOptionId;
  bool _isVoting = false;

  String _formatTimeRemaining(DateTime? endsAt) {
    if (endsAt == null) return 'No expiry';
    final now = DateTime.now();
    if (endsAt.isBefore(now)) {
      return 'Ended ${DateFormat('dd MMM yyyy').format(endsAt)}';
    }
    final diff = endsAt.difference(now);
    if (diff.inDays > 0) {
      return 'Ends in ${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'}';
    }
    if (diff.inHours > 0) {
      return 'Ends in ${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'}';
    }
    if (diff.inMinutes > 0) {
      return 'Ends in ${diff.inMinutes} mins';
    }
    return 'Ending soon';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Poll'),
          ],
        ),
        content: Text('Are you sure you want to delete "${widget.poll.question}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeletePoll?.call(widget.poll);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    final isExpired =
        widget.poll.endsAt != null && widget.poll.endsAt!.isBefore(DateTime.now());
    final hasVoted = widget.poll.hasVoted || _optimisticSelectedOptionId != null;

    // Calculate effective total votes
    int totalVotes = widget.poll.totalVotes;
    if (_optimisticSelectedOptionId != null && !widget.poll.hasVoted) {
      totalVotes += 1;
    }
    final divisor = totalVotes > 0 ? totalVotes : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header & Poll Status
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: primaryOrange.withValues(alpha: 0.1),
                child: Text(
                  widget.poll.createdByName.isNotEmpty
                      ? widget.poll.createdByName[0].toUpperCase()
                      : 'A',
                  style: const TextStyle(
                    color: primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.poll.createdByName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: darkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatTimeRemaining(widget.poll.endsAt),
                      style: const TextStyle(
                        color: greySubtext,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge (Live vs Ended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isExpired
                      ? const Color(0xFFF3F4F6)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpired ? Icons.lock_clock_outlined : Icons.poll_rounded,
                      color: isExpired
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF3B82F6),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isExpired ? 'Ended' : 'Live Poll',
                      style: TextStyle(
                        color: isExpired
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF3B82F6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Delete Button (if authorized)
              if (widget.canDelete && widget.onDeletePoll != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.grey,
                    size: 18,
                  ),
                  tooltip: 'Delete Poll',
                  padding: const EdgeInsets.only(left: 6),
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(context),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Question
          Text(
            widget.poll.question,
            style: const TextStyle(
              color: darkText,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // Options List
          ...widget.poll.options.map((option) {
            int optionVotes = option.votesCount;
            if (_optimisticSelectedOptionId != null &&
                _optimisticSelectedOptionId == option.id &&
                !option.isVotedByMe) {
              optionVotes += 1;
            } else if (_optimisticSelectedOptionId != null &&
                _optimisticSelectedOptionId != option.id &&
                option.isVotedByMe) {
              optionVotes = (optionVotes - 1).clamp(0, 999999);
            }

            final double percentage = (optionVotes / divisor) * 100;
            final isSelected = _optimisticSelectedOptionId == option.id ||
                (_optimisticSelectedOptionId == null && option.isVotedByMe);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: (isExpired || _isVoting)
                    ? null
                    : () async {
                        if (isSelected && hasVoted) return; // already selected
                        setState(() {
                          _optimisticSelectedOptionId = option.id;
                          _isVoting = true;
                        });
                        try {
                          await widget.onVote(widget.poll.id, option.id);
                        } catch (error) {
                          if (!context.mounted) return;
                          setState(() => _optimisticSelectedOptionId = null);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        } finally {
                          if (mounted) setState(() => _isVoting = false);
                        }
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? primaryOrange
                          : const Color(0xFFE5E7EB),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Progress percentage bar fill
                      if (hasVoted || isExpired)
                        FractionallySizedBox(
                          widthFactor: (percentage / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryOrange.withValues(alpha: 0.18)
                                  : const Color(0xFFE5E7EB).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                        ),

                      // Option text and stats
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : (hasVoted || isExpired
                                      ? Icons.radio_button_unchecked_rounded
                                      : Icons.radio_button_off_rounded),
                              size: 18,
                              color: isSelected ? primaryOrange : greySubtext,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                option.text,
                                style: TextStyle(
                                  color: darkText,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (hasVoted || isExpired)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$optionVotes ${optionVotes == 1 ? 'vote' : 'votes'}',
                                    style: const TextStyle(
                                      color: greySubtext,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${percentage.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: isSelected
                                          ? primaryOrange
                                          : darkText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 6),
          // Total votes footer & status summary
          Row(
            children: [
              const Icon(Icons.people_outline, size: 14, color: greySubtext),
              const SizedBox(width: 4),
              Text(
                '$totalVotes ${totalVotes == 1 ? 'total vote' : 'total votes'}',
                style: const TextStyle(
                  color: greySubtext,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hasVoted) ...[
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: greySubtext, fontSize: 12)),
                const SizedBox(width: 8),
                const Text(
                  'Vote registered',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

