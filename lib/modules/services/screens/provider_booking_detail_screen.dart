import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/service_models.dart';
import '../../../services/service_marketplace_service.dart';

class ProviderBookingDetailScreen extends StatefulWidget {
  const ProviderBookingDetailScreen({
    super.key,
    required this.booking,
  });

  final ServiceBookingModel booking;

  @override
  State<ProviderBookingDetailScreen> createState() => _ProviderBookingDetailScreenState();
}

class _ProviderBookingDetailScreenState extends State<ProviderBookingDetailScreen> {
  final _service = ServiceMarketplaceService();

  late ServiceBookingModel _booking;
  bool _loadingReview = false;
  ServiceReviewModel? _receivedReview;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _fetchReviewIfCompleted();
  }

  Future<void> _fetchReviewIfCompleted() async {
    if (_booking.status.toLowerCase() == 'completed') {
      setState(() => _loadingReview = true);
      try {
        final reviews = await _service.getReviews(bookingId: _booking.id);
        if (mounted) {
          setState(() {
            _receivedReview = reviews.isNotEmpty ? reviews.first : null;
            _loadingReview = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loadingReview = false);
      }
    }
  }

  Future<void> _handleAcceptBooking() async {
    setState(() => _isActionInProgress = true);
    try {
      await _service.updateBookingStatus(_booking.id, 'confirmed');
      if (!mounted) return;
      setState(() {
        _booking = _booking.copyWith(status: 'confirmed');
        _isActionInProgress = false;
      });
      _showToast('Booking #${_booking.id} confirmed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionInProgress = false);
      _showToast('Failed to accept: $e');
    }
  }

  Future<void> _handleRejectBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Booking Request?'),
        content: Text('Are you sure you want to decline booking #${_booking.id}?'),
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
      setState(() => _isActionInProgress = true);
      try {
        await _service.updateBookingStatus(_booking.id, 'cancelled');
        if (!mounted) return;
        setState(() {
          _booking = _booking.copyWith(status: 'cancelled');
          _isActionInProgress = false;
        });
        _showToast('Booking request declined');
      } catch (e) {
        if (!mounted) return;
        setState(() => _isActionInProgress = false);
        _showToast('Failed to decline: $e');
      }
    }
  }

  Future<void> _handleCompleteBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Complete this booking?'),
        content: const Text(
          'This will mark the service as completed. The customer will be prompted to leave a review.',
        ),
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
      setState(() => _isActionInProgress = true);
      try {
        await _service.updateBookingStatus(_booking.id, 'completed');
        if (!mounted) return;
        setState(() {
          _booking = _booking.copyWith(status: 'completed');
          _isActionInProgress = false;
        });
        _showToast('Service marked as completed! 🎉');
        _fetchReviewIfCompleted();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isActionInProgress = false);
        _showToast('Failed to mark completed: $e');
      }
    }
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      _showToast('Customer phone number not available');
      return;
    }
    final uri = Uri.parse('tel:${phone.trim()}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showToast('Could not launch phone app');
      }
    } catch (e) {
      _showToast('Call error: $e');
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
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Return updated booking status if changed
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE1EAE4),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
            onPressed: () => Navigator.pop(context, _booking),
          ),
          title: Text(
            'Booking #${_booking.id}',
            style: const TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.bold),
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
              // 1. Status & Header Card
              _buildHeaderStatusCard(),
              const SizedBox(height: 16),

              // 2. Status Stepper
              _buildStatusStepperCard(),
              const SizedBox(height: 16),

              // 3. Service Information
              _buildServiceInfoCard(),
              const SizedBox(height: 16),

              // 4. Customer Information
              _buildCustomerInfoCard(),
              const SizedBox(height: 16),

              // 5. Schedule & Details
              _buildScheduleCard(),
              const SizedBox(height: 16),

              // 6. Review Card if Completed & Available
              if (_booking.status == 'completed') ...[
                _buildReviewSection(),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomActions(),
      ),
    );
  }

  Widget _buildHeaderStatusCard() {
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Booking ID', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 2),
              Text(
                '#${_booking.id}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
            ],
          ),
          _buildStatusBadge(_booking.status),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'Pending Approval';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildStatusStepperCard() {
    final status = _booking.status.toLowerCase();
    final isCancelled = status == 'cancelled';

    int currentStep = 0;
    if (status == 'confirmed') currentStep = 1;
    if (status == 'completed') currentStep = 2;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Progress',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 16),
          if (isCancelled)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.cancel, color: Color(0xFFEF4444), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This booking was cancelled. No further actions can be taken.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                _buildStepNode(title: 'Pending', stepIndex: 0, currentStep: currentStep),
                _buildStepConnector(isCompleted: currentStep >= 1),
                _buildStepNode(title: 'Confirmed', stepIndex: 1, currentStep: currentStep),
                _buildStepConnector(isCompleted: currentStep >= 2),
                _buildStepNode(title: 'Completed', stepIndex: 2, currentStep: currentStep),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStepNode({required String title, required int stepIndex, required int currentStep}) {
    final isCompleted = currentStep > stepIndex;
    final isCurrent = currentStep == stepIndex;

    Color circleColor;
    Color textColor;
    Widget icon;

    if (isCompleted) {
      circleColor = const Color(0xFF10B981);
      textColor = const Color(0xFF10B981);
      icon = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isCurrent) {
      circleColor = const Color(0xFF111827);
      textColor = const Color(0xFF111827);
      icon = Text('${stepIndex + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold));
    } else {
      circleColor = const Color(0xFFE5E7EB);
      textColor = const Color(0xFF9CA3AF);
      icon = Text('${stepIndex + 1}', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.bold));
    }

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          child: Center(child: icon),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(fontSize: 11, fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500, color: textColor),
        ),
      ],
    );
  }

  Widget _buildStepConnector({required bool isCompleted}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        height: 2,
        color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
      ),
    );
  }

  Widget _buildServiceInfoCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Service Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.handyman_outlined, color: Color(0xFF111827), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _booking.serviceTitle ?? 'Service Request',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _booking.amount != null ? 'Rate: ₹${_booking.amount!.toStringAsFixed(0)}' : 'Standard Rate',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    final phone = _booking.customerPhone;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF3F4F6),
                ),
                child: const Icon(Icons.person, color: Color(0xFF6B7280), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _booking.customerName ?? 'Neighborhood Resident',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone ?? 'Verified Resident',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              if (phone != null && phone.isNotEmpty) ...[
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFECFDF5),
                    foregroundColor: const Color(0xFF10B981),
                  ),
                  icon: const Icon(Icons.call, size: 20),
                  tooltip: 'Call Customer',
                  onPressed: () => _makeCall(phone),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    final dateStr = _booking.scheduledAt != null
        ? '${_booking.scheduledAt!.day}/${_booking.scheduledAt!.month}/${_booking.scheduledAt!.year}'
        : 'Date TBD';
    final timeStr = _booking.scheduledAt != null
        ? '${_booking.scheduledAt!.hour.toString().padLeft(2, '0')}:${_booking.scheduledAt!.minute.toString().padLeft(2, '0')}'
        : 'Time TBD';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Schedule & Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 18, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(dateStr, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, size: 18, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(timeStr, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF6B7280)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Resident address details provided upon appointment confirmation.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection() {
    if (_loadingReview) {
      return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
    }

    if (_receivedReview == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: const [
            Icon(Icons.rate_review_outlined, color: Color(0xFF6B7280), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Completed booking. Waiting for customer review.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Customer Feedback', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < _receivedReview!.rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: const Color(0xFFD97706),
                  );
                }),
              ),
            ],
          ),
          if (_receivedReview!.comment != null && _receivedReview!.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '“${_receivedReview!.comment!}”',
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF78350F)),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildBottomActions() {
    final status = _booking.status.toLowerCase();

    if (status == 'pending') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isActionInProgress ? null : _handleRejectBooking,
                  child: const Text('Decline Request', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: _isActionInProgress ? null : _handleAcceptBooking,
                  child: _isActionInProgress
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Accept Booking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (status == 'confirmed') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              onPressed: _isActionInProgress ? null : _handleCompleteBooking,
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: _isActionInProgress
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Mark as Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ),
      );
    }

    return null; // Completed or Cancelled: No primary bottom action needed
  }
}
