import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat.dart';

class ZenWorkspace extends StatelessWidget {
  final int selectedIndex;
  final List<Chat> chats;
  final String? selectedChatId;
  final Chat? selectedChat;
  final VoidCallback? onCreateChat;
  final Future<void> Function(String)? onSendMessage;
  final bool isSendingMessage;
  final bool isChatLoading;

  const ZenWorkspace({
    super.key,
    this.selectedIndex = 0,
    this.chats = const [],
    this.selectedChatId,
    this.selectedChat,
    this.onCreateChat,
    this.onSendMessage,
    this.isSendingMessage = false,
    this.isChatLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // If a chat is selected, show the chat view
    if (selectedChatId != null) {
      Chat? resolvedChat = selectedChat;
      if (resolvedChat == null) {
        try {
          resolvedChat = chats.firstWhere((c) => c.id == selectedChatId);
        } catch (_) {
          resolvedChat = Chat(
            id: selectedChatId!,
            uid: '',
            title: 'Chat',
            messages: const [],
          );
        }
      }
      final bool isPlaceholder = selectedChat == null;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: _ChatView(
            chat: resolvedChat,
            onSend: onSendMessage,
            onCreate: onCreateChat,
            isSending: isSendingMessage,
            isLoading: isChatLoading || isPlaceholder,
          ),
        ),
      );
    }

    // If no chat selected and user is in main workspace, show the big centered composer
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64.0, vertical: 48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            'Hallo Bennet, wie geht es dir?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
          const SizedBox(height: 40),
          // show big composer when no chat is selected
          ZenChatComposer(
            onSend: onSendMessage,
            isSending: isSendingMessage,
          ),
          const SizedBox(height: 48),
          const Spacer(),
        ],
      ),
    );
  }

  // removed unused time formatter
}

class _ChatView extends StatefulWidget {
  final Chat chat;
  final Future<void> Function(String)? onSend;
  final VoidCallback? onCreate;
  final bool isSending;
  final bool isLoading;

