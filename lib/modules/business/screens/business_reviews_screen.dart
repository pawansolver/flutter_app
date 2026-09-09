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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _brandOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.reply_rounded, color: _brandOrange, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reply to ${review.userName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _primaryDark),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '"${review.comment}"',
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Color(0xFF475569)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: replyCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Your Official Response',
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  hintText: 'Thank the resident or address their feedback...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _brandOrange, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _subGrey, fontWeight: FontWeight.w600)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Post Response', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return 'R';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasReviews = _reviews.isNotEmpty;
    final totalReviews = _reviews.length;
    final double avgRating = hasReviews
        ? _reviews.map((r) => r.rating).reduce((a, b) => a + b) / totalReviews
        : 0.0;
    final formattedRating = hasReviews ? avgRating.toStringAsFixed(1) : '--';

    final star5 = hasReviews ? _reviews.where((r) => r.rating >= 4.5).length / totalReviews : 0.0;
    final star4 = hasReviews ? _reviews.where((r) => r.rating >= 3.5 && r.rating < 4.5).length / totalReviews : 0.0;
    final star3 = hasReviews ? _reviews.where((r) => r.rating >= 2.5 && r.rating < 3.5).length / totalReviews : 0.0;
    final star2 = hasReviews ? _reviews.where((r) => r.rating >= 1.5 && r.rating < 2.5).length / totalReviews : 0.0;
    final star1 = hasReviews ? _reviews.where((r) => r.rating < 1.5).length / totalReviews : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Ratings & Reviews',
              style: TextStyle(color: _primaryDark, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
            ),
            Text(
              hasReviews ? '$totalReviews Verified Reviews from neighbourhood' : 'Storefront reputation summary',
              style: const TextStyle(fontSize: 12, color: _subGrey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        iconTheme: const IconThemeData(color: _primaryDark),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _brandOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Rating Score Hero Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x050F172A),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedRating,
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                color: _primaryDark,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  hasReviews && i < avgRating.round()
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: const Color(0xFFF59E0B),
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: hasReviews ? _brandGreen.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                hasReviews
                                    ? '$totalReviews Verified ${totalReviews == 1 ? "Review" : "Reviews"}'
                                    : 'No reviews yet',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: hasReviews ? _brandGreen : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: hasReviews
                              ? Column(
                                  children: [
                                    _buildBar(5, star5),
                                    _buildBar(4, star4),
                                    _buildBar(3, star3),
                                    _buildBar(2, star2),
                                    _buildBar(1, star1),
                                  ],
                                )
                              : const Center(
                                  child: Text(
                                    'No ratings recorded yet for this storefront.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: _subGrey),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Neighbourhood Reviews',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _primaryDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_reviews.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.rate_review_outlined, size: 40, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Reviews Yet',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _primaryDark),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Neighbourhood ratings and feedback will appear here as customers share their shopping experience.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: _subGrey, height: 1.4),
                              ),
                            ],
                          ),
                        ),
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
          Text('$star★', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: const Color(0xFFF1F5F9),
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
    final initials = _getInitials(review.userName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // User Avatar initials
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    review.userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _primaryDark,
                    ),
                  ),
                ),
                // Star Rating Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        review.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
            ),
            if (review.replyText != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.reply_rounded, size: 14, color: _brandGreen),
                        SizedBox(width: 5),
                        Text(
                          'Your Official Store Response',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.replyText!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF14532D), height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => _openReplyDialog(review),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(review.replyText == null ? Icons.reply_rounded : Icons.edit_outlined, size: 14, color: _brandOrange),
                        const SizedBox(width: 4),
                        Text(
                          review.replyText == null ? 'Reply to Review' : 'Edit Response',
                          style: const TextStyle(fontSize: 11, color: _brandOrange, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
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
