import 'package:flutter/material.dart';
import 'profile_setup_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  int _selectedRoleIndex = 0; // 0: Resident, 1: Shopkeeper, 2: Service Provider

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF10B981);
    const Color primaryText = Color(0xFF111827);
    const Color subText = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Top Header with Background & Icon ---
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                ClipPath(
                  clipper: _BottomCurveClipper(),
                  child: Image.asset(
                    'assets/images/neighbourhood_bg.png',
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 16.0),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF111827),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                // Center Icon
                Positioned(
                  bottom: -20,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.house_rounded,
                        color: brandGreen,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Title ---
                  const Text(
                    'Who are you?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: brandGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 14, color: subText),
                      children: [
                        TextSpan(text: 'Choose your identity on '),
                        TextSpan(
                          text: 'smartgali',
                          style: TextStyle(
                            color: brandGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Cards ---
                  _buildRoleCard(
                    index: 0,
                    title: 'Resident',
                    subtitle: 'I live in this neighbourhood',
                    icon: Icons.home_rounded,
                    iconColor: brandGreen,
                    iconBgColor: brandGreen.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    index: 1,
                    title: 'Business Owner',
                    subtitle: 'I own a shop or business\nin this neighbourhood',
                    icon: Icons.storefront_rounded,
                    iconColor: const Color(0xFFFF6B00),
                    iconBgColor: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    index: 2,
                    title: 'Service Provider',
                    subtitle: 'I provide services in\nthis neighbourhood',
                    icon: Icons.handyman_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    iconBgColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    index: 3,
                    title: 'Society Admin',
                    subtitle: 'I manage society operations,\nresidents, visitors & facilities',
                    icon: Icons.admin_panel_settings_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    iconBgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 32),

                  // --- Trust Badge ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: brandGreen.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield, color: brandGreen, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your information is safe with us',
                                style: TextStyle(
                                  color: brandGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We respect your privacy and\nnever share your data.',
                                style: TextStyle(
                                  color: subText,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.lock_outline,
                          color: brandGreen.withValues(alpha: 0.3),
                          size: 36,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Continue Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileSetupScreen(
                              initialRole: ['Resident', 'Business Owner', 'Service Provider', 'Society Admin'][_selectedRoleIndex],
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    bool isSelected = _selectedRoleIndex == index;
    const Color brandGreen = Color(0xFF10B981);
    const Color primaryText = Color(0xFF111827);
    const Color subText = Color(0xFF6B7280);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRoleIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? brandGreen : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandGreen.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: subText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? brandGreen : const Color(0xFFD1D5DB),
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
