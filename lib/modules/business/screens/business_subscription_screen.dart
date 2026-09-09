import 'package:flutter/material.dart';

class BusinessSubscriptionScreen extends StatelessWidget {
  final bool isVerified;
  const BusinessSubscriptionScreen({super.key, this.isVerified = false});

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storefront Subscription & Plan',
              style: TextStyle(color: _primaryDark, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
            ),
            Text(
              'Merchant tier & hyperlocal society reach',
              style: TextStyle(fontSize: 12, color: _subGrey, fontWeight: FontWeight.w500),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Active Plan Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A0F172A),
                    blurRadius: 16,
                    offset: Offset(0, 6),
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
                          'ACTIVE STOREFRONT TIER',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isVerified ? _brandGreen.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVerified ? Icons.verified_rounded : Icons.storefront_rounded,
                              color: isVerified ? _brandGreen : const Color(0xFF94A3B8),
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isVerified ? 'VERIFIED' : 'NOT VERIFIED',
                              style: TextStyle(
                                color: isVerified ? _brandGreen : const Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isVerified ? 'SmartGali Verified Local' : 'SmartGali Free Local',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Direct neighbourhood visibility across nearby residential towers.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 16),
                  _buildPlanFeatureDark('Hyperlocal discovery within your neighborhood'),
                  _buildPlanFeatureDark('Unlimited product catalog listings'),
                  _buildPlanFeatureDark('Promotional offer broadcasting to residents'),
                  _buildPlanFeatureDark('Direct resident WhatsApp & phone inquiries'),
                  _buildPlanFeatureDark('0% Commission on all direct sales'),
                  _buildPlanFeatureDark(
                    isVerified
                        ? 'Verified Merchant Trust Badge (Active)'
                        : 'Verified Merchant Trust Badge (Pending verification)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Plan Details Info
            const Text(
              'Merchant Guarantee',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _primaryDark, letterSpacing: -0.2),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _brandGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
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
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _primaryDark),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'SmartGali connects you directly with neighbours without charging middleman commissions or per-order fees.',
                          style: TextStyle(fontSize: 12, color: _subGrey, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Support & Contact
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Merchant Support & Assistance',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _primaryDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Need assistance with your catalog, timing updates, or society reach? Contact the local merchant desk.',
                    style: TextStyle(fontSize: 12, color: _subGrey, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Support request sent to merchant desk.')),
                      );
                    },
                    icon: const Icon(Icons.support_agent_rounded, size: 18, color: _brandOrange),
                    label: const Text('Contact Merchant Desk', style: TextStyle(color: _brandOrange, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _brandOrange),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _brandGreen, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
