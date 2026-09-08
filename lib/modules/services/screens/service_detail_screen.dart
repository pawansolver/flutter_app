import 'package:flutter/material.dart';

import '../../../models/service_models.dart';
import '../../../services/auth_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/service_marketplace_service.dart';
import '../../chat/chat_window_screen.dart';
import 'book_service_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({super.key, required this.listing});

  final ServiceListingModel listing;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final _service = ServiceMarketplaceService();
  final _chatService = ChatService();
  final _authService = AuthService();

  bool _loadingReviews = true;
  List<ServiceReviewModel> _reviews = [];
  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      final reviews = await _service.getReviews();
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _loadingReviews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _handleChatWithProvider() async {
    final providerUserId = widget.listing.providerUserId;
    if (providerUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Direct chat is currently unavailable for this provider.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _openingChat = true);
    try {
      final currentUserId = await _authService.getUserId();
      if (currentUserId == null) {
        throw Exception('Please sign in to message this provider.');
      }

      final chat = await _chatService.getOrCreateOneToOneChat(
        userId: currentUserId,
        targetUserId: providerUserId,
      );

      if (!mounted) return;
      setState(() => _openingChat = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatWindowScreen(
            chatId: chat.id,
            chatName: widget.listing.providerName ?? chat.name ?? 'Provider',
            currentUserId: currentUserId,
            isOnline: false,
            recipientUserId: providerUserId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingChat = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.listing;

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
          'Service Details',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF111827)),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Service Header Card ──
            _buildServiceHeaderCard(item),
            const SizedBox(height: 16),

            // ── 2. Service Information Box ──
            _buildServiceInfoBox(item),
            const SizedBox(height: 16),

            // ── 3. Provider Section ──
            _buildProviderSection(item),
            const SizedBox(height: 20),

            // ── 4. Reviews Preview ──
            _buildReviewsSection(item),
          ],
        ),
      ),
      // ── 5. Sticky Bottom CTA Bar ──
      bottomNavigationBar: _buildBottomBar(item),
    );
  }

  Widget _buildServiceHeaderCard(ServiceListingModel item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.categoryName ?? 'General Service',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2B7BB9)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isAvailable ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.isAvailable ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.isAvailable ? 'Available Now' : 'Currently Busy',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: item.isAvailable ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 4),
              Text(
                item.rating > 0 ? item.rating.toStringAsFixed(1) : '--',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              Text(
                ' (${item.reviewsCount > 0 ? '${item.reviewsCount} reviews' : 'No reviews yet'})',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const Spacer(),
              if (item.distance != null) ...[
                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFF59E0B)),
                const SizedBox(width: 2),
                Text(item.distance!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceInfoBox(ServiceListingModel item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Details',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Standard Price', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      const SizedBox(height: 4),
                      Text(
                        item.price != null ? '₹${item.price!.toStringAsFixed(0)}' : 'On Request',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estimated Time', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      const SizedBox(height: 4),
                      Text(
                        item.duration != null && item.duration!.isNotEmpty ? item.duration! : '--',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'What is Included',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 6),
            Text(
              item.description!,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderSection(ServiceListingModel item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About the Service Provider',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF3F4F6),
                ),
                child: const Icon(Icons.person, size: 28, color: Color(0xFF6B7280)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.providerName ?? 'Service Provider',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 2),
                    if (item.providerExperience != null && item.providerExperience!.isNotEmpty)
                      Text(
                        '${item.providerExperience} experience in neighborhood',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      )
                    else
                      Text(
                        item.isProviderVerified ? 'Verified Community Professional' : 'Community Service Professional',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                  ],
                ),
              ),
              if (item.isProviderVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified, size: 12, color: Color(0xFF10B981)),
                      SizedBox(width: 3),
                      Text('Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.shield_outlined, size: 12, color: Color(0xFF6B7280)),
                      SizedBox(width: 3),
                      Text('Not verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(ServiceListingModel item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customer Reviews',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              Text(
                item.rating > 0 ? '⭐ ${item.rating.toStringAsFixed(1)} / 5.0' : '⭐ -- / 5.0',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingReviews)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No written reviews yet. Be the first to book and share your feedback.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontStyle: FontStyle.italic),
              ),
            )
          else
            Column(
              children: _reviews.take(3).map((r) => _buildReviewItem(r)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(ServiceReviewModel r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                r.userName ?? 'Neighbor',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              Row(
                children: List.generate(
                  r.rating,
                  (i) => const Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
                ),
              ),
            ],
          ),
          if (r.comment != null && r.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r.comment!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(ServiceListingModel item) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Row(
          children: [
            // Secondary CTA: Chat Provider
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _openingChat ? null : _handleChatWithProvider,
              icon: _openingChat
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF374151)),
              label: const Text('Chat', style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),

            // Primary CTA: Book Service
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookServiceScreen(listing: item),
                    ),
                  );
                },
                child: const Text(
                  'Book Service',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
