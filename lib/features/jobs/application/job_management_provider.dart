import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../data/jobs_management_repository.dart';
import '../data/models/job_management_model.dart';

final jobManagementRepositoryProvider =
    Provider((ref) => JobManagementRepository(ref.watch(dioProvider)));

// ============================================================
// Shared: Job Detail (both recruiter and candidate views)
// ============================================================

/// Fetches a single job for job_detail_screen.dart. Both the recruiter and
/// candidate views watch this same provider/endpoint (GET /jobs/:jobId is
/// public) and layer role-specific actions on top in the screen itself.
final jobDetailProvider =
    FutureProvider.autoDispose.family<JobDetail, String>((ref, jobId) {
  return ref.watch(jobManagementRepositoryProvider).getJobDetail(jobId);
});

class JobManagementState {
  const JobManagementState({this.summary, this.isLoading = false, this.error});

  final JobManagementSummary? summary;
  final bool isLoading;
  final String? error;

  JobManagementState copyWith(
      {JobManagementSummary? summary, bool? isLoading, String? error}) {
    return JobManagementState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class JobManagementNotifier extends StateNotifier<JobManagementState> {
  JobManagementNotifier(this._repository)
      : super(const JobManagementState(isLoading: true)) {
    load();
  }

  final JobManagementRepository _repository;

  /// Which tab's postings are currently shown — kept here (not in the
  /// screen's local state) so a pull-to-refresh or retry reloads the same
  /// tab instead of silently resetting to Active.
  JobPipelineStatus _tab = JobPipelineStatus.active;

  /// Pass [tab] on tab change to refetch with that filter; omit it (e.g.
  /// on retry/pull-to-refresh) to reload whatever tab was last shown.
  Future<void> load({JobPipelineStatus? tab}) async {
    if (tab != null) _tab = tab;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final summary = await _repository.loadJobManagement(tab: _tab);
      state = state.copyWith(summary: summary, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final jobManagementProvider = StateNotifierProvider.autoDispose<
    JobManagementNotifier, JobManagementState>((ref) {
  return JobManagementNotifier(ref.watch(jobManagementRepositoryProvider));
});

// ============================================================
// Post-job form state
// ============================================================

/// [draft] holds the current state of the single-screen post-job form.
/// `draft.id` is null until the job is first saved; every later save must
/// carry it so updates target the same job instead of creating duplicates.
class PostJobState {
  const PostJobState({
    this.draft = const JobDraft(),
    this.isSaving = false,
    this.error,
  });

  final JobDraft draft;
  final bool isSaving;
  final String? error;

  bool get hasBeenCreated => draft.id != null;

  PostJobState copyWith(
          {JobDraft? draft,
          bool? isSaving,
          String? error,
          bool clearError = false}) =>
      PostJobState(
        draft: draft ?? this.draft,
        isSaving: isSaving ?? this.isSaving,
        error: clearError ? null : (error ?? this.error),
      );
}

class PostJobNotifier extends StateNotifier<PostJobState> {
  PostJobNotifier(this._repository) : super(const PostJobState());

  final JobManagementRepository _repository;

  /// Persists the whole form in a single call. Now that "Post New Job" is
  /// one screen instead of a multi-step wizard, there's no reason to stage
  /// the save across several round-trips — [formValues] should already be
  /// the complete current state of the form. Preserves the existing draft
  /// id (if any) so this targets the same job on repeat saves instead of
  /// creating duplicates.
  Future<bool> saveJob(JobDraft formValues) =>
      _saveStep(formValues.copyWith(id: state.draft.id));

  /// "Save as Draft" button — persists whatever's currently accumulated in
  /// [PostJobState.draft] without changing status.
  Future<bool> saveDraft() => _saveStep(state.draft);

  /// "Continue to Publish". The backend re-validates required fields even
  /// if [JobDraft.isReadyToPublish] already passed client-side — this call
  /// can still fail, and the returned error message should be shown as-is
  /// since it names exactly which fields are missing.
  Future<bool> publish() async {
    final jobId = state.draft.id;
    if (jobId == null) {
      state = state.copyWith(error: 'Save the job before publishing.');
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repository.publishJob(jobId);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _saveStep(JobDraft updated) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      if (updated.id == null) {
        final id = await _repository.createJobDraft(updated);
        state =
            state.copyWith(draft: updated.copyWith(id: id), isSaving: false);
      } else {
        await _repository.updateJobDraft(updated.id!, updated);
        state = state.copyWith(draft: updated, isSaving: false);
      }
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  /// Call when leaving the form (e.g. on successful publish, or if the
  /// user navigates away) so a stale draft/id doesn't leak into the next
  /// "Post New Job" session.
  void reset() => state = const PostJobState();
}

final postJobProvider =
    StateNotifierProvider.autoDispose<PostJobNotifier, PostJobState>((ref) {
  return PostJobNotifier(ref.watch(jobManagementRepositoryProvider));
});

// ============================================================
// Candidate-facing: Browse Jobs
// ============================================================

class BrowseJobsState {
  const BrowseJobsState({
    this.jobs = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
    this.filters = const JobBrowseFilters(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<JobListing> jobs;
  final int total;
  final int page;
  final int totalPages;
  final JobBrowseFilters filters;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  bool get hasMore => page < totalPages;

  BrowseJobsState copyWith({
    List<JobListing>? jobs,
    int? total,
    int? page,
    int? totalPages,
    JobBrowseFilters? filters,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) =>
      BrowseJobsState(
        jobs: jobs ?? this.jobs,
        total: total ?? this.total,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        filters: filters ?? this.filters,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class BrowseJobsNotifier extends StateNotifier<BrowseJobsState> {
  BrowseJobsNotifier(this._repository) : super(const BrowseJobsState()) {
    _fetch(page: 1);
  }

  final JobManagementRepository _repository;

  /// Replaces the current filters and reloads from page 1. Used by the
  /// filter chips — pass `state.filters.copyWith(...)`.
  Future<void> applyFilters(JobBrowseFilters filters) =>
      _fetch(page: 1, filters: filters);

  /// Wired to the shared top-bar search box (see app_shell_route.dart) —
  /// clears the search filter entirely on an empty query rather than
  /// sending `search=''` to the backend.
  Future<void> setSearchText(String query) {
    final trimmed = query.trim();
    return applyFilters(state.filters.copyWith(
      search: trimmed.isEmpty ? null : trimmed,
      clearSearch: trimmed.isEmpty,
    ));
  }

  Future<void> refresh() => _fetch(page: 1, filters: state.filters);

  /// "Load more opportunities" — appends the next page instead of
  /// replacing the list, so scroll position and already-loaded cards stay
  /// put.
  Future<void> loadMore() {
    if (state.isLoadingMore || !state.hasMore) return Future.value();
    return _fetch(page: state.page + 1, filters: state.filters, append: true);
  }

  /// Client-only toggle — see JobListing.isSaved for why this doesn't
  /// persist yet (no saved-jobs endpoint exists).
  void toggleSaved(String jobId) {
    state = state.copyWith(
      jobs: [
        for (final job in state.jobs)
          if (job.id == jobId) job.copyWith(isSaved: !job.isSaved) else job,
      ],
    );
  }

  Future<void> _fetch({
    required int page,
    JobBrowseFilters? filters,
    bool append = false,
  }) async {
    final effectiveFilters = filters ?? state.filters;
    state = state.copyWith(
      isLoading: !append,
      isLoadingMore: append,
      filters: effectiveFilters,
      clearError: true,
    );
    try {
      final result =
          await _repository.browseJobs(filters: effectiveFilters, page: page);
      state = state.copyWith(
        jobs: append ? [...state.jobs, ...result.jobs] : result.jobs,
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

final browseJobsProvider =
    StateNotifierProvider.autoDispose<BrowseJobsNotifier, BrowseJobsState>(
        (ref) {
  return BrowseJobsNotifier(ref.watch(jobManagementRepositoryProvider));
});
