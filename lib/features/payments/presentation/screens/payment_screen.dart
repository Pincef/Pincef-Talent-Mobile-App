import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/payment_provider.dart';
import '../../data/payment_repository.dart';

class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(subscriptionPlansProvider);
    final view = ref.watch(paymentViewProvider);
    return plans.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Unable to load plans: $error')),
      data: (items) => LayoutBuilder(
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
                    const Text('More than a job board.',
                        style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const Text('An AI-powered recruitment workspace.',
                        style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    const Text(
                        'Select the tier that aligns with your hiring velocity. Upgrade seamlessly as your',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const Text('team scales.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 18),
                    _BillingToggle(
                        isAnnual: view.isAnnual,
                        onChanged:
                            ref.read(paymentViewProvider.notifier).setAnnual),
                    const SizedBox(height: 24),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: wide ? 2 : 1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: wide ? 390 : 365,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, index) => _PlanCard(
                        plan: items[index],
                        annual: view.isAnnual,
                        selected: items[index].id == view.selectedPlan,
                        onSelect: () => ref
                            .read(paymentViewProvider.notifier)
                            .selectPlan(items[index].id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                fontSize: 10,
                fontWeight: isAnnual ? FontWeight.w400 : FontWeight.w700)),
        Switch(
            value: isAnnual,
            onChanged: onChanged,
            activeThumbColor: AppColors.orange,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        Text('Annually',
            style: TextStyle(
                fontSize: 10,
                fontWeight: isAnnual ? FontWeight.w700 : FontWeight.w400)),
        const SizedBox(width: 8),
        const Text('20%',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.orange)),
      ]);
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(
      {required this.plan,
      required this.annual,
      required this.selected,
      required this.onSelect});
  final SubscriptionPlan plan;
  final bool annual;
  final bool selected;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) {
    final amount =
        annual ? (plan.monthlyPrice * .8).round() : plan.monthlyPrice;
    final price = plan.monthlyPrice == 0
        ? '₦0'
        : NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0)
            .format(amount);
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: plan.featured ? AppColors.orange : AppColors.divider,
              width: plan.featured ? 1.5 : 1),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D101828), blurRadius: 12, offset: Offset(0, 3))
          ]),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (plan.featured)
          Transform.translate(
              offset: const Offset(0, -32),
              child: Align(
                  alignment: Alignment.center,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('MOST POPULAR',
                          style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.w800))))),
        Text(plan.name,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 7),
        SizedBox(
            height: 29,
            child: Text(plan.description,
                style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.35,
                    color: AppColors.textSecondary))),
        const SizedBox(height: 12),
        RichText(
            text: TextSpan(children: [
          TextSpan(
              text: price,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const TextSpan(
              text: ' /mo',
              style: TextStyle(fontSize: 9, color: AppColors.textSecondary))
        ])),
        const SizedBox(height: 3),
        Text(annual ? 'Billed annually' : 'Billed monthly',
            style:
                const TextStyle(fontSize: 8.5, color: AppColors.textSecondary)),
        const SizedBox(height: 15),
        Expanded(
            child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: plan.features.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.navy, size: 11),
                          const SizedBox(width: 7),
                          Expanded(
                              child: Text(plan.features[i],
                                  style: const TextStyle(
                                      fontSize: 9.5,
                                      color: AppColors.textPrimary)))
                        ]))),
        SizedBox(
            width: double.infinity,
            height: 32,
            child: OutlinedButton(
                onPressed: onSelect,
                style: OutlinedButton.styleFrom(
                    backgroundColor: selected ? AppColors.orange : Colors.white,
                    foregroundColor:
                        selected ? Colors.white : AppColors.textPrimary,
                    side: BorderSide(
                        color: selected ? AppColors.orange : AppColors.navy),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4))),
                child: Text(
                    selected
                        ? 'Selected'
                        : plan.monthlyPrice == 0
                            ? 'Create Free Account'
                            : 'Choose ${plan.name[0]}${plan.name.substring(1).toLowerCase()}',
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w600)))),
      ]),
    );
  }
}
