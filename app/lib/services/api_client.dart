import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiBaseUrlProvider = Provider<String>((ref) {
  const fromEnv = String.fromEnvironment('SLEEP_HABITS_API_BASE');
  if (fromEnv.isNotEmpty) {
    return fromEnv;
  }
  return 'http://localhost:8000';
});

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final options = BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 60),
  );
  return Dio(options);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});

class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? token,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: _options(token),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
    String? token,
  }) {
    return _dio.post<T>(
      path,
      queryParameters: queryParameters,
      data: data,
      options: _options(token),
    );
  }

  Future<Response<T>> postMultipart<T>(
    String path, {
    required FormData formData,
    String? token,
  }) {
    return _dio.post<T>(
      path,
      data: formData,
      options: _options(token),
    );
  }

  Options _options(String? token) {
    final headers = <String, dynamic>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return Options(headers: headers);
  }
}
