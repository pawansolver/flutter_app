class BusinessCategoryModel {
  final int id;
  final String name;
  final String? slug;
  final String? icon;
  final String? description;

  BusinessCategoryModel({
    required this.id,
    required this.name,
    this.slug,
    this.icon,
    this.description,
  });

  factory BusinessCategoryModel.fromJson(Map<String, dynamic> json) {
    return BusinessCategoryModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'General',
      slug: json['slug']?.toString(),
      icon: json['icon']?.toString(),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'icon': icon,
    'description': description,
  };
}

class BusinessProfileModel {
  final int id;
  final int? userId;
  final String businessName;
  final int? categoryId;
  final String categoryName;
  final String? description;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? operatingHours;
  final String? bannerUrl;
  final String? logoUrl;
  final bool isVerified;
  final double? rating;
  final int? reviewCount;
  final bool isOpen;

  BusinessProfileModel({
    required this.id,
    this.userId,
    required this.businessName,
    this.categoryId,
    this.categoryName = 'Local Business',
    this.description,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.operatingHours,
    this.bannerUrl,
    this.logoUrl,
    this.isVerified = false,
    this.rating,
    this.reviewCount,
    this.isOpen = true,
  });

  bool get hasRating => rating != null && rating! > 0;
  String get formattedRating => rating != null ? rating!.toStringAsFixed(1) : '--';
  String get formattedReviewCount => (reviewCount != null && reviewCount! > 0) ? '($reviewCount reviews)' : 'No reviews yet';
  String get displayOperatingHours => (operatingHours != null && operatingHours!.trim().isNotEmpty) ? operatingHours! : 'Hours not available';

  factory BusinessProfileModel.fromJson(Map<String, dynamic> json) {
    final rawRating = json['rating'] ?? json['avgRating'] ?? json['average_rating'];
    final rawReviewCount = json['reviewCount'] ?? json['totalReviews'] ?? json['reviews_count'];
    final rawHours = json['operatingHours'] ?? json['operating_hours'] ?? json['timings'];

    return BusinessProfileModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '1') ?? 1,
      userId: json['userId'] is int
          ? json['userId']
          : int.tryParse(json['userId']?.toString() ?? json['user_id']?.toString() ?? ''),
      businessName: json['businessName']?.toString() ??
          json['business_name']?.toString() ??
          json['name']?.toString() ??
          'Local Business',
      categoryId: json['categoryId'] is int
          ? json['categoryId']
          : int.tryParse(json['categoryId']?.toString() ?? json['category_id']?.toString() ?? ''),
      categoryName: json['category'] is Map
          ? (json['category']['name']?.toString() ?? 'Local Business')
          : (json['categoryName']?.toString() ?? json['category_name']?.toString() ?? json['category']?.toString() ?? 'Local Business'),
      description: json['description']?.toString(),
      address: json['address']?.toString() ?? json['location']?.toString(),
      phone: json['phone']?.toString() ??
          json['contactNumber']?.toString() ??
          json['contact_number']?.toString(),
      email: json['email']?.toString(),
      website: json['website']?.toString(),
      operatingHours: rawHours?.toString(),
      bannerUrl: json['bannerUrl']?.toString() ??
          json['banner_url']?.toString() ??
          json['coverImage']?.toString(),
      logoUrl: json['logoUrl']?.toString() ??
          json['logo_url']?.toString() ??
          json['logo']?.toString() ??
          json['profileImage']?.toString(),
      isVerified: json['isVerified'] == true || json['is_verified'] == true,
      rating: rawRating != null ? double.tryParse(rawRating.toString()) : null,
      reviewCount: rawReviewCount != null ? int.tryParse(rawReviewCount.toString()) : null,
      isOpen: json['isOpen'] == null ? true : (json['isOpen'] == true || json['is_open'] == true),
    );
  }

  BusinessProfileModel copyWith({
    String? businessName,
    String? categoryName,
    String? description,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? operatingHours,
    String? bannerUrl,
    String? logoUrl,
    bool? isVerified,
    double? rating,
    int? reviewCount,
    bool? isOpen,
  }) {
    return BusinessProfileModel(
      id: id,
      userId: userId,
      businessName: businessName ?? this.businessName,
      categoryId: categoryId,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      operatingHours: operatingHours ?? this.operatingHours,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isOpen: isOpen ?? this.isOpen,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'business_name': businessName,
    'category_id': categoryId,
    'category_name': categoryName,
    'description': description,
    'address': address,
    'phone': phone,
    'email': email,
    'website': website,
    'operating_hours': operatingHours,
    'banner_url': bannerUrl,
    'logo_url': logoUrl,
    'is_verified': isVerified,
    'rating': rating,
    'review_count': reviewCount,
    'is_open': isOpen,
  };
}

