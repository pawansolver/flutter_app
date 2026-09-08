import 'package:flutter/material.dart';

import '../../../models/service_models.dart';
import '../../../services/service_marketplace_service.dart';
import 'provider_booking_detail_screen.dart';

enum EarningsPeriod { thisWeek, thisMonth, allTime }

class ProviderEarningsScreen extends StatefulWidget {
  const ProviderEarningsScreen({super.key});

  @override
  State<ProviderEarningsScreen> createState() => _ProviderEarningsScreenState();
}

class _ProviderEarningsScreenState extends State<ProviderEarningsScreen> {
  final _service = ServiceMarketplaceService();

  bool _loading = true;
  String? _errorMessage;
  List<ServiceBookingModel> _completedBookings = [];
  EarningsPeriod _selectedPeriod = EarningsPeriod.allTime;

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  Future<void> _fetchEarnings() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final allBookings = await _service.getProviderBookings();
      if (!mounted) return;
      setState(() {
        // Filter strictly completed bookings
        _completedBookings = allBookings
            .where((b) => b.status.toLowerCase() == 'completed')
            .toList();
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

  List<ServiceBookingModel> _getFilteredBookings() {
    if (_selectedPeriod == EarningsPeriod.allTime) {
      return _completedBookings;
    }

    final now = DateTime.now();
    if (_selectedPeriod == EarningsPeriod.thisWeek) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final startOfThisWeek = DateTime(weekStart.year, weekStart.month, weekStart.day);
      return _completedBookings.where((b) {
        if (b.scheduledAt == null) return true;
        return b.scheduledAt!.isAfter(startOfThisWeek);
      }).toList();
    } else if (_selectedPeriod == EarningsPeriod.thisMonth) {
      final startOfThisMonth = DateTime(now.year, now.month, 1);
      return _completedBookings.where((b) {
        if (b.scheduledAt == null) return true;
        return b.scheduledAt!.isAfter(startOfThisMonth);
      }).toList();
    }

    return _completedBookings;
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
          'Earnings Overview',
          style: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
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
              const Text('Failed to load earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _fetchEarnings,
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _getFilteredBookings();
    final totalEarned = filtered.fold<double>(0.0, (sum, b) => sum + (b.amount ?? 0.0));
    final completedCount = filtered.length;
    final avgValue = completedCount > 0 ? (totalEarned / completedCount) : 0.0;

    return RefreshIndicator(
      onRefresh: _fetchEarnings,
      color: const Color(0xFF111827),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Filter Selector
            _buildPeriodFilter(),
            const SizedBox(height: 16),

            // Summary Metrics Cards
            _buildSummaryMetrics(totalEarned, completedCount, avgValue),
            const SizedBox(height: 24),

            // Recent Completed Bookings Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Completed Bookings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                Text(
                  '$completedCount total',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bookings List or Empty State
            if (filtered.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildCompletedBookingCard(filtered[index]);
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          _buildPeriodTab('This Week', EarningsPeriod.thisWeek),
          _buildPeriodTab('This Month', EarningsPeriod.thisMonth),
          _buildPeriodTab('All Time', EarningsPeriod.allTime),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String label, EarningsPeriod period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPeriod = period),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF111827) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetrics(double totalEarned, int completedCount, double avgValue) {
    return Column(
      children: [
        // Big Total Earnings Hero Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA7F3D0)),
            boxShadow: const [
              BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Total Earnings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF047857))),
                  Icon(Icons.payments_outlined, size: 22, color: Color(0xFF059669)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                completedCount > 0 ? '₹${totalEarned.toStringAsFixed(0)}' : '--',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
              ),
              const SizedBox(height: 4),
              Text(
                'Calculated from completed client appointments',
                style: TextStyle(fontSize: 12, color: const Color(0xFF047857).withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Sub-metrics: Completed Bookings & Avg Booking Value
        Row(
          children: [
            Expanded(
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
                    const Text('Completed Bookings', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    Text(
                      '$completedCount',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                    const Text('Avg Booking Value', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    Text(
                      completedCount > 0 ? '₹${avgValue.toStringAsFixed(0)}' : '--',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompletedBookingCard(ServiceBookingModel booking) {
    final dateStr = booking.scheduledAt != null
        ? '${booking.scheduledAt!.day}/${booking.scheduledAt!.month}/${booking.scheduledAt!.year}'
        : 'Completed';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProviderBookingDetailScreen(booking: booking)),
        );
      },
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.serviceTitle ?? 'Service Job',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('#${booking.id} • $dateStr', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      if (booking.customerName != null) ...[
                        const SizedBox(width: 6),
                        Text('• ${booking.customerName}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              booking.amount != null ? '₹${booking.amount!.toStringAsFixed(0)}' : '--',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: const [
          Icon(Icons.account_balance_wallet_outlined, size: 48, color: Color(0xFF9CA3AF)),
          SizedBox(height: 12),
          Text(
            'No completed earnings yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          SizedBox(height: 6),
          Text(
            'When you complete bookings from residents, your earnings and revenue summaries will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
