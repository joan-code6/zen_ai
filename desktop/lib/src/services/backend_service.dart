import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/auth.dart';
import '../models/chat.dart';

class BackendException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  BackendException({
    required this.statusCode,
    required this.message,
    this.code,
    this.details,
  });

  @override
  String toString() => 'BackendException($statusCode, $code, $message)';
}

class BackendService {
  static const String _gistUrl =
      'https://gist.githubusercontent.com/joan-code6/8b995d800205dbb119842fa588a2bd2c/raw/zen.json';
  static String? _cachedUrl;
  static http.Client? _client;

  static http.Client get _http => _client ??= http.Client();

  static void configureClient(http.Client? client) {
    _client = client;
  }

  static Future<String> getBackendUrl() async {
    if (_cachedUrl != null) {
      return _cachedUrl!;
    }

    try {
      final response = await _http.get(Uri.parse(_gistUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is String) {
          _cachedUrl = _normalizeBaseUrl(data);
        } else if (data is Map && data.containsKey('url')) {
          _cachedUrl = _normalizeBaseUrl(data['url'].toString());
        }
      }
    } catch (_) {
      // ignore, we'll fall back below
    }

    _cachedUrl ??= 'http://localhost:5000';
    return _cachedUrl!;
  }

  static Future<Map<String, dynamic>> health() async {
    final data = await _get('/health');
    return (data as Map<String, dynamic>?) ?? const {'status': 'unknown'};
  }

