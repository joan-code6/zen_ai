import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat.dart';

class ZenWorkspace extends StatelessWidget {
  final int selectedIndex;
  final List? chats;
  final String? selectedChatId;
  final VoidCallback? onCreateChat;
  final ValueChanged<String>? onSendMessage;

  const ZenWorkspace({super.key, this.selectedIndex = 0, this.chats, this.selectedChatId, this.onCreateChat, this.onSendMessage});

  @override
  Widget build(BuildContext context) {
    // If a chat is selected, show the chat view
    if (selectedChatId != null && chats != null) {
      final chatList = chats as List;
      dynamic chat;
      try {
        chat = chatList.firstWhere((c) => c.id == selectedChatId);
      } catch (e) {
        chat = null;
      }
      if (chat != null) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _ChatView(chat: chat, onSend: onSendMessage, onCreate: onCreateChat),
          ),
        );
      }
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
                  color: Colors.grey.shade900,
                ),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
          const SizedBox(height: 40),
          // show big composer when no chat is selected
          ZenChatComposer(onSend: onSendMessage),
          const SizedBox(height: 48),
          const Spacer(),
        ],
      ),
    );
  }

  // removed unused time formatter
}

class _ChatView extends StatefulWidget {
  final dynamic chat;
  final ValueChanged<String>? onSend;
  final VoidCallback? onCreate;

  const _ChatView({required this.chat, this.onSend, this.onCreate});

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

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _ctrl.clear();
    // scroll to bottom a bit later
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final messages = chat.messages as List<ChatMessage>;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(chat.title ?? 'Chat', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(onPressed: widget.onCreate, icon: const Icon(Icons.add))
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                final bg = m.fromUser ? Theme.of(context).colorScheme.primary : Colors.grey.shade200;
                final fg = m.fromUser ? Colors.white : Colors.black87;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: m.fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(m.text, style: TextStyle(color: fg)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Shortcuts(
                          shortcuts: <LogicalKeySet, Intent>{
                            LogicalKeySet(LogicalKeyboardKey.enter): const SendIntent(),
                          },
                          child: Actions(
                            actions: <Type, Action<Intent>>{
                              SendIntent: CallbackAction<SendIntent>(onInvoke: (intent) {
                                _send();
                                return null;
                              }),
                            },
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _inputFocus,
                              autofocus: true,
                              keyboardType: TextInputType.multiline,
                              maxLines: 3,
                              decoration: const InputDecoration.collapsed(hintText: 'Send a message...'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoundActionButton(icon: Icons.mic_none, tooltip: 'Voice', onPressed: () {}),
                      const SizedBox(width: 8),
                      _RoundActionButton(icon: Icons.send_rounded, tooltip: 'Send', onPressed: _send, backgroundColor: Theme.of(context).colorScheme.primary, borderColor: Colors.transparent, iconColor: Colors.white),
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
  final ValueChanged<String>? onSend;
  final bool autofocus;

  const ZenChatComposer({super.key, this.onSend, this.autofocus = true});

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

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.grey.shade300;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.white,
                border: Border.all(color: borderColor),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _RoundActionButton(
                    icon: Icons.add,
                    tooltip: 'Upload a file',
                    onPressed: () {},
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Shortcuts(
                      shortcuts: <LogicalKeySet, Intent>{
                        LogicalKeySet(LogicalKeyboardKey.enter): const SendIntent(),
                      },
                      child: Actions(
                        actions: <Type, Action<Intent>>{
                          SendIntent: CallbackAction<SendIntent>(onInvoke: (intent) {
                            // if shift is pressed, insert newline instead
                            if (RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftLeft) || RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftRight)) {
                              final pos = _ctrl.selection.baseOffset;
                              final txt = _ctrl.text;
                              final newText = txt.substring(0, pos) + '\n' + txt.substring(pos);
                              _ctrl.text = newText;
                              _ctrl.selection = TextSelection.collapsed(offset: pos + 1);
                              return null;
                            }
                            _send();
                            return null;
                          }),
                        },
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          autofocus: widget.autofocus,
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
                  _RoundActionButton(
                    icon: Icons.send_rounded,
                    tooltip: 'Send message',
                    onPressed: _send,
                    backgroundColor: colorScheme.primary,
                    borderColor: Colors.transparent,
                    iconColor: Colors.white,
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
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;

  const _RoundActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultBackground = Colors.grey.shade100;
    final defaultBorder = Colors.grey.shade300;
    final defaultIcon = Colors.grey.shade700;
    const size = 44.0;
    const iconSize = 24.0;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: size / 2 + 6,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? defaultBackground,
            border: Border.all(
              color: borderColor ?? defaultBorder,
            ),
          ),
          child: Icon(
            icon,
            color: iconColor ?? defaultIcon,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
