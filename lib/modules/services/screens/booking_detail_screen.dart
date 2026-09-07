import 'package:flutter/material.dart';

import '../../../models/service_models.dart';
import '../../../services/service_marketplace_service.dart';
import '../widgets/service_review_sheet.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.booking});

  final ServiceBookingModel booking;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final _service = ServiceMarketplaceService();
  late ServiceBookingModel _booking;
  bool _isCancelling = false;
  bool _isReviewed = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _checkReviewed();
  }

  Future<void> _checkReviewed() async {
    if (_booking.status == 'completed') {
      final reviewed = await _service.hasUserReviewedBooking(_booking.id);
      if (mounted) setState(() => _isReviewed = reviewed);
    }
  }

  Future<void> _handleCancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Booking?'),
        content: const Text('Are you sure you want to cancel this booking request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking', style: TextStyle(color: Color(0xFF6B7280))),
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
      setState(() => _isCancelling = true);
      try {
        await _service.cancelBooking(_booking.id);
        setState(() {
          _booking = _booking.copyWith(status: 'cancelled');
          _isCancelling = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking has been cancelled.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isCancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel booking: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _openReviewSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ServiceReviewSheet(booking: _booking),
    );

    if (result == true) {
      setState(() => _isReviewed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final dateStr = b.scheduledAt != null
        ? '${b.scheduledAt!.day}/${b.scheduledAt!.month}/${b.scheduledAt!.year}'
        : 'To be scheduled';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.of(context).pop(_booking),
        ),
        title: Text(
          'Booking #${b.id}',
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Banner Card ──
            _buildStatusCard(b.status),
            const SizedBox(height: 16),

            // ── Booking Information ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Service Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const Divider(height: 20, color: Color(0xFFF3F4F6)),
                  _buildDetailRow('Service', b.serviceTitle ?? 'Service Request'),
                  const SizedBox(height: 10),
                  _buildDetailRow('Provider', b.customerName ?? 'Neighborhood Professional'),
                  const SizedBox(height: 10),
                  _buildDetailRow('Scheduled Date', dateStr),
                  const SizedBox(height: 10),
                  _buildDetailRow('Payment Type', 'Pay directly after completion'),
                  const Divider(height: 20, color: Color(0xFFF3F4F6)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      Text(
                        b.amount != null ? '₹${b.amount!.toStringAsFixed(0)}' : 'To be confirmed',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Actions Section ──
            if (b.status == 'completed') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Service Completed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    const SizedBox(height: 4),
                    const Text('Help your neighborhood by rating this provider.', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 14),
                    if (_isReviewed)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Text('You have reviewed this service.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _openReviewSheet,
                        icon: const Icon(Icons.star, size: 16, color: Colors.white),
                        label: const Text('Rate & Review', style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
              ),
            ] else if (b.status == 'pending' || b.status == 'confirmed') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Manage Booking', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                    const SizedBox(height: 4),
                    const Text('Need to reschedule or cancel your request?', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _isCancelling ? null : _handleCancelBooking,
                      child: _isCancelling
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Cancel Booking', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    Color bg;
    Color fg;
    String title;
    String desc;

    switch (status) {
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        title = 'Pending Provider Confirmation';
        desc = 'Your request has been sent to the provider and is waiting for their acceptance.';
        break;
      case 'confirmed':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2B7BB9);
        title = 'Booking Confirmed';
        desc = 'The provider accepted your appointment. They will arrive at the scheduled time.';
        break;
      case 'completed':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF10B981);
        title = 'Service Completed';
        desc = 'This service appointment has been marked as finished.';
        break;
      case 'cancelled':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFEF4444);
        title = 'Booking Cancelled';
        desc = 'This booking was cancelled.';
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        title = status.toUpperCase();
        desc = '';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: fg)),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.9), height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          ),
        ),
      ],
    );
  }
}
