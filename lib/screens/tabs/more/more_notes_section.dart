// @file       more_notes_section.dart
// @brief      Notes sub-tab — list, add, edit and delete notes.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';

import '../../../models/app_note.dart';
import '../../../services/firebase_repo.dart';
import '../../../utils/date_utils.dart';

/* Public classes ----------------------------------------------------- */
class MoreNotesSection extends StatelessWidget {
  const MoreNotesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openNoteEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Note'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AppNote>>(
            stream: FirebaseRepo.instance.watchNotes(),
            builder: (context, snapshot) {
              final notes = snapshot.data ?? const <AppNote>[];
              if (notes.isEmpty) {
                return const Center(
                  child: Text(
                    'No notes available. Press "Add Note" to create one.',
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return _NoteCard(
                    note: note,
                    onEdit: () => _openNoteEditor(context, note: note),
                    onDelete: () => _deleteNote(context, note),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openNoteEditor(
    BuildContext context, {
    AppNote? note,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final contentCtrl = TextEditingController(text: note?.content ?? '');

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sticky_note_2_outlined),
                    const SizedBox(width: 8),
                    Text(
                      note == null ? 'New Note' : 'Edit Note',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.blueGrey.shade100),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 8,
                          color: Color(0x11000000),
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: contentCtrl,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: 'Enter note content here...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Note'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != true) {
      titleCtrl.dispose();
      contentCtrl.dispose();
      return;
    }

    final title = titleCtrl.text.trim();
    final content = contentCtrl.text.trim();
    titleCtrl.dispose();
    contentCtrl.dispose();

    if (content.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Note content cannot be empty.')),
      );
      return;
    }

    if (note == null) {
      await FirebaseRepo.instance.createNote(title: title, content: content);
    } else {
      await FirebaseRepo.instance.updateNote(
        noteId: note.id,
        title: title,
        content: content,
      );
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          note == null ? 'Note added successfully.' : 'Note updated successfully.',
        ),
      ),
    );
  }

  Future<void> _deleteNote(BuildContext context, AppNote note) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Note'),
            content: Text(
              'Are you sure you want to delete the note "${note.title.isEmpty ? 'Untitled' : note.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    await FirebaseRepo.instance.deleteNote(note.id);

    messenger.showSnackBar(
      const SnackBar(content: Text('Note deleted successfully.')),
    );
  }
}

/* Private classes ---------------------------------------------------- */
class _NoteCard extends StatelessWidget {
  final AppNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = note.title.trim().isEmpty ? 'No title' : note.title;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Updated: ${AppDateUtils.formatShortDateTime(note.updatedAt)}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.blueGrey.shade100),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(note.content),
            ),
          ],
        ),
      ),
    );
  }

}

/* End of file -------------------------------------------------------- */
