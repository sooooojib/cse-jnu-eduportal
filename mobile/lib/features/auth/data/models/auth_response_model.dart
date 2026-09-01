import 'user_model.dart';

class AuthResponseModel {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final UserModel user;

  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = "Firebase",
    this.expiresIn = 3600,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json["accessToken"] as String? ?? "",
      refreshToken: json["refreshToken"] as String? ?? "",
      tokenType: json["tokenType"] as String? ?? "Firebase",
      expiresIn: json["expiresIn"] as int? ?? 3600,
      user: UserModel.fromJson(json["user"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "accessToken": accessToken,
      "refreshToken": refreshToken,
      "tokenType": tokenType,
      "expiresIn": expiresIn,
      "user": user.toJson(),
    };
  }
}
