import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/modules/business/models/business_models.dart';

void main() {
  group('BusinessProfileModel Data Honesty & Fallbacks', () {
    test('returns neutral fallbacks when ratings and reviews are missing', () {
      final profile = BusinessProfileModel(
        id: 1,
        businessName: 'Sharma Grocery',
        categoryName: 'Grocery',
      );

      expect(profile.rating, isNull);
      expect(profile.reviewCount, isNull);
      expect(profile.hasRating, isFalse);
      expect(profile.formattedRating, '--');
      expect(profile.formattedReviewCount, 'No reviews yet');
      expect(profile.displayOperatingHours, 'Hours not available');
      expect(profile.isVerified, isFalse);
    });

    test('formats real ratings and reviews when present from backend', () {
      final profile = BusinessProfileModel(
        id: 2,
        businessName: 'Patel Sweets',
        categoryName: 'Sweets',
        rating: 4.5,
        reviewCount: 14,
        operatingHours: '09:00 - 21:00',
        isVerified: true,
      );

      expect(profile.hasRating, isTrue);
      expect(profile.formattedRating, '4.5');
      expect(profile.formattedReviewCount, '(14 reviews)');
      expect(profile.displayOperatingHours, '09:00 - 21:00');
      expect(profile.isVerified, isTrue);
    });

    test('parses fromJson with missing fields without fabricating fake stats', () {
      final json = {
        'id': 10,
        'business_name': 'Gupta Medicos',
        'category_name': 'Pharmacy',
      };
      final profile = BusinessProfileModel.fromJson(json);

      expect(profile.id, 10);
      expect(profile.businessName, 'Gupta Medicos');
      expect(profile.categoryName, 'Pharmacy');
      expect(profile.rating, isNull);
      expect(profile.reviewCount, isNull);
      expect(profile.isVerified, isFalse);
      expect(profile.formattedRating, '--');
      expect(profile.formattedReviewCount, 'No reviews yet');
    });

    test('toJson serializes core profile attributes correctly', () {
      final profile = BusinessProfileModel(
        id: 5,
        businessName: 'Apex Electronics',
        categoryName: 'Electronics',
        description: 'Quality gadgets',
        phone: '9876543210',
        address: 'Main Bazaar',
      );

      final json = profile.toJson();
      expect(json['business_name'], 'Apex Electronics');
      expect(json['category_name'], 'Electronics');
      expect(json['description'], 'Quality gadgets');
      expect(json['phone'], '9876543210');
      expect(json['address'], 'Main Bazaar');
    });
  });

  group('BusinessOfferModel Data Honesty', () {
    test('parses fromJson without fake fallback values', () {
      final json = {
        'id': 1,
        'business_id': 10,
        'title': 'Diwali Festive Sale',
      };
      final offer = BusinessOfferModel.fromJson(json);

      expect(offer.id, 1);
      expect(offer.title, 'Diwali Festive Sale');
      expect(offer.discountPercent, 0);
      expect(offer.promoCode, isNull);
      expect(offer.isActive, isTrue);
    });
  });

  group('BusinessLeadModel Data Honesty', () {
    test('parses fromJson with neutral status and null product info', () {
      final json = {
        'id': 20,
        'business_id': 10,
        'customer_name': 'Ramesh Kumar',
        'customer_phone': '9876500000',
        'message': 'Is sugar in stock?',
      };
      final lead = BusinessLeadModel.fromJson(json);

      expect(lead.id, '20');
      expect(lead.customerName, 'Ramesh Kumar');
      expect(lead.inquiryType, 'General Inquiry');
      expect(lead.status, 'NEW');
    });
  });

  group('BusinessReviewModel Data Honesty', () {
    test('parses real rating without fabricating 5 stars', () {
      final json = {
        'id': 100,
        'business_id': 10,
        'user_name': 'Aarav',
        'rating': 3,
        'comment': 'Average service',
      };
      final review = BusinessReviewModel.fromJson(json);

      expect(review.id, 100);
      expect(review.rating, 3);
      expect(review.comment, 'Average service');
      expect(review.replyText, isNull);
    });
  });
}