  const _ChatView({
    required this.chat,
    this.onSend,
    this.onCreate,
    this.isSending = false,
    this.isLoading = false,
  });

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // ensure the input is focused when the chat view appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocus.requestFocus();
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    await widget.onSend?.call(text);
    _ctrl.clear();
    // scroll to bottom a bit later
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
  final chat = widget.chat;
  final messages = chat.messages;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final composerBorderColor = colorScheme.outlineVariant.withOpacity(
      isDark ? 0.4 : 0.32,
    );
    final composerBackground = colorScheme.surface;
    final composerShadow = theme.shadowColor.withOpacity(isDark ? 0.5 : 0.12);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                chat.title ?? 'Chat',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: widget.isLoading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Text(
                            'No messages yet. Say hello!',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        itemCount: messages.length,
                        itemBuilder: (context, i) {
                          final m = messages[i];
                          final bg = m.fromUser
                              ? colorScheme.primary
                              : colorScheme.surfaceVariant;
                          final fg = m.fromUser
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface.withOpacity(0.92);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: m.fromUser
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      m.content,
                                      style: TextStyle(color: fg),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),
          // bottom composer styled similar to big composer
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: composerBorderColor),
                    color: composerBackground,
                    boxShadow: [
                      BoxShadow(
                        color: composerShadow,
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _RoundActionButton(
                        icon: Icons.attach_file,
                        tooltip: 'Upload file',
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Shortcuts(
                          shortcuts: <LogicalKeySet, Intent>{
                            LogicalKeySet(LogicalKeyboardKey.enter):
                                const SendIntent(),
                          },
                          child: Actions(
                            actions: <Type, Action<Intent>>{
                              SendIntent: CallbackAction<SendIntent>(
                                onInvoke: (intent) {
                                  _send();
                                  return null;
                                },
                              ),
                            },
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _inputFocus,
                              autofocus: true,
                              keyboardType: TextInputType.multiline,
                              maxLines: 3,
                              decoration: const InputDecoration.collapsed(
                                hintText: 'Send a message...',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoundActionButton(
                        icon: Icons.mic_none,
                        tooltip: 'Voice',
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      _RoundActionButton(
                        icon: Icons.send_rounded,
                        tooltip: 'Send',
                        onPressed: widget.isSending || widget.isLoading
                            ? null
                            : () {
                                _send();
                              },
                        backgroundColor: colorScheme.primary,
                        borderColor: Colors.transparent,
                        iconColor: colorScheme.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SendIntent extends Intent {
  const SendIntent();
}

class ZenChatComposer extends StatefulWidget {
  final Future<void> Function(String)? onSend;
  final bool autofocus;
  final bool isSending;

  const ZenChatComposer({
    super.key,
    this.onSend,
    this.autofocus = true,
    this.isSending = false,
  });

  @override
  State<ZenChatComposer> createState() => _ZenChatComposerState();
}

class _ZenChatComposerState extends State<ZenChatComposer> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.autofocus) _focus.requestFocus();
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    if (widget.isSending) return;
    await widget.onSend?.call(text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = colorScheme.outlineVariant.withOpacity(
      isDark ? 0.38 : 0.32,
    );
    final composerBackground = colorScheme.surface;
    final shadowColor = theme.shadowColor.withOpacity(isDark ? 0.55 : 0.12);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: composerBackground,
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _RoundActionButton(
                    icon: Icons.attach_file,
                    tooltip: 'Upload a file',
                    onPressed: () {},
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Shortcuts(
                      shortcuts: <LogicalKeySet, Intent>{
                        LogicalKeySet(LogicalKeyboardKey.enter):
                            const SendIntent(),
                      },
                      child: Actions(
                        actions: <Type, Action<Intent>>{
                          SendIntent: CallbackAction<SendIntent>(
                            onInvoke: (intent) {
                              // if shift is pressed, insert newline instead
                              if (RawKeyboard.instance.keysPressed.contains(
                                    LogicalKeyboardKey.shiftLeft,
                                  ) ||
                                  RawKeyboard.instance.keysPressed.contains(
                                    LogicalKeyboardKey.shiftRight,
                                  )) {
                                final pos = _ctrl.selection.baseOffset;
                                final txt = _ctrl.text;
                                final newText =
                                    txt.substring(0, pos) +
                                    '\n' +
                                    txt.substring(pos);
                                _ctrl.text = newText;
                                _ctrl.selection = TextSelection.collapsed(
                                  offset: pos + 1,
                                );
                                return null;
                              }
                              _send();
                              return null;
                            },
                          ),
                        },
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          autofocus: widget.autofocus,
                          enabled: !widget.isSending,
                          keyboardType: TextInputType.multiline,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Hallo, das ist ein Test …',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RoundActionButton(
                    icon: Icons.mic_none,
                    tooltip: 'Voice to text',
                    onPressed: () {},
                  ),
                  const SizedBox(width: 12),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      _RoundActionButton(
                        icon: Icons.send_rounded,
                        tooltip: 'Send message',
                        onPressed: widget.isSending
                            ? null
                            : () {
                                _send();
                              },
                        backgroundColor: colorScheme.primary,
                        borderColor: Colors.transparent,
                        iconColor: colorScheme.onPrimary,
                      ),
                      if (widget.isSending)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;

  const _RoundActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final defaultBackground = colorScheme.surfaceVariant.withOpacity(
      isDark ? 0.45 : 0.9,
    );
    final defaultBorder = colorScheme.outlineVariant.withOpacity(
      isDark ? 0.4 : 0.5,
    );
    final defaultIcon = colorScheme.onSurfaceVariant;
    const size = 44.0;
    const iconSize = 24.0;
    final effectiveBackground = backgroundColor ?? defaultBackground;
    final effectiveBorder = borderColor ?? defaultBorder;
    final effectiveIcon = iconColor ?? defaultIcon;
    final bool enabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: size / 2 + 6,
        containedInkWell: true,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: effectiveBackground,
              border: Border.all(color: effectiveBorder),
            ),
            child: Icon(icon, color: effectiveIcon, size: iconSize),
          ),
        ),
      ),
    );
  }
}
