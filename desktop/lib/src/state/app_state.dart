import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:universal_io/io.dart' as io;
import 'package:url_launcher/url_launcher.dart';

import '../models/auth.dart';
import '../models/chat.dart';
import '../services/backend_service.dart';
import 'user_preferences.dart';

const _kOAuthAuthorizeEndpoint = 'accounts.google.com';
const _kOAuthAuthorizePath = '/o/oauth2/v2/auth';
const _kOAuthTokenEndpoint = 'https://oauth2.googleapis.com/token';

const String _oauthSuccessPage = '''<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8" />
	<title>Google Sign-in Complete</title>
	<style>
		body { font-family: Roboto, Arial, sans-serif; margin: 0; padding: 32px; background: #f5f5f5; color: #202124; }
		main { max-width: 480px; margin: 80px auto; background: #fff; border-radius: 12px; padding: 32px; box-shadow: 0 12px 32px rgba(60,64,67,.15); text-align: center; }
		h1 { font-size: 1.75rem; margin-bottom: 12px; }
		p { font-size: 1rem; line-height: 1.6; }
	</style>
</head>
<body>
	<main>
		<h1>You're signed in!</h1>
		<p>Close this Window and return to the app.</p>
		<script>setTimeout(() => window.close(), 1500);</script>
	</main>
</body>
</html>''';

String _oauthErrorPage(String? description) => '''<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8" />
	<title>Google Sign-in Failed</title>
	<style>
		body { font-family: Roboto, Arial, sans-serif; margin: 0; padding: 32px; background: #fff3f3; color: #202124; }
		main { max-width: 480px; margin: 80px auto; background: #ffffff; border-radius: 12px; padding: 32px; box-shadow: 0 12px 32px rgba(217,48,37,.2); }
		h1 { font-size: 1.75rem; margin-bottom: 12px; color: #d93025; }
		p { font-size: 1rem; line-height: 1.6; }
	</style>
</head>
<body>
	<main>
		<h1>Sign-in was cancelled</h1>
		<p>${description ?? 'You can safely close this window.'}</p>
	</main>
</body>
</html>''';

const String _desktopGoogleClientId =
	String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID', defaultValue: '');
const String _desktopGoogleClientSecret =
	String.fromEnvironment('GOOGLE_OAUTH_CLIENT_SECRET', defaultValue: '');
const List<String> _googleOAuthScopes = <String>['openid', 'email', 'profile'];

class AppState extends ChangeNotifier {
	AuthSession? _session;
	String? _displayName;
	String? _photoUrl;
	bool _isNewUser = false;
	bool _isRestoringSession = false;
	bool _isAuthenticating = false;
	bool _isSyncingChats = false;
	bool _isSendingMessage = false;
	bool _isUploadingFile = false;
	final List<Chat> _chats = [];
	final Map<String, Chat> _chatCache = {};
	final Map<String, bool> _chatLoading = {};
	String? _lastError;
	String? _lastInfo;
	final GoogleSignIn _googleSignIn = GoogleSignIn(
		scopes: const ['email'],
	);

	AuthSession? get session => _session;
	String? get uid => _session?.uid;
	String? get email => _session?.email;
	String? get displayName => _displayName;
	String? get photoUrl => _photoUrl;
	bool get isNewUser => _isNewUser;
	bool get isAuthenticated => _session != null;
	bool get isAuthenticating => _isAuthenticating;
	bool get isSyncingChats => _isSyncingChats;
	bool get isSendingMessage => _isSendingMessage;
	bool get isUploadingFile => _isUploadingFile;
	bool get isRestoringSession => _isRestoringSession;

	List<Chat> get chats => List.unmodifiable(_chats);

	Chat? chatById(String? id) {
		if (id == null) return null;
		return _chatCache[id];
	}

	bool isChatLoading(String chatId) => _chatLoading[chatId] ?? false;

	String? consumeError() {
		final error = _lastError;
		_lastError = null;
		return error;
	}

	String? consumeInfo() {
		final info = _lastInfo;
		_lastInfo = null;
		return info;
	}

	void _setError(String message) {
		_lastError = message;
		notifyListeners();
	}

	void _setInfo(String message) {
		_lastInfo = message;
		notifyListeners();
	}

