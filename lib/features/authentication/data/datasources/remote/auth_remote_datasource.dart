import 'dart:developer' as developer;

import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_endpoints.dart';
import 'package:skillverse_app/core/network/dtos/auth_dtos.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';
import '../../models/user_model.dart';
import '../auth_datasource.dart';

class AuthRemoteDatasource implements AuthDatasource {
  final ApiClient _apiClient;
  final LocalStorageService _storage;

  String? _pendingSignupPassword;
  String? _pendingSignupDisplayName;
  UserModel? _pendingVerifiedUser;

  AuthRemoteDatasource({
    required ApiClient apiClient,
    required LocalStorageService storage,
  }) : _apiClient = apiClient,
       _storage = storage;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final requestDto = LoginRequestDto(email: email, password: password);
      final response = await _apiClient.post(
        ApiEndpoints.login,
        body: requestDto.toJson(),
      );

      if (response is Map<String, dynamic>) {
        final resDto = LoginSuccessResponseDto.fromJson(response);

        if (resDto.accessToken.isNotEmpty) {
          await _storage.setString(StorageKeys.authToken, resDto.accessToken);
        }
        if (resDto.refreshToken.isNotEmpty) {
          await _storage.setString(StorageKeys.refreshToken, resDto.refreshToken);
        }

        final clientId = resDto.client?.id.isNotEmpty == true ? resDto.client!.id : '1';
        final clientEmail = resDto.client?.email.isNotEmpty == true ? resDto.client!.email : email;
        final clientName = resDto.client?.username.isNotEmpty == true
            ? resDto.client!.username
            : clientEmail.split('@').first;

        await _storage.setString(StorageKeys.currentUserId, clientId);

        return UserModel(
          id: clientId,
          email: clientEmail,
          displayName: clientName,
        );
      }
    } on NetworkException catch (e) {
      developer.log('Backend unreachable ($e)', name: 'AuthRemote');
      rethrow;
    }

    throw const AuthException(
      'Invalid response from authentication server.',
      'invalid-response',
    );
  }

  @override
  Future<String?> requestSignUpOtp({
    required String email,
    String? password,
    String? displayName,
  }) async {
    final cleanEmail = email.trim();
    if (password != null && password.isNotEmpty) {
      _pendingSignupPassword = password;
    }
    if (displayName != null && displayName.isNotEmpty) {
      _pendingSignupDisplayName = displayName.trim();
    }

    if (password == null && displayName == null) {
      return resendSignUpOtp(email: cleanEmail);
    }

    final requestDto = SignupSendCodeRequestDto(
      email: cleanEmail,
      password: password ?? _pendingSignupPassword ?? '',
      displayName:
          displayName?.trim() ??
          _pendingSignupDisplayName ??
          cleanEmail.split('@').first,
    );

    final response = await _apiClient.post(
      ApiEndpoints.signupSendCode,
      body: requestDto.toJson(),
    );

    if (response is Map<String, dynamic>) {
      final resDto = SignupSendCodeResponseDto.fromJson(response);
      return resDto.otp ?? resDto.message;
    }
    return null;
  }

  @override
  Future<String?> resendSignUpOtp({required String email}) async {
    final requestDto = SignupResendCodeRequestDto(email: email);
    final response = await _apiClient.post(
      ApiEndpoints.signupResendCode,
      body: requestDto.toJson(),
    );
    if (response is Map<String, dynamic>) {
      final resDto = SignupSendCodeResponseDto.fromJson(response);
      return resDto.otp ?? resDto.message;
    }
    return null;
  }

  @override
  Future<void> verifySignUpOtp({
    required String email,
    required String otp,
  }) async {
    final cleanEmail = email.trim();
    final requestDto = SignupVerifyRequestDto(
      email: cleanEmail,
      code: otp,
    );

    final response = await _apiClient.post(
      ApiEndpoints.signupVerify,
      body: requestDto.toJson(),
    );

    if (response is Map<String, dynamic>) {
      final resDto = LoginSuccessResponseDto.fromJson(response);

      if (resDto.accessToken.isNotEmpty) {
        await _storage.setString(StorageKeys.authToken, resDto.accessToken);
      }
      if (resDto.refreshToken.isNotEmpty) {
        await _storage.setString(StorageKeys.refreshToken, resDto.refreshToken);
      }

      final clientId = resDto.client?.id.isNotEmpty == true ? resDto.client!.id : '1';
      final clientEmail = resDto.client?.email.isNotEmpty == true ? resDto.client!.email : cleanEmail;
      final clientName = resDto.client?.username.isNotEmpty == true
          ? resDto.client!.username
          : (_pendingSignupDisplayName ?? clientEmail.split('@').first);

      await _storage.setString(StorageKeys.currentUserId, clientId);

      _pendingVerifiedUser = UserModel(
        id: clientId,
        email: clientEmail,
        displayName: clientName,
      );
    }
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_pendingVerifiedUser != null) {
      final user = _pendingVerifiedUser!;
      _pendingVerifiedUser = null;
      return user;
    }

    return await login(email: email, password: password);
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    final token = _storage.getString(StorageKeys.authToken);
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _apiClient.get(ApiEndpoints.session);
      if (response is Map<String, dynamic>) {
        final clientDto = AuthClientDto.fromJson(response);
        final clientId = clientDto.id.isNotEmpty ? clientDto.id : id;
        final clientEmail = clientDto.email;
        final clientName = clientDto.username.isNotEmpty
            ? clientDto.username
            : clientEmail.split('@').first;

        return UserModel(
          id: clientId,
          email: clientEmail,
          displayName: clientName,
        );
      }
    } on AuthException {
      await _storage.remove(StorageKeys.authToken);
      await _storage.remove(StorageKeys.refreshToken);
      await _storage.remove(StorageKeys.currentUserId);
      return null;
    } catch (e) {
      developer.log(
        'Failed to fetch user session from backend: $e',
        name: 'AuthRemote',
      );
      return null;
    }

    return null;
  }

  @override
  Future<void> logout() async {
    final refreshToken = _storage.getString(StorageKeys.refreshToken);
    await _apiClient.post(
      ApiEndpoints.logout,
      body: refreshToken == null ? null : {'refreshToken': refreshToken},
    );
  }

  @override
  Future<UserModel> updateDisplayName({
    required String userId,
    required String displayName,
  }) async {
    await _apiClient.put(
      ApiEndpoints.profile,
      body: {'name': displayName.trim()},
    );
    final user = await getUserById(userId);
    if (user == null) {
      throw const AuthException(
        'Unable to reload the updated user profile.',
        'profile-refresh-failed',
      );
    }
    return UserModel(
      id: user.id,
      email: user.email,
      displayName: displayName.trim(),
    );
  }
}
