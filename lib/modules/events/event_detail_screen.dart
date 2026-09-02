import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/community_service.dart';
import '../../models/community_models.dart';
import 'event_participants_screen.dart';
import 'widgets/edit_event_sheet.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;
  final EventModel? initialEvent;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.initialEvent,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventService _eventService = EventService();
  final AuthService _authService = AuthService();

  EventModel? _event;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRsvpUpdating = false;
  bool _isActionLoading = false;
  int? _currentUserId;
  bool _isGlobalAdmin = false;
  CommunityRole? _myCommunityRole;

  @override
  void initState() {
    super.initState();
    _event = widget.initialEvent;
    if (_event != null) {
      _isLoading = false;
    }
    _fetchDetails();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    _currentUserId = await _authService.getUserId();
    _isGlobalAdmin = await _authService.isGlobalAdmin();
    if (_event?.communityId != null) {
      await _loadCommunityRole(_event!.communityId!);
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadCommunityRole(int communityId) async {
    try {
      final details = await CommunityService().getCommunityDetails(communityId);
      if (mounted) {
        setState(() {
          _myCommunityRole = details.myRole;
        });
      }
    } catch (_) {}
  }

  bool get _isCreator =>
      _currentUserId != null &&
      _event?.creator != null &&
      _event!.creator!.userId == _currentUserId;

  bool get _isCommunityAdminOrMod =>
      _myCommunityRole == CommunityRole.admin ||
      _myCommunityRole == CommunityRole.moderator;

  bool get _isCommunityAdmin =>
      _myCommunityRole == CommunityRole.admin;

  bool get _canEdit =>
      _isCreator || _isGlobalAdmin || _isCommunityAdminOrMod;

  bool get _canCancel =>
      (_event != null && !_event!.isCancelled) &&
      (_isCreator || _isGlobalAdmin || _isCommunityAdminOrMod);

  bool get _canDelete =>
      _isCreator || _isGlobalAdmin || _isCommunityAdmin;

  bool get _hasManagementPrivileges =>
      _canEdit || _canCancel || _canDelete;

  Future<void> _fetchDetails() async {
    try {
      final fresh = await _eventService.getEventDetails(widget.eventId);
      if (fresh.communityId != null && _myCommunityRole == null) {
        _loadCommunityRole(fresh.communityId!);
      }
      if (mounted) {
        setState(() {
          _event = fresh;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_event == null) {
            _errorMessage = e.toString();
          }
        });
      }
    }
  }

  Future<void> _handleRsvp(String targetStatus) async {
    if (_event == null || _isRsvpUpdating) return;

    final currentStatus = _event!.myRsvpStatus;
    if (currentStatus == targetStatus) {
      // Toggle off / cancel RSVP
      final prevEvent = _event!;
      setState(() {
        _isRsvpUpdating = true;
        _event = _event!.copyWith(
          myRsvpStatus: null,
          goingCount: targetStatus == 'going' ? (_event!.goingCount - 1).clamp(0, 99999) : _event!.goingCount,
          interestedCount: targetStatus == 'interested' ? (_event!.interestedCount - 1).clamp(0, 99999) : _event!.interestedCount,
        );
      });

      try {
        await _eventService.cancelEventRsvp(widget.eventId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('RSVP removed'), duration: Duration(seconds: 2)),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _event = prevEvent);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isRsvpUpdating = false);
      }
      return;
    }

    // Set new RSVP
    final prevEvent = _event!;
    setState(() {
      _isRsvpUpdating = true;
      int gDelta = 0;
      int iDelta = 0;

      if (currentStatus == 'going') gDelta -= 1;
      if (currentStatus == 'interested') iDelta -= 1;

      if (targetStatus == 'going') gDelta += 1;
      if (targetStatus == 'interested') iDelta += 1;

      _event = _event!.copyWith(
        myRsvpStatus: targetStatus,
        goingCount: (_event!.goingCount + gDelta).clamp(0, 99999),
        interestedCount: (_event!.interestedCount + iDelta).clamp(0, 99999),
      );
    });

    try {
      final res = await _eventService.setEventRsvp(widget.eventId, targetStatus);
      if (mounted) {
        setState(() {
          _event = _event!.copyWith(
            myRsvpStatus: res.status,
            goingCount: res.goingCount,
            interestedCount: res.interestedCount,
            declinedCount: res.declinedCount,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              targetStatus == 'going'
                  ? '🎉 You are going to this event!'
                  : 'Marked as interested',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _event = prevEvent);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update RSVP: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRsvpUpdating = false);
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Date TBD';
    return DateFormat('EEEE, MMMM d, yyyy • hh:mm a').format(dt);
  }

  // ── Owner Actions ─────────────────────────────────────────────

  void _openEdit() {
    if (_event == null) return;
    EditEventSheet.show(
      context,
      event: _event!,
      onEventUpdated: (updated) {
        setState(() => _event = updated);
      },
    );
  }

  Future<void> _handleCancel() async {
    if (_event == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Event', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to cancel this event? All attendees will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      final updated = await _eventService.cancelEvent(_event!.id);
      if (mounted) setState(() { _event = updated; _isActionLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event cancelled.'), backgroundColor: Color(0xFFDC2626)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    if (_event == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
        content: const Text('This action is permanent. Delete this event and remove all RSVPs?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await _eventService.deleteEvent(_event!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted.'), backgroundColor: Color(0xFF374151)),
        );
        Navigator.pop(context, 'deleted');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openParticipants() {
    if (_event == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventParticipantsScreen(
          eventId: _event!.id,
          eventTitle: _event!.title,
          goingCount: _event!.goingCount,
          interestedCount: _event!.interestedCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _event == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && _event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchDetails,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final event = _event!;
    final hasCover = event.coverImage != null && event.coverImage!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          // ── App Bar with Hero Cover Image ─────────────────────────
          SliverAppBar(
            expandedHeight: hasCover ? 240 : 120,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_isActionLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
                )
              else if (_hasManagementPrivileges)
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                  ),
                  onSelected: (val) {
                    if (val == 'edit') _openEdit();
                    if (val == 'cancel') _handleCancel();
                    if (val == 'delete') _handleDelete();
                  },
                  itemBuilder: (_) => [
                    if (_canEdit)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)), SizedBox(width: 10), Text('Edit Event', style: TextStyle(fontWeight: FontWeight.w600))]),
                      ),
                    if (_canCancel)
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Row(children: [Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFD97706)), SizedBox(width: 10), Text('Cancel Event', style: TextStyle(fontWeight: FontWeight.w600))]),
                      ),
                    if (_canDelete)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)), SizedBox(width: 10), Text('Delete Event', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626)))]),
                      ),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: hasCover
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          event.coverImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E293B)),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                      ),
                    ),
            ),
          ),

          // ── Main Details Body ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges: Category, Event Type, Cancelled Status
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (event.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            '${event.category?.icon ?? ''} ${event.category?.name ?? ''}'.trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.eventType.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ),
                      if (event.isCancelled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'CANCELLED',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Date & Time Card ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calendar_today, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Date & Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDateTime(event.startAt),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Location & Venue Card ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_on, color: Color(0xFFD97706), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Venue',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                event.venueDisplay,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              if (event.address != null && event.address!.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  event.address!,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Capacity Progress Bar (if limited) ────────────
                  if (event.maxParticipants != null && event.maxParticipants! > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Capacity',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                              ),
                              Text(
                                '${event.goingCount} / ${event.maxParticipants} Spots filled',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: event.isFull ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (event.goingCount / event.maxParticipants!).clamp(0.0, 1.0),
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                event.isFull ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Host / Organizer Card ─────────────────────────
                  if (event.creator != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFE0E7FF),
                            child: Text(
                              event.creator!.userName.isNotEmpty
                                  ? event.creator!.userName[0].toUpperCase()
                                  : 'H',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4338CA)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Organized by',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                ),
                                Text(
                                  event.creator!.userName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Participants Summary (tappable) ───────────────
                  if (event.goingCount > 0 || event.interestedCount > 0) ...[
                    InkWell(
                      onTap: _openParticipants,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.people_outline, color: Color(0xFF059669), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                                  children: [
                                    TextSpan(
                                      text: '${event.goingCount} Going',
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                    ),
                                    if (event.interestedCount > 0) ...[
                                      const TextSpan(text: '  •  '),
                                      TextSpan(
                                        text: '${event.interestedCount} Interested',
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Description ───────────────────────────────────
                  if (event.description != null && event.description!.trim().isNotEmpty) ...[
                    const Text(
                      'About this event',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        event.description!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Persistent RSVP Bottom Bar ───────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Going Button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: event.isCancelled ? null : () => _handleRsvp('going'),
                  icon: Icon(
                    event.myRsvpStatus == 'going' ? Icons.check_circle : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(event.myRsvpStatus == 'going' ? 'Going ✓' : 'Going'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: event.myRsvpStatus == 'going'
                        ? const Color(0xFF059669)
                        : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: event.myRsvpStatus == 'going' ? 0 : 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Interested Button
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: event.isCancelled ? null : () => _handleRsvp('interested'),
                  icon: Icon(
                    event.myRsvpStatus == 'interested' ? Icons.star : Icons.star_border,
                    size: 18,
                    color: event.myRsvpStatus == 'interested' ? const Color(0xFFD97706) : const Color(0xFF4B5563),
                  ),
                  label: Text(
                    event.myRsvpStatus == 'interested' ? 'Interested ★' : 'Interested',
                    style: TextStyle(
                      color: event.myRsvpStatus == 'interested' ? const Color(0xFFD97706) : const Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: event.myRsvpStatus == 'interested' ? const Color(0xFFFEF3C7) : Colors.white,
                    side: BorderSide(
                      color: event.myRsvpStatus == 'interested' ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
