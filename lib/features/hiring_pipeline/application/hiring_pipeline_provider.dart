import 'package:flutter_riverpod/flutter_riverpod.dart';

// Adjust if dio_provider.dart lives elsewhere in your tree.
import '../../../core/network/dio_provider.dart';
import '../data/models/hiring_pipeline_model.dart';
import '../data/hiring_pipline_repository.dart';

final hiringPipelineRepositoryProvider =
    Provider<HiringPipelineRepository>((ref) {
  return HiringPipelineRepository(ref.watch(dioProvider));
});

/// What the company's plan allows (stage types, custom pipeline limits).
final pipelineCapabilitiesProvider =
    FutureProvider<PipelineCapabilities>((ref) {
  return ref.watch(hiringPipelineRepositoryProvider).capabilities();
});

final pipelinesProvider =
    AsyncNotifierProvider<PipelinesNotifier, List<HiringPipeline>>(
        PipelinesNotifier.new);

class PipelinesNotifier extends AsyncNotifier<List<HiringPipeline>> {
  HiringPipelineRepository get _repo =>
      ref.read(hiringPipelineRepositoryProvider);

  @override
  Future<List<HiringPipeline>> build() => _repo.list();

  /// Pull-to-refresh. Keeps the current list on screen if the refresh fails.
  Future<void> refresh() async {
    try {
      state = AsyncData(await _repo.list());
    } catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
    }
  }

  Future<HiringPipeline> create({
    required String name,
    required List<PipelineStage> stages,
    String? description,
    String? status,
  }) async {
    final created = await _repo.create(
      name: name,
      stages: stages,
      description: description,
      status: status,
    );
    state = AsyncData([...(state.value ?? const []), created]);
    return created;
  }

  Future<HiringPipeline> updatePipeline(
    String id, {
    String? name,
    List<PipelineStage>? stages,
    String? description,
    String? status,
  }) async {
    final updated = await _repo.update(
      id,
      name: name,
      stages: stages,
      description: description,
      status: status,
    );
    state = AsyncData([
      for (final p in state.value ?? const <HiringPipeline>[])
        p.id == id ? updated : p,
    ]);
    return updated;
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = AsyncData([
      for (final p in state.value ?? const <HiringPipeline>[])
        if (p.id != id) p,
    ]);
  }
}
