import 'dart:convert';
import '../core/api_config.dart';

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

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim())?.toLocal();
  }
  return null;
}

class EventCategoryModel {
  final int id;
  final String name;
  final String? icon;

  const EventCategoryModel({
    required this.id,
    required this.name,
    this.icon,
  });

  factory EventCategoryModel.fromJson(Map<String, dynamic> json) {
    return EventCategoryModel(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? 'General',
      icon: json['icon']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
  };
}

class EventCreatorModel {
  final int userId;
  final String userName;
  final String? profileImage;
  final String? email;
  final String? phone;

  const EventCreatorModel({
    required this.userId,
    required this.userName,
    this.profileImage,
    this.email,
    this.phone,
  });

  factory EventCreatorModel.fromJson(Map<String, dynamic> json) {
    return EventCreatorModel(
      userId: _asInt(json['userId'] ?? json['id']) ?? 0,
      userName: json['userName']?.toString() ?? 'Host',
      profileImage: ApiConfig.normalizeMediaUrl(json['profile_image']?.toString()),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}

class EventCommunityModel {
  final int communityId;
  final String communityName;
  final String? coverImage;
  final bool isPrivate;

  const EventCommunityModel({
    required this.communityId,
    required this.communityName,
    this.coverImage,
    this.isPrivate = false,
  });

  factory EventCommunityModel.fromJson(Map<String, dynamic> json) {
    return EventCommunityModel(
      communityId: _asInt(json['communityId'] ?? json['id']) ?? 0,
      communityName: json['communityName']?.toString() ?? 'Community',
      coverImage: ApiConfig.normalizeMediaUrl(json['cover_image']?.toString()),
      isPrivate: json['is_private'] == true || json['is_private'] == 1,
    );
  }
}

class SubEventModel {
  final String id;
  final String title;
  final String? description;
  final String? date;
  final String? startTime;
  final String? endTime;
  final String? venue;
  final String? location;
  final String? address;
  final String eventType; // offline, online, hybrid
  final String? speakerOrHost;
  final String activityType; // ceremony, competition, sports, cultural, dining, workshop, meeting, general
  final int? capacity;
  final bool isRegistrationRequired;
  final String status; // scheduled, ongoing, completed, cancelled
  final String? coverImage;
  final String? localImagePath;

  const SubEventModel({
    required this.id,
    required this.title,
    this.description,
    this.date,
    this.startTime,
    this.endTime,
    this.venue,
    this.location,
    this.address,
    this.eventType = 'offline',
    this.speakerOrHost,
    this.activityType = 'general',
    this.capacity,
    this.isRegistrationRequired = false,
    this.status = 'scheduled',
    this.coverImage,
    this.localImagePath,
  });

  factory SubEventModel.fromJson(Map<String, dynamic> json) {
    final venueStr = json['venue']?.toString() ?? json['location_name']?.toString() ?? json['location']?.toString();
    return SubEventModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      date: json['date']?.toString(),
      startTime: json['start_time']?.toString() ?? json['startTime']?.toString(),
      endTime: json['end_time']?.toString() ?? json['endTime']?.toString(),
      venue: venueStr,
      location: json['location']?.toString() ?? venueStr,
      address: json['address']?.toString(),
      eventType: json['event_type']?.toString() ?? json['eventType']?.toString() ?? 'offline',
      speakerOrHost: json['speaker_or_host']?.toString() ?? json['speakerOrHost']?.toString(),
      activityType: json['activity_type']?.toString() ?? json['activityType']?.toString() ?? 'general',
      capacity: _asInt(json['capacity'] ?? json['max_participants'] ?? json['maxParticipants']),
      isRegistrationRequired: json['is_registration_required'] == true ||
          json['is_registration_required'] == 1 ||
          json['isRegistrationRequired'] == true,
      status: json['status']?.toString() ?? 'scheduled',
      coverImage: ApiConfig.normalizeMediaUrl(json['cover_image']?.toString() ?? json['coverImage']?.toString()),
      localImagePath: json['local_image_path']?.toString() ?? json['localImagePath']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'title': title,
      if (description != null && description!.isNotEmpty) 'description': description,
      if (date != null && date!.isNotEmpty) 'date': date,
      if (startTime != null && startTime!.isNotEmpty) 'start_time': startTime,
      if (endTime != null && endTime!.isNotEmpty) 'end_time': endTime,
      if (venue != null && venue!.isNotEmpty) 'venue': venue,
      if (location != null && location!.isNotEmpty) 'location': location,
      if (address != null && address!.isNotEmpty) 'address': address,
      'event_type': eventType,
      if (speakerOrHost != null && speakerOrHost!.isNotEmpty) 'speaker_or_host': speakerOrHost,
      'activity_type': activityType,
      if (capacity != null) 'capacity': capacity,
      if (capacity != null) 'max_participants': capacity,
      'is_registration_required': isRegistrationRequired,
      'status': status,
      if (coverImage != null && coverImage!.isNotEmpty) 'cover_image': coverImage,
    };
  }

  SubEventModel copyWith({
    String? id,
    String? title,
    String? description,
    String? date,
    String? startTime,
    String? endTime,
    String? venue,
    String? location,
    String? address,
    String? eventType,
    String? speakerOrHost,
    String? activityType,
    int? capacity,
    bool? isRegistrationRequired,
    String? status,
    String? coverImage,
    String? localImagePath,
  }) {
    return SubEventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      venue: venue ?? this.venue,
      location: location ?? this.location,
      address: address ?? this.address,
      eventType: eventType ?? this.eventType,
      speakerOrHost: speakerOrHost ?? this.speakerOrHost,
      activityType: activityType ?? this.activityType,
      capacity: capacity ?? this.capacity,
      isRegistrationRequired: isRegistrationRequired ?? this.isRegistrationRequired,
      status: status ?? this.status,
      coverImage: coverImage ?? this.coverImage,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }
}

class EventModel {
  final int id;
  final String title;
  final String? description;
  final int? categoryId;
  final int? communityId;
  final int? societyId;
  final String eventType; // online, offline, hybrid
  final String visibility; // public, community, private
  final String status; // draft, published, cancelled, completed
  final DateTime? startAt;
  final DateTime? endAt;
  final String? location;
  final String? locationName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? coverImage;
  final int? maxParticipants;
  final String? speakerOrHost;
  final bool isRegistrationRequired;
  final int goingCount;
  final int interestedCount;
  final int declinedCount;
  final String? myRsvpStatus; // going, interested, declined, invited, null
  final double? distanceKm;
  final List<SubEventModel> subEvents;
  final EventCreatorModel? creator;
  final EventCommunityModel? community;
  final EventCategoryModel? category;

