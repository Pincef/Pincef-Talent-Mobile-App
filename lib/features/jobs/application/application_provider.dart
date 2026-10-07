import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../data/application_repository.dart';
import '../data/models/application_model.dart';

final applicationsRepositoryProvider =
    Provider((ref) => ApplicationsRepository(ref.watch(dioProvider)));

/// The candidate's own applications — used on the Job Detail screen to
/// check "have I already applied to this job". autoDispose since it's
/// only needed while viewing job-related screens.
final myApplicationsProvider =
    FutureProvider.autoDispose<List<ApplicationSummary>>((ref) {
  return ref.watch(applicationsRepositoryProvider).getMyApplications();
});

class MyApplicationsState {
  const MyApplicationsState({
    this.applications = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<ApplicationSummary> applications;
  final int total;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  bool get hasMore => page < totalPages;

  MyApplicationsState copyWith({
    List<ApplicationSummary>? applications,
    int? total,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) =>
      MyApplicationsState(
        applications: applications ?? this.applications,
        total: total ?? this.total,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class MyApplicationsNotifier extends StateNotifier<MyApplicationsState> {
  MyApplicationsNotifier(this._repository)
      : super(const MyApplicationsState(isLoading: true)) {
    _fetch(page: 1);
  }

  final ApplicationsRepository _repository;

  Future<void> refresh() => _fetch(page: 1);

  Future<void> loadMore() {
    if (state.isLoadingMore || !state.hasMore) return Future.value();
    return _fetch(page: state.page + 1, append: true);
  }

  Future<void> _fetch({required int page, bool append = false}) async {
    state = state.copyWith(
      isLoading: !append,
      isLoadingMore: append,
      clearError: true,
    );
    try {
      final result = await _repository.getMyApplicationsPage(page: page);
      state = state.copyWith(
        applications: append
            ? [...state.applications, ...result.applications]
            : result.applications,
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
        isLoading: false,
        isLoadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: error.toString(),
      );
    }
  }
}

final myApplicationsListProvider = StateNotifierProvider.autoDispose<
    MyApplicationsNotifier, MyApplicationsState>((ref) {
  return MyApplicationsNotifier(ref.watch(applicationsRepositoryProvider));
});

/// The candidate's CV files, for the "which CV should we use?" picker.
/// Fetched lazily (only when Apply is actually pressed) since most
/// applicants have exactly one CV and never need this.
final myCvFilesProvider = FutureProvider.autoDispose<List<CvFileOption>>((ref) {
  return ref.watch(applicationsRepositoryProvider).getMyCvFiles();
});

class ApplyState {
  const ApplyState({this.isSubmitting = false, this.error, this.result});

  final bool isSubmitting;
  final String? error;
  final ApplicationSummary? result;

  ApplyState copyWith({
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    ApplicationSummary? result,
  }) =>
      ApplyState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: clearError ? null : (error ?? this.error),
        result: result ?? this.result,
      );
}

/// Drives the "Apply Now" button on job_detail_screen.dart. Separate from
/// myApplicationsProvider (that's a list; this is a single in-flight
/// submission) so a failed/retried apply doesn't touch the list state
/// until it actually succeeds.
class ApplyNotifier extends StateNotifier<ApplyState> {
  ApplyNotifier(this._repository) : super(const ApplyState());

  final ApplicationsRepository _repository;

  /// Returns true on success. Doesn't know about CV-picker UI — the screen
  /// is expected to resolve [cvPublicId] (via myCvFilesProvider) before
  /// calling this, since the backend only needs it when there's more than
  /// one CV to choose from.
  Future<bool> submit(String jobId, {String? cvPublicId}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await _repository.apply(jobId, cvPublicId: cvPublicId);
      state = state.copyWith(isSubmitting: false, result: result);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  void reset() => state = const ApplyState();
}

final applyProvider =
    StateNotifierProvider.autoDispose<ApplyNotifier, ApplyState>((ref) {
  return ApplyNotifier(ref.watch(applicationsRepositoryProvider));
});

// ============================================================
// Recruiter-facing: applicants for one job (job_candidates_screen.dart)
// ============================================================

class JobApplicantsState {
  const JobApplicantsState({
    this.applications = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<JobApplicantSummary> applications;
  final int total;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  bool get hasMore => page < totalPages;

  JobApplicantsState copyWith({
    List<JobApplicantSummary>? applications,
    int? total,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) =>
      JobApplicantsState(
        applications: applications ?? this.applications,
        total: total ?? this.total,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Same load-more-appends-instead-of-replaces shape as BrowseJobsNotifier
/// in job_management_provider.dart, family'd by jobId since each job's
/// candidates list is independently paginated. autoDispose so leaving the
/// candidates screen drops the cached page rather than holding it forever.
class JobApplicantsNotifier extends StateNotifier<JobApplicantsState> {
  JobApplicantsNotifier(this._repository, this._jobId)
      : super(const JobApplicantsState(isLoading: true)) {
    _fetch(page: 1);
  }

  final ApplicationsRepository _repository;
  final String _jobId;

  Future<void> refresh() => _fetch(page: 1);

  /// "Load more" at the bottom of the grid — appends the next page rather
  /// than replacing the list, same reasoning as BrowseJobsNotifier.loadMore.
  Future<void> loadMore() {
    if (state.isLoadingMore || !state.hasMore) return Future.value();
    return _fetch(page: state.page + 1, append: true);
  }

  Future<void> _fetch({required int page, bool append = false}) async {
    state = state.copyWith(
      isLoading: !append,
      isLoadingMore: append,
      clearError: true,
    );
    try {
      final result = await _repository.getJobApplications(_jobId, page: page);
      state = state.copyWith(
        applications: append
            ? [...state.applications, ...result.applications]
            : result.applications,
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
        isLoading: false,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false, isLoadingMore: false, error: e.toString());
    }
  }
}

final jobApplicantsProvider = StateNotifierProvider.autoDispose
    .family<JobApplicantsNotifier, JobApplicantsState, String>((ref, jobId) {
  return JobApplicantsNotifier(
      ref.watch(applicationsRepositoryProvider), jobId);
});
