import '../../domain/entities/app_user.dart';

/// Data-layer representation of a user. Adds (de)serialization on top of the
/// plain [AppUser] domain entity so Firestore document shapes stay out of
/// the domain/presentation layers.
class UserModel extends AppUser {
  const UserModel({
    required super.id,
    required super.email,
    required super.displayName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
  };
}
