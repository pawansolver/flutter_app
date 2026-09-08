/// SmartGali Flutter Core — Client-Side UI Permission Guards
/// NOTE: Frontend guards control UI element visibility only.
/// The backend REST API remains the authoritative security boundary.
library;

class UserEffectivePermissions {
  final int? userId;
  final Set<String> permissions;
  final Set<String> directAllows;
  final Set<String> directDenies;
  final List<String> roles;
  final bool isSuperAdmin;
  final bool isGlobalAdmin;

  UserEffectivePermissions({
    this.userId,
    required this.permissions,
    required this.directAllows,
    required this.directDenies,
    required this.roles,
    required this.isSuperAdmin,
    required this.isGlobalAdmin,
  });

  factory UserEffectivePermissions.fromJson(Map<String, dynamic> json) {
    return UserEffectivePermissions(
      userId: json['userId'] is int ? json['userId'] : int.tryParse(json['userId']?.toString() ?? ''),
      permissions: (json['permissions'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {},
      directAllows: (json['directAllows'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {},
      directDenies: (json['directDenies'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {},
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isSuperAdmin: json['isSuperAdmin'] == true,
      isGlobalAdmin: json['isGlobalAdmin'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'permissions': permissions.toList(),
      'directAllows': directAllows.toList(),
      'directDenies': directDenies.toList(),
      'roles': roles,
      'isSuperAdmin': isSuperAdmin,
      'isGlobalAdmin': isGlobalAdmin,
    };
  }
}

class PermissionGuards {
  /// Checks if the user is a Super Administrator (R001)
  static bool isSuperAdmin(dynamic user) {
    if (user == null) return false;
    final role = _extractRole(user);
    return role == 'super_admin' || role == 'superadmin';
  }

  /// Checks if the user is a Global Administrator (R001 or R002) for platform operational features
  static bool isGlobalAdmin(dynamic user) {
    if (user == null) return false;
    final role = _extractRole(user);
    return role == 'super_admin' || role == 'superadmin' || role == 'admin';
  }

  /// Checks if the user has a specific permission, respecting direct DENY precedence
  static bool hasPermission(
    dynamic user,
    String permissionCode, {
    UserEffectivePermissions? effectivePermissions,
  }) {
    if (user == null || permissionCode.isEmpty) return false;

    // 1. If effective permissions are loaded, check direct DENY first
    if (effectivePermissions != null) {
      if (effectivePermissions.directDenies.contains(permissionCode)) {
        return false;
      }
      if (effectivePermissions.isSuperAdmin) {
        return true;
      }
      if (effectivePermissions.directAllows.contains(permissionCode)) {
        return true;
      }
      if (effectivePermissions.permissions.contains(permissionCode)) {
        return true;
      }
    }

    // 2. Fallback to platform role checks
    if (isSuperAdmin(user)) {
      return true;
    }

    return false;
  }

  /// Checks if the user has ANY of the specified permissions
  static bool hasAnyPermission(
    dynamic user,
    List<String> permissionCodes, {
    UserEffectivePermissions? effectivePermissions,
  }) {
    for (final code in permissionCodes) {
      if (hasPermission(user, code, effectivePermissions: effectivePermissions)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if the user has ALL of the specified permissions
  static bool hasAllPermissions(
    dynamic user,
    List<String> permissionCodes, {
    UserEffectivePermissions? effectivePermissions,
  }) {
    for (final code in permissionCodes) {
      if (!hasPermission(user, code, effectivePermissions: effectivePermissions)) {
        return false;
      }
    }
    return true;
  }

  /// Returns visible navigation items according to user authority and permissions
  static List<Map<String, dynamic>> getVisibleAdminNavigation(
    dynamic user, {
    UserEffectivePermissions? effectivePermissions,
  }) {
    final superAdmin = isSuperAdmin(user);
    final globalAdmin = isGlobalAdmin(user);

    final allItems = [
      {'id': 'dashboard', 'title': 'Dashboard', 'icon': 'dashboard', 'visible': globalAdmin},
      {'id': 'communities', 'title': 'Communities', 'icon': 'people', 'visible': globalAdmin},
      {'id': 'societies', 'title': 'Societies', 'icon': 'apartment', 'visible': globalAdmin},
      {'id': 'users', 'title': 'User Management', 'icon': 'group', 'visible': globalAdmin},
      {'id': 'reports', 'title': 'Content Moderation', 'icon': 'report', 'visible': globalAdmin},
      {'id': 'businesses', 'title': 'Business Directory', 'icon': 'store', 'visible': globalAdmin},

      // Super Admin Exclusive Navigation Items
      {'id': 'admin_users', 'title': 'Admin User Management', 'icon': 'admin_panel_settings', 'visible': superAdmin},
      {'id': 'roles', 'title': 'Roles & Hierarchy', 'icon': 'badge', 'visible': superAdmin},
      {'id': 'permissions', 'title': 'Permissions Registry', 'icon': 'lock', 'visible': superAdmin},
      {'id': 'api_config', 'title': 'API Configuration', 'icon': 'api', 'visible': superAdmin},
      {'id': 'payment_gateway', 'title': 'Payment Gateway', 'icon': 'payments', 'visible': superAdmin},
      {'id': 'backup_restore', 'title': 'Backup & Restore', 'icon': 'backup', 'visible': superAdmin},
      {'id': 'platform_settings', 'title': 'Platform Settings', 'icon': 'settings', 'visible': superAdmin},
      {'id': 'audit_logs', 'title': 'Audit Logs', 'icon': 'history', 'visible': superAdmin},
      {'id': 'system_logs', 'title': 'System Logs', 'icon': 'terminal', 'visible': superAdmin},
    ];

    return allItems.where((item) => item['visible'] == true).toList();
  }

  static String _extractRole(dynamic user) {
    if (user is Map) {
      final r = user['userRole'] ?? user['role'] ?? user['role_code'] ?? '';
      return r.toString().toLowerCase().trim();
    }
    return '';
  }
}
