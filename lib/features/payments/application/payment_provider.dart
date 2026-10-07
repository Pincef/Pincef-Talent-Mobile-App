import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) => PaymentRepository());
final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>(
  (ref) => ref.watch(paymentRepositoryProvider).getPlans(),
);

class PaymentViewState {
  const PaymentViewState({this.isAnnual = false, this.selectedPlan = 'free'});
  final bool isAnnual;
  final String selectedPlan;

  PaymentViewState copyWith({bool? isAnnual, String? selectedPlan}) => PaymentViewState(
        isAnnual: isAnnual ?? this.isAnnual,
        selectedPlan: selectedPlan ?? this.selectedPlan,
      );
}

class PaymentViewNotifier extends StateNotifier<PaymentViewState> {
  PaymentViewNotifier() : super(const PaymentViewState());
  void setAnnual(bool value) => state = state.copyWith(isAnnual: value);
  void selectPlan(String id) => state = state.copyWith(selectedPlan: id);
}

final paymentViewProvider = StateNotifierProvider<PaymentViewNotifier, PaymentViewState>(
  (ref) => PaymentViewNotifier(),
);
