import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_loading_provider.dart';

class LoadingInterceptor extends Interceptor {
  LoadingInterceptor(this._ref);
  final Ref _ref;

  void _increment() => _ref.read(apiLoadingCountProvider.notifier).state++;

  void _decrement() {
    final current = _ref.read(apiLoadingCountProvider.notifier).state;
    if (current > 0) _ref.read(apiLoadingCountProvider.notifier).state = current - 1;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['skipLoading'] != true) _increment();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.extra['skipLoading'] != true) _decrement();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.extra['skipLoading'] != true) _decrement();
    handler.next(err);
  }
}