import 'package:flutter/material.dart';

import '../workspace/workspace.dart';
import '../models/chat.dart';
import '../sidebar/sidebar.dart';
import '../sidebar/notes_panel.dart';

class ZenHomePage extends StatefulWidget {
  const ZenHomePage({super.key});

  @override
  State<ZenHomePage> createState() => _ZenHomePageState();
}

class _ZenHomePageState extends State<ZenHomePage> {
  // 0 = New Chat, 1 = Search, 2 = Notes
  int _selectedIndex = 0;

  // notes storage (in-memory for now)
  final List<Note> _notes = List.generate(
    4,
    (i) => Note(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
      title: 'Favourite Color',
      excerpt: "Alice's favourite color is ...",
      updated: DateTime.now().subtract(Duration(minutes: 10 * (i + 1))),
    ),
  );

  // currently selected note shown in the right-side notes panel
  Note? _notesPanelSelectedNote;
  // chats
  final List<Chat> _chats = [];
  String? _selectedChatId;
  // Spotlight overlay search controller
  final TextEditingController _spotlightController = TextEditingController();
  String _spotlightQuery = '';

  @override
  void initState() {
    super.initState();
    _spotlightController.addListener(() {
      setState(() => _spotlightQuery = _spotlightController.text);
    });
  }

  @override
  void dispose() {
    _spotlightController.dispose();
    super.dispose();
  }

  void _onSidebarItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onNoteSelected(Note note) {
    setState(() {
      // show the clicked note inside the right-hand notes panel
      _notesPanelSelectedNote = note;
      // ensure Notes tab is visible
      _selectedIndex = 2;
    });
  }

  void _onCreateNote() {
    setState(() {
      final newNote = Note(id: DateTime.now().millisecondsSinceEpoch.toString(), title: 'New note', excerpt: '', updated: DateTime.now());
      _notes.insert(0, newNote);
      _notesPanelSelectedNote = newNote;
      _selectedIndex = 2;
    });
  }

  void _onCloseNoteInPanel() {
    setState(() => _notesPanelSelectedNote = null);
  }

  void _onCloseNotesPanel() {
    setState(() {
      _notesPanelSelectedNote = null;
      _selectedIndex = 0;
    });
  }

  void _onSaveNote(Note updated) {
    setState(() {
      final idx = _notes.indexWhere((n) => n.id == updated.id);
      if (idx >= 0) {
        _notes[idx] = updated;
      } else {
        // if it wasn't present for some reason, add to top
        _notes.insert(0, updated);
      }
      // keep the panel showing the updated note
      _notesPanelSelectedNote = updated;
    });
  }

  void _onDeleteNote(Note toDelete) {
    setState(() {
      _notes.removeWhere((n) => n.id == toDelete.id);
      if (_notesPanelSelectedNote?.id == toDelete.id) {
        _notesPanelSelectedNote = null;
      }
    });
  }

  void _onCreateChat() {
    setState(() {
      // instead of creating a chat immediately, open the central composer
      // the actual chat will be created when the user sends the first message
      _selectedChatId = null;
      _selectedIndex = 0; // focus workspace which shows the big composer
    });
  }

