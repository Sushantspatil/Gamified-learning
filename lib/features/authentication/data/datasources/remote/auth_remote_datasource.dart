import 'dart:developer' as developer;

import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';
import '../../models/user_model.dart';
import '../auth_datasource.dart';

class AuthRemoteDatasource implements AuthDatasource {
  final ApiClient _apiClient;
  final LocalStorageService _storage;
  final AuthDatasource? _fallbackDatasource;

  AuthRemoteDatasource({
    required ApiClient apiClient,
    required LocalStorageService storage,
    AuthDatasource? fallbackDatasource,
  })  : _apiClient = apiClient,
        _storage = storage,
        _fallbackDatasource = fallbackDatasource;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        body: {
          'email': email.trim(),
          'password': password,
        },
      );

      if (response is Map<String, dynamic>) {
        final token = response['accessToken'] as String?;
        final refreshToken = response['refreshToken'] as String?;
        final client = response['client'] as Map<String, dynamic>?;

        if (token != null && token.isNotEmpty) {
          await _storage.setString(StorageKeys.authToken, token);
        }
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _storage.setString(StorageKeys.refreshToken, refreshToken);
        }

        final clientId = client?['id']?.toString() ?? '1';
        final clientEmail = client?['email'] as String? ?? email;
        final clientName = client?['username'] as String? ?? clientEmail.split('@').first;

        await _storage.setString(StorageKeys.currentUserId, clientId);

        return UserModel(
          id: clientId,
          email: clientEmail,
          displayName: clientName,
        );
      }
    } on NetworkException catch (e) {
      developer.log('Backend unreachable ($e), trying fallback.', name: 'AuthRemote');
      if (_fallbackDatasource != null) {
        return _fallbackDatasource.login(email: email, password: password);
      }
      rethrow;
    }

    throw const AuthException('Invalid response from authentication server.', 'invalid-response');
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // 1. Register client in backend database
      await _apiClient.post(
        '/auth/register/validate-basic',
        body: {
          'username': displayName.trim(),
          'email': email.trim(),
          'password': password,
        },
      );

      // 2. Automatically log in to retrieve JWT tokens and establish session
      return await login(email: email, password: password);
    } on NetworkException catch (e) {
      developer.log('Backend unreachable ($e), trying fallback.', name: 'AuthRemote');
      if (_fallbackDatasource != null) {
        return _fallbackDatasource.signUp(
          email: email,
          password: password,
          displayName: displayName,
        );
      }
      rethrow;
    }
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    final token = _storage.getString(StorageKeys.authToken);
    if (token == null || token.isEmpty) {
      if (_fallbackDatasource != null) {
        return _fallbackDatasource.getUserById(id);
      }
      return null;
    }

    try {
      final response = await _apiClient.get('/session');
      if (response is Map<String, dynamic>) {
        final clientId = response['id']?.toString() ?? id;
        final clientEmail = response['email'] as String? ?? '';
        final clientName = response['username'] as String? ?? clientEmail.split('@').first;

        return UserModel(
          id: clientId,
          email: clientEmail,
          displayName: clientName,
        );
      }
    } on AuthException {
      // Token is expired or unauthorized; clean up stored token
      await _storage.remove(StorageKeys.authToken);
      await _storage.remove(StorageKeys.refreshToken);
      await _storage.remove(StorageKeys.currentUserId);
      return null;
    } catch (e) {
      developer.log('Failed to fetch user session from backend: $e', name: 'AuthRemote');
      if (_fallbackDatasource != null) {
        return _fallbackDatasource.getUserById(id);
      }
      final storedId = _storage.getString(StorageKeys.currentUserId);
      if (storedId == id) {
        return UserModel(id: id, email: '', displayName: 'Player');
      }
    }

    return null;
  }

  @override
  Future<UserModel> updateDisplayName({
    required String userId,
    required String displayName,
  }) async {
    return UserModel(
      id: userId,
      email: '',
      displayName: displayName,
    );
  }
}
