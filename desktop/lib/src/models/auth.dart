import 'dart:convert';

class AuthSession {
  final String uid;
  final String email;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? displayName;
  final String? photoUrl;
  final bool isNewUser;

  const AuthSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    this.displayName,
    this.photoUrl,
    this.isNewUser = false,
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
      displayName: _nullableString(json['displayName']),
      photoUrl: _nullableString(json['photoUrl']),
      isNewUser: _parseBool(json['isNewUser']),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'idToken': idToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        if (displayName != null) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'isNewUser': isNewUser,
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      idToken: json['idToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ?? DateTime.now(),
      displayName: _nullableString(json['displayName']),
      photoUrl: _nullableString(json['photoUrl']),
      isNewUser: _parseBool(json['isNewUser']),
    );
  }

  AuthSession copyWith({
    String? uid,
    String? email,
    String? idToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? displayName,
    String? photoUrl,
    bool? isNewUser,
  }) {
    return AuthSession(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      idToken: idToken ?? this.idToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isNewUser: isNewUser ?? this.isNewUser,
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

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
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
