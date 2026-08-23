import 'package:flutter/material.dart';
import '../dashboard/main_dashboard.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/help_support_screen.dart';
import '../profile/notification_preferences_screen.dart';
import 'change_password_screen.dart';
import 'privacy_settings_screen.dart';
import 'delete_account_screen.dart';
import 'terms_conditions_screen.dart';
import 'about_screen.dart';

// ─── App Colors ───────────────────────────────────────────────────
class _AppColors {
  static const background = Color(0xFFF9FAFB);
  static const primaryText = Color(0xFF111827);
  static const subText = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
}

// ─── Screen ───────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ─── Section Header ────────────────────────────────────────────
  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _AppColors.subText,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ─── Flat Tile (Navigation) ────────────────────────────────────
  Widget _buildNavTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color iconColor = _AppColors.primaryText,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _AppColors.background,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _AppColors.border),
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
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
                            fontWeight: FontWeight.w500,
                            color: _AppColors.primaryText,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _AppColors.subText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: _AppColors.subText,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Container(height: 1, color: _AppColors.border),
          ),
      ],
    );
  }

  // ─── Group Container ───────────────────────────────────────────
  Widget _buildGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    void handleBack() {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainDashboard()),
          (route) => false,
        );
      }
    }

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack();
      },
      child: Scaffold(
        backgroundColor: _AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.white,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _AppColors.primaryText),
            onPressed: handleBack,
          ),
          title: const Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _AppColors.primaryText,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _AppColors.border),
          ),
        ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Account ─────────────────────────────────────────
            _buildSectionHeader('Account'),
            _buildGroup([
              _buildNavTile(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                subtitle: 'Update name, photo & details',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                ),
              ),
              _buildNavTile(
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: 'Update your login password',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChangePasswordScreen(),
                  ),
                ),
              ),
              _buildNavTile(
                icon: Icons.security_outlined,
                title: 'Privacy Settings',
                subtitle: 'Control who sees your data',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacySettingsScreen(),
                  ),
                ),
                showDivider: false,
              ),
            ]),

            // ─── Notification Preferences ─────────────────────────
            _buildSectionHeader('Notification Preferences'),
            _buildGroup([
              _buildNavTile(
                icon: Icons.notifications_outlined,
                title: 'Manage Notifications',
                subtitle: 'Push, email, society, and business alerts',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationPreferencesScreen(),
                  ),
                ),
                showDivider: false,
              ),
            ]),

            // ─── Support ──────────────────────────────────────────
            _buildSectionHeader('Support'),
            _buildGroup([
              _buildNavTile(
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpSupportScreen(),
                  ),
                ),
              ),
              _buildNavTile(
                icon: Icons.article_outlined,
                title: 'Terms & Conditions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsConditionsScreen(),
                  ),
                ),
              ),
              _buildNavTile(
                icon: Icons.info_outline,
                title: 'About smartgali',
                subtitle: 'v1.0.0 – Built with ❤️',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                ),
                showDivider: false,
              ),
            ]),

            // ─── Danger Zone ──────────────────────────────────────
            _buildSectionHeader('Danger Zone'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DeleteAccountScreen(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Color(0xFF9F1239),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete Account',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9F1239),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Permanently remove your account & data',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFBE123C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFBE123C),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }
}
