import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/auth_provider.dart';
import '../../application/payment_provider.dart';
import '../../data/payment_repository.dart';

String tierNameForCode(String code, String fallback) {
  final normalized = code.toLowerCase();
  if (normalized == 'free') return 'Free';
  if (normalized.contains('starter')) return 'Starter';
  if (normalized.contains('business') || normalized.contains('premium')) {
    return 'Business';
  }
  if (normalized.contains('pro') || normalized.contains('professional')) {
    return 'Pro';
  }
  return fallback;
}

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({
    super.key,
    this.checkoutResult,
    this.checkoutPlanId,
    this.checkoutReference,
  });

  final String? checkoutResult;
  final String? checkoutPlanId;
  final String? checkoutReference;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String? _checkoutPlanId;

  @override
  void initState() {
    super.initState();
    _handleCheckoutReturn(
      widget.checkoutResult,
      widget.checkoutPlanId,
      widget.checkoutReference,
    );
  }

  @override
  void didUpdateWidget(covariant PaymentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkoutResult != widget.checkoutResult ||
        oldWidget.checkoutPlanId != widget.checkoutPlanId ||
        oldWidget.checkoutReference != widget.checkoutReference) {
      _handleCheckoutReturn(
        widget.checkoutResult,
        widget.checkoutPlanId,
        widget.checkoutReference,
      );
    }
  }

  void _handleCheckoutReturn(
    String? result,
    String? expectedPlanId,
    String? reference,
  ) {
    if (result == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_resolveCheckoutReturn(result, expectedPlanId, reference));
    });
  }

  Future<void> _resolveCheckoutReturn(
    String result,
    String? expectedPlanId,
    String? reference,
  ) async {
    if (result == 'cancelled') {
      ref.invalidate(currentSubscriptionProvider);
      try {
        await ref.read(authProvider.notifier).refreshSession();
      } catch (_) {
        // Keep the current screen usable if a session refresh is temporarily
        // unavailable; the subscription summary can still be refreshed.
      }
      if (!mounted) return;
      ref.invalidate(currentSubscriptionProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Checkout was cancelled. Your current plan is unchanged.'),
          ),
        );
      }
      return;
    }
    if (result != 'complete') return;

    // Verify Paystack's reference on the server, then wait for its webhook to
    // persist the matching subscription before updating the signed-in user.
    try {
      var confirmedPlanId = expectedPlanId;
      var paymentStatus = 'pending';
      for (var attempt = 0; attempt < 15; attempt++) {
        if (reference != null && reference.isNotEmpty) {
          final verification = await ref
              .read(paymentRepositoryProvider)
              .verifyCheckout(reference);
          if (!mounted) return;
          paymentStatus = verification.status.toLowerCase();
          if (paymentStatus == 'failed') {
            ref.invalidate(currentSubscriptionProvider);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Paystack could not complete the payment. No new plan was activated.'),
              duration: Duration(seconds: 7),
            ));
            return;
          }
          if (paymentStatus == 'success') {
            if (confirmedPlanId != null &&
                confirmedPlanId.isNotEmpty &&
                verification.planId != confirmedPlanId) {
              throw const FormatException(
                  'The payment reference does not match the selected plan.');
            }
            confirmedPlanId = verification.planId;
          }
        }

        ref.invalidate(currentSubscriptionProvider);
        final subscription =
            await ref.read(currentSubscriptionProvider.future);
        if (!mounted) return;
        final planMatches = confirmedPlanId == null ||
            confirmedPlanId.isEmpty ||
            subscription?.planId == confirmedPlanId;
        final periodIsCurrent = subscription?.currentPeriodEnd
                ?.isAfter(DateTime.now()) ==
            true;
        if (subscription?.status.toLowerCase() == 'active' &&
            planMatches &&
            periodIsCurrent) {
          await ref.read(authProvider.notifier).refreshSession();
          if (!mounted) return;
          ref.invalidate(currentSubscriptionProvider);
          ref.invalidate(subscriptionPlansProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Payment confirmed. ${subscription!.planName} is active.'),
            ));
          }
          return;
        }
        if (attempt < 14) {
          await Future<void>.delayed(const Duration(seconds: 2));
          if (!mounted) return;
        }
      }
      if (mounted && paymentStatus == 'success') {
        ref.invalidate(currentSubscriptionProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Payment succeeded, but plan activation is still pending. Refresh billing shortly; don’t pay again.',
          ),
          duration: Duration(seconds: 8),
        ));
      } else if (mounted) {
        ref.invalidate(currentSubscriptionProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Payment is still awaiting confirmation. Refresh billing shortly; don’t submit another payment yet.',
          ),
          duration: Duration(seconds: 7),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Could not confirm the payment status yet. Refresh billing shortly before trying again.',
          ),
          duration: Duration(seconds: 7),
        ));
      }
    }
  }

  String _tierName(SubscriptionPlan plan) => tierNameForCode(plan.code, plan.name);

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
        title: Text('Choose ${_tierName(plan)}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${NumberFormat.simpleCurrency(
                name: plan.currency,
                decimalDigits: plan.currency == 'NGN' ? 0 : 2,
              ).format(plan.amountMinor / 100)} · billed ${plan.interval == 'yearly' ? 'annually' : 'monthly'}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You’ll continue to Paystack’s secure checkout. Your company plan changes after Paystack confirms payment, then you’ll return to TalentBridge.',
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
      // Use the current browser tab on web so the provider callback returns
      // to this app without leaving a duplicate TalentBridge tab open.
      // Native platforms ignore webOnlyWindowName and use their normal flow.
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      );
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
                          'More than a job board.\nAn automated recruitment workspace.',
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
                          'Choose a plan based on the hiring tools your company needs. Every plan includes job posting and basic applicant management.',
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
                                Flexible(
                                  child: Text(
                                    subscription.isTrial &&
                                            subscription.trialEndsAt != null
                                        ? 'Starter trial · ends ${DateFormat.yMMMd().format(subscription.trialEndsAt!.toLocal())}'
                                        : 'Current plan: ${subscription.planName} · ${subscription.status}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textPrimary),
                                  ),
                                ),
                                if (!subscription.isTrial &&
                                    !subscription.planCode
                                        .toLowerCase()
                                        .startsWith('dev_'))
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
                        if (subscription == null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF6F0),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.orange),
                            ),
                            child: const Text(
                              'Eligible new companies receive a 14-day Starter trial without payment details. After the trial, the account moves to Free unless a paid plan is selected.',
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: AppColors.textPrimary),
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
                              mainAxisExtent: 540,
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
                                hasActiveSubscription: subscription != null &&
                                    !subscription.isTrial,
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

  String get _tierLabel => tierNameForCode(plan.code, plan.name);

  String get _tierDescription {
    final code = plan.code.toLowerCase();
    if (plan.isFree) {
      return 'For recruiters who need the essentials for managing applicants.';
    }
    if (code.contains('starter')) {
      return 'Add the Standard hiring pipeline and candidate processing.';
    }
    if (code.contains('business') || code.contains('premium')) {
      return 'For companies that need full workflow and interview automation.';
    }
    if (code.contains('pro') || code.contains('professional')) {
      return 'Add assessments, comparison, messaging, and reporting.';
    }
    return plan.description;
  }

  List<String> _keyFeatures() {
    final code = plan.code.toLowerCase();
    if (plan.isFree) {
      return const [
        'Unlimited job posts',
        'View candidates and candidate details',
        'Manually shortlist candidates',
        'Download CVs',
        'Send offer and rejection emails',
      ];
    }
    if (code.contains('starter')) {
      return const [
        'Everything in Free',
        'Standard hiring pipeline',
        'Process up to 500 applicant CVs per job',
        'Match and rank up to 10 candidates per job',
        'Candidate summaries and automatic pipeline steps',
      ];
    }
    if (code.contains('business') || code.contains('premium')) {
      return const [
        'Everything in Pro',
        'Process up to 1,500 applicant CVs per job; rank up to 30',
        'Custom pipelines: up to 10',
        'Automated assessment generation and grading',
        'Interview tools: 5 invitations per job; Google Calendar',
        '30 assessment invitations per job; 5 team seats',
        'Job description generation; 3 assessment stages per custom pipeline',
      ];
    }
    if (code.contains('pro') || code.contains('professional')) {
      return const [
        'Everything in Starter',
        'Process up to 1,000 applicant CVs; rank up to 20 per job',
        'Premium pipeline and manual assessments',
        'Compare up to 20 candidates',
        'Messaging, reports, and auto-invite shortlisted candidates',
        '20 assessment invitations per job',
      ];
    }
    return plan.features;
  }

  @override
  Widget build(BuildContext context) {
    final total = plan.amountMinor / 100;
    final monthlyEquivalent = annual ? total / 12 : total;
    final price = NumberFormat.simpleCurrency(
      name: plan.currency,
      decimalDigits: plan.currency == 'NGN' ? 0 : 2,
    ).format(monthlyEquivalent);
    final includedFeatures = _keyFeatures();
    final excludedFeatures = const <String>[];
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
        Text(_tierLabel.toUpperCase(),
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(_tierDescription,
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
                Text(annual ? '/month, billed yearly' : '/month',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ]),
        const SizedBox(height: 6),
        Text(
          plan.isFree
              ? 'Free forever · no automation or advanced features'
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
                                : !plan.checkoutAvailable
                                    ? 'Payment setup pending'
                                    : hasActiveSubscription
                                        ? 'Switch to $_tierLabel'
                                        : 'Choose $_tierLabel',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)))),
      ]),
    );
  }
}