	void _applySession(AuthSession session) {
		_session = session;
		_displayName = session.displayName;
		_photoUrl = session.photoUrl;
		_isNewUser = session.isNewUser;
	}

	void _clearSession() {
		_session = null;
		_displayName = null;
		_photoUrl = null;
		_isNewUser = false;
	}

	Future<bool> _finalizeSession(
		AuthSession session, {
		String? fallbackDisplayName,
		bool fromGoogle = false,
	}) async {
		_applySession(session);
		await UserPreferences.setAuthSession(session);
		notifyListeners();
		await fetchChats();
		final resolvedName =
			session.displayName != null && session.displayName!.isNotEmpty
				? session.displayName!
				: (fallbackDisplayName != null && fallbackDisplayName.isNotEmpty
					? fallbackDisplayName
					: (session.email.isNotEmpty ? session.email : 'your account'));
		if (fromGoogle) {
			if (session.isNewUser) {
				_setInfo('Welcome $resolvedName! Your Google account is all set.');
			} else {
				_setInfo('Signed in with Google as $resolvedName.');
			}
		} else {
			_setInfo('Signed in as $resolvedName.');
		}
		return true;
	}

	Future<void> restoreSession() async {
		if (_isRestoringSession) return;
		_isRestoringSession = true;
		notifyListeners();

		try {
			final stored = UserPreferences.authSession;
			if (stored != null && !stored.isExpired) {
				_applySession(stored);
				notifyListeners();
				try {
					await BackendService.verifyToken(stored.idToken);
				} on BackendException catch (e) {
					_clearSession();
					await UserPreferences.clearAuthSession();
					_setError(e.message);
				}
			}
			if (_session != null) {
				await fetchChats();
			}
		} finally {
			_isRestoringSession = false;
			notifyListeners();
		}
	}

		Future<bool> signup({
		required String email,
		required String password,
		String? displayName,
		}) async {
		_isAuthenticating = true;
		notifyListeners();
			var success = false;
		try {
			await BackendService.signup(
				email: email,
				password: password,
				displayName: displayName,
			);
			_setInfo('Account created successfully. Please sign in.');
				success = true;
		} on BackendException catch (e) {
			_setError(e.message);
		} catch (e) {
			_setError('Sign up failed: $e');
		} finally {
			_isAuthenticating = false;
			notifyListeners();
		}
			return success;
	}

		Future<bool> login({
		required String email,
		required String password,
	}) async {
		_isAuthenticating = true;
		notifyListeners();
			var success = false;
		try {
					final session = await BackendService.login(email: email, password: password);
					success = await _finalizeSession(session);
		} on BackendException catch (e) {
			_setError(e.message);
		} catch (e) {
			_setError('Unable to sign in: $e');
		} finally {
			_isAuthenticating = false;
			notifyListeners();
		}
			return success;
	}

		Future<bool> loginWithGoogle({String? requestUri}) async {
			if (_isAuthenticating) return false;
			_isAuthenticating = true;
			notifyListeners();
			try {
				if (!kIsWeb && (io.Platform.isWindows || io.Platform.isLinux)) {
					return await _loginWithGoogleDesktop(requestUri: requestUri);
				}
				return await _loginWithGooglePlugin(requestUri: requestUri);
			} finally {
				_isAuthenticating = false;
				notifyListeners();
			}
		}

		Future<bool> _loginWithGooglePlugin({String? requestUri}) async {
			try {
				GoogleSignInAccount? account;
				try {
					account = await _googleSignIn.signInSilently();
				} catch (_) {
					account = null;
				}
				account ??= await _googleSignIn.signIn();
				if (account == null) {
					_setInfo('Google sign-in was cancelled.');
					return false;
				}
				final authentication = await account.authentication;
				final idToken = authentication.idToken;
				final accessToken = authentication.accessToken;
				if ((idToken == null || idToken.isEmpty) && (accessToken == null || accessToken.isEmpty)) {
					_setError('Google sign-in failed: missing credentials.');
					return false;
				}
				final resolvedRequestUri =
					requestUri != null && requestUri.isNotEmpty
						? requestUri
						: (kIsWeb ? Uri.base.origin : null);
				final backendSession = await BackendService.googleSignIn(
					idToken: idToken,
					accessToken: idToken == null ? accessToken : null,
					requestUri: resolvedRequestUri,
				);
				final mergedSession = backendSession.copyWith(
					displayName: backendSession.displayName ?? account.displayName,
					photoUrl: backendSession.photoUrl ?? account.photoUrl,
				);
				return await _finalizeSession(
					mergedSession,
					fallbackDisplayName: account.displayName?.isNotEmpty == true
						? account.displayName
						: account.email,
					fromGoogle: true,
				);
			} on BackendException catch (e) {
				_setError(e.message);
			} catch (e) {
				_setError('Google sign-in failed: $e');
			}
			return false;
		}

