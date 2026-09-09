import 'package:flutter/material.dart';
import '../services/business_service.dart';

class WriteBusinessReviewSheet extends StatefulWidget {
  final int businessId;
  final String businessName;
  final VoidCallback onReviewSubmitted;

  const WriteBusinessReviewSheet({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.onReviewSubmitted,
  });

  @override
  State<WriteBusinessReviewSheet> createState() => _WriteBusinessReviewSheetState();
}

class _WriteBusinessReviewSheetState extends State<WriteBusinessReviewSheet> {
  final BusinessService _service = BusinessService();
  final TextEditingController _commentCtrl = TextEditingController();
  double _selectedRating = 5.0;
  bool _isSubmitting = false;

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your review feedback.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _service.createReview(
        businessId: widget.businessId,
        rating: _selectedRating,
        comment: comment,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onReviewSubmitted();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you! Your review has been submitted.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit review: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Review ${widget.businessName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _primaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'How was your experience with this neighbourhood shop?',
              style: TextStyle(fontSize: 13, color: _subGrey),
            ),
            const SizedBox(height: 16),

            // 5-Star Rating Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1.0;
                final isFilled = _selectedRating >= starValue;
                return IconButton(
                  iconSize: 36,
                  icon: Icon(
                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                  onPressed: () => setState(() => _selectedRating = starValue),
                );
              }),
            ),
            Center(
              child: Text(
                '$_selectedRating / 5.0',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share your feedback (product freshness, delivery speed, pricing...)',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _brandOrange),
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Review',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
