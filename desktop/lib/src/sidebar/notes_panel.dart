import 'package:flutter/material.dart';

class ZenNotesPanel extends StatefulWidget {
  final List<Note> notes;
  final Note? selectedNote;
  final VoidCallback? onCreate;
  final ValueChanged<Note>? onNoteSelected;
  final ValueChanged<Note>? onSave; // save/update note
  final ValueChanged<Note>? onDelete;
  final VoidCallback? onCloseNote;
  final VoidCallback? onClosePanel;

  const ZenNotesPanel({super.key, required this.notes, this.selectedNote, this.onCreate, this.onNoteSelected, this.onSave, this.onDelete, this.onCloseNote, this.onClosePanel});

  @override
  State<ZenNotesPanel> createState() => _ZenNotesPanelState();
}

class _ZenNotesPanelState extends State<ZenNotesPanel> {
  // notes are now provided by the parent

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  bool _editing = false;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _excerptCtrl = TextEditingController();
  final TextEditingController _keywordCtrl = TextEditingController();
  final TextEditingController _triggerCtrl = TextEditingController();
  List<String> _keywords = [];
  List<String> _triggers = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _titleCtrl.dispose();
    _excerptCtrl.dispose();
    _keywordCtrl.dispose();
    _triggerCtrl.dispose();
    super.dispose();
  }

  List<Note> get _filteredNotes {
    final source = widget.notes;
    if (_query.trim().isEmpty) return source;
    final q = _query.toLowerCase();
    return source.where((n) {
      return n.title.toLowerCase().contains(q) || n.excerpt.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your notes',
                  style: theme.textTheme.titleLarge,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: widget.onCreate ?? _createNote,
                      child: const Text('Create new note'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Close notes',
                      onPressed: widget.onClosePanel,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // cleaner search box: filled TextField with rounded border and subtle shadow
            Material(
              elevation: 2,
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search through all notes',
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    prefixIcon: const Icon(Icons.search),
                    prefixIconColor: theme.colorScheme.onSurface,
                    prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.selectedNote != null
                  ? _buildNoteDetail(widget.selectedNote!, theme)
                  : _filteredNotes.isEmpty
                      ? Center(
                          child: Text(
                            'No notes match your search',
                            style: theme.textTheme.bodyLarge,
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          itemCount: _filteredNotes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final n = _filteredNotes[index];
                            return AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: 1,
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    // notify parent which note was selected
                                    widget.onNoteSelected?.call(n);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.note_alt, size: 28, color: Colors.indigo),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(n.title, style: theme.textTheme.titleMedium),
                                              const SizedBox(height: 6),
                                              Text(
                                                n.excerpt.isEmpty ? 'No content yet' : n.excerpt,
                                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(_formatTime(n.updated), style: theme.textTheme.bodySmall),
                                            const SizedBox(height: 8),
                                            PopupMenuButton<String>(
                                                                      itemBuilder: (ctx) => [
                                                                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                                                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                                                      ],
                                                                      onSelected: (v) {
                                                                        if (v == 'edit') {
                                                                          // enter edit mode for this note
                                                                          setState(() {
                                                                            _editing = true;
                                                                            _titleCtrl.text = n.title;
                                                                            _excerptCtrl.text = n.excerpt;
                                                                            _keywords = List.from(n.keywords);
                                                                            _triggers = List.from(n.triggerwords);
                                                                            widget.onNoteSelected?.call(n);
                                                                          });
                                                                        } else if (v == 'delete') {
                                                                          widget.onDelete?.call(n);
                                                                        }
                                                                      },
                                                                      child: const Icon(Icons.more_vert),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteDetail(Note n, ThemeData theme) {
    if (_editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: TextField(controller: _titleCtrl, style: theme.textTheme.headlineSmall)),
              IconButton(onPressed: () {
                setState(() => _editing = false);
                widget.onCloseNote?.call();
              }, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_formatTime(n.updated), style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(controller: _excerptCtrl, maxLines: 6, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Write note content...')),
          const SizedBox(height: 12),
          Text('Keywords', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (var k in _keywords)
                Chip(label: Text(k), onDeleted: () => setState(() => _keywords.remove(k))),
              ActionChip(label: const Text('Add'), onPressed: () {
                // focus keyword input
                showDialog(context: context, builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Add keyword'),
                    content: TextField(controller: _keywordCtrl, decoration: const InputDecoration(hintText: 'keyword')),
                    actions: [
                      TextButton(onPressed: () { Navigator.of(ctx).pop(); _keywordCtrl.clear(); }, child: const Text('Cancel')),
                      TextButton(onPressed: () { if (_keywordCtrl.text.trim().isNotEmpty) setState(() => _keywords.add(_keywordCtrl.text.trim())); _keywordCtrl.clear(); Navigator.of(ctx).pop(); }, child: const Text('Add')),
                    ],
                  );
                });
              }),
            ],
          ),
          const SizedBox(height: 12),
          Text('Trigger words', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (var t in _triggers)
                Chip(label: Text(t), onDeleted: () => setState(() => _triggers.remove(t))),
              ActionChip(label: const Text('Add'), onPressed: () {
                showDialog(context: context, builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Add trigger word'),
                    content: TextField(controller: _triggerCtrl, decoration: const InputDecoration(hintText: 'trigger word')),
                    actions: [
                      TextButton(onPressed: () { Navigator.of(ctx).pop(); _triggerCtrl.clear(); }, child: const Text('Cancel')),
                      TextButton(onPressed: () { if (_triggerCtrl.text.trim().isNotEmpty) setState(() => _triggers.add(_triggerCtrl.text.trim())); _triggerCtrl.clear(); Navigator.of(ctx).pop(); }, child: const Text('Add')),
                    ],
                  );
                });
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(onPressed: () {
                // save changes
                final updated = Note(id: n.id, title: _titleCtrl.text.trim(), excerpt: _excerptCtrl.text.trim(), updated: DateTime.now(), keywords: List.from(_keywords), triggerwords: List.from(_triggers));
                widget.onSave?.call(updated);
                setState(() => _editing = false);
              }, child: const Text('Save')),
              const SizedBox(width: 12),
              TextButton(onPressed: () { setState(() => _editing = false); }, child: const Text('Cancel')),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(n.title, style: theme.textTheme.headlineSmall),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit note',
                  onPressed: () {
                    setState(() {
                      _editing = true;
                      _titleCtrl.text = n.title;
                      _excerptCtrl.text = n.excerpt;
                      _keywords = List.from(n.keywords);
                      _triggers = List.from(n.triggerwords);
                      widget.onNoteSelected?.call(n);
                    });
                  },
                  icon: const Icon(Icons.edit),
                ),
                IconButton(onPressed: widget.onCloseNote, icon: const Icon(Icons.close)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(_formatTime(n.updated), style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Expanded(child: SingleChildScrollView(child: Text(n.excerpt.isEmpty ? 'No content yet.' : n.excerpt, style: theme.textTheme.bodyLarge))),
        const SizedBox(height: 12),
        if (n.keywords.isNotEmpty) ...[
          Text('Keywords', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: n.keywords.map((k) => Chip(label: Text(k))).toList()),
        ],
        if (n.triggerwords.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Trigger words', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: n.triggerwords.map((t) => Chip(label: Text(t))).toList()),
        ],
      ],
    );
  }

  void _createNote() {
    // if parent handles create, that will be used; otherwise, do nothing
    widget.onCreate?.call();
    // Clear search and scroll to top for a smoother UX
    _searchController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min. ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}

class Note {
  final String id;
  String title;
  String excerpt;
  DateTime updated;
  List<String> keywords;
  List<String> triggerwords;

  Note({required this.id, required this.title, required this.excerpt, required this.updated, List<String>? keywords, List<String>? triggerwords})
      : keywords = keywords ?? [],
        triggerwords = triggerwords ?? [];
}
