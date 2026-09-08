import 'package:flutter/material.dart';

import '../../../models/service_models.dart';
import '../../../services/service_marketplace_service.dart';

class ProviderReviewsScreen extends StatefulWidget {
  const ProviderReviewsScreen({super.key});

  @override
  State<ProviderReviewsScreen> createState() => _ProviderReviewsScreenState();
}

class _ProviderReviewsScreenState extends State<ProviderReviewsScreen> {
  final _service = ServiceMarketplaceService();

  bool _loading = true;
  String? _errorMessage;
  List<ServiceReviewModel> _reviews = [];

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final list = await _service.getReviews();
      if (!mounted) return;
      setState(() {
        _reviews = list;
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

  double _calculateAverageRating() {
    if (_reviews.isEmpty) return 0.0;
    final sum = _reviews.fold<int>(0, (prev, r) => prev + r.rating);
    return sum / _reviews.length;
  }

  Map<int, int> _calculateRatingCounts() {
    final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      final star = r.rating.clamp(1, 5);
      counts[star] = (counts[star] ?? 0) + 1;
    }
    return counts;
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
          'Reviews & Ratings',
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
              const Text('Failed to load reviews', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _fetchReviews,
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReviews,
      color: const Color(0xFF111827),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Summary Card
            _buildSummaryCard(),
            const SizedBox(height: 20),

            // 2. Reviews List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Customer Feedback',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                Text(
                  '${_reviews.length} ${_reviews.length == 1 ? 'review' : 'reviews'}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Reviews List or Empty State
            if (_reviews.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reviews.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildReviewCard(_reviews[index]);
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final avg = _calculateAverageRating();
    final counts = _calculateRatingCounts();
    final total = _reviews.length;

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              // Left: Big Average Number & Stars
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    total > 0 ? avg.toStringAsFixed(1) : '--',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF111827), height: 1.0),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(5, (index) {
                      final starVal = index + 1;
                      return Icon(
                        starVal <= avg.round() ? Icons.star : Icons.star_border,
                        size: 18,
                        color: const Color(0xFFFFB800),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total > 0 ? '$total verified reviews' : 'No ratings yet',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(width: 24),

              // Right: Rating breakdown bars
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1].map((star) {
                    final count = counts[star] ?? 0;
                    final pct = total > 0 ? count / total : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text('$star★', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFF3F4F6),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 20,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ServiceReviewModel review) {
    final dateStr = review.createdAt != null
        ? '${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}'
        : 'Recent';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x02000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reviewer row & Rating
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF3F4F6),
                ),
                child: const Icon(Icons.person, size: 20, color: Color(0xFF6B7280)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName ?? 'Resident',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating ? Icons.star : Icons.star_border,
                    size: 15,
                    color: const Color(0xFFFFB800),
                  );
                }),
              ),
            ],
          ),

          // Comment
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!.trim(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
            ),
          ],
        ],
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
          Icon(Icons.rate_review_outlined, size: 48, color: Color(0xFF9CA3AF)),
          SizedBox(height: 12),
          Text(
            'No reviews yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          SizedBox(height: 6),
          Text(
            'Reviews and ratings from residents who booked your services will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
