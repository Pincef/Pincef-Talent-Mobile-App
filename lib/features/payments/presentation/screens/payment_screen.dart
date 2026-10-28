import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/auth_provider.dart';
import '../../application/payment_provider.dart';
import '../../data/payment_repository.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String? _checkoutPlanId;

  String _loadErrorMessage(Object error, String resource) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 404) {
        return 'The backend does not currently provide the $resource endpoint. Deploy the backend billing update, then reload this page.';
      }
      if (status == 401 || status == 403) {
        return 'Your session cannot access billing. Sign in again with a recruiter account.';
      }
      if (error.response == null) {
        return 'Could not reach the billing server. Check the API URL and, when running Flutter web locally, the backend CORS settings.';
      }
    }
    return 'Unable to load $resource: $error';
  }

  Future<void> _refreshSubscription() async {
    try {
      await ref.read(authProvider.notifier).refreshSession();
      ref.invalidate(currentSubscriptionProvider);
      ref.invalidate(subscriptionPlansProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription status refreshed.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh subscription: $error')),
        );
      }
    }
  }

  Future<void> _confirmAndCheckout(SubscriptionPlan plan) async {
    if (!plan.checkoutAvailable || plan.isFree || _checkoutPlanId != null) {
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Subscribe to ${plan.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${NumberFormat.simpleCurrency(
                name: plan.currency,
                decimalDigits: plan.currency == 'NGN' ? 0 : 2,
              ).format(plan.amountMinor / 100)} per job · billed ${plan.interval == 'yearly' ? 'annually' : 'monthly'}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You’ll continue to ${_providerLabel(plan.provider)}’s secure checkout to complete payment. You’ll return to TalentBridge when checkout is finished.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue to payment'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    setState(() => _checkoutPlanId = plan.id);
    try {
      final uri =
          await ref.read(paymentRepositoryProvider).createCheckout(plan);
      // Stripe Checkout and Paystack both provide hosted checkout pages.
      // Use the platform's normal navigation (same tab on web, browser on
      // native) so their success/cancel return URLs bring the user back here.
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open the secure checkout page.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start checkout: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkoutPlanId = null);
    }
  }

  String _providerLabel(String? provider) => switch (provider?.toLowerCase()) {
        'paystack' => 'Paystack',
        'stripe' => 'Stripe',
        _ => 'our payment provider',
      };

  int _planOrder(SubscriptionPlan plan) {
    final code = plan.code.toLowerCase();
    if (code == 'free') return 0;
    if (code.contains('starter')) return 1;
    if (code.contains('professional') || code.contains('pro')) return 2;
    if (code.contains('business')) return 3;
    return 4;
  }

  Future<void> _manageSubscription() async {
    try {
      final uri =
          await ref.read(paymentRepositoryProvider).createManagementLink();
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the billing portal.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not open subscription management: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(subscriptionPlansProvider);
    final current = ref.watch(currentSubscriptionProvider);
    final view = ref.watch(paymentViewProvider);
    return plans.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loadErrorMessage(error, 'billing plans')),
        ),
      ),
      data: (allItems) => current.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(_loadErrorMessage(error, 'your subscription')),
        ),
        data: (subscription) {
          final items = allItems
              .where((plan) =>
                  plan.interval == (view.isAnnual ? 'yearly' : 'monthly'))
              .toList();
          items.sort((a, b) => _planOrder(a).compareTo(_planOrder(b)));
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              return SingleChildScrollView(
                padding:
                    EdgeInsets.fromLTRB(wide ? 44 : 20, 30, wide ? 44 : 20, 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      children: [
                        Text(
                          'More than a job board.\nAn AI-powered recruitment workspace.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: wide ? 29 : 22,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Select the tier that aligns with your hiring velocity. Upgrade seamlessly as your team scales.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _BillingToggle(
                            isAnnual: view.isAnnual,
                            onChanged: (value) {
                              ref
                                  .read(paymentViewProvider.notifier)
                                  .setAnnual(value);
                            }),
                        if (subscription != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F8F4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Current plan: ${subscription.planName} · ${subscription.status}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary),
                                ),
                                TextButton(
                                  onPressed: _manageSubscription,
                                  child: const Text('Manage billing'),
                                ),
                                IconButton(
                                  tooltip: 'Refresh subscription status',
                                  onPressed: _refreshSubscription,
                                  icon: const Icon(Icons.refresh, size: 17),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                                'No plans are configured for this billing interval yet.'),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: wide ? 2 : 1,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: wide ? 500 : 440,
                            ),
                            itemCount: items.length,
                            itemBuilder: (_, index) {
                              final plan = items[index];
                              final isCurrent =
                                  plan.code == subscription?.planCode ||
                                      (subscription == null && plan.isFree);
                              return _PlanCard(
                                plan: plan,
                                annual: view.isAnnual,
                                selected: isCurrent,
                                hasActiveSubscription: subscription != null,
                                isLoading: _checkoutPlanId == plan.id,
                                onSelect: () => _confirmAndCheckout(plan),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BillingToggle extends StatelessWidget {
  const _BillingToggle({required this.isAnnual, required this.onChanged});
  final bool isAnnual;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Monthly',
            style: TextStyle(
                fontSize: 13,
                fontWeight: isAnnual ? FontWeight.w400 : FontWeight.w700,
                color: AppColors.textPrimary)),
        Switch(
            value: isAnnual,
            onChanged: onChanged,
            activeThumbColor: AppColors.orange,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        Text('Annually',
            style: TextStyle(
                fontSize: 13,
                fontWeight: isAnnual ? FontWeight.w700 : FontWeight.w400,
                color: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('−20%',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange)),
        ),
      ]);
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(
      {required this.plan,
      required this.annual,
      required this.selected,
      this.hasActiveSubscription = false,
      this.isLoading = false,
      required this.onSelect});
  final SubscriptionPlan plan;
  final bool annual;
  final bool selected;
  final bool hasActiveSubscription;
  final bool isLoading;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) {
    final total = plan.amountMinor / 100;
    final monthlyEquivalent = annual ? total / 12 : total;
    final price = NumberFormat.simpleCurrency(
      name: plan.currency,
      decimalDigits: plan.currency == 'NGN' ? 0 : 2,
    ).format(monthlyEquivalent);
    final includedFeatures = plan.features;
    final excludedFeatures = plan.excludedFeatures;
    return Container(
      decoration: BoxDecoration(
          color: plan.featured ? const Color(0xFFF3F4F7) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: plan.featured ? AppColors.orange : AppColors.divider,
              width: plan.featured ? 1.5 : 1),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D101828), blurRadius: 12, offset: Offset(0, 3))
          ]),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (plan.featured)
          Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              // Keep the badge aligned with the card's top edge without a
              // negative Container margin (Flutter requires nonnegative
              // margins).
              offset: const Offset(0, -24),
              child: Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('MOST POPULAR',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        Text(plan.name.toUpperCase(),
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(plan.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14, height: 1.4, color: AppColors.textSecondary)),
        const SizedBox(height: 18),
        Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(price,
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ),
              ),
              if (!plan.isFree) ...[
                const SizedBox(width: 8),
                const Text('/Job',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ],
            ]),
        const SizedBox(height: 6),
        Text(
          plan.isFree
              ? 'Forever free'
              : annual
                  ? 'BILLED ANNUALLY · ${NumberFormat.simpleCurrency(name: plan.currency, decimalDigits: plan.currency == 'NGN' ? 0 : 2).format(total)}'
                  : 'BILLED MONTHLY',
          style: const TextStyle(
              fontSize: 11, letterSpacing: 0.4, color: AppColors.textSecondary),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 18, bottom: 6),
          child: Divider(height: 1, color: AppColors.divider),
        ),
        Expanded(
            child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: includedFeatures.length + excludedFeatures.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final isIncluded = i < includedFeatures.length;
                  final label = isIncluded
                      ? includedFeatures[i]
                      : excludedFeatures[i - includedFeatures.length];
                  final featureColor = isIncluded
                      ? (plan.featured
                          ? const Color(0xFF290075)
                          : AppColors.navy)
                      : const Color(0xFFB7BBC5);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isIncluded ? Icons.check_circle : Icons.highlight_off,
                        color: featureColor,
                        size: 17,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            color: isIncluded
                                ? AppColors.textPrimary
                                : const Color(0xFFB7BBC5),
                          ),
                        ),
                      ),
                    ],
                  );
                })),
        SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
                onPressed: (selected ||
                        !plan.checkoutAvailable ||
                        plan.isFree ||
                        (hasActiveSubscription && !selected) ||
                        isLoading)
                    ? null
                    : onSelect,
                style: OutlinedButton.styleFrom(
                    backgroundColor:
                        plan.featured ? AppColors.orange : Colors.white,
                    foregroundColor: plan.featured || selected
                        ? Colors.white
                        : AppColors.textPrimary,
                    side: BorderSide(
                        color:
                            plan.featured ? AppColors.orange : AppColors.navy,
                        width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7))),
                child: Text(
                    isLoading
                        ? 'Opening secure checkout…'
                        : selected
                            ? 'Current plan'
                            : plan.isFree
                                ? 'Create Free Account'
                                : hasActiveSubscription
                                    ? 'Manage current plan first'
                                    : !plan.checkoutAvailable
                                        ? 'Payment setup pending'
                                        : plan.featured
                                            ? 'Subscribe ${plan.name}'
                                            : 'Choose ${plan.name}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)))),
      ]),
    );
  }
}
