import 'package:flutter/material.dart';

import '../../../models/service_models.dart';
import '../../../services/service_marketplace_service.dart';

class ServiceReviewSheet extends StatefulWidget {
  const ServiceReviewSheet({super.key, required this.booking});

  final ServiceBookingModel booking;

  @override
  State<ServiceReviewSheet> createState() => _ServiceReviewSheetState();
}

class _ServiceReviewSheetState extends State<ServiceReviewSheet> {
  final _service = ServiceMarketplaceService();
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitReview() async {
    setState(() => _isSubmitting = true);

    try {
      await _service.submitReview(
        bookingId: widget.booking.id,
        rating: _rating,
        comment: _commentController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true); // Return success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you! Your review has been published.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit review: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rate Your Service',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'How was your experience with ${b.serviceTitle ?? 'the service'}?',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),

            // Star Rating Row
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    iconSize: 36,
                    icon: Icon(
                      starIndex <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                    onPressed: () => setState(() => _rating = starIndex),
                  );
                }),
              ),
            ),
            Center(
              child: Text(
                _getRatingDescription(_rating),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
              ),
            ),
            const SizedBox(height: 20),

            // Written Review Box
            const Text(
              'Your Feedback',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share feedback regarding quality, punctuality, and work done...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: _isSubmitting ? null : _handleSubmitReview,
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingDescription(int stars) {
    switch (stars) {
      case 1:
        return 'Needs Improvement 😞';
      case 2:
        return 'Below Expectations 😐';
      case 3:
        return 'Satisfactory 🙂';
      case 4:
        return 'Very Good! 😊';
      case 5:
        return 'Excellent! Highly Recommended 🎉';
      default:
        return '';
    }
  }
}
