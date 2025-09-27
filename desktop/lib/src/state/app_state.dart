import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/auth.dart';
import '../models/chat.dart';
import '../services/backend_service.dart';
import 'user_preferences.dart';

class AppState extends ChangeNotifier {
	AuthSession? _session;
	bool _isRestoringSession = false;
	bool _isAuthenticating = false;
	bool _isSyncingChats = false;
	bool _isSendingMessage = false;
	final List<Chat> _chats = [];
	final Map<String, Chat> _chatCache = {};
	final Map<String, bool> _chatLoading = {};
	String? _lastError;
	String? _lastInfo;

	AuthSession? get session => _session;
	String? get uid => _session?.uid;
	String? get email => _session?.email;
	bool get isAuthenticated => _session != null;
	bool get isAuthenticating => _isAuthenticating;
	bool get isSyncingChats => _isSyncingChats;
	bool get isSendingMessage => _isSendingMessage;
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

	Future<void> restoreSession() async {
		if (_isRestoringSession) return;
		_isRestoringSession = true;
		notifyListeners();

		try {
			final stored = UserPreferences.authSession;
			if (stored != null && !stored.isExpired) {
				_session = stored;
				try {
					await BackendService.verifyToken(stored.idToken);
				} on BackendException catch (e) {
					_session = null;
					UserPreferences.clearAuthSession();
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
			final result = await BackendService.login(email: email, password: password);
			_session = result;
			await UserPreferences.setAuthSession(result);
			await fetchChats();
			_setInfo('Signed in as ${result.email}.');
				success = true;
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

	Future<void> logout() async {
		_session = null;
		_chats.clear();
		_chatCache.clear();
		_chatLoading.clear();
		await UserPreferences.clearAuthSession();
		notifyListeners();
	}

	Future<void> fetchChats() async {
		final currentUid = uid;
		if (currentUid == null) return;

		_isSyncingChats = true;
		notifyListeners();
		try {
			final fetched = await BackendService.listChats(currentUid);
			_chats
				..clear()
				..addAll(fetched);
			for (final chat in fetched) {
				final existing = _chatCache[chat.id];
				if (existing != null && existing.messages.isNotEmpty) {
					_chatCache[chat.id] = chat.copyWith(messages: List.of(existing.messages));
				} else {
					_chatCache[chat.id] = chat;
				}
			}
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
		required String content,
		String role = 'user',
	}) async {
		final currentUid = uid;
		if (currentUid == null) {
			_setError('Please sign in to send messages.');
			return null;
		}

		_isSendingMessage = true;
		notifyListeners();
		try {
			final result = await BackendService.sendMessage(
				chatId: chatId,
				uid: currentUid,
				content: content,
				role: role,
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

	void _upsertChat(Chat chat, {required bool moveToTop}) {
		_chatCache[chat.id] = chat;
		final index = _chats.indexWhere((c) => c.id == chat.id);
		if (index == -1) {
			_chats.insert(0, chat);
		} else {
			_chats[index] = chat;
			if (moveToTop && index != 0) {
				_chats.removeAt(index);
				_chats.insert(0, chat);
			}
		}
		if (moveToTop && _chats.length > 1) {
			_chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
		}
	}
}
