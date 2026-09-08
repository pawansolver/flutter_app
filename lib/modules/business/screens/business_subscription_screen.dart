import 'package:flutter/material.dart';

class BusinessSubscriptionScreen extends StatelessWidget {
  const BusinessSubscriptionScreen({super.key});

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
          'Business Plan & Tier',
          style: TextStyle(color: _primaryDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _primaryDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Active Plan Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF111827), Color(0xFF1F2937)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _brandOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CURRENT ACTIVE PLAN',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.verified, color: _brandGreen, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'VERIFIED',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SmartGali Verified Local',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Full hyperlocal neighborhood reach for registered storefronts.',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF374151)),
                  const SizedBox(height: 12),
                  _buildPlanFeatureDark('Hyperlocal discovery within 5km radius'),
                  _buildPlanFeatureDark('Unlimited product catalog listings'),
                  _buildPlanFeatureDark('Neighbourhood promotional offer banners'),
                  _buildPlanFeatureDark('Direct customer call & WhatsApp inquiries'),
                  _buildPlanFeatureDark('0% Commission on direct customer sales'),
                  _buildPlanFeatureDark('Verified Merchant Trust Badge'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Plan Details Info
            const Text(
              'Merchant Guarantee',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _primaryDark),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _brandGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: _brandGreen, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Direct Local Connection',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryDark),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'SmartGali connects you directly with neighbours without charging middleman commissions.',
                          style: TextStyle(fontSize: 12, color: _subGrey, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Support & Contact
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Need Help or Custom Promos?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Contact the SmartGali merchant support team for banner highlights or society sponsorship.',
                    style: TextStyle(fontSize: 12, color: _subGrey),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Support request sent to merchant desk.')),
                      );
                    },
                    icon: const Icon(Icons.support_agent, size: 18, color: _brandOrange),
                    label: const Text('Contact Merchant Desk', style: TextStyle(color: _brandOrange)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _brandOrange),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanFeatureDark(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: _brandGreen, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
