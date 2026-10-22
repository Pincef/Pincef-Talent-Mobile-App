import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../data/recruiter_dashboard_repository.dart';
import '../data/model/recruiter_dashboard_models.dart';

final recruiterDashboardRepositoryProvider =
    Provider((ref) => RecruiterDashboardRepository(ref.watch(dioProvider)));

class RecruiterDashboardState {
  final RecruiterDashboardSummary? summary;
  final bool isLoading;
  final String? error;
  final DateTime? from;
  final DateTime? to;

  RecruiterDashboardState(
      {this.summary, this.isLoading = false, this.error, this.from, this.to});

  RecruiterDashboardState copyWith(
      {RecruiterDashboardSummary? summary,
      bool? isLoading,
      String? error,
      DateTime? from,
      DateTime? to}) {
    return RecruiterDashboardState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      from: from ?? this.from,
      to: to ?? this.to,
    );
  }
}

class RecruiterDashboardNotifier
    extends StateNotifier<RecruiterDashboardState> {
  RecruiterDashboardNotifier(this._repository)
      : super(RecruiterDashboardState(isLoading: true)) {
    load();
  }

  final RecruiterDashboardRepository _repository;

  Future<void> load({DateTime? from, DateTime? to}) async {
    final start = from ?? state.from;
    final end = to ?? state.to;
    state = state.copyWith(isLoading: true, error: null, from: start, to: end);
    try {
      final summary = await _repository.loadDashboard(from: start, to: end);
      state = state.copyWith(summary: summary, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final recruiterDashboardProvider =
    StateNotifierProvider<RecruiterDashboardNotifier, RecruiterDashboardState>(
        (ref) {
  return RecruiterDashboardNotifier(
      ref.watch(recruiterDashboardRepositoryProvider));
});
