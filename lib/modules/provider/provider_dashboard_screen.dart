import 'package:flutter/material.dart';

import '../dashboard/main_dashboard.dart';
import '../../models/service_models.dart';
import '../../services/service_marketplace_service.dart';
import '../../shared/widgets/role_switch_sheet.dart';
import '../services/screens/create_service_flow_screen.dart';
import '../services/screens/manage_availability_screen.dart';
import '../services/screens/my_services_screen.dart';
import '../services/screens/provider_booking_detail_screen.dart';
import '../services/screens/provider_bookings_screen.dart';
import '../services/screens/provider_earnings_screen.dart';
import '../services/screens/provider_reviews_screen.dart';
import '../core/notifications_screen.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  final _service = ServiceMarketplaceService();

  bool _loading = true;
  String? _errorMessage;
  bool _isAuthorized = false;

  // Data
  String _providerName = 'Not available';
  bool _isVerified = false;
  bool _isOnline = true;

  List<ServiceListingModel> _services = [];
  List<ServiceBookingModel> _bookings = [];
  ProviderOverviewStats _stats = const ProviderOverviewStats();

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final authorized = await _service.isProviderAuthorized();
      if (!authorized) {
        if (!mounted) return;
        setState(() {
          _isAuthorized = false;
          _loading = false;
        });
        return;
      }

      // Load Profile, Listings, Bookings, and Reviews in parallel
      final results = await Future.wait([
        _service.getProviderProfile(),
        _service.getProviderListings().catchError((_) => <ServiceListingModel>[]),
        _service.getProviderBookings().catchError((_) => <ServiceBookingModel>[]),
        _service.getReviews().catchError((_) => <ServiceReviewModel>[]),
      ]);

      final profile = results[0] as ServiceProviderProfileModel?;
      final services = results[1] as List<ServiceListingModel>;
      final bookings = results[2] as List<ServiceBookingModel>;
      final reviews = results[3] as List<ServiceReviewModel>;

      double calculatedRating = 0.0;
      if (reviews.isNotEmpty) {
        final sum = reviews.fold<int>(0, (prev, r) => prev + r.rating);
        calculatedRating = sum / reviews.length;
      }

      if (!mounted) return;
      setState(() {
        _isAuthorized = true;
        _providerName = profile?.userName ?? 'Not available';
        _isVerified = profile?.isVerified ?? false;
        _services = services;
        _bookings = bookings;
        _stats = ProviderOverviewStats.fromData(
          services: services,
          bookings: bookings,
          rating: calculatedRating,
        );
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

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
        (route) => false,
      );
    }
  }

  Future<void> _handleAcceptBooking(ServiceBookingModel booking) async {
    try {
      await _service.updateBookingStatus(booking.id, 'confirmed');
      setState(() {
        _bookings = _bookings.map((b) {
          if (b.id == booking.id) {
            return b.copyWith(status: 'confirmed');
          }
          return b;
        }).toList();
        _stats = ProviderOverviewStats.fromData(
          services: _services,
          bookings: _bookings,
        );
      });
      _showToast('Booking #${booking.id} Accepted');
    } catch (e) {
      _showToast('Failed to accept: $e');
    }
  }

  Future<void> _handleRejectBooking(ServiceBookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Booking Request?'),
        content: Text('Are you sure you want to decline this request from ${booking.customerName}?'),
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
          _bookings = _bookings.map((b) {
            if (b.id == booking.id) {
              return b.copyWith(status: 'cancelled');
            }
            return b;
          }).toList();
          _stats = ProviderOverviewStats.fromData(
            services: _services,
            bookings: _bookings,
          );
        });
        _showToast('Booking request declined');
      } catch (e) {
        _showToast('Failed to decline: $e');
      }
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
    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE1EAE4),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
            onPressed: _handleBack,
          ),
          title: const Text(
            'Provider Workspace',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF111827)),
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF111827)));
    }

    // Role Guard Unauthorized State
    if (!_isAuthorized) {
      return _buildUnauthorizedState();
    }

    // Error State
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      color: const Color(0xFF111827),
      onRefresh: _checkAuthAndLoad,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Section
            _buildHeader(),
            const SizedBox(height: 16),

            // 2. Overview Section
            _buildOverviewSection(),
            const SizedBox(height: 20),

            // 3. Quick Actions
            _buildQuickActions(),
            const SizedBox(height: 24),

            // 4. My Services Preview Section
            _buildMyServicesSection(),
            const SizedBox(height: 24),

            // 5. Bookings Section
            _buildBookingsSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── 1. Header Section ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar with Online indicator
          Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF3F4F6),
                ),
                child: const Icon(Icons.person, size: 28, color: Color(0xFF6B7280)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _isOnline ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Provider Name & Verification Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (_isVerified) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified, size: 12, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text(
                              'Verified Pro',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.shield_outlined, size: 12, color: Color(0xFF6B7280)),
                            SizedBox(width: 4),
                            Text(
                              'Not verified',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _isOnline ? '• Online' : '• Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _isOnline ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Online Switch
          Switch(
            value: _isOnline,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: (val) {
              setState(() => _isOnline = val);
              _showToast(val ? 'You are now Online' : 'You are now Offline');
            },
          ),
        ],
      ),
    );
  }

  // ── 2. Overview Section ──────────────────────────────────────────────────
  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid: 2 columns on mobile, 3 columns on wider screens
            final isWide = constraints.maxWidth > 550;
            final cardWidth = isWide
                ? (constraints.maxWidth - 24) / 3
                : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSummaryCard(
                  'Total Services',
                  '${_stats.totalServices}',
                  Icons.design_services,
                  const Color(0xFF2B7BB9),
                  cardWidth,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyServicesScreen()));
                    _checkAuthAndLoad();
                  },
                ),
                _buildSummaryCard(
                  'Pending Bookings',
                  '${_stats.pendingBookings}',
                  Icons.pending_actions,
                  const Color(0xFFF59E0B),
                  cardWidth,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderBookingsScreen(initialFilter: 'Pending')));
                    _checkAuthAndLoad();
                  },
                ),
                _buildSummaryCard(
                  'Upcoming Bookings',
                  '${_stats.upcomingBookings}',
                  Icons.event_available,
                  const Color(0xFF6366F1),
                  cardWidth,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderBookingsScreen(initialFilter: 'Confirmed')));
                    _checkAuthAndLoad();
                  },
                ),
                _buildSummaryCard(
                  'Completed Bookings',
                  '${_stats.completedBookings}',
                  Icons.task_alt,
                  const Color(0xFF10B981),
                  cardWidth,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderBookingsScreen(initialFilter: 'Completed')));
                    _checkAuthAndLoad();
                  },
                ),
                _buildSummaryCard(
                  'Rating',
                  _stats.rating > 0 ? '⭐ ${_stats.rating.toStringAsFixed(1)}' : '--',
                  Icons.star_outline,
                  const Color(0xFFFF6B00),
                  cardWidth,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderReviewsScreen()));
                  },
                ),
                _buildSummaryCard(
                  'Earnings',
                  _stats.completedBookings > 0 ? '₹${_stats.earnings.toStringAsFixed(0)}' : '₹0',
                  Icons.account_balance_wallet_outlined,
                  const Color(0xFF047857),
                  cardWidth,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderEarningsScreen()));
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color, double width, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
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
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Quick Actions ─────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    final actions = [
      {'label': 'Create Service', 'icon': Icons.add_circle_outline, 'color': const Color(0xFF111827), 'action': () async {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const CreateServiceFlowScreen()),
        );
        if (created == true) _checkAuthAndLoad();
      }},
      {'label': 'Manage Services', 'icon': Icons.list_alt, 'color': const Color(0xFF2B7BB9), 'action': () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyServicesScreen()),
        );
        _checkAuthAndLoad();
      }},
      {'label': 'Availability', 'icon': Icons.schedule, 'color': const Color(0xFF10B981), 'action': () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageAvailabilityScreen()),
        );
        _checkAuthAndLoad();
      }},
      {'label': 'Bookings', 'icon': Icons.calendar_month_outlined, 'color': const Color(0xFF6366F1), 'action': () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProviderBookingsScreen()),
        );
        _checkAuthAndLoad();
      }},
      {'label': 'Reviews', 'icon': Icons.rate_review_outlined, 'color': const Color(0xFFFF6B00), 'action': () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProviderReviewsScreen()),
        );
      }},
      {'label': 'Earnings', 'icon': Icons.payments_outlined, 'color': const Color(0xFF047857), 'action': () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProviderEarningsScreen()),
        );
      }},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final colCount = constraints.maxWidth > 550 ? 6 : 3;
            final itemWidth = (constraints.maxWidth - ((colCount - 1) * 10)) / colCount;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: actions.map((act) {
                return InkWell(
                  onTap: act['action'] as VoidCallback,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: itemWidth,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (act['color'] as Color).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(act['icon'] as IconData, size: 20, color: act['color'] as Color),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          act['label'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ── 4. My Services Preview Section ───────────────────────────────────────
  Widget _buildMyServicesSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Services',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            if (_services.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyServicesScreen()));
                  _checkAuthAndLoad();
                },
                child: const Text('View All', style: TextStyle(color: Color(0xFF2B7BB9), fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_services.isEmpty)
          _buildServicesEmptyState()
        else
          Column(
            children: _services.take(3).map((s) => _buildServicePreviewCard(s)).toList(),
          ),
      ],
    );
  }

  Widget _buildServicePreviewCard(ServiceListingModel s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.handyman, size: 20, color: Color(0xFF111827)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(s.categoryName ?? 'General', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    if (s.price != null) ...[
                      const SizedBox(width: 6),
                      Text('• ₹${s.price!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: s.isAvailable ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              s.isAvailable ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: s.isAvailable ? const Color(0xFF10B981) : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.handyman_outlined, size: 40, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 10),
          const Text(
            'No services listed yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add your services to get discovered by neighbors in your area.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CreateServiceFlowScreen()),
              );
              if (created == true) _checkAuthAndLoad();
            },
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text('Create Service', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── 5. Bookings Section ──────────────────────────────────────────────────
  Widget _buildBookingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Bookings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            if (_bookings.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProviderBookingsScreen()),
                  );
                  _checkAuthAndLoad();
                },
                child: const Text('View All', style: TextStyle(color: Color(0xFF2B7BB9), fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_bookings.isEmpty)
          _buildBookingsEmptyState()
        else
          Column(
            children: _bookings.take(5).map((b) => _buildBookingCard(b)).toList(),
          ),
      ],
    );
  }

  Widget _buildBookingCard(ServiceBookingModel booking) {
    final isPending = booking.status == 'pending';
    final dateStr = booking.scheduledAt != null
        ? '${booking.scheduledAt!.day}/${booking.scheduledAt!.month}/${booking.scheduledAt!.year}'
        : 'Date TBD';

    return InkWell(
      onTap: () async {
        final updated = await Navigator.push<ServiceBookingModel>(
          context,
          MaterialPageRoute(builder: (_) => ProviderBookingDetailScreen(booking: booking)),
        );
        if (updated != null) {
          _checkAuthAndLoad();
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Customer & Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  booking.customerName ?? 'Neighborhood Resident',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                _buildStatusPill(booking.status),
              ],
            ),
            const SizedBox(height: 8),

            // Service Title & Scheduled Date
            Text(
              booking.serviceTitle ?? 'Service Request',
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                if (booking.amount != null) ...[
                  const SizedBox(width: 12),
                  Text('•  ₹${booking.amount!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                ],
              ],
            ),

            // Pending Actions: Accept / Reject
            if (isPending) ...[
              const Divider(height: 20, color: Color(0xFFF3F4F6)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _handleRejectBooking(booking),
                      child: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _handleAcceptBooking(booking),
                      child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
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

  Widget _buildBookingsEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: const [
          Icon(Icons.calendar_month_outlined, size: 40, color: Color(0xFF9CA3AF)),
          SizedBox(height: 10),
          Text(
            'No booking requests yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          SizedBox(height: 4),
          Text(
            'When residents book your services, requests will appear here for you to accept.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  // ── Unauthorized State ───────────────────────────────────────────────────
  Widget _buildUnauthorizedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF7ED),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, size: 36, color: Color(0xFFFF6B00)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Provider Access Required',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 8),
            const Text(
              'This workspace is dedicated to registered service providers. Switch to your Provider profile to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () {
                showRoleSwitchSheet(context, currentRole: 'resident');
              },
              child: const Text('Switch to Provider Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error State ──────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            const Text('Unable to load workspace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 6),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _checkAuthAndLoad,
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