		Future<bool> _loginWithGoogleDesktop({String? requestUri}) async {
			if (_desktopGoogleClientId.isEmpty) {
				_setError(
					'Google desktop sign-in requires configuring GOOGLE_OAUTH_CLIENT_ID via --dart-define.',
				);
				return false;
			}

			late final io.HttpServer server;
			try {
				server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
			} catch (e) {
				_setError('Google sign-in failed: unable to open a local callback server ($e).');
				return false;
			}

			try {
				final redirectUri = Uri(
					scheme: 'http',
					host: 'localhost',
					port: server.port,
					path: '/',
				);
				final state = _generateVerifier(32);
				final codeVerifier = _generateVerifier(64);
				final codeChallenge = _computeCodeChallenge(codeVerifier);
				final authUri = Uri.https(
					_kOAuthAuthorizeEndpoint,
					_kOAuthAuthorizePath,
					{
						'response_type': 'code',
						'client_id': _desktopGoogleClientId,
						'redirect_uri': redirectUri.toString(),
						'scope': _googleOAuthScopes.join(' '),
						'state': state,
						'prompt': 'select_account consent',
						'access_type': 'offline',
						'code_challenge': codeChallenge,
						'code_challenge_method': 'S256',
					},
				);

				final launched = await launchUrl(authUri, mode: LaunchMode.externalApplication);
				if (!launched) {
					_setError('Unable to open browser for Google sign-in.');
					return false;
				}

				final callback = await _waitForOAuthCallback(server, state).timeout(
					const Duration(minutes: 5),
					onTimeout: () => _OAuthCallbackResult.timeout(),
				);

				if (callback.timedOut) {
					_setError('Google sign-in timed out. Please try again.');
					return false;
				}
				if (callback.error != null) {
					if (callback.error == 'access_denied') {
						_setInfo('Google sign-in was cancelled.');
					} else {
						_setError('Google sign-in failed: ${callback.errorDescription ?? callback.error}.');
					}
					return false;
				}
				final authCode = callback.code;
				if (authCode == null || authCode.isEmpty) {
					_setError('Google sign-in failed: missing authorization code.');
					return false;
				}

				final tokenResponse = await http.post(
					Uri.parse(_kOAuthTokenEndpoint),
					headers: {
						'Content-Type': 'application/x-www-form-urlencoded',
						'Accept': 'application/json',
					},
					body: {
						'code': authCode,
						'client_id': _desktopGoogleClientId,
						'redirect_uri': redirectUri.toString(),
						'grant_type': 'authorization_code',
						'code_verifier': codeVerifier,
						if (_desktopGoogleClientSecret.isNotEmpty) 'client_secret': _desktopGoogleClientSecret,
					},
				);
				Map<String, dynamic>? tokenData;
				try {
					if (tokenResponse.body.isNotEmpty) {
						tokenData = json.decode(tokenResponse.body) as Map<String, dynamic>;
					}
				} catch (e) {
					tokenData = null;
				}
				if (tokenResponse.statusCode != 200 || tokenData == null) {
					final error = tokenData?['error']?.toString();
					final errorDescription = tokenData?['error_description']?.toString();
					final detail = [
						if (error != null && error.isNotEmpty) error,
						if (errorDescription != null && errorDescription.isNotEmpty) errorDescription,
					].join(': ');
					var message = 'Google sign-in failed: token exchange returned HTTP ${tokenResponse.statusCode}${detail.isEmpty ? '' : ' ($detail)'}.';
					if (_desktopGoogleClientSecret.isEmpty &&
						(errorDescription?.contains('client_secret') ?? false)) {
						message =
							'Google sign-in failed because Google expects a client secret. Either supply GOOGLE_OAUTH_CLIENT_SECRET via --dart-define or switch to a Desktop OAuth client (Installed app) that doesn\'t require a secret.';
					}
					debugPrint('[oauth] token exchange failed -> status ${tokenResponse.statusCode}; body: ${tokenResponse.body}');
					_setError(message);
					return false;
				}
				final idToken = tokenData['id_token'] as String?;
				final accessToken = (tokenData['access_token'] as String?) ?? '';
				if ((idToken == null || idToken.isEmpty) && accessToken.isEmpty) {
					_setError('Google sign-in failed: missing Google credentials.');
					return false;
				}
				try {
					final backendSession = await BackendService.googleSignIn(
						idToken: idToken,
						accessToken: idToken == null ? accessToken : null,
						requestUri: requestUri,
					);
					return await _finalizeSession(backendSession, fromGoogle: true);
				} on BackendException catch (e) {
					_setError(e.message);
				} catch (e) {
					_setError('Google sign-in failed: $e');
				}
				return false;
			} finally {
				await server.close(force: true);
			}
		}