  static Future<SignupResult> signup({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final trimmedName = displayName?.trim();
    final payload = {
      'email': email,
      'password': password,
      if (trimmedName != null && trimmedName.isNotEmpty) ...{
        'displayName': trimmedName,
        'display_name': trimmedName,
      },
    };
    final data = await _post('/auth/signup', payload);
    if (data is Map<String, dynamic>) {
      return SignupResult.fromJson(data);
    }
    throw BackendException(statusCode: 500, message: 'Invalid signup response');
  }

  static Future<AuthSession> login({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final trimmedName = displayName?.trim();
    final payload = {
      'email': email,
      'password': password,
      if (trimmedName != null && trimmedName.isNotEmpty) ...{
        'displayName': trimmedName,
        'display_name': trimmedName,
      },
    };
    final data = await _post('/auth/login', payload);
    if (data is Map<String, dynamic>) {
      return AuthSession.fromLoginResponse(data);
    }
    throw BackendException(statusCode: 500, message: 'Invalid login response');
  }

  static Future<AuthSession> googleSignIn({
    String? idToken,
    String? accessToken,
    String? requestUri,
  }) async {
    if ((idToken == null || idToken.isEmpty) &&
        (accessToken == null || accessToken.isEmpty)) {
      throw ArgumentError('Either idToken or accessToken must be provided');
    }

    final payload = <String, dynamic>{
      if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
      if (accessToken != null && accessToken.isNotEmpty)
        'accessToken': accessToken,
      if (requestUri != null && requestUri.isNotEmpty) 'requestUri': requestUri,
    };

    final data = await _post('/auth/google-signin', payload);
    if (data is Map<String, dynamic>) {
      return AuthSession.fromLoginResponse(data);
    }
    throw BackendException(
      statusCode: 500,
      message: 'Invalid google-signin response',
    );
  }

  static Future<Map<String, dynamic>> verifyToken(String idToken) async {
    final payload = {'idToken': idToken};
    final data = await _post('/auth/verify-token', payload);
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw BackendException(
      statusCode: 500,
      message: 'Invalid verify-token response',
    );
  }

  static Future<UserProfile> fetchUserProfile({
    required String uid,
    required String idToken,
  }) async {
    final uri = await _buildUri('/users/$uid');
    final response = await _http.get(
      uri,
      headers: _jsonHeaders({'Authorization': 'Bearer $idToken'}),
    );
    if (response.statusCode == 404) {
      // Treat missing profile as an empty profile rather than an error.
      return const UserProfile();
    }

    final data = _decodeResponse(response);
    if (data is Map<String, dynamic>) {
      final profileJson = data['profile'];
      if (profileJson is Map<String, dynamic>) {
        return UserProfile.fromJson(profileJson);
      }
    }
    throw BackendException(
      statusCode: 500,
      message: 'Invalid profile response',
    );
  }

  static Future<UserProfile> updateDisplayName({
    required String uid,
    required String idToken,
    required String displayName,
  }) async {
    final uri = await _buildUri('/users/$uid');
    final response = await _http.patch(
      uri,
      headers: _jsonHeaders({'Authorization': 'Bearer $idToken'}),
      body: jsonEncode({
        'displayName': displayName,
        'display_name': displayName,
      }),
    );
    if (response.statusCode == 204 || response.body.isEmpty) {
      return fetchUserProfile(uid: uid, idToken: idToken);
    }

    final data = _decodeResponse(response);
    if (data is Map<String, dynamic>) {
      final profileJson = data['profile'];
      if (profileJson is Map<String, dynamic>) {
        return UserProfile.fromJson(profileJson);
      }

      final directProfile = <String, dynamic>{
        if (data['display_name'] != null) 'display_name': data['display_name'],
        if (data['displayName'] != null) 'display_name': data['displayName'],
        if (data['created_at'] != null) 'created_at': data['created_at'],
        if (data['createdAt'] != null) 'created_at': data['createdAt'],
        if (data['updated_at'] != null) 'updated_at': data['updated_at'],
        if (data['updatedAt'] != null) 'updated_at': data['updatedAt'],
      };
      if (directProfile.isNotEmpty) {
        return UserProfile.fromJson(directProfile);
      }
    }

    return fetchUserProfile(uid: uid, idToken: idToken);
  }

  static Future<List<Chat>> listChats(String uid) async {
    final data = await _get('/chats', queryParameters: {'uid': uid});
    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        return items
            .map(
              (item) =>
                  Chat.fromJson(item as Map<String, dynamic>, messages: []),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
    }
    return [];
  }

  static Future<Chat> createChat({
    required String uid,
    String? title,
    String? systemPrompt,
  }) async {
    final payload = {
      'uid': uid,
      if (title != null) 'title': title,
      if (systemPrompt != null) 'systemPrompt': systemPrompt,
    };
    final data = await _post('/chats', payload);
    if (data is Map<String, dynamic>) {
      return Chat.fromJson(data);
    }
    throw BackendException(
      statusCode: 500,
      message: 'Invalid chat creation response',
    );
  }

  static Future<Chat> updateChat({
    required String chatId,
    required String uid,
    String? title,
    String? systemPrompt,
  }) async {
    final payload = {
      'uid': uid,
      if (title != null) 'title': title,
      if (systemPrompt != null) 'systemPrompt': systemPrompt,
    };
    final data = await _patch('/chats/$chatId', payload);
    if (data is Map<String, dynamic>) {
      return Chat.fromJson(data);
    }
    throw BackendException(
      statusCode: 500,
      message: 'Invalid chat update response',
    );
  }

  static Future<void> deleteChat({
    required String chatId,
    required String uid,
  }) async {
    await _delete('/chats/$chatId', {'uid': uid});
  }

  static Future<Chat> getChat({
    required String chatId,
    required String uid,
  }) async {
    final data = await _get('/chats/$chatId', queryParameters: {'uid': uid});
    if (data is Map<String, dynamic>) {
      final chatJson = data['chat'] as Map<String, dynamic>?;
      final messages = data['messages'] as List? ?? const [];
      final files = data['files'] as List? ?? const [];
      if (chatJson != null) {
        return Chat.fromJson(
          chatJson,
          messages: messages
              .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList(),
          files: files
              .whereType<Map<String, dynamic>>()
              .map(ChatFile.fromJson)
              .toList(),
        );
      }
    }
    throw BackendException(
      statusCode: 500,
      message: 'Invalid chat fetch response',
    );
  }

  static Future<MessageSendResult> sendMessage({
    required String chatId,
    required String uid,
    String? content,
    String role = 'user',
    List<String>? fileIds,
  }) async {
    final payload = <String, dynamic>{
      'uid': uid,
      'role': role,
      if (content != null && content.isNotEmpty) 'content': content,
      if (fileIds != null && fileIds.isNotEmpty) 'fileIds': fileIds,
    };
    final data = await _post('/chats/$chatId/messages', payload);
    if (data is Map<String, dynamic>) {
      final user = data['userMessage'];
      final assistant = data['assistantMessage'];
      return MessageSendResult(
        userMessage: user is Map<String, dynamic>
            ? ChatMessage.fromJson(user)
            : ChatMessage(
                id: DateTime.now().toIso8601String(),
                role: role,
                content: content ?? '',
                fileIds: fileIds ?? const [],
              ),
        assistantMessage: assistant is Map<String, dynamic>
            ? ChatMessage.fromJson(assistant)
            : null,
        rawResponse: data,
      );
    }
    throw BackendException(
      statusCode: 500,
      message: 'Invalid message response',
    );
  }

  static Future<ChatFile> uploadChatFile({
    required String chatId,
    required String uid,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final uri = await _buildUri('/chats/$chatId/files');
    final request = http.MultipartRequest('POST', uri)..fields['uid'] = uid;

    http.MultipartFile multipartFile;
    if (mimeType != null && mimeType.isNotEmpty) {
      try {
        multipartFile = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        );
      } catch (_) {
        multipartFile = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        );
      }
    } else {
      multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      );
    }

    request.files.add(multipartFile);

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = _decodeResponse(response);
    if (data is Map<String, dynamic>) {
      final fileJson = data['file'];
      if (fileJson is Map<String, dynamic>) {
        return ChatFile.fromJson(fileJson);
      }
    }
    throw BackendException(
      statusCode: response.statusCode,
      message: 'Invalid file upload response',
    );
  }

