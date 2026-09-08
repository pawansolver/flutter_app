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
  final str = value.toString().toLowerCase().trim();
  if (str == 'true' || str == '1') return true;
  if (str == 'false' || str == '0') return false;
  return defaultValue;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

/// Category of a local service (e.g., Electrician, Plumber, Cleaner)
class ServiceCategoryModel {
  final int id;
  final String name;
  final String? image;

  const ServiceCategoryModel({
    required this.id,
    required this.name,
    this.image,
  });

  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) {
    return ServiceCategoryModel(
      id: _asInt(json['serviceCategoryId'] ?? json['id']) ?? 0,
      name: json['serviceCategoryName']?.toString() ?? json['name']?.toString() ?? 'General Service',
      image: json['serviceCategoryImage']?.toString() ?? json['image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'serviceCategoryId': id,
    'serviceCategoryName': name,
    'serviceCategoryImage': image,
  };
}

/// Service Provider profile details
class ServiceProviderProfileModel {
  final int id;
  final int? userId;
  final int? serviceCategoryId;
  final String? description;
  final String? experience;
  final double? hourlyRate;
  final bool isVerified;
  final String? userName;
  final String? userEmail;
  final String? categoryName;

  const ServiceProviderProfileModel({
    required this.id,
    this.userId,
    this.serviceCategoryId,
    this.description,
    this.experience,
    this.hourlyRate,
    this.isVerified = false,
    this.userName,
    this.userEmail,
    this.categoryName,
  });

  factory ServiceProviderProfileModel.fromJson(Map<String, dynamic> json) {
    final userObj = json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : null;
    final catObj = json['category'] is Map<String, dynamic> ? json['category'] as Map<String, dynamic> : null;

    return ServiceProviderProfileModel(
      id: _asInt(json['id']) ?? 0,
      userId: _asInt(json['user_id'] ?? json['userId']),
      serviceCategoryId: _asInt(json['service_category_id'] ?? json['serviceCategoryId']),
      description: json['description']?.toString(),
      experience: json['experience']?.toString(),
      hourlyRate: _asDouble(json['hourly_rate'] ?? json['hourlyRate']),
      isVerified: _asBool(json['is_verified'] ?? json['isVerified']),
      userName: userObj?['userName']?.toString() ?? userObj?['name']?.toString() ?? json['userName']?.toString(),
      userEmail: userObj?['email']?.toString() ?? json['userEmail']?.toString(),
      categoryName: catObj?['serviceCategoryName']?.toString() ?? json['categoryName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'service_category_id': serviceCategoryId,
    'description': description,
    'experience': experience,
    'hourly_rate': hourlyRate,
    'is_verified': isVerified,
  };
}

/// Service Listing offering (e.g. AC Repair, Pipe Fitting)
class ServiceListingModel {
  final int id;
  final int? providerId;
  final int? providerUserId;
  final String title;
  final String? description;
  final double? price;
  final String? duration;
  final bool isAvailable;
  final String? categoryName;
  final int? categoryId;
  final int bookingsCount;
  final String? providerName;
  final String? providerAvatar;
  final String? providerExperience;
  final bool isProviderVerified;
  final double rating;
  final int reviewsCount;
  final String? distance;

  const ServiceListingModel({
    required this.id,
    this.providerId,
    this.providerUserId,
    required this.title,
    this.description,
    this.price,
    this.duration,
    this.isAvailable = true,
    this.categoryName,
    this.categoryId,
    this.bookingsCount = 0,
    this.providerName,
    this.providerAvatar,
    this.providerExperience,
    this.isProviderVerified = false,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.distance,
  });

  factory ServiceListingModel.fromJson(Map<String, dynamic> json) {
    final providerObj = json['provider'] is Map<String, dynamic> ? json['provider'] as Map<String, dynamic> : null;
    final catObj = providerObj?['category'] is Map<String, dynamic> ? providerObj!['category'] as Map<String, dynamic> : null;
    final userObj = providerObj?['user'] is Map<String, dynamic> ? providerObj!['user'] as Map<String, dynamic> : null;

    return ServiceListingModel(
      id: _asInt(json['id']) ?? 0,
      providerId: _asInt(json['provider_id'] ?? json['providerId']),
      providerUserId: _asInt(providerObj?['user_id'] ?? json['provider_user_id']),
      title: json['title']?.toString() ?? 'Untitled Service',
      description: json['description']?.toString(),
      price: _asDouble(json['price']),
      duration: json['duration']?.toString(),
      isAvailable: _asBool(json['is_available'] ?? json['isAvailable'], defaultValue: true),
      categoryName: catObj?['serviceCategoryName']?.toString() ?? json['categoryName']?.toString() ?? 'General',
      categoryId: _asInt(providerObj?['service_category_id'] ?? json['categoryId']),
      bookingsCount: _asInt(json['bookingsCount'] ?? json['booking_count']) ?? 0,
      providerName: userObj?['userName']?.toString() ?? json['providerName']?.toString(),
      providerAvatar: userObj?['profile_image']?.toString() ?? json['providerAvatar']?.toString(),
      providerExperience: providerObj?['experience']?.toString() ?? json['experience']?.toString(),
      isProviderVerified: _asBool(providerObj?['is_verified'] ?? json['is_verified'], defaultValue: false),
      rating: _asDouble(json['rating']) ?? 0.0,
      reviewsCount: _asInt(json['reviews_count'] ?? json['reviewsCount']) ?? 0,
      distance: json['distance']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider_id': providerId,
    'title': title,
    'description': description,
    'price': price,
    'duration': duration,
    'is_available': isAvailable,
  };

  ServiceListingModel copyWith({
    int? id,
    int? providerId,
    int? providerUserId,
    String? title,
    String? description,
    double? price,
    String? duration,
    bool? isAvailable,
    String? categoryName,
    int? categoryId,
    int? bookingsCount,
    String? providerName,
    String? providerAvatar,
    String? providerExperience,
    bool? isProviderVerified,
    double? rating,
    int? reviewsCount,
    String? distance,
  }) {
    return ServiceListingModel(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      providerUserId: providerUserId ?? this.providerUserId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      duration: duration ?? this.duration,
      isAvailable: isAvailable ?? this.isAvailable,
      categoryName: categoryName ?? this.categoryName,
      categoryId: categoryId ?? this.categoryId,
      bookingsCount: bookingsCount ?? this.bookingsCount,
      providerName: providerName ?? this.providerName,
      providerAvatar: providerAvatar ?? this.providerAvatar,
      providerExperience: providerExperience ?? this.providerExperience,
      isProviderVerified: isProviderVerified ?? this.isProviderVerified,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      distance: distance ?? this.distance,
    );
  }
}

/// Service Review model
class ServiceReviewModel {
  final int id;
  final int? bookingId;
  final int? userId;
  final int rating;
  final String? comment;
  final String? userName;
  final String? userAvatar;
  final DateTime? createdAt;

  const ServiceReviewModel({
    required this.id,
    this.bookingId,
    this.userId,
    this.rating = 5,
    this.comment,
    this.userName,
    this.userAvatar,
    this.createdAt,
  });

  factory ServiceReviewModel.fromJson(Map<String, dynamic> json) {
    final userObj = json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : null;

    return ServiceReviewModel(
      id: _asInt(json['id']) ?? 0,
      bookingId: _asInt(json['booking_id'] ?? json['bookingId']),
      userId: _asInt(json['user_id'] ?? json['userId']),
      rating: _asInt(json['rating']) ?? 5,
      comment: json['comment']?.toString(),
      userName: userObj?['userName']?.toString() ?? userObj?['name']?.toString() ?? json['userName']?.toString() ?? 'Resident',
      userAvatar: userObj?['profile_image']?.toString() ?? json['userAvatar']?.toString(),
      createdAt: _asDateTime(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'booking_id': bookingId,
    'user_id': userId,
    'rating': rating,
    'comment': comment,
  };
}

/// Service Booking representation
class ServiceBookingModel {
  final int id;
  final int? listingId;
  final int? userId;
  final DateTime? scheduledAt;
  final String status; // 'pending', 'confirmed', 'completed', 'cancelled'
  final double? amount;
  final String? serviceTitle;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;

  const ServiceBookingModel({
    required this.id,
    this.listingId,
    this.userId,
    this.scheduledAt,
    this.status = 'pending',
    this.amount,
    this.serviceTitle,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
  });

  factory ServiceBookingModel.fromJson(Map<String, dynamic> json) {
    final listingObj = json['listing'] is Map<String, dynamic> ? json['listing'] as Map<String, dynamic> : null;
    final userObj = json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : null;

    return ServiceBookingModel(
      id: _asInt(json['id']) ?? 0,
      listingId: _asInt(json['listing_id'] ?? json['listingId']),
      userId: _asInt(json['user_id'] ?? json['userId']),
      scheduledAt: _asDateTime(json['scheduled_at'] ?? json['scheduledAt']),
      status: (json['status']?.toString().toLowerCase().trim() ?? 'pending'),
      amount: _asDouble(json['amount'] ?? listingObj?['price']),
      serviceTitle: listingObj?['title']?.toString() ?? json['serviceTitle']?.toString() ?? 'Service Request',
      customerName: userObj?['userName']?.toString() ?? userObj?['name']?.toString() ?? json['customerName']?.toString() ?? 'Neighbor',
      customerPhone: userObj?['phone']?.toString() ?? userObj?['mobile']?.toString() ?? json['customerPhone']?.toString(),
      customerEmail: userObj?['email']?.toString() ?? json['customerEmail']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'listing_id': listingId,
    'user_id': userId,
    'scheduled_at': scheduledAt?.toIso8601String(),
    'status': status,
    'amount': amount,
  };

  ServiceBookingModel copyWith({
    int? id,
    int? listingId,
    int? userId,
    DateTime? scheduledAt,
    String? status,
    double? amount,
    String? serviceTitle,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
  }) {
    return ServiceBookingModel(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      userId: userId ?? this.userId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
    );
  }
}

/// Provider-side summary statistics for the Overview section
class ProviderOverviewStats {
  final int totalServices;
  final int pendingBookings;
  final int upcomingBookings;
  final int completedBookings;
  final double rating;
  final double earnings;

  const ProviderOverviewStats({
    this.totalServices = 0,
    this.pendingBookings = 0,
    this.upcomingBookings = 0,
    this.completedBookings = 0,
    this.rating = 0.0,
    this.earnings = 0.0,
  });

  factory ProviderOverviewStats.fromData({
    required List<ServiceListingModel> services,
    required List<ServiceBookingModel> bookings,
    double rating = 0.0,
  }) {
    int pending = 0;
    int upcoming = 0;
    int completed = 0;
    double totalEarned = 0.0;

    for (final b in bookings) {
      final s = b.status.toLowerCase();
      if (s == 'pending') {
        pending++;
      } else if (s == 'confirmed' || s == 'in_progress') {
        upcoming++;
      } else if (s == 'completed') {
        completed++;
        totalEarned += (b.amount ?? 0.0);
      }
    }

    return ProviderOverviewStats(
      totalServices: services.length,
      pendingBookings: pending,
      upcomingBookings: upcoming,
      completedBookings: completed,
      rating: rating,
      earnings: totalEarned,
    );
  }
}
