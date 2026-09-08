import 'package:flutter/material.dart';
import '../../modules/dashboard/main_dashboard.dart';
import '../../modules/business/screens/business_dashboard_screen.dart';
import '../../modules/provider/provider_dashboard_screen.dart';
import '../../modules/society/society_dashboard_screen.dart';

// ─── App Colors ───────────────────────────────────────────────────
class _AppColors {
  static const primaryText = Color(0xFF111827);
  static const subText = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const brandOrange = Color(0xFFFF6B00);
  static const brandOrangeBg = Color(0xFFFFF4EC);
}

// ─── Role Model ───────────────────────────────────────────────────
class _Role {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  const _Role({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

const List<_Role> _roles = [
  _Role(
    id: 'resident',
    title: 'Resident',
    subtitle: 'Browse services, posts & community',
    icon: Icons.home_outlined,
  ),
  _Role(
    id: 'business',
    title: 'Business Owner',
    subtitle: 'Manage products, offers & leads',
    icon: Icons.storefront_outlined,
  ),
  _Role(
    id: 'provider',
    title: 'Service Provider',
    subtitle: 'Handle bookings & service catalog',
    icon: Icons.handyman_outlined,
  ),
  _Role(
    id: 'society_admin',
    title: 'Society Admin',
    subtitle: 'Manage residents, visitors & complaints',
    icon: Icons.admin_panel_settings_outlined,
  ),
];

// ─── Show Function ────────────────────────────────────────────────
void showRoleSwitchSheet(
  BuildContext context, {
  String currentRole = 'resident',
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RoleSwitchSheet(currentRole: currentRole),
  );
}

// ─── Bottom Sheet Widget ──────────────────────────────────────────
class _RoleSwitchSheet extends StatefulWidget {
  final String currentRole;

  const _RoleSwitchSheet({required this.currentRole});

  @override
  State<_RoleSwitchSheet> createState() => _RoleSwitchSheetState();
}

class _RoleSwitchSheetState extends State<_RoleSwitchSheet> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentRole;
  }

  void _onRoleTap(_Role role) {
    if (role.id == _selectedRole) return;

    setState(() => _selectedRole = role.id);

    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(role.icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('Switched to ${role.title} view'),
            ],
          ),
          backgroundColor: _AppColors.brandOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Role-based navigation
      switch (role.id) {
        case 'business':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()),
          );
          break;
        case 'provider':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProviderDashboardScreen()),
          );
          break;
        case 'society_admin':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SocietyDashboardScreen()),
          );
          break;
        case 'resident':
        default:
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainDashboard()),
            (route) => false,
          );
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Switch Profile View',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _AppColors.primaryText,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choose how you want to use smartgali',
                    style: TextStyle(fontSize: 13, color: _AppColors.subText),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: _AppColors.border),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: _AppColors.subText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Role Options
          ...(_roles.map((role) {
            final isActive = _selectedRole == role.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _onRoleTap(role),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isActive ? _AppColors.brandOrangeBg : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? _AppColors.brandOrange
                          : _AppColors.border,
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Icon Container
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFFFDDBE)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFFFFB27A)
                                : _AppColors.border,
                          ),
                        ),
                        child: Icon(
                          role.icon,
                          size: 22,
                          color: isActive
                              ? _AppColors.brandOrange
                              : _AppColors.subText,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? _AppColors.brandOrange
                                    : _AppColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              role.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _AppColors.subText,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Checkmark (active) or circle (inactive)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isActive
                            ? Container(
                                key: const ValueKey('check'),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: _AppColors.brandOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              )
                            : Container(
                                key: const ValueKey('circle'),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _AppColors.border),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList()),
        ],
      ),
    );
  }
}
