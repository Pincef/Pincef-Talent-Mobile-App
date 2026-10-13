import 'package:dio/dio.dart';

class PaymentRepository {
  PaymentRepository(this._dio);
  final Dio _dio;

  Future<List<SubscriptionPlan>> getPlans() async {
    final response = await _dio.get('/payment/plans');
    final body = Map<String, dynamic>.from(response.data as Map);
    final rows = body['data'] as List? ?? const [];
    return rows
        .map((row) =>
            SubscriptionPlan.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<CurrentSubscription?> getCurrentSubscription() async {
    final response = await _dio.get('/payment/subscription');
    final body = Map<String, dynamic>.from(response.data as Map);
    final data = Map<String, dynamic>.from(body['data'] as Map);
    final subscription = data['subscription'];
    return subscription is Map
        ? CurrentSubscription.fromJson(Map<String, dynamic>.from(subscription))
        : null;
  }

  Future<Uri> createCheckout(SubscriptionPlan plan) async {
    final response = await _dio.post('/payment/checkout', data: {
      'planId': plan.id,
      'subscriberType': 'company',
    });
    final body = Map<String, dynamic>.from(response.data as Map);
    final data = Map<String, dynamic>.from(body['data'] as Map);
    final uri = Uri.tryParse(data['url']?.toString() ?? '');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException(
          'The server returned an invalid checkout URL.');
    }
    return uri;
  }

  Future<Uri> createManagementLink() async {
    final response = await _dio.post('/payment/manage');
    final body = Map<String, dynamic>.from(response.data as Map);
    final data = Map<String, dynamic>.from(body['data'] as Map);
    final uri = Uri.tryParse(data['url']?.toString() ?? '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException(
          'The server returned an invalid billing URL.');
    }
    return uri;
  }
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.amountMinor,
    required this.currency,
    required this.interval,
    required this.features,
    required this.checkoutAvailable,
    required this.featured,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final int amountMinor;
  final String currency;
  final String interval;
  final List<String> features;
  final bool checkoutAvailable;
  final bool featured;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        id: json['id'] as String,
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? 'Plan').toString(),
        description: (json['description'] ?? '').toString(),
        amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
        currency: (json['currency'] ?? 'NGN').toString().toUpperCase(),
        interval: (json['interval'] ?? 'monthly').toString(),
        features: (json['features'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
        checkoutAvailable: json['checkoutAvailable'] == true,
        featured: json['featured'] == true,
      );

  bool get isFree => amountMinor == 0 || code.toLowerCase() == 'free';
}

class CurrentSubscription {
  const CurrentSubscription({
    required this.status,
    required this.provider,
    required this.currentPeriodEnd,
    required this.planCode,
    required this.planName,
  });

  final String status;
  final String provider;
  final DateTime? currentPeriodEnd;
  final String planCode;
  final String planName;

  factory CurrentSubscription.fromJson(Map<String, dynamic> json) {
    final plan = Map<String, dynamic>.from(json['plan'] as Map? ?? const {});
    return CurrentSubscription(
      status: (json['status'] ?? 'unknown').toString(),
      provider: (json['provider'] ?? '').toString(),
      currentPeriodEnd:
          DateTime.tryParse((json['currentPeriodEnd'] ?? '').toString()),
      planCode: (plan['code'] ?? '').toString(),
      planName: (plan['name'] ?? 'Free').toString(),
    );
  }
}
