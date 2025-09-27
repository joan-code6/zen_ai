import 'dart:convert';

class AuthSession {
  final String uid;
  final String email;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;

  const AuthSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isNearExpiry => DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 2)));

  factory AuthSession.fromLoginResponse(Map<String, dynamic> json) {
    final expiresIn = int.tryParse(json['expiresIn']?.toString() ?? '') ?? 3600;
    return AuthSession(
      uid: json['localId']?.toString() ?? json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      idToken: json['idToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'idToken': idToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      idToken: json['idToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  String encode() => jsonEncode(toJson());

  static AuthSession? decode(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      return AuthSession.fromJson(jsonDecode(source) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

class SignupResult {
  final String uid;
  final String email;
  final String? displayName;
  final bool emailVerified;

  const SignupResult({
    required this.uid,
    required this.email,
    this.displayName,
    required this.emailVerified,
  });

  factory SignupResult.fromJson(Map<String, dynamic> json) {
    return SignupResult(
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString(),
      emailVerified: json['emailVerified'] == true,
    );
  }
}
