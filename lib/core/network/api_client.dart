import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors/app_exception.dart';
import '../storage/local_storage_service.dart';
import '../storage/storage_keys.dart';
import 'api_config.dart';

class ApiClient {
  final http.Client _httpClient;
  final ApiConfig _config;
  final LocalStorageService _storage;

  ApiClient({
    required ApiConfig config,
    required LocalStorageService storage,
    http.Client? httpClient,
  }) : _config = config,
       _storage = storage,
       _httpClient = httpClient ?? http.Client();

  String get _apiRootUrl {
    if (_config.baseUrl.endsWith('/api/v1')) {
      return _config.baseUrl.substring(0, _config.baseUrl.length - 7);
    }
    return _config.baseUrl;
  }

  Uri _buildUri(
    String endpoint, [
    Map<String, String>? queryParams,
    bool useApiRoot = false,
  ]) {
    var cleanEndpoint = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;
    final baseUrl = useApiRoot ? _apiRootUrl : _config.baseUrl;
    if (baseUrl.endsWith('/api/v1') && cleanEndpoint.startsWith('api/v1/')) {
      cleanEndpoint = cleanEndpoint.substring(7);
    }
    final urlStr = '$baseUrl/$cleanEndpoint';
    final uri = Uri.parse(urlStr);
    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: {...uri.queryParameters, ...queryParams},
    );
  }

  Map<String, String> _buildHeaders(Map<String, String>? extraHeaders) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = _storage.getString(StorageKeys.authToken);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    bool useApiRoot = false,
  }) async {
    final uri = _buildUri(endpoint, queryParams, useApiRoot);
    try {
      final response = await _httpClient
          .get(uri, headers: _buildHeaders(headers))
          .timeout(_config.timeout);
      final resolvedResponse = await _refreshAndRetryIfNeeded(
        endpoint: endpoint,
        response: response,
        retry: () => _httpClient
            .get(uri, headers: _buildHeaders(headers))
            .timeout(_config.timeout),
      );
      return _handleResponse(resolvedResponse);
    } on SocketException catch (e) {
      throw NetworkException(
        'Unable to reach backend server at ${uri.host}:${uri.port}: ${e.message}',
      );
    } on TimeoutException {
      throw const NetworkException(
        'Request timed out. Please check your backend connection.',
      );
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
    bool useApiRoot = false,
  }) async {
    final uri = _buildUri(endpoint, null, useApiRoot);
    try {
      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .post(uri, headers: _buildHeaders(headers), body: encodedBody)
          .timeout(_config.timeout);
      final resolvedResponse = await _refreshAndRetryIfNeeded(
        endpoint: endpoint,
        response: response,
        retry: () => _httpClient
            .post(uri, headers: _buildHeaders(headers), body: encodedBody)
            .timeout(_config.timeout),
      );
      return _handleResponse(resolvedResponse);
    } on SocketException catch (e) {
      throw NetworkException(
        'Unable to reach backend server at ${uri.host}:${uri.port}: ${e.message}',
      );
    } on TimeoutException {
      throw const NetworkException(
        'Request timed out. Please check your backend connection.',
      );
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
    bool useApiRoot = false,
  }) async {
    final uri = _buildUri(endpoint, null, useApiRoot);
    try {
      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .put(uri, headers: _buildHeaders(headers), body: encodedBody)
          .timeout(_config.timeout);
      final resolvedResponse = await _refreshAndRetryIfNeeded(
        endpoint: endpoint,
        response: response,
        retry: () => _httpClient
            .put(uri, headers: _buildHeaders(headers), body: encodedBody)
            .timeout(_config.timeout),
      );
      return _handleResponse(resolvedResponse);
    } on SocketException catch (e) {
      throw NetworkException(
        'Unable to reach backend server at ${uri.host}:${uri.port}: ${e.message}',
      );
    } on TimeoutException {
      throw const NetworkException(
        'Request timed out. Please check your backend connection.',
      );
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Future<http.Response> _refreshAndRetryIfNeeded({
    required String endpoint,
    required http.Response response,
    required Future<http.Response> Function() retry,
  }) async {
    if (response.statusCode != 401 ||
        endpoint.contains('/auth/login') ||
        endpoint.contains('/auth/refresh')) {
      return response;
    }

    final refreshToken = _storage.getString(StorageKeys.refreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearSession();
      return response;
    }

    final refreshResponse = await _httpClient
        .post(
          _buildUri('/auth/refresh'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(_config.timeout);

    if (refreshResponse.statusCode < 200 || refreshResponse.statusCode >= 300) {
      await _clearSession();
      return response;
    }

    final decoded = jsonDecode(utf8.decode(refreshResponse.bodyBytes));
    final payload = decoded is Map<String, dynamic> && decoded['data'] is Map
        ? Map<String, dynamic>.from(decoded['data'] as Map)
        : decoded;
    final accessToken = payload is Map<String, dynamic>
        ? payload['accessToken'] as String?
        : null;
    if (accessToken == null || accessToken.isEmpty) {
      await _clearSession();
      return response;
    }

    await _storage.setString(StorageKeys.authToken, accessToken);
    return retry();
  }

  Future<void> _clearSession() async {
    await _storage.remove(StorageKeys.currentUserId);
    await _storage.remove(StorageKeys.authToken);
    await _storage.remove(StorageKeys.refreshToken);
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        return decoded['data'];
      }
      return decoded;
    }

    final message =
        (decoded is Map<String, dynamic> && decoded['message'] is String)
        ? decoded['message'] as String
        : 'Server returned HTTP ${response.statusCode}';

    if (response.statusCode == 401) {
      throw AuthException(message, 'unauthorized');
    }

    throw ServerException(message, response.statusCode.toString());
  }

  void close() {
    _httpClient.close();
  }
}
