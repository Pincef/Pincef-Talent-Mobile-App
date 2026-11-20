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
    // Billing state can change while this page is open (Paystack's webhook
    // runs asynchronously). A unique read URL avoids stale browser-cache
    // validation responses when the app returns from hosted checkout.
    final response = await _dio.get(
      '/payment/subscription',
      queryParameters: {'_fresh': DateTime.now().microsecondsSinceEpoch},
    );
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

  Future<CheckoutVerification> verifyCheckout(String reference) async {
    final response = await _dio.post(
      '/payment/verify',
      data: {'reference': reference},
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    final data = Map<String, dynamic>.from(body['data'] as Map);
    return CheckoutVerification(
      reference: (data['reference'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      planId: (data['planId'] ?? '').toString(),
    );
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

class CheckoutVerification {
  const CheckoutVerification({
    required this.reference,
    required this.status,
    required this.planId,
  });

  final String reference;
  final String status;
  final String planId;
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.amountMinor,
    required this.currency,
    required this.provider,
    required this.interval,
    required this.features,
    required this.excludedFeatures,
    required this.checkoutAvailable,
    required this.featured,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final int amountMinor;
  final String currency;
  final String? provider;
  final String interval;
  final List<String> features;
  final List<String> excludedFeatures;
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
        provider: json['provider']?.toString(),
        interval: (json['interval'] ?? 'monthly').toString(),
        features: (json['features'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
        excludedFeatures: (json['excludedFeatures'] as List? ?? const [])
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
    required this.planId,
    required this.planCode,
    required this.planName,
    required this.trialEndsAt,
  });

  final String status;
  final String provider;
  final DateTime? currentPeriodEnd;
  final String planId;
  final String planCode;
  final String planName;
  final DateTime? trialEndsAt;

  bool get isTrial =>
      status.toLowerCase() == 'trial' || trialEndsAt != null;

  factory CurrentSubscription.fromJson(Map<String, dynamic> json) {
    final plan = Map<String, dynamic>.from(json['plan'] as Map? ?? const {});
    return CurrentSubscription(
      status: (json['status'] ?? 'unknown').toString(),
      provider: (json['provider'] ?? '').toString(),
      currentPeriodEnd:
          DateTime.tryParse((json['currentPeriodEnd'] ?? '').toString()),
      planId: (plan['id'] ?? '').toString(),
      planCode: (plan['code'] ?? '').toString(),
      planName: (plan['name'] ?? 'Free').toString(),
      trialEndsAt: DateTime.tryParse((json['trialEndsAt'] ?? '').toString()),
    );
  }
}
