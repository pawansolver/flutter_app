import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';

class EventParticipantsScreen extends StatefulWidget {
  final int eventId;
  final String eventTitle;
  final int goingCount;
  final int interestedCount;

  const EventParticipantsScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.goingCount,
    required this.interestedCount,
  });

  @override
  State<EventParticipantsScreen> createState() => _EventParticipantsScreenState();
}

class _EventParticipantsScreenState extends State<EventParticipantsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EventService _eventService = EventService();

  // Going
  List<EventParticipantModel> _going = [];
  bool _isLoadingGoing = true;
  bool _hasMoreGoing = false;
  String? _goingCursor;
  bool _isLoadingMoreGoing = false;

  // Interested
  List<EventParticipantModel> _interested = [];
  bool _isLoadingInterested = false;
  bool _hasMoreInterested = false;
  String? _interestedCursor;
  bool _isLoadingMoreInterested = false;

  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadGoing(refresh: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1 && _interested.isEmpty && !_isLoadingInterested) {
      _loadInterested(refresh: true);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final cur = _scrollController.position.pixels;
    if (cur >= max - 200) {
      if (_tabController.index == 0 && _hasMoreGoing && !_isLoadingMoreGoing) {
        _loadGoing(cursor: _goingCursor);
      } else if (_tabController.index == 1 && _hasMoreInterested && !_isLoadingMoreInterested) {
        _loadInterested(cursor: _interestedCursor);
      }
    }
  }

  Future<void> _loadGoing({bool refresh = false, String? cursor}) async {
    if (refresh) {
      setState(() { _isLoadingGoing = true; _error = null; });
    } else {
      setState(() => _isLoadingMoreGoing = true);
    }
    try {
      final res = await _eventService.getEventParticipants(
        widget.eventId, status: 'going', cursor: cursor, limit: 20,
      );
      if (mounted) {
        setState(() {
          if (refresh) { _going = res.participants; } else { _going.addAll(res.participants); }
          _goingCursor = res.nextCursor;
          _hasMoreGoing = res.hasMore;
          _isLoadingGoing = false;
          _isLoadingMoreGoing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingGoing = false; _isLoadingMoreGoing = false; _error = e.toString(); });
    }
  }

  Future<void> _loadInterested({bool refresh = false, String? cursor}) async {
    if (refresh) {
      setState(() { _isLoadingInterested = true; _error = null; });
    } else {
      setState(() => _isLoadingMoreInterested = true);
    }
    try {
      final res = await _eventService.getEventParticipants(
        widget.eventId, status: 'interested', cursor: cursor, limit: 20,
      );
      if (mounted) {
        setState(() {
          if (refresh) { _interested = res.participants; } else { _interested.addAll(res.participants); }
          _interestedCursor = res.nextCursor;
          _hasMoreInterested = res.hasMore;
          _isLoadingInterested = false;
          _isLoadingMoreInterested = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingInterested = false; _isLoadingMoreInterested = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Participants', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w800, fontSize: 18)),
            Text(widget.eventTitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: [
            Tab(text: '✅ Going (${widget.goingCount})'),
            Tab(text: '⭐ Interested (${widget.interestedCount})'),
          ],
        ),
      ),
      body: _error != null
          ? _buildError()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_going, _isLoadingGoing, _hasMoreGoing, () => _loadGoing(refresh: true)),
                _buildList(_interested, _isLoadingInterested, _hasMoreInterested, () => _loadInterested(refresh: true)),
              ],
            ),
    );
  }

  Widget _buildList(
    List<EventParticipantModel> list,
    bool isLoading,
    bool hasMore,
    VoidCallback onRefresh,
  ) {
    if (isLoading && list.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No participants yet', style: TextStyle(color: Color(0xFF6B7280), fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: const Color(0xFF2563EB),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == list.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
            );
          }
          return _buildParticipantTile(list[index]);
        },
      ),
    );
  }

  Widget _buildParticipantTile(EventParticipantModel p) {
    final name = p.user?.userName ?? 'User #${p.userId}';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final avatarUrl = p.user?.profileImage;
    final statusColor = p.status == 'going' ? const Color(0xFF059669) : const Color(0xFFD97706);
    final statusIcon = p.status == 'going' ? '✅' : '⭐';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFEFF6FF),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(initial, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB), fontSize: 16))
                : null,
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111827))),
                if (p.joinedAt != null)
                  Text(
                    'Joined ${_formatDate(p.joinedAt!)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
              ],
            ),
          ),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$statusIcon ${p.status[0].toUpperCase()}${p.status.substring(1)}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadGoing(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