class BusinessProductModel {
  final String id;
  final int businessId;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final String? imageUrl;
  final bool inStock;
  final String category;

  BusinessProductModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description = '',
    required this.price,
    this.originalPrice,
    this.imageUrl,
    this.inStock = true,
    this.category = 'General',
  });

  factory BusinessProductModel.fromJson(Map<String, dynamic> json) {
    return BusinessProductModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      businessId: json['businessId'] is int ? json['businessId'] : int.tryParse(json['businessId']?.toString() ?? '1') ?? 1,
      name: json['name']?.toString() ?? 'Product',
      description: json['description']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      originalPrice: double.tryParse(json['originalPrice']?.toString() ?? ''),
      imageUrl: json['imageUrl']?.toString(),
      inStock: json['inStock'] != false,
      category: json['category']?.toString() ?? 'General',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'name': name,
    'description': description,
    'price': price,
    'originalPrice': originalPrice,
    'imageUrl': imageUrl,
    'inStock': inStock,
    'category': category,
  };
}

class BusinessOfferModel {
  final int id;
  final int businessId;
  final String title;
  final String description;
  final int discountPercent;
  final String? promoCode;
  final String validUntil;
  final String? bannerUrl;
  final bool isActive;

  BusinessOfferModel({
    required this.id,
    required this.businessId,
    required this.title,
    required this.description,
    required this.discountPercent,
    this.promoCode,
    required this.validUntil,
    this.bannerUrl,
    this.isActive = true,
  });

  factory BusinessOfferModel.fromJson(Map<String, dynamic> json) {
    return BusinessOfferModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '1') ?? 1,
      businessId: json['businessId'] is int ? json['businessId'] : int.tryParse(json['businessId']?.toString() ?? '1') ?? 1,
      title: json['title']?.toString() ?? json['offerTitle']?.toString() ?? 'Special Offer',
      description: json['description']?.toString() ?? '',
      discountPercent: int.tryParse(json['discountPercent']?.toString() ?? json['discount']?.toString() ?? '') ?? 0,
      promoCode: json['promoCode']?.toString(),
      validUntil: json['validUntil']?.toString() ?? json['validTo']?.toString() ?? 'Limited period',
      bannerUrl: json['bannerUrl']?.toString() ?? json['imageUrl']?.toString(),
      isActive: json['isActive'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'title': title,
    'description': description,
    'discountPercent': discountPercent,
    'promoCode': promoCode,
    'validUntil': validUntil,
    'bannerUrl': bannerUrl,
    'isActive': isActive,
  };
}

class BusinessLeadModel {
  final String id;
  final int businessId;
  final String customerName;
  final String customerPhone;
  final String inquiryType;
  final String message;
  final String status; // 'NEW', 'CONTACTED', 'CONVERTED', 'CLOSED'
  final DateTime createdAt;

  BusinessLeadModel({
    required this.id,
    required this.businessId,
    required this.customerName,
    required this.customerPhone,
    required this.inquiryType,
    required this.message,
    this.status = 'NEW',
    required this.createdAt,
  });

  factory BusinessLeadModel.fromJson(Map<String, dynamic> json) {
    return BusinessLeadModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      businessId: json['businessId'] is int ? json['businessId'] : 1,
      customerName: json['customerName']?.toString() ?? json['customer_name']?.toString() ?? 'Resident Customer',
      customerPhone: json['customerPhone']?.toString() ?? json['customer_phone']?.toString() ?? '',
      inquiryType: json['inquiryType']?.toString() ?? json['inquiry_type']?.toString() ?? 'General Inquiry',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'NEW',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'inquiryType': inquiryType,
    'message': message,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };
}

class BusinessReviewModel {
  final int id;
  final int businessId;
  final String userName;
  final String? userAvatar;
  final double rating;
  final String comment;
  final String? replyText;
  final DateTime? repliedAt;
  final DateTime createdAt;

  BusinessReviewModel({
    required this.id,
    required this.businessId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    required this.comment,
    this.replyText,
    this.repliedAt,
    required this.createdAt,
  });

  factory BusinessReviewModel.fromJson(Map<String, dynamic> json) {
    return BusinessReviewModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '1') ?? 1,
      businessId: json['businessId'] is int ? json['businessId'] : 1,
      userName: json['userName']?.toString() ?? json['user']?['fullName']?.toString() ?? 'Resident',
      userAvatar: json['userAvatar']?.toString() ?? json['user']?['avatarUrl']?.toString(),
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 0.0,
      comment: json['comment']?.toString() ?? '',
      replyText: json['replyText']?.toString() ?? json['reply']?.toString(),
      repliedAt: json['repliedAt'] != null ? DateTime.tryParse(json['repliedAt'].toString()) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
