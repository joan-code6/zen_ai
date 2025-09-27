import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../workspace/workspace.dart';
import '../models/chat.dart';
import '../sidebar/sidebar.dart';
import '../sidebar/notes_panel.dart';
import '../state/user_preferences.dart';

class ZenHomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Color seedColor;
  final ValueChanged<Color> onSeedColorChanged;

  const ZenHomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.seedColor,
    required this.onSeedColorChanged,
  });

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
  bool _showUserOverlay = false;

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
      _showUserOverlay = false;
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
      final newNote = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New note',
        excerpt: '',
        updated: DateTime.now(),
      );
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
        chat = Chat(
          id: id,
          title: text.length > 20 ? text.substring(0, 20) : text,
        );
        _chats.insert(0, chat);
        _selectedChatId = id;
      } else {
        chat = _chats.firstWhere((c) => c.id == _selectedChatId);
      }
      chat.messages.add(
        ChatMessage(id: DateTime.now().toString(), text: text, fromUser: true),
      );
    });

    // simulate AI reply after a short delay
    Future.delayed(const Duration(milliseconds: 650), () {
      setState(() {
        final chat = _chats.firstWhere((c) => c.id == _selectedChatId);
        chat.messages.add(
          ChatMessage(
            id: DateTime.now().toString(),
            text: 'Simulated reply to: "$text"',
            fromUser: false,
          ),
        );
      });
    });
  }

  void _openUserOverlay() {
    setState(() => _showUserOverlay = true);
  }

  void _closeUserOverlay() {
    setState(() => _showUserOverlay = false);
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
            onUserPressed: _openUserOverlay,
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOut,
                      width: _selectedIndex == 2 ? 360 : 0,
                      child: _selectedIndex == 2
                          ? SizedBox(
                              width: 360,
                              child: Builder(
                                builder: (ctx) {
                                  final theme = Theme.of(ctx);
                                  return Row(
                                    children: [
                                      // clear vertical divider between workspace and notes
                                      SizedBox(
                                        width: 1,
                                        child: LayoutBuilder(
                                          builder: (ctx, constraints) {
                                            return Container(
                                              height:
                                                  constraints.maxHeight.isFinite
                                                  ? constraints.maxHeight
                                                  : null,
                                              decoration: BoxDecoration(
                                                color: theme.dividerColor,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: theme.shadowColor
                                                        .withAlpha(12),
                                                    blurRadius: 4,
                                                    offset: const Offset(-1, 0),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
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
                                },
                              ),
                            )
                          : const SizedBox.shrink(),
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
                                          decoration:
                                              const InputDecoration.collapsed(
                                                hintText:
                                                    'Search notes and chats...',
                                              ),
                                          onSubmitted: (_) {},
                                        ),
                                      ),
                                      if (_spotlightQuery.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () =>
                                              _spotlightController.clear(),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 360,
                                    ),
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

                if (_showUserOverlay)
                  Positioned.fill(
                    child: _UserAccountOverlay(
                      onClose: _closeUserOverlay,
                      themeMode: widget.themeMode,
                      onThemeModeChanged: widget.onThemeModeChanged,
                      seedColor: widget.seedColor,
                      onSeedColorChanged: widget.onSeedColorChanged,
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
      final tokens = q
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      if (tokens.isNotEmpty && tokens.every((t) => s.contains(t))) return true;
      return false;
    }

    final noteMatches = q.isEmpty
        ? _notes.take(6).toList()
        : _notes
              .where((n) => matches(n.title, q) || matches(n.excerpt, q))
              .toList();

    final chatMatches = q.isEmpty
        ? _chats.take(6).toList()
        : _chats
              .where(
                (c) =>
                    matches(c.title, q) ||
                    c.messages.any((m) => matches(m.text, q)),
              )
              .toList();

    final results = <Widget>[];
    for (var n in noteMatches) {
      results.add(
        ListTile(
          leading: const Icon(Icons.note),
          title: Text(n.title),
          subtitle: Text(
            n.excerpt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            setState(() {
              _notesPanelSelectedNote = n;
              _selectedIndex = 2; // show notes panel
            });
          },
        ),
      );
    }

    for (var c in chatMatches) {
      results.add(
        ListTile(
          leading: const Icon(Icons.chat_bubble_outline),
          title: Text(c.title),
          subtitle: c.messages.isNotEmpty
              ? Text(
                  c.messages.last.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          onTap: () {
            setState(() {
              _selectedChatId = c.id;
              _selectedIndex = 0; // focus workspace/chat
            });
          },
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'No results',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) => results[i],
    );
  }
}

class _UserAccountOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Color seedColor;
  final ValueChanged<Color> onSeedColorChanged;

  const _UserAccountOverlay({
    required this.onClose,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.seedColor,
    required this.onSeedColorChanged,
  });

  @override
  State<_UserAccountOverlay> createState() => _UserAccountOverlayState();
}

class _UserAccountOverlayState extends State<_UserAccountOverlay> {
  late ThemeMode _localThemeMode;
  late Color _accentColor;
  late bool _notificationsEnabled;
  late bool _smartReplySuggestions;
  late bool _autoArchiveChats;

  static const List<_AccentColorOption> _accentColorOptions = [
    _AccentColorOption(Color(0xFFEE5396), 'Pink'),
    _AccentColorOption(Color(0xFF0F62FE), 'Blue'),
    _AccentColorOption(Color(0xFF12A595), 'Teal'),
    _AccentColorOption(Color(0xFF9356D5), 'Purple'),
    _AccentColorOption(Color(0xFFF18F01), 'Amber'),
    _AccentColorOption(Color(0xFF2E8540), 'Green'),
    _AccentColorOption(Color(0xFF6F6CF0), 'Lavender'),
  ];

  @override
  void initState() {
    super.initState();
    _localThemeMode = widget.themeMode;
    _accentColor = widget.seedColor;
    _notificationsEnabled = UserPreferences.notificationsEnabled;
    _smartReplySuggestions = UserPreferences.smartReplySuggestions;
    _autoArchiveChats = UserPreferences.autoArchiveChats;
  }

  @override
  void didUpdateWidget(covariant _UserAccountOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeMode != widget.themeMode) {
      _localThemeMode = widget.themeMode;
    }
    if (oldWidget.seedColor != widget.seedColor) {
      _accentColor = widget.seedColor;
    }
  }

  void _onAccentColorSelected(Color color) {
    if (_accentColor == color) return;
    setState(() {
      _accentColor = color;
    });
    widget.onSeedColorChanged(color);
  }

  Future<void> _openCustomColorPicker() async {
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (dialogContext) {
        Color tempColor = _accentColor;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Eigene Akzentfarbe'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ColorPicker(
                      pickerColor: tempColor,
                      onColorChanged: (color) =>
                          setStateDialog(() => tempColor = color),
                      enableAlpha: false,
                      paletteType: PaletteType.hsvWithHue,
                      labelTypes: const [],
                      displayThumbColor: true,
                      pickerAreaHeightPercent: 0.72,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: tempColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12, width: 1),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(tempColor),
                  child: const Text('Übernehmen'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedColor != null) {
      _onAccentColorSelected(selectedColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            opacity: 1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: Container(color: Colors.black.withOpacity(0.45)),
            ),
          ),
        ),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
              child: Material(
                color: colorScheme.surface,
                elevation: 24,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        color: colorScheme.surfaceVariant.withOpacity(0.35),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Account center',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manage personal details, preferences, and session history.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: widget.onClose,
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      TabBar(
                        labelColor: colorScheme.primary,
                        indicatorColor: colorScheme.primary,
                        indicatorWeight: 2.5,
                        tabs: const [
                          Tab(text: 'Profile'),
                          Tab(text: 'Preferences'),
                          Tab(text: 'Activity'),
                        ],
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: TabBarView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildProfileTab(context),
                            _buildPreferencesTab(context),
                            _buildActivityTab(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                child: Text(
                  'B',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bennet Bauer',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lead Product Designer',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Member since March 2024',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.mail_outline),
                  title: Text('Email'),
                  subtitle: Text('bennet@example.com'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.workspace_premium_outlined),
                  title: Text('Workspace role'),
                  subtitle: Text('Administrator'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.schedule_outlined),
                  title: Text('Time zone'),
                  subtitle: Text('Europe/Berlin (CEST)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Security',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Password'),
                  subtitle: const Text('Last changed 2 months ago'),
                  trailing: TextButton(
                    onPressed: () {},
                    child: const Text('Update'),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: true,
                  onChanged: (_) {},
                  title: const Text('Two-factor authentication'),
                  subtitle: const Text(
                    'Secure your account with an extra step.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.logout),
            label: const Text('Sign out of all devices'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: Icon(Icons.auto_mode_outlined),
                label: Text('System'),
              ),
            ],
            selected: {_localThemeMode},
            onSelectionChanged: (modes) {
              final selected = modes.first;
              setState(() => _localThemeMode = selected);
              widget.onThemeModeChanged(selected);
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Accent color',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final option in _accentColorOptions)
                _AccentColorSwatch(
                  option: option,
                  selected: option.color == _accentColor,
                  onTap: () => _onAccentColorSelected(option.color),
                ),
              _CustomColorButton(
                selected: !_accentColorOptions
                    .any((option) => option.color == _accentColor),
                currentColor: _accentColor,
                onTap: _openCustomColorPicker,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Assistant',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _notificationsEnabled,
                  title: const Text('Desktop notifications'),
                  subtitle: const Text(
                    'Get a ping when Zen finishes a response.',
                  ),
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    UserPreferences.setNotificationsEnabled(value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _smartReplySuggestions,
                  title: const Text('Smart reply suggestions'),
                  subtitle: const Text(
                    'Surface quick follow-up ideas in the composer.',
                  ),
                  onChanged: (value) {
                    setState(() => _smartReplySuggestions = value);
                    UserPreferences.setSmartReplySuggestions(value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _autoArchiveChats,
                  title: const Text('Auto-archive inactive chats'),
                  subtitle: const Text(
                    'Keep the sidebar tidy after 14 days of inactivity.',
                  ),
                  onChanged: (value) {
                    setState(() => _autoArchiveChats = value);
                    UserPreferences.setAutoArchiveChats(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Workspace',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Language'),
                  subtitle: const Text('German (Deutsch)'),
                  trailing: TextButton(
                    onPressed: () {},
                    child: const Text('Change'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.public_off),
                  title: const Text('Data residency'),
                  subtitle: const Text('EU-restricted'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab(BuildContext context) {
    final theme = Theme.of(context);
    final activity = [
      (
        'Today · 09:42',
        'Signed in from Zen Desktop (Windows) using password + 2FA.',
      ),
      (
        'Yesterday · 18:05',
        'Exported chat history for “Brand strategy kickoff”.',
      ),
      ('Sep 24 · 11:17', 'Created workspace note “Competitive insights Q3”.'),
      ('Sep 21 · 07:54', 'Updated profile details.'),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: activity.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == activity.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download activity log'),
            ),
          );
        }

        final entry = activity[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
            child: Icon(
              Icons.timeline_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          title: Text(entry.$1),
          subtitle: Text(entry.$2),
        );
      },
    );
  }
}

class _AccentColorOption {
  final Color color;
  final String label;

  const _AccentColorOption(this.color, this.label);
}

class _AccentColorSwatch extends StatelessWidget {
  final _AccentColorOption option;
  final bool selected;
  final VoidCallback onTap;

  const _AccentColorSwatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant.withOpacity(0.6);
    final brightness = ThemeData.estimateBrightnessForColor(option.color);
    final iconColor = brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Tooltip(
      message: option.label,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: option.color,
            border: Border.all(color: borderColor, width: selected ? 3 : 1.5),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Icon(Icons.check, size: 22, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _CustomColorButton extends StatelessWidget {
  final bool selected;
  final Color currentColor;
  final VoidCallback onTap;

  const _CustomColorButton({
    required this.selected,
    required this.currentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant.withOpacity(0.6);

    return Tooltip(
      message: 'Eigene Farbe',
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFFFF5F6D),
                Color(0xFFFFC371),
                Color(0xFF47CF73),
                Color(0xFF17BEBB),
                Color(0xFF4A00E0),
                Color(0xFFFF5F6D),
              ],
            ),
            border: Border.all(
              color: borderColor,
              width: selected ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (selected)
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentColor,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              Icon(
                selected ? Icons.check : Icons.add,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