	Future<void> logout() async {
		_clearSession();
		_chats.clear();
		_chatCache.clear();
		_chatLoading.clear();
		await UserPreferences.clearAuthSession();
		try {
			await _googleSignIn.signOut();
		} catch (_) {
			// ignore platform-specific sign out issues
		}
		notifyListeners();
	}

	Future<void> fetchChats() async {
		final currentUid = uid;
		if (currentUid == null) return;

		_isSyncingChats = true;
		notifyListeners();
		try {
			final fetched = await BackendService.listChats(currentUid);
			final fetchedIds = fetched.map((chat) => chat.id).toSet();
			_chatCache.removeWhere((key, value) => !fetchedIds.contains(key));
			final merged = <Chat>[];
			for (final chat in fetched) {
				final existing = _chatCache[chat.id];
				if (existing != null) {
					final preservedMessages = existing.messages.isNotEmpty
						? List<ChatMessage>.from(existing.messages)
						: <ChatMessage>[];
					final preservedFiles = existing.files.isNotEmpty
						? List<ChatFile>.from(existing.files)
						: <ChatFile>[];
					final mergedChat = chat.copyWith(
						messages: preservedMessages,
						files: preservedFiles,
					);
					_chatCache[chat.id] = mergedChat;
					merged.add(mergedChat);
				} else {
					_chatCache[chat.id] = chat;
					merged.add(chat);
				}
			}
			_chats
				..clear()
				..addAll(merged);
		} on BackendException catch (e) {
			_setError(e.message);
		} catch (e) {
			_setError('Failed to load chats: $e');
		} finally {
			_isSyncingChats = false;
			notifyListeners();
		}
	}

	Future<Chat?> ensureChatLoaded(String chatId) async {
		final chat = _chatCache[chatId];
		if (chat != null && chat.messages.isNotEmpty) {
			return chat;
		}
		return await getChat(chatId);
	}

	Future<Chat?> getChat(String chatId) async {
		final currentUid = uid;
		if (currentUid == null) return null;
		if (_chatLoading[chatId] == true) return _chatCache[chatId];

		_chatLoading[chatId] = true;
		notifyListeners();
		try {
			final chat = await BackendService.getChat(chatId: chatId, uid: currentUid);
			_upsertChat(chat, moveToTop: false);
			return chat;
		} on BackendException catch (e) {
			_setError(e.message);
		} catch (e) {
			_setError('Failed to load chat: $e');
		} finally {
			_chatLoading[chatId] = false;
			notifyListeners();
		}
		return null;
	}

	Future<Chat?> createChat({
		required String title,
		String? systemPrompt,
	}) async {
		final currentUid = uid;
		if (currentUid == null) {
			_setError('Please sign in to create chats.');
			return null;
		}

		try {
			final chat = await BackendService.createChat(
				uid: currentUid,
				title: title,
				systemPrompt: systemPrompt,
			);
			_upsertChat(chat, moveToTop: true);
			notifyListeners();
			return chat;
		} on BackendException catch (e) {
			_setError(e.message);
		} catch (e) {
			_setError('Failed to create chat: $e');
		}
		return null;
	}