  const EventModel({
    required this.id,
    required this.title,
    this.description,
    this.categoryId,
    this.communityId,
    this.societyId,
    this.eventType = 'offline',
    this.visibility = 'public',
    this.status = 'published',
    this.startAt,
    this.endAt,
    this.location,
    this.locationName,
    this.address,
    this.latitude,
    this.longitude,
    this.coverImage,
    this.maxParticipants,
    this.speakerOrHost,
    this.isRegistrationRequired = false,
    this.goingCount = 0,
    this.interestedCount = 0,
    this.declinedCount = 0,
    this.myRsvpStatus,
    this.distanceKm,
    this.subEvents = const [],
    this.creator,
    this.community,
    this.category,
  });

  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isFull =>
      maxParticipants != null &&
      maxParticipants! > 0 &&
      goingCount >= maxParticipants!;

  String get venueDisplay {
    if (locationName != null && locationName!.trim().isNotEmpty) {
      return locationName!.trim();
    }
    if (location != null && location!.trim().isNotEmpty) {
      return location!.trim();
    }
    if (address != null && address!.trim().isNotEmpty) {
      return address!.trim();
    }
    return eventType.toLowerCase() == 'online' ? 'Online Event' : 'Local Venue';
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: _asInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? 'Event',
      description: json['description']?.toString(),
      categoryId: _asInt(json['category_id'] ?? json['categoryId']),
      communityId: _asInt(json['community_id'] ?? json['communityId']),
      societyId: _asInt(json['society_id'] ?? json['societyId']),
      eventType: json['event_type']?.toString() ?? 'offline',
      visibility: json['visibility']?.toString() ?? 'public',
      status: json['status']?.toString() ?? 'published',
      startAt: _asDate(json['start_at'] ?? json['date']),
      endAt: _asDate(json['end_at']),
      location: json['location']?.toString(),
      locationName: json['location_name']?.toString(),
      address: json['address']?.toString(),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      coverImage: ApiConfig.normalizeMediaUrl(json['cover_image']?.toString()),
      maxParticipants: _asInt(json['max_participants']),
      speakerOrHost: json['speaker_or_host']?.toString() ?? json['speakerOrHost']?.toString(),
      isRegistrationRequired: json['is_registration_required'] == true ||
          json['is_registration_required'] == 1 ||
          json['isRegistrationRequired'] == true,
      goingCount: _asInt(json['going_count'] ?? json['goingCount']) ?? 0,
      interestedCount: _asInt(json['interested_count'] ?? json['interestedCount']) ?? 0,
      declinedCount: _asInt(json['declined_count'] ?? json['declinedCount']) ?? 0,
      myRsvpStatus: json['myRsvpStatus']?.toString() ?? json['my_rsvp_status']?.toString(),
      distanceKm: _asDouble(json['distance_km'] ?? json['distanceKm']),
      subEvents: () {
        dynamic raw = json['sub_events'] ?? json['subEvents'];
        if (raw == null) return <SubEventModel>[];
        if (raw is String && raw.trim().isNotEmpty) {
          try {
            raw = jsonDecode(raw);
          } catch (_) {
            return <SubEventModel>[];
          }
        }
        if (raw is List) {
          return raw
              .where((e) => e != null && e is Map)
              .map((e) => SubEventModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
        return <SubEventModel>[];
      }(),
      creator: json['creator'] is Map<String, dynamic>
          ? EventCreatorModel.fromJson(json['creator'])
          : null,
      community: json['community'] is Map<String, dynamic>
          ? EventCommunityModel.fromJson(json['community'])
          : null,
      category: json['category'] is Map<String, dynamic>
          ? EventCategoryModel.fromJson(json['category'])
          : null,
    );
  }

  EventModel copyWith({
    String? myRsvpStatus,
    int? goingCount,
    int? interestedCount,
    int? declinedCount,
    String? status,
    String? title,
    String? description,
    String? location,
    String? locationName,
    String? address,
    DateTime? startAt,
    DateTime? endAt,
    String? coverImage,
    int? societyId,
    int? maxParticipants,
    String? speakerOrHost,
    bool? isRegistrationRequired,
    List<SubEventModel>? subEvents,
  }) {
    return EventModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId,
      communityId: communityId,
      societyId: societyId ?? this.societyId,
      eventType: eventType,
      visibility: visibility,
      status: status ?? this.status,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      location: location ?? this.location,
      locationName: locationName ?? this.locationName,
      address: address ?? this.address,
      latitude: latitude,
      longitude: longitude,
      coverImage: coverImage ?? this.coverImage,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      speakerOrHost: speakerOrHost ?? this.speakerOrHost,
      isRegistrationRequired: isRegistrationRequired ?? this.isRegistrationRequired,
      goingCount: goingCount ?? this.goingCount,
      interestedCount: interestedCount ?? this.interestedCount,
      declinedCount: declinedCount ?? this.declinedCount,
      myRsvpStatus: myRsvpStatus ?? this.myRsvpStatus,
      distanceKm: distanceKm,
      subEvents: subEvents ?? this.subEvents,
      creator: creator,
      community: community,
      category: category,
    );
  }
}

class EventParticipantModel {
  final int id;
  final int eventId;
  final int userId;
  final String status;
  final DateTime? joinedAt;
  final EventCreatorModel? user;

