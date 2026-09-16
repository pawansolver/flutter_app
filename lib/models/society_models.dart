import 'dart:convert';

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool _asBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.trim().toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return defaultValue;
}

String? _asString(dynamic value) {
  if (value == null) return null;
  final str = value.toString().trim();
  return str.isEmpty ? null : str;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

// ─── Paginated Response Wrapper ─────────────────────────────────────────────
class SocietyPaginatedResponse<T> {
  final List<T> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const SocietyPaginatedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory SocietyPaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final rawList = json['data'] as List? ?? [];
    final items = rawList
        .whereType<Map<String, dynamic>>()
        .map(itemParser)
        .toList();

    final pagination = json['pagination'] as Map<String, dynamic>?;
    return SocietyPaginatedResponse<T>(
      data: items,
      total: _asInt(pagination?['total'] ?? json['total']) ?? items.length,
      page: _asInt(pagination?['page'] ?? json['page']) ?? 1,
      limit: _asInt(pagination?['limit'] ?? json['limit']) ?? 20,
      totalPages: _asInt(pagination?['totalPages'] ?? json['totalPages']) ?? 1,
    );
  }
}

// ─── 1. Society Profile Model ───────────────────────────────────────────────
class SocietyProfileModel {
  final int id;
  final int? userId;
  final String societyName;
  final String? registrationNo;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int? totalFlats;
  final int? createdBy;
  final Map<String, dynamic>? adminUser;
  final DateTime? createdAt;
  final String? userRole;

  const SocietyProfileModel({
    required this.id,
    this.userId,
    required this.societyName,
    this.registrationNo,
    this.address,
    this.latitude,
    this.longitude,
    this.totalFlats,
    this.createdBy,
    this.adminUser,
    this.createdAt,
    this.userRole,
  });

  String get name => societyName;

  factory SocietyProfileModel.fromJson(Map<String, dynamic> json) {
    String? resolvedRole;
    if (json['membership'] is Map) {
      resolvedRole = _asString(json['membership']['role']);
    }
    resolvedRole ??= _asString(json['role'] ?? json['userRole']);

    return SocietyProfileModel(
      id: _asInt(json['id'] ?? json['societyId']) ?? 0,
      userId: _asInt(json['user_id'] ?? json['userId']),
      societyName: _asString(json['society_name'] ?? json['societyName']) ?? 'Society',
      registrationNo: _asString(json['registration_no'] ?? json['registrationNo']),
      address: _asString(json['address']),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      totalFlats: _asInt(json['total_flats'] ?? json['totalFlats']),
      createdBy: _asInt(json['created_by'] ?? json['createdBy']),
      adminUser: json['admin_user'] as Map<String, dynamic>?,
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
      userRole: resolvedRole,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'society_name': societyName,
    'registration_no': registrationNo,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'total_flats': totalFlats,
  };
}

// ─── 2. Society Member Model ────────────────────────────────────────────────
class SocietyMemberModel {
  final int id;
  final int societyId;
  final int userId;
  final String? flatNo;
  final String role; // 'owner' | 'admin' | 'committee' | 'security' | 'member' | 'tenant'
  final String status; // 'active' | 'pending' | 'rejected' | 'inactive'
  final DateTime? joinedAt;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? society;
  final DateTime? createdAt;