	Future<Chat?> updateChat({
		required String chatId,
		String? title,
		String? systemPrompt,
	}) async {
		final currentUid = uid;
		if (currentUid == null) {
			_setError('Please sign in to update chats.');
			return null;
		}

		try {
			final chat = await BackendService.updateChat(
				chatId: chatId,
				uid: currentUid,
				title: title,
				systemPrompt: systemPrompt,
			);
			final existingMessages = _chatCache[chatId]?.messages ?? const <ChatMessage>[];
			_upsertChat(chat.copyWith(messages: List.of(existingMessages)), moveToTop: false);
			notifyListeners();
			return chat;
		} on BackendException catch (e) {
			_setError(e.message);
		} catch (e) {
			_setError('Failed to update chat: $e');
		}
		return null;
	}

	Future<void> deleteChat(String chatId) async {
		final currentUid = uid;
		if (currentUid == null) {
			_setError('Please sign in to delete chats.');
			return;
		}

		try {
			await BackendService.deleteChat(chatId: chatId, uid: currentUid);
			_chats.removeWhere((c) => c.id == chatId);
			_chatCache.remove(chatId);
			notifyListeners();
		} on BackendException catch (e) {
			_setError(e.message);
		} catch (e) {
			_setError('Failed to delete chat: $e');
		}
	}

	Future<MessageSendResult?> sendMessage({
		required String chatId,
		String? content,
		String role = 'user',
		List<String> fileIds = const [],
	}) async {
		final currentUid = uid;
		if (currentUid == null) {
			_setError('Please sign in to send messages.');
			return null;
		}

		final trimmedContent = content?.trim();
		final hasContent = trimmedContent != null && trimmedContent.isNotEmpty;
		if (!hasContent && fileIds.isEmpty) {
			_setError('Please enter a message or attach a file.');
			return null;
		}

		_isSendingMessage = true;
		notifyListeners();
		try {
			final result = await BackendService.sendMessage(
				chatId: chatId,
				uid: currentUid,
				content: hasContent ? trimmedContent : null,
				role: role,
				fileIds: fileIds.isEmpty ? null : fileIds,
			);
			final existing = _chatCache[chatId];
			if (existing != null) {
				final messages = List<ChatMessage>.from(existing.messages)
					..add(result.userMessage);
				if (result.assistantMessage != null) {
					messages.add(result.assistantMessage!);
				}
				final updatedChat = existing.copyWith(
					messages: messages,
					updatedAt: DateTime.now(),
				);
				_upsertChat(updatedChat, moveToTop: true);
			} else {
				await getChat(chatId);
			}
			return result;
		} on BackendException catch (e) {
			_setError(e.message);
		} catch (e) {
			_setError('Failed to send message: $e');
		} finally {
			_isSendingMessage = false;
			notifyListeners();
		}
		return null;
	}

	Future<ChatFile?> uploadChatFile({
		required String chatId,
		required String fileName,
		required List<int> bytes,
		String? mimeType,
	}) async {
		final currentUid = uid;
		if (currentUid == null) {
			_setError('Please sign in to upload files.');
			return null;
		}

		_isUploadingFile = true;
		notifyListeners();
		try {
			final uploaded = await BackendService.uploadChatFile(
				chatId: chatId,
				uid: currentUid,
				bytes: bytes,
				fileName: fileName,
				mimeType: mimeType,
			);
			final existing = _chatCache[chatId];
			if (existing != null) {
				final files = List<ChatFile>.from(existing.files)
					..removeWhere((f) => f.id == uploaded.id)
					..add(uploaded);
				final updatedChat = existing.copyWith(
					files: files,
					updatedAt: uploaded.createdAt,
				);
				_upsertChat(updatedChat, moveToTop: false);
			} else {
				await getChat(chatId);
			}
			_setInfo('Uploaded ${uploaded.fileName}');
			return uploaded;
		} on BackendException catch (e) {
			_setError(e.message);
		} catch (e) {
			_setError('Failed to upload file: $e');
		}
		finally {
			_isUploadingFile = false;
			notifyListeners();
		}
		return null;
	}

