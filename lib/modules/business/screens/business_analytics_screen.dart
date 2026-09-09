import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/business_service.dart';

class BusinessAnalyticsScreen extends StatefulWidget {
  final int businessId;
  const BusinessAnalyticsScreen({super.key, required this.businessId});

  @override
  State<BusinessAnalyticsScreen> createState() => _BusinessAnalyticsScreenState();
}

class _BusinessAnalyticsScreenState extends State<BusinessAnalyticsScreen> {
  final BusinessService _service = BusinessService();

  bool _isLoading = true;
  List<BusinessLeadModel> _leads = [];
  List<BusinessOfferModel> _offers = [];

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final leads = await _service.getLeads(widget.businessId);
      final offers = await _service.getOffers(widget.businessId);
      if (!mounted) return;
      setState(() {
        _leads = leads;
        _offers = offers;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOffersCount = _offers.where((o) => o.isActive).length;
    final totalInquiries = _leads.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Business Analytics',
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
                  // Time range header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hyperlocal Insights',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _primaryDark),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Text('Last 7 Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Top Summary Row - Data Honest
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Total Views',
                          value: '--',
                          trend: 'No data available',
                          icon: Icons.visibility_outlined,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Inquiries & Leads',
                          value: totalInquiries > 0 ? totalInquiries.toString() : '--',
                          trend: totalInquiries > 0 ? '$totalInquiries total leads' : 'No inquiries yet',
                          icon: Icons.phone_forwarded_outlined,
                          color: _brandGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Active Offers',
                          value: activeOffersCount > 0 ? activeOffersCount.toString() : '--',
                          trend: activeOffersCount > 0 ? '$activeOffersCount live locally' : 'No active offers',
                          icon: Icons.local_offer_outlined,
                          color: _brandOrange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Conversion Rate',
                          value: '--',
                          trend: 'Not enough data',
                          icon: Icons.trending_up,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Impressions Section - Honest Empty State
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Profile Impressions',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primaryDark),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              const Text(
                                'No impression data available',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Visitor activity will appear here once neighbourhood residents view your shop profile.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: _subGrey, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Traffic Channels Section - Honest Empty State
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Neighbourhood Discovery Channels',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primaryDark),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Not enough data to calculate referral traffic distribution.',
                          style: TextStyle(fontSize: 13, color: _subGrey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String trend,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _primaryDark),
          ),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 12, color: _subGrey)),
          const SizedBox(height: 4),
          Text(
            trend,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