  static Future<dynamic> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = await _buildUri(path, queryParameters: queryParameters);
    final response = await _http.get(uri, headers: _jsonHeaders());
    return _decodeResponse(response);
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final uri = await _buildUri(path);
    final response = await _http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  static Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final uri = await _buildUri(path);
    final response = await _http.patch(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  static Future<dynamic> _delete(String path, Map<String, dynamic> body) async {
    final uri = await _buildUri(path);
    final response = await _http.delete(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  static Future<Uri> _buildUri(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    var base = await getBackendUrl();
    if (!base.endsWith('/')) base = '$base/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse(base).resolve(normalizedPath);
    if (queryParameters == null) return uri;
    final filtered = {
      for (final entry in queryParameters.entries)
        if (entry.value != null)
          entry.key: entry.value is List
              ? entry.value
                    .where((element) => element != null)
                    .map((element) => element.toString())
                    .toList()
              : entry.value.toString(),
    };
    return uri.replace(queryParameters: filtered.isEmpty ? null : filtered);
  }

  static dynamic _decodeResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      if (statusCode == 204 || response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    Map<String, dynamic>? errorBody;
    try {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          errorBody = decoded;
        }
      }
    } catch (_) {
      // ignore parse errors
    }

    final message =
        errorBody?['message']?.toString() ??
        response.reasonPhrase ??
        'Request failed with status $statusCode';
    final code = errorBody?['error']?.toString();
    throw BackendException(
      statusCode: statusCode,
      message: message,
      code: code,
      details: errorBody,
    );
  }

  static Map<String, String> _jsonHeaders([Map<String, String>? extra]) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (extra != null) ...extra,
    };
  }

  static String _normalizeBaseUrl(String url) {
    var value = url.trim();
    if (value.isEmpty) return 'http://localhost:5000';
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    return value;
  }
}

class MessageSendResult {
  final ChatMessage userMessage;
  final ChatMessage? assistantMessage;
  final Map<String, dynamic> rawResponse;

  const MessageSendResult({
    required this.userMessage,
    this.assistantMessage,
    this.rawResponse = const {},
  });
}
