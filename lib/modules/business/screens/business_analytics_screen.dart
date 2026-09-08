import 'package:flutter/material.dart';

class BusinessAnalyticsScreen extends StatelessWidget {
  final int businessId;
  const BusinessAnalyticsScreen({super.key, required this.businessId});

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time range pill
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

            // Top Summary Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Views',
                    value: '428',
                    trend: '+18% vs last week',
                    icon: Icons.visibility_outlined,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Call / WhatsApp',
                    value: '34',
                    trend: '+8 this week',
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
                    title: 'Offer Clicks',
                    value: '89',
                    trend: 'GALI15 leading',
                    icon: Icons.local_offer_outlined,
                    color: _brandOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Conversion Rate',
                    value: '7.9%',
                    trend: 'Healthy (+1.2%)',
                    icon: Icons.trending_up,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Weekly Impressions Graph (Visual Chart)
            Container(
              padding: const EdgeInsets.all(18),
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildDayBar('Mon', 45, 0.45),
                      _buildDayBar('Tue', 52, 0.52),
                      _buildDayBar('Wed', 68, 0.68),
                      _buildDayBar('Thu', 74, 0.74),
                      _buildDayBar('Fri', 95, 0.95),
                      _buildDayBar('Sat', 100, 1.0, isHighest: true),
                      _buildDayBar('Sun', 88, 0.88),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Traffic Distribution Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Neighbourhood Discovery Channels',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primaryDark),
                  ),
                  const SizedBox(height: 14),
                  _buildChannelRow('Hyperlocal Search (within 2km)', 0.52, '52%', _brandOrange),
                  const SizedBox(height: 10),
                  _buildChannelRow('Resident Feed & Discover Tab', 0.28, '28%', const Color(0xFF3B82F6)),
                  const SizedBox(height: 10),
                  _buildChannelRow('Society Recommendations', 0.20, '20%', _brandGreen),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Top Products
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Viewed Products',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primaryDark),
                  ),
                  const SizedBox(height: 12),
                  _buildTopItem('1. Organic Desi Cow Ghee (500ml)', '184 views'),
                  const Divider(height: 16),
                  _buildTopItem('2. Whole Wheat Farm Atta (10kg)', '142 views'),
                  const Divider(height: 16),
                  _buildTopItem('3. Cold Pressed Mustard Oil (1L)', '98 views'),
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
          Text(trend, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDayBar(String day, int count, double fillFactor, {bool isHighest = false}) {
    return Column(
      children: [
        Text(count.toString(), style: const TextStyle(fontSize: 10, color: _subGrey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: 24,
          height: 90 * fillFactor,
          decoration: BoxDecoration(
            color: isHighest ? _brandOrange : _brandOrange.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(day, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _primaryDark)),
      ],
    );
  }

  Widget _buildChannelRow(String channel, double fill, String percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(channel, style: const TextStyle(fontSize: 13, color: _primaryDark)),
            Text(percentage, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fill,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildTopItem(String name, String stat) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        Text(stat, style: const TextStyle(fontSize: 12, color: _subGrey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