	void _upsertChat(Chat chat, {required bool moveToTop}) {
		final existing = _chatCache[chat.id];
		Chat merged = chat;
		if (existing != null) {
			final mergedMessages = chat.messages.isNotEmpty
				? chat.messages
				: existing.messages;
			final mergedFiles = chat.files.isNotEmpty
				? chat.files
				: existing.files;
			merged = chat.copyWith(
				messages: List<ChatMessage>.from(mergedMessages),
				files: List<ChatFile>.from(mergedFiles),
			);
		}
		_chatCache[chat.id] = merged;
		final index = _chats.indexWhere((c) => c.id == chat.id);
		if (index == -1) {
			_chats.insert(0, merged);
		} else {
			_chats[index] = merged;
			if (moveToTop && index != 0) {
				_chats.removeAt(index);
				_chats.insert(0, merged);
			}
		}
		if (moveToTop && _chats.length > 1) {
			_chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
		}
	}
}

const String _pkceCharset =
	'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

String _generateVerifier(int length) {
	final random = _newSecureRandom();
	final buffer = StringBuffer();
	for (var i = 0; i < length; i++) {
		buffer.write(_pkceCharset[random.nextInt(_pkceCharset.length)]);
	}
	return buffer.toString();
}

Random _newSecureRandom() {
	try {
		return Random.secure();
	} catch (_) {
		return Random();
	}
}

String _computeCodeChallenge(String verifier) {
	final digest = sha256.convert(utf8.encode(verifier));
	return base64UrlEncode(digest.bytes).replaceAll('=', '');
}

Future<_OAuthCallbackResult> _waitForOAuthCallback(
	io.HttpServer server,
	String expectedState,
) async {
	await for (final request in server) {
		if (request.uri.path == '/favicon.ico') {
			request.response.statusCode = io.HttpStatus.noContent;
			await request.response.close();
			continue;
		}
		if (request.method != 'GET') {
			await _respondPlain(
				request.response,
				io.HttpStatus.methodNotAllowed,
				'Only GET is supported.',
			);
			continue;
		}
		final params = request.uri.queryParameters;
		if (!params.containsKey('state') || params['state'] != expectedState) {
			await _respondPlain(
				request.response,
				io.HttpStatus.badRequest,
				'State validation failed.',
			);
			continue;
		}
		final error = params['error'];
		if (error != null) {
			final description = params['error_description'];
			await _respondHtml(
				request.response,
				_oauthErrorPage(description),
				statusCode: io.HttpStatus.ok,
			);
			return _OAuthCallbackResult(
				error: error,
				errorDescription: description,
			);
		}
		final code = params['code'];
		if (code != null && code.isNotEmpty) {
			await _respondHtml(
				request.response,
				_oauthSuccessPage,
				statusCode: io.HttpStatus.ok,
			);
			return _OAuthCallbackResult(code: code);
		}
		await _respondPlain(
			request.response,
			io.HttpStatus.badRequest,
			'Missing authorization code.',
		);
	}
	return _OAuthCallbackResult(
		error: 'loopback_server_closed',
		errorDescription: 'Callback server closed before receiving authorization response.',
	);
}

Future<void> _respondHtml(
	io.HttpResponse response,
	String body, {
	int statusCode = io.HttpStatus.ok,
}) async {
	response.statusCode = statusCode;
	response.headers.set(io.HttpHeaders.contentTypeHeader, 'text/html; charset=utf-8');
	response.headers.set('Cache-Control', 'no-store');
	response.write(body);
	await response.close();
}

Future<void> _respondPlain(
	io.HttpResponse response,
	int statusCode,
	String message,
) async {
	response.statusCode = statusCode;
	response.headers.set(io.HttpHeaders.contentTypeHeader, 'text/plain; charset=utf-8');
	response.headers.set('Cache-Control', 'no-store');
	response.write(message);
	await response.close();
}

class _OAuthCallbackResult {
	final String? code;
	final String? error;
	final String? errorDescription;
	final bool timedOut;

	const _OAuthCallbackResult({
		this.code,
		this.error,
		this.errorDescription,
		this.timedOut = false,
	});

	factory _OAuthCallbackResult.timeout() => const _OAuthCallbackResult(timedOut: true);
}
