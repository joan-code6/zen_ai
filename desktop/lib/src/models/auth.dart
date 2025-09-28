import 'dart:convert';

class _CopyWithPlaceholder {
  const _CopyWithPlaceholder();
}

const _copyWithPlaceholder = _CopyWithPlaceholder();

class UserProfile {
  final String? displayName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({this.displayName, this.createdAt, this.updatedAt});

  UserProfile copyWith({
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    if (displayName != null && displayName!.isNotEmpty)
      'display_name': displayName,
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final created = json['created_at'] ?? json['createdAt'];
    final updated = json['updated_at'] ?? json['updatedAt'];
    return UserProfile(
      displayName: _nullableString(json['display_name'] ?? json['displayName']),
      createdAt: _parseDateTime(created),
      updatedAt: _parseDateTime(updated),
    );
  }
}

class AuthSession {
  final String uid;
  final String email;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? displayName;
  final String? photoUrl;
  final bool isNewUser;
  final UserProfile? profile;

  const AuthSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    this.displayName,
    this.photoUrl,
    this.isNewUser = false,
    this.profile,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isNearExpiry =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 2)));

  factory AuthSession.fromLoginResponse(Map<String, dynamic> json) {
    final expiresIn = int.tryParse(json['expiresIn']?.toString() ?? '') ?? 3600;
    final profileJson = json['profile'];
    final profile = profileJson is Map<String, dynamic>
        ? UserProfile.fromJson(profileJson)
        : null;
    return AuthSession(
      uid: json['localId']?.toString() ?? json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      idToken: json['idToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      displayName: _nullableString(json['displayName']) ?? profile?.displayName,
      photoUrl: _nullableString(json['photoUrl']),
      isNewUser: _parseBool(json['isNewUser']),
      profile: profile,
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
    if (profile != null) 'profile': profile!.toJson(),
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    final profile = profileJson is Map<String, dynamic>
        ? UserProfile.fromJson(profileJson)
        : null;
    return AuthSession(
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      idToken: json['idToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now(),
      displayName: _nullableString(json['displayName']) ?? profile?.displayName,
      photoUrl: _nullableString(json['photoUrl']),
      isNewUser: _parseBool(json['isNewUser']),
      profile: profile,
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
    Object? profile = _copyWithPlaceholder,
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
      profile: profile == _copyWithPlaceholder
          ? this.profile
          : profile as UserProfile?,
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

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is num) {
    final millis = value >= 1000000000000
        ? value.toInt()
        : (value * 1000).toInt();
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
  }
  if (value is Map<String, dynamic>) {
    final seconds = value['seconds'] ?? value['_seconds'];
    final nanoseconds = value['nanoseconds'] ?? value['_nanoseconds'];
    if (seconds is num) {
      var date = DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
        isUtc: true,
      );
      if (nanoseconds is num) {
        final micros = (nanoseconds / 1000).round();
        date = date.add(Duration(microseconds: micros));
      }
      return date.toLocal();
    }
  }
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  return parsed?.toLocal();
}

class SignupResult {
  final String uid;
  final String email;
  final String? displayName;
  final bool emailVerified;
  final UserProfile? profile;

  const SignupResult({
    required this.uid,
    required this.email,
    this.displayName,
    required this.emailVerified,
    this.profile,
  });

  factory SignupResult.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    final profile = profileJson is Map<String, dynamic>
        ? UserProfile.fromJson(profileJson)
        : null;
    return SignupResult(
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: _nullableString(json['displayName']) ?? profile?.displayName,
      emailVerified:
          json['emailVerified'] == true || json['email_verified'] == true,
      profile: profile,
    );
  }
}
