import 'package:flutter/material.dart';
import '../../../models/community_models.dart';

class CommunityPollCard extends StatefulWidget {
  final CommunityPollModel poll;
  final Function(int pollId, int optionId) onVote;

  const CommunityPollCard({
    super.key,
    required this.poll,
    required this.onVote,
  });

  @override
  State<CommunityPollCard> createState() => _CommunityPollCardState();
}

class _CommunityPollCardState extends State<CommunityPollCard> {
  int? _selectedOptionId;

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    final totalVotes = widget.poll.totalVotes > 0 ? widget.poll.totalVotes : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: primaryOrange.withOpacity(0.1),
                child: Text(
                  widget.poll.createdByName.isNotEmpty ? widget.poll.createdByName[0].toUpperCase() : 'A',
                  style: const TextStyle(
                    color: primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.poll.createdByName,
                    style: const TextStyle(
                      color: darkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Text(
                    'Community Poll',
                    style: TextStyle(
                      color: greySubtext,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.poll_rounded, color: Color(0xFF3B82F6), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Live Poll',
                      style: TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
              fontSize: 16,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // Options List
          ...widget.poll.options.map((option) {
            final double percentage = (option.votesCount / totalVotes) * 100;
            final isVoted = option.isVotedByMe || _selectedOptionId == option.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: widget.poll.hasVoted || _selectedOptionId != null
                    ? null
                    : () {
                        setState(() => _selectedOptionId = option.id);
                        widget.onVote(widget.poll.id, option.id);
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isVoted ? primaryOrange : const Color(0xFFE5E7EB),
                      width: isVoted ? 1.5 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Progress percentage bar fill
                      if (widget.poll.hasVoted || _selectedOptionId != null)
                        FractionallySizedBox(
                          widthFactor: (percentage / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isVoted ? primaryOrange.withOpacity(0.18) : const Color(0xFFE5E7EB).withOpacity(0.6),
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
                              isVoted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: isVoted ? primaryOrange : greySubtext,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                option.text,
                                style: TextStyle(
                                  color: darkText,
                                  fontWeight: isVoted ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (widget.poll.hasVoted || _selectedOptionId != null)
                              Text(
                                '${percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: isVoted ? primaryOrange : greySubtext,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
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
          // Total votes count
          Row(
            children: [
              const Icon(Icons.people_outline, size: 14, color: greySubtext),
              const SizedBox(width: 4),
              Text(
                '${widget.poll.totalVotes} total votes',
                style: const TextStyle(
                  color: greySubtext,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
