import 'package:flutter_test/flutter_test.dart';
import 'package:talentbridge/core/router/return_destination.dart';

void main() {
  test('keeps the plan and transaction reference on checkout return', () {
    final callback = Uri.parse(
      'https://example.invalid/payments?checkout=complete&planId=business'
      '&reference=payment-123&unrelated=ignored',
    );

    final destination = Uri.parse(paymentCheckoutDestination(callback)!);
    expect(destination.path, '/payments');
    expect(destination.queryParameters, {
      'checkout': 'complete',
      'planId': 'business',
      'reference': 'payment-123',
    });
  });

  test('leaves hash-routed links and normal visits to billing alone', () {
    expect(
      paymentCheckoutDestination(Uri.parse('https://example.invalid/payments')),
      isNull,
    );
    expect(
      paymentCheckoutDestination(
        Uri.parse('https://example.invalid/payments?checkout=complete#/jobs'),
      ),
      isNull,
    );
  });
}
