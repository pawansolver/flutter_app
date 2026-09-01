import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/event_model.dart';
import '../event_detail_screen.dart';

class EventCard extends StatelessWidget {
  final EventModel event;
  final ValueChanged<String>? onRsvpChanged;

  const EventCard({
    super.key,
    required this.event,
    this.onRsvpChanged,
  });

  String _formatMonth(DateTime? dt) {
    if (dt == null) return 'UPCOMING';
    return DateFormat('MMM').format(dt).toUpperCase();
  }

  String _formatDay(DateTime? dt) {
    if (dt == null) return '--';
    return DateFormat('dd').format(dt);
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = event.coverImage != null && event.coverImage!.trim().isNotEmpty;
    final monthStr = _formatMonth(event.startAt);
    final dayStr = _formatDay(event.startAt);
    final timeStr = _formatTime(event.startAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailScreen(
                eventId: event.id,
                initialEvent: event,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Image / Badge Banner ────────────────────────────
            if (hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    event.coverImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF3F4F6),
                      child: const Center(
                        child: Icon(Icons.event, size: 48, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Date Calendar Badge ───────────────────────────
                  Container(
                    width: 54,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          monthStr,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dayStr,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // ── Event Information ─────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category & Status pill
                        Row(
                          children: [
                            if (event.category != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${event.category?.icon ?? ''} ${event.category?.name ?? ''}'.trim(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            if (event.isCancelled) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'CANCELLED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (event.distanceKm != null)
                              Text(
                                '${event.distanceKm} km away',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Title
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Time & Location
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 14, color: Color(0xFF6B7280)),
                            const SizedBox(width: 4),
                            Text(
                              timeStr,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF6B7280)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.venueDisplay,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            // ── Bottom Attendance Bar ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.people_outline, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(
                    '${event.goingCount} Going',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  if (event.interestedCount > 0) ...[
                    const Text(' • ', style: TextStyle(color: Color(0xFF9CA3AF))),
                    Text(
                      '${event.interestedCount} Interested',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                  const Spacer(),
                  if (event.myRsvpStatus != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: event.myRsvpStatus == 'going'
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: event.myRsvpStatus == 'going'
                              ? const Color(0xFF10B981)
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Text(
                        event.myRsvpStatus == 'going' ? '✓ Going' : event.myRsvpStatus!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: event.myRsvpStatus == 'going'
                              ? const Color(0xFF059669)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                    )
                  else
                    const Text(
                      'View Details →',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
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
