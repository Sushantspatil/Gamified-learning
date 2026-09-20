/// Strongly typed DTOs for Authentication requests and responses.
library;

class LoginRequestDto {
  final String email;
  final String password;

  const LoginRequestDto({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
  };
}

class SignupSendCodeRequestDto {
  final String email;
  final String password;
  final String displayName;

  const SignupSendCodeRequestDto({
    required this.email,
    required this.password,
    required this.displayName,
  });

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'displayName': displayName.trim(),
  };
}

class SignupResendCodeRequestDto {
  final String email;

  const SignupResendCodeRequestDto({required this.email});

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
  };
}

class SignupVerifyRequestDto {
  final String email;
  final String code;

  const SignupVerifyRequestDto({
    required this.email,
    required this.code,
  });

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'code': code.trim(),
  };
}

class AuthTokensDto {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  const AuthTokensDto({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn = 2592000,
  });

  factory AuthTokensDto.fromJson(Map<String, dynamic> json) => AuthTokensDto(
    accessToken: json['accessToken'] as String? ?? '',
    refreshToken: json['refreshToken'] as String? ?? '',
    tokenType: json['tokenType'] as String? ?? 'Bearer',
    expiresIn: json['expiresIn'] as int? ?? 2592000,
  );
}

class AuthClientDto {
  final String id;
  final String email;
  final String username;
  final String? phone;
  final String status;

  const AuthClientDto({
    required this.id,
    required this.email,
    required this.username,
    this.phone,
    this.status = 'active',
  });

  factory AuthClientDto.fromJson(Map<String, dynamic> json) => AuthClientDto(
    id: json['id']?.toString() ?? '',
    email: json['email'] as String? ?? '',
    username: json['username'] as String? ?? (json['email'] as String? ?? '').split('@').first,
    phone: json['phone'] as String?,
    status: json['status'] as String? ?? 'active',
  );
}

class LoginSuccessResponseDto {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final AuthClientDto? client;
  final String? message;

  const LoginSuccessResponseDto({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn = 2592000,
    this.client,
    this.message,
  });

  factory LoginSuccessResponseDto.fromJson(Map<String, dynamic> json) =>
      LoginSuccessResponseDto(
        accessToken: json['accessToken'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
        tokenType: json['tokenType'] as String? ?? 'Bearer',
        expiresIn: json['expiresIn'] as int? ?? 2592000,
        client: json['client'] is Map<String, dynamic>
            ? AuthClientDto.fromJson(json['client'] as Map<String, dynamic>)
            : null,
        message: json['message'] as String?,
      );
}

class SignupSendCodeResponseDto {
  final String email;
  final int cooldownSeconds;
  final int expiresIn;
  final String? message;
  final String? otp;

  const SignupSendCodeResponseDto({
    required this.email,
    required this.cooldownSeconds,
    required this.expiresIn,
    this.message,
    this.otp,
  });

  factory SignupSendCodeResponseDto.fromJson(Map<String, dynamic> json) =>
      SignupSendCodeResponseDto(
        email: json['email'] as String? ?? '',
        cooldownSeconds: json['cooldownSeconds'] as int? ?? 60,
        expiresIn: json['expiresIn'] as int? ?? 600,
        message: json['message'] as String?,
        otp: json['otp'] as String?,
      );
}