  const SocietyMemberModel({
    required this.id,
    required this.societyId,
    required this.userId,
    this.flatNo,
    required this.role,
    required this.status,
    this.joinedAt,
    this.user,
    this.society,
    this.createdAt,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isAdmin => role.toLowerCase() == 'admin' || role.toLowerCase() == 'owner';
  bool get isCommittee => role.toLowerCase() == 'committee';
  bool get isSecurity => role.toLowerCase() == 'security';

  String get memberName =>
      _asString(user?['userName'] ?? user?['name']) ?? 'Resident #$userId';
  String get memberPhone => _asString(user?['phone']) ?? '';
  String get memberEmail => _asString(user?['email']) ?? '';
  String get userName => memberName;
  String get userPhone => memberPhone;
  String get userEmail => memberEmail;

  factory SocietyMemberModel.fromJson(Map<String, dynamic> json) {
    return SocietyMemberModel(
      id: _asInt(json['id'] ?? json['memberId']) ?? 0,
      societyId: _asInt(json['society_id'] ?? json['societyId']) ?? 0,
      userId: _asInt(json['user_id'] ?? json['userId']) ?? 0,
      flatNo: _asString(json['flat_no'] ?? json['flatNo']),
      role: _asString(json['role'])?.toLowerCase() ?? 'member',
      status: _asString(json['status'])?.toLowerCase() ?? 'pending',
      joinedAt: _asDateTime(json['joined_at'] ?? json['joinedAt']),
      user: json['user'] as Map<String, dynamic>?,
      society: json['society'] as Map<String, dynamic>?,
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'society_id': societyId,
    'user_id': userId,
    'flat_no': flatNo,
    'role': role,
    'status': status,
  };
}

// ─── 3. Society Announcement Model ──────────────────────────────────────────
class AnnouncementAttachmentModel {
  final String fileUrl;
  final String fileName;
  final String? fileType;
  final int? fileSize;

  const AnnouncementAttachmentModel({
    required this.fileUrl,
    required this.fileName,
    this.fileType,
    this.fileSize,
  });

  bool get isPdf =>
      fileName.toLowerCase().endsWith('.pdf') || (fileType?.toLowerCase().contains('pdf') ?? false);

  bool get isImage =>
      fileName.toLowerCase().endsWith('.png') ||
      fileName.toLowerCase().endsWith('.jpg') ||
      fileName.toLowerCase().endsWith('.jpeg') ||
      fileName.toLowerCase().endsWith('.webp') ||
      (fileType?.toLowerCase().contains('image') ?? false);

  String get formattedSize {
    if (fileSize == null || fileSize! <= 0) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory AnnouncementAttachmentModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementAttachmentModel(
      fileUrl: _asString(json['file_url'] ?? json['url'] ?? json['fileUrl']) ?? '',
      fileName: _asString(json['file_name'] ?? json['name'] ?? json['fileName']) ?? 'Attachment',
      fileType: _asString(json['file_type'] ?? json['type'] ?? json['fileType']),
      fileSize: _asInt(json['file_size'] ?? json['size'] ?? json['fileSize']),
    );
  }

  Map<String, dynamic> toJson() => {
    'file_url': fileUrl,
    'file_name': fileName,
    if (fileType != null) 'file_type': fileType,
    if (fileSize != null) 'file_size': fileSize,
  };
}

class SocietyAnnouncementModel {
  final int id;
  final String announcementNumber;
  final int societyId;
  final int? createdBy;
  final String title;
  final String? summary;
  final String message;
  final String? actionText;
  final String audience; // 'entire_society' | 'block' | 'committee'
  final String priority; // 'low' | 'medium' | 'high' | 'urgent'
  final String category; // 'general' | 'maintenance' | 'security' | 'finance' | 'event' | 'rules_notice' | 'emergency'
  final bool isPinned;
  final String status; // 'draft' | 'published' | 'archived'
  final DateTime? publishAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final List<AnnouncementAttachmentModel> attachments;
  final Map<String, dynamic>? creator;

  const SocietyAnnouncementModel({
    required this.id,
    this.announcementNumber = '',
    required this.societyId,
    this.createdBy,
    required this.title,
    this.summary,
    required this.message,
    this.actionText,
    this.audience = 'entire_society',
    required this.priority,
    required this.category,
    required this.isPinned,
    this.status = 'published',
    this.publishAt,
    this.publishedAt,
    this.expiresAt,
    this.createdAt,
    this.attachments = const [],
    this.creator,
  });

  bool get isUrgent =>
      priority.toLowerCase() == 'urgent' || priority.toLowerCase() == 'high';

  bool get isDraft => status.toLowerCase() == 'draft';
  bool get isPublished => status.toLowerCase() == 'published';
  bool get isArchived => status.toLowerCase() == 'archived';
  bool get hasAttachments => attachments.isNotEmpty;

  DateTime? get effectivePublishedDate => publishedAt ?? createdAt;

  String get authorName =>
      _asString(creator?['userName'] ?? creator?['name']) ?? 'Management';

  factory SocietyAnnouncementModel.fromJson(Map<String, dynamic> json) {
    List<AnnouncementAttachmentModel> parsedAttachments = [];
    dynamic rawAtt = json['attachments'];
    if (rawAtt is String) {
      try {
        rawAtt = jsonDecode(rawAtt);
      } catch (_) {}
    }
    if (rawAtt is List) {
      for (final a in rawAtt) {
        if (a is Map) {
          parsedAttachments.add(AnnouncementAttachmentModel.fromJson(Map<String, dynamic>.from(a)));
        }
      }
    }

    return SocietyAnnouncementModel(
      id: _asInt(json['id'] ?? json['announcementId']) ?? 0,
      announcementNumber: _asString(json['announcement_number'] ?? json['announcementNumber']) ?? '',
      societyId: _asInt(json['society_id'] ?? json['societyId']) ?? 0,
      createdBy: _asInt(json['created_by'] ?? json['createdBy']),
      title: _asString(json['title']) ?? '',
      summary: _asString(json['summary']),
      message: _asString(json['message'] ?? json['description'] ?? json['content']) ?? '',
      actionText: _asString(json['action_text'] ?? json['actionText']),
      audience: _asString(json['audience']) ?? 'entire_society',
      priority: _asString(json['priority'])?.toLowerCase() ?? 'medium',
      category: _asString(json['category']) ?? 'general',
      isPinned: _asBool(json['is_pinned'] ?? json['isPinned']),
      status: _asString(json['status'])?.toLowerCase() ?? 'published',
      publishAt: _asDateTime(json['publish_at'] ?? json['publishAt']),
      publishedAt: _asDateTime(json['published_at'] ?? json['publishedAt']),
      expiresAt: _asDateTime(json['expires_at'] ?? json['expiresAt']),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
      attachments: parsedAttachments,
      creator: json['creator'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'announcement_number': announcementNumber,
    'society_id': societyId,
    'title': title,
    if (summary != null) 'summary': summary,
    'message': message,
    if (actionText != null) 'action_text': actionText,
    'audience': audience,
    'priority': priority,
    'category': category,
    'is_pinned': isPinned,
    'status': status,
    if (publishAt != null) 'publish_at': publishAt!.toIso8601String(),
    if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
    if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
  };
}

// ─── 4. Society Complaint Model ─────────────────────────────────────────────
class SocietyComplaintModel {
  final int id;
  final int societyId;
  final int userId;
  final String title;
  final String description;
  final String category; // 'electrical' | 'plumbing' | 'security' | 'lift' | 'maintenance' | 'general'
  final String? subCategory;
  final String? locationType; // 'my_flat' | 'common_area' | 'parking' | 'lift' | 'garden' | 'clubhouse' | 'other'
  final String? flatNo;
  final String? exactLocation;
  final String priority; // 'low' | 'medium' | 'high' | 'urgent'
  final String status; // 'open' | 'assigned' | 'in_progress' | 'resolved' | 'closed'
  final int? assignedTo;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final String? remark;
  final DateTime? createdAt;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? assignee;

  const SocietyComplaintModel({
    required this.id,
    required this.societyId,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    this.subCategory,
    this.locationType,
    this.flatNo,
    this.exactLocation,
    required this.priority,
    required this.status,
    this.assignedTo,
    this.resolvedAt,
    this.closedAt,
    this.remark,
    this.createdAt,
    this.user,
    this.assignee,
  });

  String get ticketNumber => '#CMP-${id.toString().padLeft(4, '0')}';

  bool get isOpen => status.toLowerCase() == 'open';
  bool get isAssigned => status.toLowerCase() == 'assigned';
  bool get isInProgress => status.toLowerCase() == 'in_progress';
  bool get isResolved => status.toLowerCase() == 'resolved';
  bool get isClosed => status.toLowerCase() == 'closed';

  bool get canReopen => isResolved || isClosed;
  bool get canClose => isResolved;

  bool get hasAssignee => assignedTo != null || assigneeName.isNotEmpty;
  bool get hasResolution => resolvedAt != null || (remark != null && remark!.trim().isNotEmpty);

  String get complainantName =>
      _asString(user?['userName'] ?? user?['name']) ?? 'Resident #$userId';
  String get raisedByName => complainantName;
  String get assigneeName =>
      _asString(assignee?['userName'] ?? assignee?['name']) ?? '';
  String get assigneeDisplay =>
      assigneeName.isNotEmpty ? assigneeName : (assignedTo != null ? 'Staff #$assignedTo' : 'Unassigned');
  String get assigneePhone =>
      _asString(assignee?['phone']) ?? '';
  String get assigneeEmail =>
      _asString(assignee?['email']) ?? '';

  bool get hasStructuredLocation =>
      (locationType != null && locationType!.trim().isNotEmpty) ||
      (flatNo != null && flatNo!.trim().isNotEmpty) ||
      (exactLocation != null && exactLocation!.trim().isNotEmpty);

  String get locationTypeDisplay {
    switch (locationType?.toLowerCase()) {
      case 'my_flat':
        return 'My Flat';
      case 'common_area':
        return 'Common Area';
      case 'parking':
        return 'Parking';
      case 'lift':
        return 'Lift';
      case 'garden':
        return 'Garden';
      case 'clubhouse':
        return 'Clubhouse';
      case 'other':
        return 'Other';
      default:
        return locationType ?? '';
    }
  }

  String get locationDisplay {
    final parts = <String>[];
    if (locationType != null && locationType!.trim().isNotEmpty) {
      parts.add(locationTypeDisplay);
    }
    if (flatNo != null && flatNo!.trim().isNotEmpty) {
      parts.add('Flat: ${flatNo!.trim()}');
    }
    if (exactLocation != null && exactLocation!.trim().isNotEmpty) {
      parts.add(exactLocation!.trim());
    }
    return parts.isEmpty ? 'Not specified' : parts.join(' • ');
  }

  factory SocietyComplaintModel.fromJson(Map<String, dynamic> json) {
    return SocietyComplaintModel(
      id: _asInt(json['id'] ?? json['complaintId']) ?? 0,
      societyId: _asInt(json['society_id'] ?? json['societyId']) ?? 0,
      userId: _asInt(json['user_id'] ?? json['userId']) ?? 0,
      title: _asString(json['title']) ?? '',
      description: _asString(json['description']) ?? '',
      category: _asString(json['category']) ?? 'general',
      subCategory: _asString(json['sub_category'] ?? json['subCategory']),
      locationType: _asString(json['location_type'] ?? json['locationType']),
      flatNo: _asString(json['flat_no'] ?? json['flatNo']),
      exactLocation: _asString(json['exact_location'] ?? json['exactLocation']),
      priority: _asString(json['priority'])?.toLowerCase() ?? 'medium',
      status: _asString(json['status'])?.toLowerCase() ?? 'open',
      assignedTo: _asInt(json['assigned_to'] ?? json['assignedTo']),
      resolvedAt: _asDateTime(json['resolved_at'] ?? json['resolvedAt']),
      closedAt: _asDateTime(json['closed_at'] ?? json['closedAt']),
      remark: _asString(json['remark']),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
      user: json['user'] as Map<String, dynamic>?,
      assignee: json['assignee'] as Map<String, dynamic>?,
    );
  }

  bool get isReopened =>
      (status.toLowerCase() == 'open' || status.toLowerCase() == 'in_progress') && resolvedAt != null;

  String get statusBadgeLabel =>
      isReopened && status.toLowerCase() == 'open' ? 'REOPENED' : status.replaceAll('_', ' ').toUpperCase();

  String get residentFlatDisplay =>
      (flatNo != null && flatNo!.trim().isNotEmpty)
          ? flatNo!.trim()
          : (_asString(user?['flat_no']) ?? '');

  String get residentPhone => _asString(user?['phone']) ?? '';
  String get residentEmail => _asString(user?['email']) ?? '';

  Map<String, dynamic> toJson() => {
    'id': id,
    'society_id': societyId,
    'title': title,
    'description': description,
    'category': category,
    'sub_category': subCategory,
    'location_type': locationType,
    'flat_no': flatNo,
    'exact_location': exactLocation,
    'priority': priority,
    'status': status,
  };
}

// ─── 4b. Society Complaint Summary Model ────────────────────────────────────
class SocietyComplaintSummaryModel {
  final int total;
  final int open;
  final int assigned;
  final int inProgress;
  final int resolved;
  final int closed;

  const SocietyComplaintSummaryModel({
    this.total = 0,
    this.open = 0,
    this.assigned = 0,
    this.inProgress = 0,
    this.resolved = 0,
    this.closed = 0,
  });

  factory SocietyComplaintSummaryModel.fromJson(Map<String, dynamic> json) {
    return SocietyComplaintSummaryModel(
      total: _asInt(json['total']) ?? 0,
      open: _asInt(json['open']) ?? 0,
      assigned: _asInt(json['assigned']) ?? 0,
      inProgress: _asInt(json['in_progress'] ?? json['inProgress']) ?? 0,
      resolved: _asInt(json['resolved']) ?? 0,
      closed: _asInt(json['closed']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'open': open,
    'assigned': assigned,
    'in_progress': inProgress,
    'resolved': resolved,
    'closed': closed,
  };
}

// ─── 4c. Society Complaint History Item Model ──────────────────────────────
class SocietyComplaintHistoryItemModel {
  final int id;
  final int? societyId;
  final int? actorUserId;
  final String action;
  final int? targetUserId;
  final String? targetEntityType;
  final int? targetEntityId;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String? reason;
  final DateTime? createdAt;
  final Map<String, dynamic>? actor;
  final Map<String, dynamic>? targetUser;

  const SocietyComplaintHistoryItemModel({
    required this.id,
    this.societyId,
    this.actorUserId,
    required this.action,
    this.targetUserId,
    this.targetEntityType,
    this.targetEntityId,
    this.oldValue,
    this.newValue,
    this.reason,
    this.createdAt,
    this.actor,
    this.targetUser,
  });

  String get actorName =>
      _asString(actor?['userName'] ?? actor?['name']) ??
      (actorUserId != null ? 'User #$actorUserId' : 'System');

  String get targetName =>
      _asString(targetUser?['userName'] ?? targetUser?['name']) ??
      (targetUserId != null ? 'User #$targetUserId' : '');

  String get actionTitle => formattedTitle;

  String get remark =>
      reason ??
      _asString(newValue?['remark']) ??
      _asString(newValue?['resolution_note']) ??
      '';

  String get formattedTitle {
    switch (action) {
      case 'society.complaint_created':
        return 'Complaint Raised';
      case 'society.complaint_assigned':
        return targetName.isNotEmpty ? 'Assigned to $targetName' : 'Complaint Assigned';
      case 'society.complaint_status_changed':
        final newStatus = _asString(newValue?['status'])?.toLowerCase();
        if (newStatus == 'in_progress') return 'Work Started (In Progress)';
        if (newStatus == 'resolved') return 'Marked Resolved';
        if (newStatus == 'closed') return 'Complaint Closed';
        if (newStatus == 'open') return 'Complaint Reopened';
        return 'Status Changed: ${newStatus?.toUpperCase() ?? ''}';
      case 'society.complaint_deleted':
        return 'Complaint Deleted';
      default:
        return action.replaceAll('society.', '').replaceAll('_', ' ').toUpperCase();
    }
  }

  factory SocietyComplaintHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return SocietyComplaintHistoryItemModel(
      id: _asInt(json['id']) ?? 0,
      societyId: _asInt(json['society_id'] ?? json['societyId']),
      actorUserId: _asInt(json['actor_user_id'] ?? json['actorUserId']),
      action: _asString(json['action']) ?? '',
      targetUserId: _asInt(json['target_user_id'] ?? json['targetUserId']),
      targetEntityType: _asString(json['target_entity_type'] ?? json['targetEntityType']),
      targetEntityId: _asInt(json['target_entity_id'] ?? json['targetEntityId']),
      oldValue: json['old_value'] is Map ? Map<String, dynamic>.from(json['old_value'] as Map) : null,
      newValue: json['new_value'] is Map ? Map<String, dynamic>.from(json['new_value'] as Map) : null,
      reason: _asString(json['reason']),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
      actor: json['actor'] is Map ? Map<String, dynamic>.from(json['actor'] as Map) : null,
      targetUser: json['targetUser'] is Map ? Map<String, dynamic>.from(json['targetUser'] as Map) : null,
    );
  }
}


// ─── 5. Society Facility Model ──────────────────────────────────────────────
class SocietyFacilityModel {
  final int id;
  final int societyId;
  final String name;
  final String? description;
  final String? operatingHours;
  final String? bookingRules;
  final int? maxCapacity;
  final bool isActive;
  final DateTime? createdAt;

  const SocietyFacilityModel({
    required this.id,
    required this.societyId,
    required this.name,
    this.description,
    this.operatingHours,
    this.bookingRules,
    this.maxCapacity,
    required this.isActive,
    this.createdAt,
  });

  factory SocietyFacilityModel.fromJson(Map<String, dynamic> json) {
    return SocietyFacilityModel(
      id: _asInt(json['id'] ?? json['facilityId']) ?? 0,
      societyId: _asInt(json['society_id'] ?? json['societyId']) ?? 0,
      name: _asString(json['name']) ?? '',
      description: _asString(json['description']),
      operatingHours: _asString(json['operating_hours'] ?? json['operatingHours']),
      bookingRules: _asString(json['booking_rules'] ?? json['bookingRules']),
      maxCapacity: _asInt(json['max_capacity'] ?? json['maxCapacity']),
      isActive: _asBool(json['is_active'] ?? json['isActive'], defaultValue: true),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'society_id': societyId,
    'name': name,
    'description': description,
    'operating_hours': operatingHours,
    'booking_rules': bookingRules,
    'max_capacity': maxCapacity,
    'is_active': isActive,
  };
}

// ─── 6. Society Parking Model ───────────────────────────────────────────────
class SocietyParkingModel {
  final int id;
  final int societyId;
  final int? userId;
  final String parkingSlotNo;
  final String vehicleType; // '2_wheeler' | '4_wheeler' | 'other'
  final String vehicleNo;
  final String? vehicleModel;
  final bool isVisitorParking;
  final String status; // 'active' | 'inactive'
  final Map<String, dynamic>? owner;
  final DateTime? createdAt;

  const SocietyParkingModel({
    required this.id,
    required this.societyId,
    this.userId,
    required this.parkingSlotNo,
    required this.vehicleType,
    required this.vehicleNo,
    this.vehicleModel,
    required this.isVisitorParking,
    required this.status,
    this.owner,
    this.createdAt,
  });

  bool get is4Wheeler => vehicleType.contains('4') || vehicleType.toLowerCase() == 'car';
  bool get is2Wheeler => vehicleType.contains('2') || vehicleType.toLowerCase() == 'bike';
  String get ownerName =>
      _asString(owner?['userName'] ?? owner?['name']) ?? (userId != null ? 'Resident #$userId' : 'Unassigned');

  factory SocietyParkingModel.fromJson(Map<String, dynamic> json) {
    return SocietyParkingModel(
      id: _asInt(json['id'] ?? json['parkingId']) ?? 0,
      societyId: _asInt(json['society_id'] ?? json['societyId']) ?? 0,
      userId: _asInt(json['user_id'] ?? json['userId']),
      parkingSlotNo: _asString(json['parking_slot_no'] ?? json['parkingSlotNo'] ?? json['slot']) ?? '',
      vehicleType: _asString(json['vehicle_type'] ?? json['vehicleType']) ?? '4_wheeler',
      vehicleNo: _asString(json['vehicle_no'] ?? json['vehicleNo'] ?? json['plate']) ?? '',
      vehicleModel: _asString(json['vehicle_model'] ?? json['vehicleModel'] ?? json['name']),
      isVisitorParking: _asBool(json['is_visitor_parking'] ?? json['isVisitorParking']),
      status: _asString(json['status'])?.toLowerCase() ?? 'active',
      owner: json['owner'] as Map<String, dynamic>?,
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'society_id': societyId,
    'user_id': userId,
    'parking_slot_no': parkingSlotNo,
    'vehicle_type': vehicleType,
    'vehicle_no': vehicleNo,
    'vehicle_model': vehicleModel,
    'is_visitor_parking': isVisitorParking,
    'status': status,
  };
}

// ─── 7. Society Poll Model ──────────────────────────────────────────────────
class SocietyPollOptionModel {
  final int index;
  final String text;
  final int count;
  final int percentage;

  const SocietyPollOptionModel({
    required this.index,
    required this.text,
    required this.count,
    required this.percentage,
  });

  factory SocietyPollOptionModel.fromJson(dynamic data, int defaultIndex) {
    if (data is String) {
      return SocietyPollOptionModel(
        index: defaultIndex,
        text: data,
        count: 0,
        percentage: 0,
      );
    }
    if (data is Map<String, dynamic>) {
      return SocietyPollOptionModel(
        index: _asInt(data['index']) ?? defaultIndex,
        text: _asString(data['text'] ?? data['title']) ?? '',
        count: _asInt(data['count'] ?? data['votes']) ?? 0,
        percentage: _asInt(data['percentage']) ?? 0,
      );
    }
    return SocietyPollOptionModel(
      index: defaultIndex,
      text: data.toString(),
      count: 0,
      percentage: 0,
    );
  }
}

class SocietyPollModel {
  final int id;
  final int societyId;
  final int? createdBy;
  final String question;
  final List<SocietyPollOptionModel> options;
  final String status; // 'active' | 'closed'
  final DateTime? expiresAt;
  final int totalVotes;
  final bool hasVoted;
  final int? userVotedOption;
  final Map<String, dynamic>? creator;
  final DateTime? createdAt;

  const SocietyPollModel({
    required this.id,
    required this.societyId,
    this.createdBy,
    required this.question,
    required this.options,
    required this.status,
    this.expiresAt,
    required this.totalVotes,
    required this.hasVoted,
    this.userVotedOption,
    this.creator,
    this.createdAt,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory SocietyPollModel.fromJson(Map<String, dynamic> json) {
    List<SocietyPollOptionModel> parsedOptions = [];
    final rawOptions = json['options'];
    if (rawOptions is List) {
      for (int i = 0; i < rawOptions.length; i++) {
        parsedOptions.add(SocietyPollOptionModel.fromJson(rawOptions[i], i));
      }
    } else if (rawOptions is String && rawOptions.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawOptions);
        if (decoded is List) {
          for (int i = 0; i < decoded.length; i++) {
            parsedOptions.add(SocietyPollOptionModel.fromJson(decoded[i], i));
          }
        }
      } catch (_) {}
    }

    return SocietyPollModel(
      id: _asInt(json['id'] ?? json['pollId']) ?? 0,
      societyId: _asInt(json['society_id'] ?? json['societyId']) ?? 0,
      createdBy: _asInt(json['created_by'] ?? json['createdBy']),
      question: _asString(json['question']) ?? '',
      options: parsedOptions,
      status: _asString(json['status'])?.toLowerCase() ?? 'active',
      expiresAt: _asDateTime(json['expires_at'] ?? json['expiresAt']),
      totalVotes: _asInt(json['total_votes'] ?? json['totalVotes']) ?? 0,
      hasVoted: _asBool(json['has_voted'] ?? json['hasVoted'] ?? json['voted']),
      userVotedOption: _asInt(json['user_voted_option'] ?? json['selectedOption']),
      creator: json['creator'] as Map<String, dynamic>?,
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'society_id': societyId,
    'question': question,
    'options': options.map((o) => o.text).toList(),
    'status': status,
    'expires_at': expiresAt?.toIso8601String(),
  };
}

// ─── 8. Society Visitor Model ───────────────────────────────────────────────
class SocietyVisitorModel {
  final int id;
  final int societyId;
  final int? userId;
  final String visitorName;
  final String? visitorPhone;
  final String? purpose;
  final String? vehicleNo;
  final String? flatNo;
  final DateTime? expectedTime;
  final int? approvedBy;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String status; // 'expected' | 'at_gate' | 'approved' | 'denied' | 'checked_in' | 'checked_out'
  final String? remark;
  final Map<String, dynamic>? resident;
  final Map<String, dynamic>? approver;
  final DateTime? createdAt;

  const SocietyVisitorModel({
    required this.id,
    required this.societyId,
    this.userId,
    required this.visitorName,
    this.visitorPhone,
    this.purpose,
    this.vehicleNo,
    this.flatNo,
    this.expectedTime,
    this.approvedBy,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.remark,
    this.resident,
    this.approver,
    this.createdAt,
  });

  bool get isExpected => status.toLowerCase() == 'expected';
  bool get isAtGate => status.toLowerCase() == 'at_gate';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isDenied => status.toLowerCase() == 'denied';
  bool get isCheckedIn => status.toLowerCase() == 'checked_in';
  bool get isCheckedOut => status.toLowerCase() == 'checked_out';

  String get residentName =>
      _asString(resident?['userName'] ?? resident?['name']) ?? (userId != null ? 'Resident #$userId' : '');
  String get approverName =>
      _asString(approver?['userName'] ?? approver?['name']) ?? '';

  factory SocietyVisitorModel.fromJson(Map<String, dynamic> json) {
    return SocietyVisitorModel(
      id: _asInt(json['id'] ?? json['visitorId']) ?? 0,
      societyId: _asInt(json['society_id'] ?? json['societyId']) ?? 0,
      userId: _asInt(json['user_id'] ?? json['userId']),
      visitorName: _asString(json['visitor_name'] ?? json['visitorName'] ?? json['name']) ?? '',
      visitorPhone: _asString(json['visitor_phone'] ?? json['visitorPhone']),
      purpose: _asString(json['purpose'] ?? json['type']),
      vehicleNo: _asString(json['vehicle_no'] ?? json['vehicleNo']),
      flatNo: _asString(json['flat_no'] ?? json['flatNo']),
      expectedTime: _asDateTime(json['expected_time'] ?? json['expectedTime']),
      approvedBy: _asInt(json['approved_by'] ?? json['approvedBy']),
      checkInTime: _asDateTime(json['check_in_time'] ?? json['checkInTime']),
      checkOutTime: _asDateTime(json['check_out_time'] ?? json['checkOutTime']),
      status: _asString(json['status'])?.toLowerCase() ?? 'expected',
      remark: _asString(json['remark']),
      resident: json['resident'] as Map<String, dynamic>?,
      approver: json['approver'] as Map<String, dynamic>?,
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'society_id': societyId,
    'visitor_name': visitorName,
    'visitor_phone': visitorPhone,
    'purpose': purpose,
    'vehicle_no': vehicleNo,
    'flat_no': flatNo,
    'expected_time': expectedTime?.toIso8601String(),
    'status': status,
  };
}

// ─── 8. Society Document Model ──────────────────────────────────────────────
class SocietyDocumentModel {
  final int id;
  final int societyId;
  final String title;
  final String? description;
  final String fileUrl;
  final String? fileType;
  final int? fileSize;
  final String category; // 'bye_laws', 'agm_minutes', 'financial_report', 'noc_rules', 'circular', 'other'
  final int? uploadedBy;
  final Map<String, dynamic>? uploader;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SocietyDocumentModel({
    required this.id,
    required this.societyId,
    required this.title,
    this.description,
    required this.fileUrl,
    this.fileType,
    this.fileSize,
    this.category = 'other',
    this.uploadedBy,
    this.uploader,
    this.createdAt,
    this.updatedAt,
  });

  String get uploaderName =>
      _asString(uploader?['userName'] ?? uploader?['name']) ??
      (uploadedBy != null ? 'User #$uploadedBy' : 'Admin');

  String get categoryDisplayName {
    switch (category) {
      case 'bye_laws':
        return 'Bye-Laws';
      case 'agm_minutes':
        return 'AGM Minutes';
      case 'financial_report':
        return 'Financial Report';
      case 'noc_rules':
        return 'NOC / Rules';
      case 'circular':
        return 'Circular';
      default:
        return 'General Document';
    }
  }

  factory SocietyDocumentModel.fromJson(Map<String, dynamic> json) {
    return SocietyDocumentModel(
      id: _asInt(json['id']) ?? 0,
      societyId: _asInt(json['society_id'] ?? json['societyId']) ?? 0,
      title: _asString(json['title']) ?? '',
      description: _asString(json['description']),
      fileUrl: _asString(json['file_url'] ?? json['fileUrl']) ?? '',
      fileType: _asString(json['file_type'] ?? json['fileType']),
      fileSize: _asInt(json['file_size'] ?? json['fileSize']),
      category: _asString(json['category']) ?? 'other',
      uploadedBy: _asInt(json['uploaded_by'] ?? json['uploadedBy']),
      uploader: json['uploader'] as Map<String, dynamic>?,
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'society_id': societyId,
    'title': title,
    'description': description,
    'file_url': fileUrl,
    'file_type': fileType,
    'file_size': fileSize,
    'category': category,
  };
}

// ─── 9. Society Emergency Contact Model ─────────────────────────────────────
class SocietyEmergencyContactModel {
  final int id;
  final int societyId;
  final String name;
  final String? designation;
  final String phone;
  final String? altPhone;
  final String category; // 'security', 'medical', 'police', 'fire', 'plumber', 'electrician', 'management', 'other'
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SocietyEmergencyContactModel({
    required this.id,
    required this.societyId,
    required this.name,
    this.designation,
    required this.phone,
    this.altPhone,
    this.category = 'other',
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  String get categoryDisplayName {
    switch (category) {
      case 'security':
        return 'Security Guard';
      case 'medical':
        return 'Ambulance / Medical';
      case 'police':
        return 'Police Station';
      case 'fire':
        return 'Fire Station';
      case 'plumber':
        return 'Plumber';
      case 'electrician':
        return 'Electrician';
      case 'management':
        return 'Society Office / Manager';
      default:
        return 'Emergency Contact';
    }
  }

  factory SocietyEmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return SocietyEmergencyContactModel(
      id: _asInt(json['id']) ?? 0,
      societyId: _asInt(json['society_id'] ?? json['societyId']) ?? 0,
      name: _asString(json['name']) ?? '',
      designation: _asString(json['designation']),
      phone: _asString(json['phone']) ?? '',
      altPhone: _asString(json['alt_phone'] ?? json['altPhone']),
      category: _asString(json['category']) ?? 'other',
      createdBy: _asInt(json['created_by'] ?? json['createdBy']),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'society_id': societyId,
    'name': name,
    'designation': designation,
    'phone': phone,
    'alt_phone': altPhone,
    'category': category,
  };
}
