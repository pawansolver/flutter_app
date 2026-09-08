import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/business_service.dart';

class BusinessReviewsScreen extends StatefulWidget {
  final int businessId;
  const BusinessReviewsScreen({super.key, required this.businessId});

  @override
  State<BusinessReviewsScreen> createState() => _BusinessReviewsScreenState();
}

class _BusinessReviewsScreenState extends State<BusinessReviewsScreen> {
  final BusinessService _service = BusinessService();
  List<BusinessReviewModel> _reviews = [];
  bool _isLoading = true;

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    final list = await _service.getReviews(widget.businessId);
    if (!mounted) return;
    setState(() {
      _reviews = list;
      _isLoading = false;
    });
  }

  void _openReplyDialog(BusinessReviewModel review) {
    final replyCtrl = TextEditingController(text: review.replyText ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reply to ${review.userName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${review.comment}"',
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: _subGrey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: replyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Your Official Response',
                hintText: 'Thank the customer or address their concern...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (replyCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await _service.replyToReview(review.id, replyCtrl.text.trim());
              _loadReviews();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Response posted successfully!'), backgroundColor: _brandGreen),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandOrange),
            child: const Text('Post Reply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Customer Ratings & Reviews',
          style: TextStyle(color: _primaryDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _primaryDark),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _brandOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Rating Score Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '4.8',
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                color: _primaryDark,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: List.generate(
                                5,
                                (i) => const Icon(Icons.star, color: Color(0xFFF59E0B), size: 18),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_reviews.length} Verified Reviews',
                              style: const TextStyle(fontSize: 12, color: _subGrey, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            children: [
                              _buildBar(5, 0.85),
                              _buildBar(4, 0.12),
                              _buildBar(3, 0.03),
                              _buildBar(2, 0.0),
                              _buildBar(1, 0.0),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'All Resident Reviews',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_reviews.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No reviews yet.'),
                      ),
                    )
                  else
                    ..._reviews.map((rev) => _buildReviewCard(rev)),
                ],
              ),
            ),
    );
  }

  Widget _buildBar(int star, double percent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text('$star★', style: const TextStyle(fontSize: 11, color: _subGrey)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(BusinessReviewModel review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  review.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _primaryDark,
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.rating.round() ? Icons.star : Icons.star_border,
                      color: const Color(0xFFF59E0B),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: const TextStyle(fontSize: 13, color: _primaryDark, height: 1.4),
            ),
            if (review.replyText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.reply, size: 14, color: _brandGreen),
                        SizedBox(width: 4),
                        Text(
                          'Your Official Response',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _brandGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.replyText!,
                      style: const TextStyle(fontSize: 12, color: _primaryDark),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openReplyDialog(review),
                  icon: Icon(review.replyText == null ? Icons.reply : Icons.edit, size: 14, color: _brandOrange),
                  label: Text(
                    review.replyText == null ? 'Reply to Review' : 'Edit Response',
                    style: const TextStyle(fontSize: 12, color: _brandOrange, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
