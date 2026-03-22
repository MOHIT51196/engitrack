import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.note});

  final NoteItem note;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late NoteItem _workingNote;
  bool _saving = false;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _workingNote = widget.note;
    _titleController = TextEditingController(text: widget.note.title);
    _bodyController = TextEditingController(text: widget.note.body);
    _wordCount = _countWords(widget.note.body);
    _bodyController.addListener(_onBodyChanged);
  }

  void _onBodyChanged() {
    final int count = _countWords(_bodyController.text);
    if (count != _wordCount) {
      setState(() => _wordCount = count);
    }
  }

  int _countWords(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  void dispose() {
    _bodyController.removeListener(_onBodyChanged);
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final EngiTrackController controller = EngiTrackScope.of(context);
    setState(() => _saving = true);

    final DateTime now = DateTime.now();
    _workingNote = _workingNote.copyWith(
      title: _titleController.text.trim().isEmpty
          ? 'Untitled note'
          : _titleController.text.trim(),
      body: _bodyController.text,
      updatedAt: now,
    );
    await controller.upsertNote(_workingNote);

    if (mounted) setState(() => _saving = false);
  }

  Future<bool> _handleBackNavigation() async {
    await _save();
    return true;
  }

  Future<void> _deleteNote() async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Delete note?'),
          content: const Text('This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await controller.deleteNote(_workingNote.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _handleBackNavigation,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Note'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            onPressed: () async {
              await _save();
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
          ),
          actions: <Widget>[
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Delete',
              onPressed: _deleteNote,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              style: IconButton.styleFrom(
                  foregroundColor: AppColors.danger.withOpacity(0.7)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          await _save();
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        },
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
          child: AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.schedule_rounded,
                        size: 12, color: AppColors.tertiaryInk),
                    const SizedBox(width: 4),
                    Text(
                      formatTimestamp(_workingNote.createdAt),
                      style:
                          theme.textTheme.labelMedium?.copyWith(fontSize: 10),
                    ),
                    const Spacer(),
                    Text(
                      '$_wordCount words',
                      style:
                          theme.textTheme.labelMedium?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _titleController,
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20),
                  decoration: const InputDecoration(
                    hintText: 'Untitled note',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                Container(height: 0.5, color: AppColors.divider),
                const SizedBox(height: 10),
                Expanded(
                  child: TextField(
                    controller: _bodyController,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                    decoration: const InputDecoration(
                      hintText: 'Start writing...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