  void _onSelectChat(String id) {
    setState(() {
      _selectedChatId = id;
      _selectedIndex = 0; // focus workspace which shows chat
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      Chat chat;
      if (_selectedChatId == null) {
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        chat = Chat(id: id, title: text.length > 20 ? text.substring(0, 20) : text);
        _chats.insert(0, chat);
        _selectedChatId = id;
      } else {
        chat = _chats.firstWhere((c) => c.id == _selectedChatId);
      }
      chat.messages.add(ChatMessage(id: DateTime.now().toString(), text: text, fromUser: true));
    });

    // simulate AI reply after a short delay
    Future.delayed(const Duration(milliseconds: 650), () {
      setState(() {
        final chat = _chats.firstWhere((c) => c.id == _selectedChatId);
  chat.messages.add(ChatMessage(id: DateTime.now().toString(), text: 'Simulated reply to: "$text"', fromUser: false));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar on the left
          ZenSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: _onSidebarItemSelected,
            chats: _chats,
            onChatSelected: _onSelectChat,
            onNewChat: _onCreateChat,
          ),

          // Main content area wrapped in a Stack so overlays (Spotlight) can be positioned
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    // Center workspace
                    Expanded(
                      child: ZenWorkspace(
                        selectedIndex: _selectedIndex,
                        chats: _chats,
                        selectedChatId: _selectedChatId,
                        onCreateChat: _onCreateChat,
                        onSendMessage: _sendMessage,
                      ),
                    ),

                    // Notes panel on the right when Notes is selected
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: SizedBox(
                        width: 360,
                        child: Builder(builder: (ctx) {
                          final theme = Theme.of(ctx);
                          return Row(
                            children: [
                              // clear vertical divider between workspace and notes
                              Container(
                                width: 1,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: theme.dividerColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.shadowColor.withAlpha(12),
                                      blurRadius: 4,
                                      offset: const Offset(-1, 0),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ZenNotesPanel(
                                  notes: _notes,
                                  selectedNote: _notesPanelSelectedNote,
                                  onCreate: _onCreateNote,
                                  onNoteSelected: _onNoteSelected,
                                  onSave: _onSaveNote,
                                  onDelete: _onDeleteNote,
                                  onCloseNote: _onCloseNoteInPanel,
                                  onClosePanel: _onCloseNotesPanel,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      crossFadeState: _selectedIndex == 2
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 260),
                    ),
                  ],
                ),

                // Spotlight overlay for Search (centered) — only shows when Search is selected
                if (_selectedIndex == 1)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selectedIndex = 0),
                      child: Container(
                        color: Colors.black.withAlpha(60),
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 120),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Material(
                            borderRadius: BorderRadius.circular(12),
                            elevation: 8,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.search, size: 28),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: _spotlightController,
                                          autofocus: true,
                                          decoration: const InputDecoration.collapsed(hintText: 'Search notes and chats...'),
                                          onSubmitted: (_) {},
                                        ),
                                      ),
                                      if (_spotlightQuery.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () => _spotlightController.clear(),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 360),
                                    child: _buildSpotlightResults(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotlightResults() {
    final q = _spotlightQuery.trim().toLowerCase();

    bool matches(String source, String q) {
      final s = source.toLowerCase();
      if (s.contains(q)) return true;
      // match if any word starts with the query (helps short tokens like 'add')
      final words = s.split(RegExp(r'\s+'));
      for (var w in words) {
        if (w.startsWith(q)) return true;
      }
      // all tokens present (AND)
      final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (tokens.isNotEmpty && tokens.every((t) => s.contains(t))) return true;
      return false;
    }

    final noteMatches = q.isEmpty
        ? _notes.take(6).toList()
        : _notes.where((n) => matches(n.title, q) || matches(n.excerpt, q)).toList();

    final chatMatches = q.isEmpty
        ? _chats.take(6).toList()
        : _chats.where((c) => matches(c.title, q) || c.messages.any((m) => matches(m.text, q))).toList();

    final results = <Widget>[];
    for (var n in noteMatches) {
      results.add(ListTile(
        leading: const Icon(Icons.note),
        title: Text(n.title),
        subtitle: Text(n.excerpt, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () {
          setState(() {
            _notesPanelSelectedNote = n;
            _selectedIndex = 2; // show notes panel
          });
        },
      ));
    }

    for (var c in chatMatches) {
      results.add(ListTile(
        leading: const Icon(Icons.chat_bubble_outline),
  title: Text(c.title),
        subtitle: c.messages.isNotEmpty ? Text(c.messages.last.text, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
        onTap: () {
          setState(() {
            _selectedChatId = c.id;
            _selectedIndex = 0; // focus workspace/chat
          });
        },
      ));
    }

    if (results.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(12.0), child: Text('No results', style: Theme.of(context).textTheme.bodyLarge)));
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) => results[i],
    );
  }
}
