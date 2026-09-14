import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../widgets/custom_drawer.dart';
import 'widgets/create_event_sheet.dart';
import 'widgets/event_card.dart';
import 'event_invitations_screen.dart';

class EventsScreen extends StatefulWidget {
  final int? societyId;
  final String? societyName;

  const EventsScreen({
    super.key,
    this.societyId,
    this.societyName,
  });

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EventService _eventService = EventService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<EventCategoryModel> _categories = [];
  int? _selectedCategoryId;

  // Feeds
  List<EventModel> _upcomingEvents = [];
  List<EventModel> _nearbyEvents = [];
  List<EventModel> _myRsvps = [];

  bool _isLoadingUpcoming = true;
  bool _isLoadingNearby = false;
  bool _isLoadingRsvps = false;

  String? _upcomingCursor;
  String? _nearbyCursor;
  String? _rsvpsCursor;

  bool _hasMoreUpcoming = false;
  bool _hasMoreNearby = false;
  bool _hasMoreRsvps = false;

  bool _isLoadingMore = false;
  String? _errorMessage;

  // Location for Nearby
  double? _userLat;
  double? _userLng;
  bool _isLocating = false;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);

    _loadCategories();
    _loadUpcoming(refresh: true);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;
    if (index == 0 && _upcomingEvents.isEmpty && !_isLoadingUpcoming) {
      _loadUpcoming(refresh: true);
    } else if (index == 1 && _nearbyEvents.isEmpty && !_isLoadingNearby) {
      _initNearbyLocationAndFetch();
    } else if (index == 2 && _myRsvps.isEmpty && !_isLoadingRsvps) {
      _loadMyRsvps(refresh: true);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll - 200) {
      if (_tabController.index == 0 && _hasMoreUpcoming) {
        _loadUpcoming(cursor: _upcomingCursor);
      } else if (_tabController.index == 1 && _hasMoreNearby) {
        _loadNearby(cursor: _nearbyCursor);
      } else if (_tabController.index == 2 && _hasMoreRsvps) {
        _loadMyRsvps(cursor: _rsvpsCursor);
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _eventService.getEventCategories();
      if (mounted) {
        setState(() => _categories = cats);
      }
    } catch (_) {}
  }

  // ── 1. Upcoming Events ─────────────────────────────────────────
  Future<void> _loadUpcoming({bool refresh = false, String? cursor}) async {
    if (refresh) {
      setState(() {
        _isLoadingUpcoming = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _eventService.getUpcomingEvents(
        categoryId: _selectedCategoryId,
        societyId: widget.societyId,
        search: _searchController.text.trim(),
        cursor: cursor,
        limit: 15,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _upcomingEvents = res.events;
          } else {
            _upcomingEvents.addAll(res.events);
          }
          _upcomingCursor = res.nextCursor;
          _hasMoreUpcoming = res.hasMore;
          _isLoadingUpcoming = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUpcoming = false;
          _isLoadingMore = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // ── 2. Nearby Events ───────────────────────────────────────────
  Future<void> _initNearbyLocationAndFetch() async {
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      }
    } catch (_) {
      // Default fallback coordinates (e.g. NCR / Delhi-Noida)
      _userLat ??= 28.6280;
      _userLng ??= 77.3649;
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
        _loadNearby(refresh: true);
      }
    }
  }

  Future<void> _loadNearby({bool refresh = false, String? cursor}) async {
    final lat = _userLat ?? 28.6280;
    final lng = _userLng ?? 77.3649;

    if (refresh) {
      setState(() {
        _isLoadingNearby = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _eventService.getNearbyEvents(
        lat: lat,
        lng: lng,
        radiusKm: 50,
        categoryId: _selectedCategoryId,
        cursor: cursor,
        limit: 15,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _nearbyEvents = res.events;
          } else {
            _nearbyEvents.addAll(res.events);
          }
          _nearbyCursor = res.nextCursor;
          _hasMoreNearby = res.hasMore;
          _isLoadingNearby = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNearby = false;
          _isLoadingMore = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // ── 3. My RSVPs ────────────────────────────────────────────────
  Future<void> _loadMyRsvps({bool refresh = false, String? cursor}) async {
    if (refresh) {
      setState(() {
        _isLoadingRsvps = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _eventService.getMyRsvps(
        cursor: cursor,
        limit: 15,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _myRsvps = res.events;
          } else {
            _myRsvps.addAll(res.events);
          }
          _rsvpsCursor = res.nextCursor;
          _hasMoreRsvps = res.hasMore;
          _isLoadingRsvps = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRsvps = false;
          _isLoadingMore = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (_tabController.index == 0) {
        _loadUpcoming(refresh: true);
      }
    });
  }

  void _onCategorySelected(int? categoryId) {
    setState(() => _selectedCategoryId = categoryId);
    if (_tabController.index == 0) {
      _loadUpcoming(refresh: true);
    } else if (_tabController.index == 1) {
      _loadNearby(refresh: true);
    }
  }

  void _openCreateSheet() {
    CreateEventSheet.show(
      context,
      societyId: widget.societyId,
      onEventCreated: (newEvent) {
        setState(() {
          _upcomingEvents.insert(0, newEvent);
          _myRsvps.insert(0, newEvent);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      drawer: widget.societyId != null ? null : const CustomDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.societyId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          widget.societyId != null ? '${widget.societyName ?? "Society"} Events' : 'Events',
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline, color: Color(0xFFF18D38), size: 26),
            tooltip: 'Event Invitations',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventInvitationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFF18D38), size: 28),
            tooltip: 'Create Event',
            onPressed: _openCreateSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFF18D38),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFFF18D38),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Nearby'),
            Tab(text: 'My RSVPs'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: const Color(0xFFF18D38),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Event', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // ── Search Bar & Category Filters (For Upcoming / Nearby) ─
          if (_tabController.index != 2) ...[
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Search Input
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search events, topics, or venues...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadUpcoming(refresh: true);
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Category Pills
                  if (_categories.isNotEmpty)
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildCategoryChip(null, 'All Categories'),
                          ..._categories.map((c) => _buildCategoryChip(c.id, '${c.icon ?? ''} ${c.name}'.trim())),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ],

          // ── Tab View Feeds ────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUpcomingTab(),
                _buildNearbyTab(),
                _buildMyRsvpsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(int? id, String label) {
    final isSelected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onCategorySelected(id),
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
      ),
    );
  }

  Widget _buildUpcomingTab() {
    if (_isLoadingUpcoming) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF18D38)));
    }

    if (_upcomingEvents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available,
        title: 'No Upcoming Events',
        message: 'There are no events matching your criteria right now.',
        actionLabel: 'Create First Event',
        onAction: _openCreateSheet,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFF18D38),
      onRefresh: () => _loadUpcoming(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _upcomingEvents.length + (_hasMoreUpcoming ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _upcomingEvents.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFF18D38))),
            );
          }
          return EventCard(event: _upcomingEvents[index]);
        },
      ),
    );
  }

  Widget _buildNearbyTab() {
    if (_isLocating || _isLoadingNearby) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFF18D38)),
            SizedBox(height: 12),
            Text('Finding events near you...', style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    if (_nearbyEvents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.near_me_outlined,
        title: 'No Events Nearby',
        message: 'No events found within 50 km of your location.',
        actionLabel: 'Host an Event Here',
        onAction: _openCreateSheet,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFF18D38),
      onRefresh: () => _loadNearby(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _nearbyEvents.length + (_hasMoreNearby ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _nearbyEvents.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFF18D38))),
            );
          }
          return EventCard(event: _nearbyEvents[index]);
        },
      ),
    );
  }

  Widget _buildMyRsvpsTab() {
    if (_isLoadingRsvps) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF18D38)));
    }

    if (_errorMessage != null && _myRsvps.isEmpty) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        title: 'Unable to Load RSVPs',
        message: 'Could not retrieve your event RSVPs. Please check your connection and try again.',
        actionLabel: 'Retry',
        onAction: () => _loadMyRsvps(refresh: true),
      );
    }

    if (_myRsvps.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_border,
        title: 'No RSVPs Yet',
        message: 'You have not RSVPed to any events yet. Explore upcoming events to join!',
        actionLabel: 'Explore Events',
        onAction: () => _tabController.animateTo(0),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFF18D38),
      onRefresh: () => _loadMyRsvps(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myRsvps.length + (_hasMoreRsvps ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _myRsvps.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFF18D38))),
            );
          }
          return EventCard(event: _myRsvps[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF4EC),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: const Color(0xFFF18D38)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF18D38),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
