import 'package:flutter/material.dart';
import '../modules/auth/login_screen.dart';
import '../modules/society/society_dashboard_screen.dart';
import '../modules/events/events_screen.dart';
import '../modules/discover/discover_screen.dart';
import '../modules/provider/provider_dashboard_screen.dart';
import '../modules/community/community_groups_screen.dart';
import '../modules/services/screens/services_marketplace_screen.dart';
import '../modules/services/screens/my_service_bookings_screen.dart';
import '../modules/business/screens/business_listings_screen.dart';
import '../modules/business/screens/business_dashboard_screen.dart';
import '../modules/settings/settings_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../shared/widgets/role_switch_sheet.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String _userRole = 'resident';
  String _userName = 'smartgali User';
  String _userLocation = 'Patna, Bihar';

  @override
  void initState() {
    super.initState();
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    try {
      final authStore = AuthSessionStore();
      final role = await authStore.readUserRole();
      final activeRole = await const FlutterSecureStorage().read(key: 'active_role');
      final resolvedRole = (activeRole ?? role ?? 'resident').toLowerCase().trim();

      final profile = await AuthService().getAuthProfile().catchError((_) => <String, dynamic>{});
      if (mounted) {
        setState(() {
          _userRole = resolvedRole;
          final name = profile['name'] ?? profile['fullName'] ?? profile['userName'];
          if (name != null && name.toString().isNotEmpty) {
            _userName = name.toString();
          }
          final loc = profile['address'] ?? profile['societyName'] ?? profile['location'];
          if (loc != null && loc.toString().isNotEmpty) {
            _userLocation = loc.toString();
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFFEBF3EA);
    const Color sectionHeaderColor = Color(0xFF90A490);
    final isProvider = _userRole == 'provider' || _userRole == 'service provider';

    return Drawer(
      backgroundColor: bgColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF4CAF50),
                                  width: 1.5,
                                ),
                                color: Colors.transparent,
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFF9FAFB),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: 30,
                                ),
                              ),
                            ),
                            // Only one active sign at bottom right
                            Positioned(
                              bottom: 4,
                              right: -4,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: 56.0,
                            ), // Prevent overlap with Verified badge
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Color(0xFFF59E0B),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _userLocation,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isProvider ? const Color(0xFFFF6B00) : const Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isProvider ? 'Provider' : 'Verified',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF4B5563),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildSectionHeader('MAIN', sectionHeaderColor),
                  if (isProvider)
                    _buildMenuItem(
                      icon: Icons.handyman_outlined,
                      title: 'Provider Center',
                      isSelected:
                          context
                              .findAncestorWidgetOfExactType<
                                ProviderDashboardScreen
                              >() !=
                          null,
                      onTap: () {
                        final isCurrent =
                            context.findAncestorWidgetOfExactType<
                              ProviderDashboardScreen
                            >() !=
                            null;
                        Navigator.pop(context);
                        if (!isCurrent) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProviderDashboardScreen(),
                            ),
                          );
                        }
                      },
                    ),
                  _buildMenuItem(
                    icon: Icons.campaign_outlined,
                    title: 'Society Dashboard',
                    isSelected:
                        context
                            .findAncestorWidgetOfExactType<
                              SocietyDashboardScreen
                            >() !=
                        null,
                    onTap: () {
                      final isCurrent =
                          context.findAncestorWidgetOfExactType<
                            SocietyDashboardScreen
                          >() !=
                          null;
                      Navigator.pop(context);
                      if (!isCurrent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SocietyDashboardScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.event_outlined,
                    title: 'neighbourhood Events',
                    isSelected:
                        context.findAncestorWidgetOfExactType<EventsScreen>() !=
                        null,
                    onTap: () {
                      final isCurrent =
                          context.findAncestorWidgetOfExactType<EventsScreen>() !=
                          null;
                      Navigator.pop(context);
                      if (!isCurrent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EventsScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader('COMMUNITY TOOLS', sectionHeaderColor),
                  _buildMenuItem(
                    icon: Icons.search,
                    title: 'Discover Nearby',
                    isSelected:
                        context
                            .findAncestorWidgetOfExactType<DiscoverScreen>() !=
                        null,
                    onTap: () {
                      final isCurrent =
                          context.findAncestorWidgetOfExactType<
                            DiscoverScreen
                          >() !=
                          null;
                      Navigator.pop(context);
                      if (!isCurrent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DiscoverScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.groups_outlined,
                    title: 'Interest Groups',
                    isSelected:
                        context
                            .findAncestorWidgetOfExactType<
                              CommunityGroupsScreen
                            >() !=
                        null,
                    onTap: () {
                      final isCurrent =
                          context.findAncestorWidgetOfExactType<
                            CommunityGroupsScreen
                          >() !=
                          null;
                      Navigator.pop(context);
                      if (!isCurrent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CommunityGroupsScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.handyman_outlined,
                    title: 'Local Services',
                    isSelected:
                        context
                            .findAncestorWidgetOfExactType<
                              ServicesMarketplaceScreen
                            >() !=
                        null,
                    onTap: () {
                      final isCurrent =
                          context.findAncestorWidgetOfExactType<
                            ServicesMarketplaceScreen
                          >() !=
                          null;
                      Navigator.pop(context);
                      if (!isCurrent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ServicesMarketplaceScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.storefront_outlined,
                    title: 'Local Shops & Stores',
                    isSelected:
                        context
                            .findAncestorWidgetOfExactType<
                              BusinessListingsScreen
                            >() !=
                        null,
                    onTap: () {
                      final isCurrent =
                          context.findAncestorWidgetOfExactType<
                            BusinessListingsScreen
                          >() !=
                          null;
                      Navigator.pop(context);
                      if (!isCurrent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BusinessListingsScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.assignment_outlined,
                    title: 'My Bookings',
                    isSelected:
                        context
                            .findAncestorWidgetOfExactType<
                              MyServiceBookingsScreen
                            >() !=
                        null,
                    onTap: () {
                      final isCurrent =
                          context.findAncestorWidgetOfExactType<
                            MyServiceBookingsScreen
                          >() !=
                          null;
                      Navigator.pop(context);
                      if (!isCurrent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyServiceBookingsScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.storefront_outlined,
                    title: 'Business Hub',
                    isSelected:
                        context
                            .findAncestorWidgetOfExactType<
                              BusinessDashboardScreen
                            >() !=
                        null,
                    onTap: () {
                      final isCurrent =
                          context
                              .findAncestorWidgetOfExactType<
                                BusinessDashboardScreen
                              >() !=
                          null;
                      Navigator.pop(context);
                      if (!isCurrent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BusinessDashboardScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.switch_account_outlined,
                    title: 'Switch Profile View',
                    hasSwitch: true,
                    onTap: () {
                      Navigator.pop(context);
                      showRoleSwitchSheet(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader('SUPPORT & PROVIDER', sectionHeaderColor),
                  _buildMenuItem(
                    icon: Icons.handyman_outlined,
                    title: 'Provider Center',
                    isSelected:
                        context
                            .findAncestorWidgetOfExactType<
                              ProviderDashboardScreen
                            >() !=
                        null,
                    onTap: () {
                      final isCurrent =
                          context.findAncestorWidgetOfExactType<
                            ProviderDashboardScreen
                          >() !=
                          null;
                      Navigator.pop(context);
                      if (!isCurrent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProviderDashboardScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    isSelected:
                        context
                            .findAncestorWidgetOfExactType<SettingsScreen>() !=
                        null,
                    onTap: () {
                      final isCurrent =
                          context.findAncestorWidgetOfExactType<
                            SettingsScreen
                          >() !=
                          null;
                      Navigator.pop(context);
                      if (!isCurrent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.black12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: _buildMenuItem(
                icon: Icons.logout,
                title: 'Logout',
                textColor: const Color(0xFFE07A5F),
                iconColor: const Color(0xFFE07A5F),
                onTap: () async {
                  await AuthService().logout();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    bool hasSwitch = false,
    Color textColor = const Color(0xFF1F2937),
    Color iconColor = const Color(0xFF1F2937),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: isSelected
              ? const BorderSide(color: Color(0xFF2E7D32), width: 1)
              : BorderSide.none,
        ),
        tileColor: isSelected
            ? const Color(0xFFD5E8D4).withValues(alpha: 0.5)
            : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF2E7D32) : iconColor,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            color: isSelected ? const Color(0xFF2E7D32) : textColor,
          ),
        ),
        trailing: hasSwitch
            ? SizedBox(
                height: 24,
                width: 40,
                child: Switch(
                  value: true,
                  onChanged: (val) {
                    onTap();
                  },
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF4CAF50),
                ),
              )
            : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 0.0,
        ),
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
      ),
    );
  }
}
