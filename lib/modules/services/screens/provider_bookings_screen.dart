import 'package:flutter/material.dart';

import '../../../models/service_models.dart';
import '../../../services/service_marketplace_service.dart';
import 'provider_booking_detail_screen.dart';

class ProviderBookingsScreen extends StatefulWidget {
  const ProviderBookingsScreen({super.key, this.initialFilter});

  final String? initialFilter;

  @override
  State<ProviderBookingsScreen> createState() => _ProviderBookingsScreenState();
}

class _ProviderBookingsScreenState extends State<ProviderBookingsScreen>
    with SingleTickerProviderStateMixin {
  final _service = ServiceMarketplaceService();
  late TabController _tabController;

  bool _loading = true;
  String? _errorMessage;
  List<ServiceBookingModel> _bookings = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<String> _tabs = ['All', 'Pending', 'Confirmed', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialFilter != null) {
      final idx = _tabs.indexWhere((t) => t.toLowerCase() == widget.initialFilter!.toLowerCase());
      if (idx != -1) initialIndex = idx;
    }

    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _fetchBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final list = await _service.getProviderBookings();
      if (!mounted) return;
      setState(() {
        _bookings = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  List<ServiceBookingModel> _getFilteredBookings(int tabIndex) {
    final tabName = _tabs[tabIndex].toLowerCase();
    List<ServiceBookingModel> filtered = _bookings;

    if (tabName != 'all') {
      filtered = filtered.where((b) => b.status.toLowerCase() == tabName).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((b) {
        final idMatch = '#${b.id}'.contains(q) || b.id.toString().contains(q);
        final titleMatch = (b.serviceTitle ?? '').toLowerCase().contains(q);
        final customerMatch = (b.customerName ?? '').toLowerCase().contains(q);
        return idMatch || titleMatch || customerMatch;
      }).toList();
    }

    return filtered;
  }

  Future<void> _handleAccept(ServiceBookingModel booking) async {
    try {
      await _service.updateBookingStatus(booking.id, 'confirmed');
      setState(() {
        _bookings = _bookings.map((b) => b.id == booking.id ? b.copyWith(status: 'confirmed') : b).toList();
      });
      _showToast('Booking #${booking.id} confirmed');
    } catch (e) {
      _showToast('Failed to accept booking: $e');
    }
  }

  Future<void> _handleReject(ServiceBookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Booking Request?'),
        content: Text('Are you sure you want to decline request #${booking.id}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.updateBookingStatus(booking.id, 'cancelled');
        setState(() {
          _bookings = _bookings.map((b) => b.id == booking.id ? b.copyWith(status: 'cancelled') : b).toList();
        });
        _showToast('Booking #${booking.id} declined');
      } catch (e) {
        _showToast('Failed to decline booking: $e');
      }
    }
  }

  Future<void> _handleComplete(ServiceBookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Complete this booking?'),
        content: const Text('This will mark the service as completed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.updateBookingStatus(booking.id, 'completed');
        setState(() {
          _bookings = _bookings.map((b) => b.id == booking.id ? b.copyWith(status: 'completed') : b).toList();
        });
        _showToast('Booking #${booking.id} marked as completed');
      } catch (e) {
        _showToast('Failed to complete booking: $e');
      }
    }
  }

  void _openDetail(ServiceBookingModel booking) async {
    final updated = await Navigator.push<ServiceBookingModel>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderBookingDetailScreen(booking: booking),
      ),
    );

    if (updated != null) {
      setState(() {
        _bookings = _bookings.map((b) => b.id == updated.id ? updated : b).toList();
      });
    } else {
      _fetchBookings();
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF111827),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Provider Bookings',
          style: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF111827),
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: const Color(0xFF111827),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by booking #, service, customer...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF6B7280)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Color(0xFF6B7280)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Tab content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF111827)))
                : _errorMessage != null
                    ? _buildErrorState()
                    : TabBarView(
                        controller: _tabController,
                        children: List.generate(_tabs.length, (index) {
                          return _buildTabBookingsList(index);
                        }),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBookingsList(int tabIndex) {
    final filtered = _getFilteredBookings(tabIndex);

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchBookings,
        color: const Color(0xFF111827),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_busy_outlined, size: 32, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${_tabs[tabIndex]} Bookings',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No bookings match your search query.'
                      : 'Requests and appointments will appear here.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBookings,
      color: const Color(0xFF111827),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final booking = filtered[index];
          return _buildBookingCard(booking);
        },
      ),
    );
  }

  Widget _buildBookingCard(ServiceBookingModel booking) {
    final status = booking.status.toLowerCase();
    final isPending = status == 'pending';
    final isConfirmed = status == 'confirmed';
    final isCompleted = status == 'completed';

    final dateStr = booking.scheduledAt != null
        ? '${booking.scheduledAt!.day}/${booking.scheduledAt!.month}/${booking.scheduledAt!.year}'
        : 'Date TBD';
    final timeStr = booking.scheduledAt != null
        ? '${booking.scheduledAt!.hour.toString().padLeft(2, '0')}:${booking.scheduledAt!.minute.toString().padLeft(2, '0')}'
        : 'Time TBD';

    return InkWell(
      onTap: () => _openDetail(booking),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(color: Color(0x03000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Booking #, Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${booking.id}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                ),
                _buildStatusPill(booking.status),
              ],
            ),
            const SizedBox(height: 8),

            // Service Title & Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.serviceTitle ?? 'Service Request',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                ),
                if (booking.amount != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '₹${booking.amount!.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Customer Info
            Row(
              children: [
                const Icon(Icons.person_outline, size: 15, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(
                  booking.customerName ?? 'Neighborhood Resident',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Schedule Info
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text('$dateStr • $timeStr', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF3F4F6)),

            // Contextual Actions per Status
            if (isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _handleReject(booking),
                      child: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _handleAccept(booking),
                      child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ] else if (isConfirmed) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _openDetail(booking),
                      child: const Text('View Details', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _handleComplete(booking),
                      child: const Text('Mark Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Completed or Cancelled
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isCompleted ? '✓ Completed Job' : '✗ Cancelled',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openDetail(booking),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                    child: const Text('View Details →', style: TextStyle(color: Color(0xFF2B7BB9), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'Pending';
        break;
      case 'confirmed':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2B7BB9);
        label = 'Confirmed';
        break;
      case 'completed':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF10B981);
        label = 'Completed';
        break;
      case 'cancelled':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFEF4444);
        label = 'Cancelled';
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            const Text('Failed to load bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _fetchBookings,
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
