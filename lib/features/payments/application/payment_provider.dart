import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../data/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(ref.watch(dioProvider)),
);
final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>(
  (ref) => ref.watch(paymentRepositoryProvider).getPlans(),
);
final currentSubscriptionProvider = FutureProvider<CurrentSubscription?>(
  (ref) async {
    // A subscription-summary failure should not hide the plan catalog. The
    // billing screen can still show prices and checkout options; refresh or
    // manage billing will surface their own errors when the user uses them.
    try {
      return await ref.watch(paymentRepositoryProvider).getCurrentSubscription();
    } catch (_) {
      return null;
    }
  },
);

class PaymentViewState {
  const PaymentViewState({this.isAnnual = false, this.selectedPlan = 'free'});
  final bool isAnnual;
  final String selectedPlan;

  PaymentViewState copyWith({bool? isAnnual, String? selectedPlan}) =>
      PaymentViewState(
        isAnnual: isAnnual ?? this.isAnnual,
        selectedPlan: selectedPlan ?? this.selectedPlan,
      );
}

class PaymentViewNotifier extends StateNotifier<PaymentViewState> {
  PaymentViewNotifier() : super(const PaymentViewState());
  void setAnnual(bool value) => state = state.copyWith(isAnnual: value);
  void selectPlan(String id) => state = state.copyWith(selectedPlan: id);
}

final paymentViewProvider =
    StateNotifierProvider<PaymentViewNotifier, PaymentViewState>(
  (ref) => PaymentViewNotifier(),
);
