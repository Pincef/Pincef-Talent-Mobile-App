import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/recruiter_dashboard_repository.dart';
import '../data/model/recruiter_dashboard_models.dart';

final recruiterDashboardRepositoryProvider = Provider((ref) => RecruiterDashboardRepository());

class RecruiterDashboardState {
  final RecruiterDashboardSummary? summary;
  final bool isLoading;
  final String? error;

  const RecruiterDashboardState({this.summary, this.isLoading = false, this.error});

  RecruiterDashboardState copyWith({RecruiterDashboardSummary? summary, bool? isLoading, String? error}) {
    return RecruiterDashboardState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RecruiterDashboardNotifier extends StateNotifier<RecruiterDashboardState> {
  RecruiterDashboardNotifier(this._repository) : super(const RecruiterDashboardState(isLoading: true)) {
    load();
  }

  final RecruiterDashboardRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final summary = await _repository.loadDashboard();
      state = state.copyWith(summary: summary, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final recruiterDashboardProvider =
    StateNotifierProvider<RecruiterDashboardNotifier, RecruiterDashboardState>((ref) {
  return RecruiterDashboardNotifier(ref.watch(recruiterDashboardRepositoryProvider));
});