import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../storage/secure_storage_service.dart';
import 'dio_client.dart';

/// Single shared instance — SecureStorageService wraps Keychain/Keystore
/// and DioClient's auth interceptor needs to read/write the same tokens
/// everywhere, so this must not be recreated per-widget.
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// DioClient depends on SecureStorageService for the auth interceptor
/// (attaching the access token, refreshing on 401).
final dioClientProvider = Provider<DioClient>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return DioClient(storage);
});

/// Most call sites just want the configured Dio instance, not the
/// wrapper class itself.
final dioProvider = Provider<Dio>((ref) {
  return ref.watch(dioClientProvider).dio;
});
