/// lib/features/profile/application/profile_provider.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import '../data/models/activity_item.dart';
import '../data/models/recruiter_performance.dart';
import '../data/profile_repository.dart';
import '../data/models/candidate_profile_model.dart';

final candidateProfileRepositoryProvider =
    Provider<CandidateProfileRepository>((ref) {
  return CandidateProfileRepository(ref.watch(dioProvider));
});

class CandidateProfileNotifier
    extends StateNotifier<AsyncValue<CandidateProfile>> {
  CandidateProfileNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    _load();
  }

  final CandidateProfileRepository _repository;

  Future<void> _load() async {
    try {
      final profile = await _repository.getMyProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  Future<void> addExperience(ExperienceEntry entry) async {
    final current = state.valueOrNull;
    if (current == null) return;
    // New entries lead the list — matches the mockup showing the most
    // recent role first.
    final updated = [entry, ...current.experience];
    final profile = await _repository.updateProfile(experience: updated);
    state = AsyncValue.data(profile);
  }

  Future<void> updateExperienceAt(int index, ExperienceEntry entry) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = List<ExperienceEntry>.of(current.experience);
    updated[index] = entry;
    final profile = await _repository.updateProfile(experience: updated);
    state = AsyncValue.data(profile);
  }

  Future<void> removeExperienceAt(int index) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = List<ExperienceEntry>.of(current.experience)
      ..removeAt(index);
    final profile = await _repository.updateProfile(experience: updated);
    state = AsyncValue.data(profile);
  }

  Future<void> addEducation(EducationEntry entry) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = [entry, ...current.education];
    final profile = await _repository.updateProfile(education: updated);
    state = AsyncValue.data(profile);
  }

  Future<void> updateEducationAt(int index, EducationEntry entry) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = List<EducationEntry>.of(current.education);
    updated[index] = entry;
    final profile = await _repository.updateProfile(education: updated);
    state = AsyncValue.data(profile);
  }

  Future<void> removeEducationAt(int index) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = List<EducationEntry>.of(current.education)..removeAt(index);
    final profile = await _repository.updateProfile(education: updated);
    state = AsyncValue.data(profile);
  }
}

final candidateProfileProvider = StateNotifierProvider.autoDispose<
    CandidateProfileNotifier, AsyncValue<CandidateProfile>>((ref) {
  return CandidateProfileNotifier(
      ref.watch(candidateProfileRepositoryProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioProvider));
});

final recruiterPerformanceProvider =
    FutureProvider.autoDispose<RecruiterPerformance>((ref) {
  return ref.watch(profileRepositoryProvider).getMyPerformance();
});

/// First page of activity plus "load more" state, so the profile screen's
/// "View All History" can append pages in place instead of navigating away.
class ActivityState {
  final List<ActivityItem> items;
  final String? nextCursor;
  final bool isLoadingMore;

  const ActivityState({
    this.items = const [],
    this.nextCursor,
    this.isLoadingMore = false,
  });

  ActivityState copyWith({
    List<ActivityItem>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoadingMore,
  }) {
    return ActivityState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class ActivityNotifier extends StateNotifier<AsyncValue<ActivityState>> {
  ActivityNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadFirstPage();
  }

  final ProfileRepository _repository;

  Future<void> _loadFirstPage() async {
    try {
      final page = await _repository.getMyActivity();
      state = AsyncValue.data(
          ActivityState(items: page.items, nextCursor: page.nextCursor));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.nextCursor == null ||
        current.isLoadingMore) {
      return;
    }

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.getMyActivity(cursor: current.nextCursor);
      state = AsyncValue.data(current.copyWith(
        items: [...current.items, ...page.items],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      ));
    } catch (_) {
      // Leave existing items in place — just stop showing the loading
      // state so "View All History" is tappable again.
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final recruiterActivityProvider = StateNotifierProvider.autoDispose<
    ActivityNotifier, AsyncValue<ActivityState>>((ref) {
  return ActivityNotifier(ref.watch(profileRepositoryProvider));
});