  const EventParticipantModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    this.joinedAt,
    this.user,
  });

  factory EventParticipantModel.fromJson(Map<String, dynamic> json) {
    return EventParticipantModel(
      id: _asInt(json['id']) ?? 0,
      eventId: _asInt(json['event_id']) ?? 0,
      userId: _asInt(json['user_id']) ?? 0,
      status: json['status']?.toString() ?? 'going',
      joinedAt: json['joined_at'] != null ? DateTime.tryParse(json['joined_at'].toString()) : null,
      user: json['user'] is Map<String, dynamic> ? EventCreatorModel.fromJson(json['user']) : null,
    );
  }
}

class EventInvitationModel {
  final int id;
  final int eventId;
  final int inviterUserId;
  final int inviteeUserId;
  final String status; // pending, accepted, declined, cancelled
  final DateTime? responseAt;
  final EventModel? event;
  final EventCreatorModel? inviter;
  final DateTime? createdAt;

  const EventInvitationModel({
    required this.id,
    required this.eventId,
    required this.inviterUserId,
    required this.inviteeUserId,
    required this.status,
    this.responseAt,
    this.event,
    this.inviter,
    this.createdAt,
  });

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isAccepted => status.toLowerCase() == 'accepted';
  bool get isDeclined => status.toLowerCase() == 'declined';

  factory EventInvitationModel.fromJson(Map<String, dynamic> json) {
    return EventInvitationModel(
      id: _asInt(json['id']) ?? 0,
      eventId: _asInt(json['event_id'] ?? json['eventId']) ?? 0,
      inviterUserId: _asInt(json['inviter_user_id'] ?? json['inviterUserId']) ?? 0,
      inviteeUserId: _asInt(json['invitee_user_id'] ?? json['inviteeUserId']) ?? 0,
      status: json['status']?.toString().toLowerCase() ?? 'pending',
      responseAt: _asDate(json['response_at'] ?? json['responseAt']),
      event: json['event'] is Map<String, dynamic> ? EventModel.fromJson(json['event']) : null,
      inviter: json['inviter'] is Map<String, dynamic> ? EventCreatorModel.fromJson(json['inviter']) : null,
      createdAt: _asDate(json['created_at'] ?? json['createdAt']),
    );
  }
}

