import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counts in-flight requests. >0 means "show the loading UI".
final apiLoadingCountProvider = StateProvider<int>((ref) => 0);

final isApiLoadingProvider = Provider<bool>((ref) {
  return ref.watch(apiLoadingCountProvider) > 0;
});