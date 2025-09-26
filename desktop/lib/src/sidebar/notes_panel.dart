import 'package:flutter/material.dart';

class ZenNotesPanel extends StatefulWidget {
  const ZenNotesPanel({super.key});

  @override
  State<ZenNotesPanel> createState() => _ZenNotesPanelState();
}

class _ZenNotesPanelState extends State<ZenNotesPanel> {
  final List<_Note> _notes = List.generate(
    4,
    (i) => _Note(
      title: 'Favourite Color',
      excerpt: "{name}'s favourite color is ...",
      // simple timestamps
      updated: DateTime.now().subtract(Duration(minutes: 10 * (i + 1))),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
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
                  'Youre notes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ElevatedButton(
                  onPressed: _createNote,
                  child: const Text('Create new note'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search throught all notes',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _notes.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final n = _notes[index];
                  return ListTile(
                    title: Text(n.title),
                    subtitle: Text(n.excerpt),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Last updated: ${_formatTime(n.updated)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () {},
                          child: const Text('more'),
                        ),
                      ],
                    ),
                    onTap: () {},
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createNote() {
    setState(() {
      _notes.insert(
          0,
          _Note(
            title: 'New note',
            excerpt: '',
            updated: DateTime.now(),
          ));
    });
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min. ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}

class _Note {
  final String title;
  final String excerpt;
  final DateTime updated;

  _Note({required this.title, required this.excerpt, required this.updated});
}
