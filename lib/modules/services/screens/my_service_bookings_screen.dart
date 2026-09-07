import 'package:flutter/material.dart';

import '../../../models/service_models.dart';
import '../../../services/service_marketplace_service.dart';
import '../widgets/service_review_sheet.dart';
import 'booking_detail_screen.dart';

class MyServiceBookingsScreen extends StatefulWidget {
  const MyServiceBookingsScreen({super.key});

  @override
  State<MyServiceBookingsScreen> createState() => _MyServiceBookingsScreenState();
}

class _MyServiceBookingsScreenState extends State<MyServiceBookingsScreen>
    with SingleTickerProviderStateMixin {
  final _service = ServiceMarketplaceService();
  late TabController _tabController;

  bool _loading = true;
  String? _errorMessage;
  List<ServiceBookingModel> _bookings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final list = await _service.getCustomerBookings();
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
    switch (tabIndex) {
      case 1:
        return _bookings.where((b) => b.status == 'pending').toList();
      case 2:
        return _bookings.where((b) => b.status == 'confirmed').toList();
      case 3:
        return _bookings.where((b) => b.status == 'completed').toList();
      case 4:
        return _bookings.where((b) => b.status == 'cancelled').toList();
      default:
        return _bookings;
    }
  }

  Future<void> _handleCancelBooking(ServiceBookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Booking?'),
        content: const Text('Are you sure you want to cancel this booking request?'),
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
            child: const Text('Cancel Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.cancelBooking(booking.id);
        setState(() {
          _bookings = _bookings.map((b) {
            if (b.id == booking.id) return b.copyWith(status: 'cancelled');
            return b;
          }).toList();
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled.'), behavior: SnackBarBehavior.floating),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _openReviewSheet(ServiceBookingModel booking) async {
    final reviewed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ServiceReviewSheet(booking: booking),
    );

    if (reviewed == true) {
      _fetchBookings();
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Bookings',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49.0),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFF111827),
                unselectedLabelColor: const Color(0xFF6B7280),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                indicatorColor: const Color(0xFF111827),
                indicatorWeight: 2.5,
                tabs: [
                  Tab(text: 'All (${_bookings.length})'),
                  Tab(text: 'Pending (${_bookings.where((b) => b.status == 'pending').length})'),
                  Tab(text: 'Confirmed (${_bookings.where((b) => b.status == 'confirmed').length})'),
                  Tab(text: 'Completed (${_bookings.where((b) => b.status == 'completed').length})'),
                  Tab(text: 'Cancelled (${_bookings.where((b) => b.status == 'cancelled').length})'),
                ],
              ),
              Container(color: const Color(0xFFE5E7EB), height: 1.0),
            ],
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF111827)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text('Unable to load bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(_errorMessage!, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchBookings,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111827)),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: List.generate(5, (index) => _buildTabList(index)),
    );
  }

  Widget _buildTabList(int tabIndex) {
    final list = _getFilteredBookings(tabIndex);

    if (list.isEmpty) {
      return _buildEmptyState(tabIndex);
    }

    return RefreshIndicator(
      color: const Color(0xFF111827),
      onRefresh: _fetchBookings,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final b = list[index];
          return _buildBookingCard(b);
        },
      ),
    );
  }

  Widget _buildBookingCard(ServiceBookingModel b) {
    final dateStr = b.scheduledAt != null
        ? '${b.scheduledAt!.day}/${b.scheduledAt!.month}/${b.scheduledAt!.year}'
        : 'Date TBD';

    return InkWell(
      onTap: () async {
        final updated = await Navigator.push<ServiceBookingModel?>(
          context,
          MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b)),
        );
        if (updated != null) _fetchBookings();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking #${b.id}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                ),
                _buildStatusPill(b.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              b.serviceTitle ?? 'Service Request',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(b.customerName ?? 'Neighborhood Pro', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                const Spacer(),
                if (b.amount != null)
                  Text('₹${b.amount!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF3F4F6)),

            // Contextual Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'View Details →',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2B7BB9)),
                ),
                if (b.status == 'completed') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _openReviewSheet(b),
                    icon: const Icon(Icons.star, size: 14, color: Colors.white),
                    label: const Text('Rate & Review', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ] else if (b.status == 'pending' || b.status == 'confirmed') ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _handleCancelBooking(b),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
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

  Widget _buildEmptyState(int tabIndex) {
    String title = 'No bookings found';
    String desc = 'You have not booked any local services yet.';

    if (tabIndex == 1) {
      title = 'No pending requests';
      desc = 'You have no bookings currently waiting for provider acceptance.';
    } else if (tabIndex == 2) {
      title = 'No confirmed bookings';
      desc = 'Confirmed upcoming appointments will appear here.';
    } else if (tabIndex == 3) {
      title = 'No completed bookings';
      desc = 'Services marked as completed by providers will appear here for review.';
    } else if (tabIndex == 4) {
      title = 'No cancelled bookings';
      desc = 'Cancelled service requests will appear here.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 44, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 6),
            Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}
