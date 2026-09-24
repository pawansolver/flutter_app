import 'package:flutter/material.dart';
import '../dashboard/main_dashboard.dart';

class PermissionsPromptScreen extends StatefulWidget {
  const PermissionsPromptScreen({super.key});

  @override
  State<PermissionsPromptScreen> createState() => _PermissionsPromptScreenState();
}

class _PermissionsPromptScreenState extends State<PermissionsPromptScreen> {
  bool _locationGranted = true;
  bool _notificationsGranted = true;
  bool _cameraGranted = false;

  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _primaryText = Color(0xFF111827);
  static const Color _subText = Color(0xFF6B7280);

  void _finishPermissions() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainDashboard()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _finishPermissions,
            child: const Text(
              'Skip for now',
              style: TextStyle(
                color: _subText,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Icon & Titles
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _brandGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: _brandGreen,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Customize Your Experience',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Grant permissions to get hyperlocal neighbourhood updates, urgent society alerts, and connect with nearby verified services.',
                style: TextStyle(
                  fontSize: 14,
                  color: _subText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Permissions Cards
              _buildPermissionCard(
                icon: Icons.location_on_rounded,
                iconColor: _brandOrange,
                title: 'Hyperlocal Location',
                subtitle:
                    'Discovers stores, services, and posts within your chosen 500m to 5km neighbourhood radius.',
                isGranted: _locationGranted,
                onToggle: (val) => setState(() => _locationGranted = val),
              ),
              const SizedBox(height: 14),
              _buildPermissionCard(
                icon: Icons.notifications_active_rounded,
                iconColor: _brandGreen,
                title: 'Urgent Alerts & Notifications',
                subtitle:
                    'Receive real-time society announcements, emergency alerts, visitor arrival notifications, and chat replies.',
                isGranted: _notificationsGranted,
                onToggle: (val) => setState(() => _notificationsGranted = val),
              ),
              const SizedBox(height: 14),
              _buildPermissionCard(
                icon: Icons.camera_alt_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Camera & Gallery Access',
                subtitle:
                    'Allows you to upload society maintenance photos, share community moments, and set up your profile picture.',
                isGranted: _cameraGranted,
                onToggle: (val) => setState(() => _cameraGranted = val),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 16.0, top: 8.0),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _finishPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue to Home',
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
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isGranted,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? iconColor.withValues(alpha: 0.4)
              : const Color(0xFFE5E7EB),
          width: isGranted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _subText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isGranted,
            activeThumbColor: iconColor,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}
