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
  })  : _config = config,
        _storage = storage,
        _httpClient = httpClient ?? http.Client();

  Uri _buildUri(String endpoint, [Map<String, String>? queryParams]) {
    var cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    if (_config.baseUrl.endsWith('/api/v1') && cleanEndpoint.startsWith('api/v1/')) {
      cleanEndpoint = cleanEndpoint.substring(7);
    }
    final urlStr = '${_config.baseUrl}/$cleanEndpoint';
    final uri = Uri.parse(urlStr);
    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...queryParams,
    });
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
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    try {
      final response = await _httpClient
          .get(uri, headers: _buildHeaders(headers))
          .timeout(_config.timeout);
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw NetworkException('Unable to reach backend server at ${uri.host}:${uri.port}: ${e.message}');
    } on TimeoutException {
      throw const NetworkException('Request timed out. Please check your backend connection.');
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);
    try {
      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .post(uri, headers: _buildHeaders(headers), body: encodedBody)
          .timeout(_config.timeout);
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw NetworkException('Unable to reach backend server at ${uri.host}:${uri.port}: ${e.message}');
    } on TimeoutException {
      throw const NetworkException('Request timed out. Please check your backend connection.');
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
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

    final message = (decoded is Map<String, dynamic> && decoded['message'] is String)
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
