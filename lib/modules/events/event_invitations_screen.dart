import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import 'event_detail_screen.dart';

class EventInvitationsScreen extends StatefulWidget {
  const EventInvitationsScreen({super.key});

  @override
  State<EventInvitationsScreen> createState() => _EventInvitationsScreenState();
}

class _EventInvitationsScreenState extends State<EventInvitationsScreen> {
  final _eventService = EventService();

  bool _isLoading = true;
  String? _errorMessage;
  List<EventInvitationModel> _invitations = [];
  String _selectedStatus = 'all';

  final _statuses = const [
    {'key': 'all', 'label': 'All'},
    {'key': 'pending', 'label': 'Pending'},
    {'key': 'accepted', 'label': 'Accepted'},
    {'key': 'declined', 'label': 'Declined'},
  ];

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _eventService.getMyInvitations(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _invitations = res.invitations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _respond(EventInvitationModel inv, bool accept) async {
    try {
      await _eventService.respondToInvitation(inv.id, accept: accept);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Invitation accepted! Added to RSVPs.' : 'Invitation declined.'),
            backgroundColor: accept ? Colors.green : Colors.grey.shade700,
          ),
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Invitations'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadInvitations),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final st = _statuses[index];
                final isSelected = _selectedStatus == st['key'];
                return ChoiceChip(
                  label: Text(st['label']!),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFFF4EC),
                  backgroundColor: const Color(0xFFF3F4F6),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFFF18D38) : const Color(0xFF4B5563),
                  ),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFF18D38) : const Color(0xFFE5E7EB),
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedStatus = st['key']!);
                      _loadInvitations();
                    }
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Invitations list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF18D38)))
                : _errorMessage != null
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.error_outline, color: Colors.red.shade600, size: 48),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Unable to load invitations',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                textAlign: TextAlign.center,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _loadInvitations,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF18D38),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFFF18D38),
                        onRefresh: _loadInvitations,
                        child: _invitations.isEmpty
                            ? const Center(
                                child: Text('No event invitations found', style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _invitations.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final inv = _invitations[index];
                                  final event = inv.event;
                                  final inviterName = inv.inviter?.userName ?? 'A friend';

                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: event != null
                                          ? () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => EventDetailScreen(eventId: event.id),
                                                ),
                                              ).then((_) => _loadInvitations());
                                            }
                                          : null,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: const Color(0xFFFFF4EC),
                                                  child: Text(
                                                    inviterName.isNotEmpty ? inviterName[0].toUpperCase() : 'U',
                                                    style: const TextStyle(color: Color(0xFFF18D38), fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '$inviterName invited you to:',
                                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                      ),
                                                      Text(
                                                        event?.title ?? 'Event #${inv.eventId}',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                _buildStatusBadge(inv.status),
                                              ],
                                            ),
                                            if (event?.startAt != null) ...[
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '${event!.startAt!.toLocal()}'.split('.')[0],
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                                  if (event.venueDisplay.isNotEmpty) ...[
                                                    const SizedBox(width: 12),
                                                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        event.venueDisplay,
                                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],

                                            // Action buttons for Pending
                                            if (inv.isPending) ...[
                                              const SizedBox(height: 16),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      onPressed: () => _respond(inv, false),
                                                      child: const Text('Decline'),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      onPressed: () => _respond(inv, true),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF10B981),
                                                        foregroundColor: Colors.white,
                                                      ),
                                                      child: const Text('Accept & RSVP'),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.orange.shade50;
    Color fg = Colors.orange.shade800;

    switch (status.toLowerCase()) {
      case 'accepted':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'declined':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      case 'pending':
      default:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
