import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  String _searchQuery = '';
  bool _showCompleted = true;

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final ThemeData theme = Theme.of(context);
    final List<TodoItem> allTodos = controller.sortedTodos;

    final List<TodoItem> filtered = _searchQuery.isEmpty
        ? allTodos
        : allTodos
            .where((TodoItem t) =>
                t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                t.subtitle.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    final List<TodoItem> activeTodos =
        filtered.where((TodoItem t) => !t.completed).toList();
    final List<TodoItem> completedTodos =
        filtered.where((TodoItem t) => t.completed).toList();
    final int totalCount = allTodos.length;
    final int doneCount = allTodos.where((TodoItem t) => t.completed).length;

    return Column(
      children: <Widget>[
        _Header(
          theme: theme,
          totalCount: totalCount,
          doneCount: doneCount,
          onCreateTodo: () => _showCreateTodoSheet(context, controller),
        ),
        if (totalCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
            child: SizedBox(
              height: 38,
              child: TextField(
                onChanged: (String v) => setState(() => _searchQuery = v),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search todos...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 8),
                    child: Icon(Icons.search_rounded,
                        size: 18, color: AppColors.tertiaryInk),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.outline.withValues(alpha: 0.5),
                        width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.outline.withValues(alpha: 0.5),
                        width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.accent, width: 1),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
            ),
          ),
        Expanded(
          child: allTodos.isEmpty
              ? const EmptyStateCard(
                  title: 'No todos yet',
                  message:
                      'Tap + to create your first todo and start tracking tasks.',
                  icon: Icons.checklist_rounded,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                  children: <Widget>[
                    ...activeTodos.map((TodoItem todo) => _TodoRow(
                          key: ValueKey<String>(todo.id),
                          todo: todo,
                          onTap: () =>
                              _showTodoDetail(context, controller, todo),
                        )),
                    if (completedTodos.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      _CompletedSection(
                        expanded: _showCompleted,
                        count: completedTodos.length,
                        onToggle: () =>
                            setState(() => _showCompleted = !_showCompleted),
                      ),
                      if (_showCompleted)
                        ...completedTodos.map((TodoItem todo) => _TodoRow(
                              key: ValueKey<String>(todo.id),
                              todo: todo,
                              onTap: () =>
                                  _showTodoDetail(context, controller, todo),
                            )),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showCreateTodoSheet(
      BuildContext context, EngiTrackController controller) async {
    final bool? created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _CreateTodoSheet(controller: controller),
    );

    if (created == true && context.mounted) {
      showInfoSnackBar(context, 'ToDo created.');
    }
  }

  Future<void> _showTodoDetail(
    BuildContext context,
    EngiTrackController controller,
    TodoItem todo,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _TodoDetailSheet(todo: todo),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.theme,
    required this.totalCount,
    required this.doneCount,
    required this.onCreateTodo,
  });

  final ThemeData theme;
  final int totalCount;
  final int doneCount;
  final VoidCallback onCreateTodo;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Text('ToDos', style: theme.textTheme.titleLarge),
                    if (totalCount > 0) ...<Widget>[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: doneCount == totalCount
                              ? AppColors.successLight
                              : AppColors.softSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$doneCount / $totalCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: doneCount == totalCount
                                ? AppColors.success
                                : AppColors.tertiaryInk,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: onCreateTodo,
                  icon: const Icon(Icons.add_rounded,
                      size: 20, color: Colors.white),
                  padding: EdgeInsets.zero,
                  tooltip: 'New ToDo',
                ),
              ),
            ],
          ),
          if (totalCount > 0) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: totalCount > 0 ? doneCount / totalCount : 0,
                minHeight: 3,
                backgroundColor: AppColors.divider,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({super.key, required this.todo, required this.onTap});

  final TodoItem todo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final ThemeData theme = Theme.of(context);
    final bool done = todo.completed;

    return Dismissible(
      key: ValueKey<String>('dismiss-${todo.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 20),
      ),
      onDismissed: (_) => controller.deleteTodo(todo.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.outline.withValues(alpha: 0.4),
                    width: 0.5),
              ),
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () => controller.toggleTodo(todo, !done),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? AppColors.success : Colors.transparent,
                        border: Border.all(
                          color: done ? AppColors.success : AppColors.outline,
                          width: 1.5,
                        ),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          todo.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            color: done ? AppColors.tertiaryInk : AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (todo.subtitle.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            todo.subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: done
                                  ? AppColors.tertiaryInk
                                  : AppColors.secondaryInk,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            SoftTag(
                              label: todo.sourceLabel,
                              backgroundColor: _sourceColor(todo.sourceLabel)
                                  .withValues(alpha: 0.08),
                              foregroundColor: _sourceColor(todo.sourceLabel),
                              dense: true,
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.schedule_rounded,
                                size: 10, color: AppColors.tertiaryInk),
                            const SizedBox(width: 3),
                            Text(
                              formatRelativeTime(todo.createdAt),
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(fontSize: 10),
                            ),
                            if (todo.reminderDate != null) ...<Widget>[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentSuperLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(
                                        Icons.notifications_active_rounded,
                                        size: 10,
                                        color: AppColors.accent),
                                    const SizedBox(width: 3),
                                    Text(
                                      DateFormat('MMM d, h:mm a')
                                          .format(todo.reminderDate!),
                                      style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accent),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (todo.reminderRepeat != 'none') ...<Widget>[
                              const SizedBox(width: 4),
                              const Icon(Icons.repeat_rounded,
                                  size: 10, color: AppColors.secondaryInk),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (todo.sourceUrl.trim().isNotEmpty)
                    IconButton(
                      onPressed: () => openExternalUrl(context, todo.sourceUrl),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.tertiaryInk,
                        minimumSize: const Size(28, 28),
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: 'Open source',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _sourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'github pr':
        return AppColors.github;
      case 'jira':
        return AppColors.jira;
      case 'slack review':
      case 'slack alert':
        return AppColors.slack;
      default:
        return AppColors.accent;
    }
  }
}

class _CompletedSection extends StatelessWidget {
  const _CompletedSection({
    required this.expanded,
    required this.count,
    required this.onToggle,
  });

  final bool expanded;
  final int count;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: <Widget>[
              AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.tertiaryInk),
              ),
              const SizedBox(width: 4),
              Text(
                'Completed ($count)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tertiaryInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create ToDo Sheet
// ---------------------------------------------------------------------------

class _CreateTodoSheet extends StatefulWidget {
  const _CreateTodoSheet({required this.controller});
  final EngiTrackController controller;

  @override
  State<_CreateTodoSheet> createState() => _CreateTodoSheetState();
}

class _CreateTodoSheetState extends State<_CreateTodoSheet> {
  final TextEditingController _titleCtl = TextEditingController();
  final TextEditingController _subtitleCtl = TextEditingController();
  DateTime? _reminderDate;
  String _reminderRepeat = 'none';
  bool _titleEmpty = true;

  @override
  void initState() {
    super.initState();
    _titleCtl.addListener(() {
      final bool empty = _titleCtl.text.trim().isEmpty;
      if (empty != _titleEmpty) setState(() => _titleEmpty = empty);
    });
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _subtitleCtl.dispose();
    super.dispose();
  }

  Future<void> _pickReminder() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _reminderDate != null
          ? TimeOfDay.fromDateTime(_reminderDate!)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;

    setState(() {
      _reminderDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _create() async {
    if (_titleCtl.text.trim().isEmpty) return;
    await widget.controller.addToTodo(
      title: _titleCtl.text,
      subtitle: _subtitleCtl.text,
      sourceLabel: 'Manual',
    );
    if (_reminderDate != null || _reminderRepeat != 'none') {
      final List<TodoItem> todos = widget.controller.sortedTodos;
      if (todos.isNotEmpty) {
        widget.controller.updateTodo(todos.first.copyWith(
          reminderDate: _reminderDate,
          reminderRepeat: _reminderRepeat,
        ));
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // Title row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accentSuperLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_task_rounded,
                          size: 18, color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Text('New ToDo',
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Input fields
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.softSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider, width: 0.5),
                  ),
                  child: Column(
                    children: <Widget>[
                      TextField(
                        controller: _titleCtl,
                        autofocus: true,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'What needs to be done?',
                          hintStyle: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: AppColors.tertiaryInk),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                          fillColor: Colors.transparent,
                          filled: false,
                        ),
                      ),
                      const Divider(
                          height: 0.5,
                          indent: 16,
                          endIndent: 16,
                          color: AppColors.divider),
                      TextField(
                        controller: _subtitleCtl,
                        maxLines: 3,
                        minLines: 1,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.secondaryInk),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Add details (optional)',
                          hintStyle: TextStyle(color: AppColors.tertiaryInk),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.fromLTRB(16, 10, 16, 14),
                          fillColor: Colors.transparent,
                          filled: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reminder & Repeat options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.softSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider, width: 0.5),
                  ),
                  child: Column(
                    children: <Widget>[
                      _OptionTile(
                        icon: _reminderDate != null
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        iconColor: _reminderDate != null
                            ? AppColors.accent
                            : AppColors.secondaryInk,
                        label: 'Remind me',
                        value: _reminderDate != null
                            ? DateFormat('EEE, MMM d \u2022 h:mm a')
                                .format(_reminderDate!)
                            : 'No reminder set',
                        valueHighlight: _reminderDate != null,
                        onTap: _pickReminder,
                        trailing: _reminderDate != null
                            ? GestureDetector(
                                onTap: () =>
                                    setState(() => _reminderDate = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.divider, width: 0.5),
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      size: 12, color: AppColors.tertiaryInk),
                                ),
                              )
                            : null,
                      ),
                      const Divider(
                          height: 0.5,
                          indent: 48,
                          endIndent: 16,
                          color: AppColors.divider),
                      _OptionTile(
                        icon: Icons.repeat_rounded,
                        iconColor: _reminderRepeat != 'none'
                            ? AppColors.accent
                            : AppColors.secondaryInk,
                        label: 'Repeat',
                        value: _reminderRepeat == 'none'
                            ? 'Never'
                            : _reminderRepeat[0].toUpperCase() +
                                _reminderRepeat.substring(1),
                        valueHighlight: _reminderRepeat != 'none',
                        onTap: () => _showRepeatPicker(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Create button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _titleEmpty ? null : _create,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Create ToDo'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showRepeatPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Repeat',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                ...<String>['none', 'daily', 'weekly', 'monthly']
                    .map((String value) {
                  final bool selected = _reminderRepeat == value;
                  final String label = value == 'none'
                      ? 'Never'
                      : value[0].toUpperCase() + value.substring(1);
                  return ListTile(
                    dense: true,
                    title: Text(label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? AppColors.accent : AppColors.ink,
                        )),
                    trailing: selected
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: AppColors.accent)
                        : null,
                    onTap: () {
                      setState(() => _reminderRepeat = value);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Edit / Detail ToDo Sheet
// ---------------------------------------------------------------------------

class _TodoDetailSheet extends StatefulWidget {
  const _TodoDetailSheet({required this.todo});
  final TodoItem todo;

  @override
  State<_TodoDetailSheet> createState() => _TodoDetailSheetState();
}

class _TodoDetailSheetState extends State<_TodoDetailSheet> {
  late final TextEditingController _titleCtl;
  late final TextEditingController _subtitleCtl;
  late DateTime? _reminderDate;
  late String _reminderRepeat;

  @override
  void initState() {
    super.initState();
    _titleCtl = TextEditingController(text: widget.todo.title);
    _subtitleCtl = TextEditingController(text: widget.todo.subtitle);
    _reminderDate = widget.todo.reminderDate;
    _reminderRepeat = widget.todo.reminderRepeat;
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _subtitleCtl.dispose();
    super.dispose();
  }

  void _save() {
    final EngiTrackController controller = EngiTrackScope.of(context);
    controller.updateTodo(widget.todo.copyWith(
      title: _titleCtl.text.trim(),
      subtitle: _subtitleCtl.text.trim(),
      reminderDate: _reminderDate,
      reminderRepeat: _reminderRepeat,
    ));
  }

  Future<void> _pickReminder() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _reminderDate != null
          ? TimeOfDay.fromDateTime(_reminderDate!)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;

    setState(() {
      _reminderDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final ThemeData theme = Theme.of(context);
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (_titleCtl.text.trim() != widget.todo.title ||
            _subtitleCtl.text.trim() != widget.todo.subtitle) {
          _save();
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Handle
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),

                // Header row with status pill and delete
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: <Widget>[
                      GestureDetector(
                        onTap: () {
                          controller.toggleTodo(
                              widget.todo, !widget.todo.completed);
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: widget.todo.completed
                                ? AppColors.successLight
                                : AppColors.accentSuperLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.todo.completed
                                  ? AppColors.success.withValues(alpha: 0.3)
                                  : AppColors.accent.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                widget.todo.completed
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 14,
                                color: widget.todo.completed
                                    ? AppColors.success
                                    : AppColors.accent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.todo.completed ? 'Completed' : 'Active',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: widget.todo.completed
                                      ? AppColors.success
                                      : AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SoftTag(
                        label: widget.todo.sourceLabel,
                        backgroundColor: _sourceColor(widget.todo.sourceLabel)
                            .withValues(alpha: 0.08),
                        foregroundColor: _sourceColor(widget.todo.sourceLabel),
                        dense: true,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          controller.deleteTodo(widget.todo.id);
                          Navigator.of(context).pop();
                          showInfoSnackBar(context, 'ToDo deleted.');
                        },
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 20),
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          backgroundColor: AppColors.dangerLight,
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Editable fields card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.softSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: Column(
                      children: <Widget>[
                        TextField(
                          controller: _titleCtl,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Title',
                            hintStyle: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: AppColors.tertiaryInk),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                            fillColor: Colors.transparent,
                            filled: false,
                          ),
                          onChanged: (_) => _save(),
                        ),
                        const Divider(
                            height: 0.5,
                            indent: 16,
                            endIndent: 16,
                            color: AppColors.divider),
                        TextField(
                          controller: _subtitleCtl,
                          maxLines: 4,
                          minLines: 2,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.secondaryInk),
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Details...',
                            hintStyle: TextStyle(color: AppColors.tertiaryInk),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.fromLTRB(16, 10, 16, 14),
                            fillColor: Colors.transparent,
                            filled: false,
                          ),
                          onChanged: (_) => _save(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Reminder & Repeat options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.softSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: Column(
                      children: <Widget>[
                        _OptionTile(
                          icon: _reminderDate != null
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          iconColor: _reminderDate != null
                              ? AppColors.accent
                              : AppColors.secondaryInk,
                          label: 'Remind me',
                          value: _reminderDate != null
                              ? DateFormat('EEE, MMM d \u2022 h:mm a')
                                  .format(_reminderDate!)
                              : 'No reminder set',
                          valueHighlight: _reminderDate != null,
                          onTap: _pickReminder,
                          trailing: _reminderDate != null
                              ? GestureDetector(
                                  onTap: () {
                                    setState(() => _reminderDate = null);
                                    _save();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppColors.divider, width: 0.5),
                                    ),
                                    child: const Icon(Icons.close_rounded,
                                        size: 12, color: AppColors.tertiaryInk),
                                  ),
                                )
                              : null,
                        ),
                        const Divider(
                            height: 0.5,
                            indent: 48,
                            endIndent: 16,
                            color: AppColors.divider),
                        _OptionTile(
                          icon: Icons.repeat_rounded,
                          iconColor: _reminderRepeat != 'none'
                              ? AppColors.accent
                              : AppColors.secondaryInk,
                          label: 'Repeat',
                          value: _reminderRepeat == 'none'
                              ? 'Never'
                              : _reminderRepeat[0].toUpperCase() +
                                  _reminderRepeat.substring(1),
                          valueHighlight: _reminderRepeat != 'none',
                          onTap: () => _showRepeatPicker(context),
                        ),
                      ],
                    ),
                  ),
                ),

                // Source link
                if (widget.todo.sourceUrl.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: InkWell(
                      onTap: () =>
                          openExternalUrl(context, widget.todo.sourceUrl),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.softSurface,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: AppColors.divider, width: 0.5),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.accentSuperLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.link_rounded,
                                  size: 16, color: AppColors.accent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text('Source',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink)),
                                  const SizedBox(height: 1),
                                  Text(
                                    widget.todo.sourceUrl,
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.accent),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.open_in_new_rounded,
                                size: 14, color: AppColors.accent),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                // Created timestamp
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.schedule_rounded,
                          size: 12, color: AppColors.tertiaryInk),
                      const SizedBox(width: 5),
                      Text(
                        'Created ${DateFormat('EEE, MMM d, y \u2022 h:mm a').format(widget.todo.createdAt)}',
                        style:
                            theme.textTheme.labelMedium?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRepeatPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Repeat',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                ...<String>['none', 'daily', 'weekly', 'monthly']
                    .map((String value) {
                  final bool selected = _reminderRepeat == value;
                  final String label = value == 'none'
                      ? 'Never'
                      : value[0].toUpperCase() + value.substring(1);
                  return ListTile(
                    dense: true,
                    title: Text(label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? AppColors.accent : AppColors.ink,
                        )),
                    trailing: selected
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: AppColors.accent)
                        : null,
                    onTap: () {
                      setState(() => _reminderRepeat = value);
                      _save();
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _sourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'github pr':
        return AppColors.github;
      case 'jira':
        return AppColors.jira;
      case 'slack review':
      case 'slack alert':
        return AppColors.slack;
      default:
        return AppColors.accent;
    }
  }
}

// ---------------------------------------------------------------------------
// Shared option tile used in both Create and Detail sheets
// ---------------------------------------------------------------------------

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
    this.valueHighlight = false,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool valueHighlight;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      color: valueHighlight
                          ? AppColors.accent
                          : AppColors.tertiaryInk,
                      fontWeight:
                          valueHighlight ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 8),
              trailing!,
            ] else
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.tertiaryInk),
          ],
        ),
      ),
    );
  }
}
