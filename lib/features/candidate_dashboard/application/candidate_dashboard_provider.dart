import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart' show dioProvider;
import '../data/candidate_dashboard_repository.dart';
import '../data/model/dashboard_models.dart';

final dashboardRepositoryProvider = Provider(
  (ref) => CandidateDashboardRepository(ref.watch(dioProvider)),
);

class CandidateDashboardState {
  final DashboardSummary? summary;
  final bool isLoading;
  final bool isUploading;
  final String? error;

  const CandidateDashboardState(
      {this.summary,
      this.isLoading = false,
      this.isUploading = false,
      this.error});

  CandidateDashboardState copyWith(
          {DashboardSummary? summary,
          bool? isLoading,
          bool? isUploading,
          String? error}) =>
      CandidateDashboardState(
        summary: summary ?? this.summary,
        isLoading: isLoading ?? this.isLoading,
        isUploading: isUploading ?? this.isUploading,
        error: error,
      );
}

class CandidateDashboardNotifier
    extends StateNotifier<CandidateDashboardState> {
  CandidateDashboardNotifier(this._repository)
      : super(const CandidateDashboardState(isLoading: true)) {
    load();
  }

  final CandidateDashboardRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final summary = await _repository.loadDashboard();
      state = state.copyWith(summary: summary, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> uploadCv(PlatformFile file) async {
    state = state.copyWith(isUploading: true);
    try {
      await _repository.uploadCv(file);
      state = state.copyWith(isUploading: false);
      await load();
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      rethrow;
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<CandidateDashboardNotifier, CandidateDashboardState>(
        (ref) =>
            CandidateDashboardNotifier(ref.watch(dashboardRepositoryProvider)));
