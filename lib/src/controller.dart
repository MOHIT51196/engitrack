import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'ai/ai_provider.dart';
import 'ai/ai_provider_registry.dart';
import 'integrations/github_provider.dart';
import 'integrations/integration_provider.dart';
import 'integrations/jira_provider.dart';
import 'integrations/slack_provider.dart';
import 'models.dart';
import 'services.dart';
import 'storage.dart';

class EngiTrackController extends ChangeNotifier {
  EngiTrackController({
    required AppStorage storage,
    required NotificationsService notificationsService,
    GitHubService? gitHubService,
    JiraService? jiraService,
    SlackService? slackService,
    http.Client? httpClient,
  })  : _storage = storage,
        _notificationsService = notificationsService,
        _httpClient = httpClient ?? http.Client() {
    final GitHubService ghSvc = gitHubService ?? GitHubService();
    final JiraService jrSvc = jiraService ?? JiraService();
    final SlackService slSvc = slackService ?? SlackService();

    _githubProvider = GitHubProvider(service: ghSvc);
    _jiraProvider = JiraProvider(service: jrSvc);
    _slackProvider = SlackProvider(service: slSvc);

    _providers = <IntegrationProvider>[
      _githubProvider,
      _jiraProvider,
      _slackProvider,
    ];
  }

  final AppStorage _storage;
  final NotificationsService _notificationsService;
  final http.Client _httpClient;

  late final GitHubProvider _githubProvider;
  late final JiraProvider _jiraProvider;
  late final SlackProvider _slackProvider;
  late final List<IntegrationProvider> _providers;

  final Map<String, Timer> _syncTimers = <String, Timer>{};
  Set<String> _seenAlertIds = <String>{};
  Set<String> _resolvedItemIds = <String>{};

  ConnectorConfig config = const ConnectorConfig();
  List<TodoItem> todos = <TodoItem>[];
  List<NoteItem> notes = <NoteItem>[];

  final Map<String, List<IntegrationItem>> _itemsByProvider =
      <String, List<IntegrationItem>>{};
  Map<String, AiReviewResult> aiReviewCache = <String, AiReviewResult>{};

  bool isRefreshing = false;
  DateTime? lastSyncedAt;
  String? errorMessage;
  String? activeReviewPrId;

  List<IntegrationProvider> get providers => _providers;
  GitHubProvider get githubProvider => _githubProvider;
  SlackProvider get slackProvider => _slackProvider;

  List<IntegrationItem> itemsForProvider(String providerId) {
    return (_itemsByProvider[providerId] ?? <IntegrationItem>[])
        .where((IntegrationItem item) => !_resolvedItemIds.contains(item.id))
        .toList();
  }

  List<IntegrationItem> itemsForCategory(IntegrationCategory category) {
    return _itemsByProvider.values
        .expand((List<IntegrationItem> items) => items)
        .where(
          (IntegrationItem item) =>
              item.category == category && !_resolvedItemIds.contains(item.id),
        )
        .toList()
      ..sort(
        (IntegrationItem a, IntegrationItem b) =>
            b.timestamp.compareTo(a.timestamp),
      );
  }

  List<IntegrationItem> get allActiveItems {
    return _itemsByProvider.values
        .expand((List<IntegrationItem> items) => items)
        .where((IntegrationItem item) => !_resolvedItemIds.contains(item.id))
        .toList()
      ..sort(
        (IntegrationItem a, IntegrationItem b) =>
            b.timestamp.compareTo(a.timestamp),
      );
  }

  List<AiProvider> get configuredAiProviders =>
      AiProviderRegistry.configured(config);

  bool get canRunAiReview =>
      config.isGitHubConfigured && configuredAiProviders.isNotEmpty;

  int get totalActionableCount => allActiveItems.length;

  List<IntegrationItem> get codeReviewItems =>
      itemsForCategory(IntegrationCategory.codeReview);
  List<IntegrationItem> get issueTrackerItems =>
      itemsForCategory(IntegrationCategory.issueTracker);
  List<IntegrationItem> get messagingItems =>
      itemsForCategory(IntegrationCategory.messaging);

  List<IntegrationItem> get slackAlertItems => messagingItems
      .where((IntegrationItem item) => item.reason == ItemReason.alert)
      .toList();
  List<IntegrationItem> get slackReviewItems => messagingItems
      .where((IntegrationItem item) => item.reason != ItemReason.alert)
      .toList();

  bool isResolved(String itemId) => _resolvedItemIds.contains(itemId);

  List<IntegrationItem> get resolvedItems {
    return _itemsByProvider.values
        .expand((List<IntegrationItem> items) => items)
        .where((IntegrationItem item) => _resolvedItemIds.contains(item.id))
        .toList()
      ..sort(
        (IntegrationItem a, IntegrationItem b) =>
            b.timestamp.compareTo(a.timestamp),
      );
  }

  int get resolvedItemCount => _resolvedItemIds.length;

  List<TodoItem> get sortedTodos {
    final List<TodoItem> copy = List<TodoItem>.from(todos);
    copy.sort((TodoItem a, TodoItem b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }

  List<NoteItem> get sortedNotes {
    final List<NoteItem> copy = List<NoteItem>.from(notes);
    copy.sort((NoteItem a, NoteItem b) => b.updatedAt.compareTo(a.updatedAt));
    return copy;
  }

  Future<void> initialize() async {
    await _notificationsService.initialize();
    config = await _storage.loadConfig();
    todos = await _storage.loadTodos();
    notes = await _storage.loadNotes();
    _seenAlertIds = await _storage.loadSeenAlertIds();
    _resolvedItemIds = await _storage.loadResolvedItemIds();

    if (notes.isEmpty) {
      final DateTime now = DateTime.now();
      notes = <NoteItem>[
        NoteItem(
          id: 'welcome-${now.microsecondsSinceEpoch}',
          title: 'Welcome to EngiTrack',
          body:
              'Use this workspace to jot down notes, track tasks, and stay on top of your engineering workflow.',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      await _storage.saveNotes(notes);
    }

    await refreshAll(silent: true);
    _setupSyncTimers();
    await _syncAllReminders();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final Timer timer in _syncTimers.values) {
      timer.cancel();
    }
    _syncTimers.clear();
    super.dispose();
  }

  void _setupSyncTimers() {
    for (final Timer timer in _syncTimers.values) {
      timer.cancel();
    }
    _syncTimers.clear();

    if (config.githubEnabled) {
      _syncTimers['github'] = Timer.periodic(
        Duration(minutes: config.githubSyncMinutes.clamp(1, 60)),
        (_) => refreshProvider('github', silent: true),
      );
    }
    if (config.jiraEnabled) {
      _syncTimers['jira'] = Timer.periodic(
        Duration(minutes: config.jiraSyncMinutes.clamp(1, 60)),
        (_) => refreshProvider('jira', silent: true),
      );
    }
    if (config.slackEnabled) {
      _syncTimers['slack'] = Timer.periodic(
        Duration(minutes: config.slackSyncMinutes.clamp(1, 60)),
        (_) => refreshProvider('slack', silent: true),
      );
    }
  }

  Future<void> refreshProvider(String providerId, {bool silent = false}) async {
    final IntegrationProvider? provider =
        _providers.cast<IntegrationProvider?>().firstWhere(
              (IntegrationProvider? p) => p?.id == providerId,
              orElse: () => null,
            );
    if (provider == null || !provider.isConfigured(config)) return;

    try {
      final List<IntegrationItem> items = await provider.fetchItems(config);
      _itemsByProvider[providerId] = items;

      if (providerId == 'slack') {
        await _processSlackAlertNotifications(items);
      }
    } on ServiceException catch (error) {
      if (providerId == 'slack' && _isSlackTokenExpired(error)) {
        final bool refreshed = await _attemptSlackTokenRefresh();
        if (refreshed) {
          return refreshProvider(providerId, silent: silent);
        }
      }
      if (kDebugMode) debugPrint('$providerId sync failed: $error');
    } catch (error) {
      if (kDebugMode) debugPrint('$providerId sync failed: $error');
    }
    if (!silent) notifyListeners();
  }

  bool _isSlackTokenExpired(ServiceException error) {
    final String msg = error.message.toLowerCase();
    return msg.contains('token_expired') ||
        msg.contains('token_revoked') ||
        msg.contains('invalid_auth');
  }

  Future<bool> _attemptSlackTokenRefresh() async {
    if (!config.isSlackTokenRotating || !config.isSlackRefreshConfigured) {
      return false;
    }

    try {
      final Map<String, String> result =
          await _slackProvider.service.refreshAccessToken(
        refreshToken: config.slackRefreshToken,
        clientId: config.slackClientId,
        clientSecret: config.slackClientSecret,
      );

      final String newAccess = result['access_token'] ?? '';
      final String newRefresh = result['refresh_token'] ?? '';
      if (newAccess.isEmpty) return false;

      config = config.copyWith(
        slackToken: newAccess,
        slackRefreshToken: newRefresh.isNotEmpty ? newRefresh : null,
      );
      await _storage.saveConfig(config);
      notifyListeners();
      if (kDebugMode) debugPrint('Slack token refreshed successfully');
      return true;
    } catch (error) {
      if (kDebugMode) debugPrint('Slack token refresh failed: $error');
      return false;
    }
  }

  Future<void> refreshAll({bool silent = false}) async {
    if (isRefreshing) return;

    isRefreshing = true;
    if (!silent) notifyListeners();

    final List<String> errors = <String>[];

    try {
      for (final IntegrationProvider provider in _providers) {
        if (!provider.isConfigured(config)) {
          _itemsByProvider[provider.id] = <IntegrationItem>[];
          continue;
        }
        final List<IntegrationItem> previous =
            _itemsByProvider[provider.id] ?? <IntegrationItem>[];
        try {
          final List<IntegrationItem> items = await provider.fetchItems(config);
          _itemsByProvider[provider.id] = items;

          if (provider.id == 'slack') {
            await _processSlackAlertNotifications(items);
          }
        } on ServiceException catch (error) {
          if (provider.id == 'slack' && _isSlackTokenExpired(error)) {
            final bool refreshed = await _attemptSlackTokenRefresh();
            if (refreshed) {
              try {
                final List<IntegrationItem> retryItems =
                    await provider.fetchItems(config);
                _itemsByProvider[provider.id] = retryItems;
                await _processSlackAlertNotifications(retryItems);
                continue;
              } catch (_) {}
            }
          }
          _itemsByProvider[provider.id] = previous;
          errors.add(provider.displayName);
          if (kDebugMode) {
            debugPrint('${provider.displayName} sync failed: $error');
          }
        } catch (error) {
          _itemsByProvider[provider.id] = previous;
          errors.add(provider.displayName);
          if (kDebugMode) {
            debugPrint('${provider.displayName} sync failed: $error');
          }
        }
      }
      errorMessage = errors.isEmpty
          ? null
          : 'Some integrations could not sync: ${errors.join(', ')}';
      lastSyncedAt = DateTime.now();
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _processSlackAlertNotifications(
    List<IntegrationItem> items,
  ) async {
    final bool allowNotifications =
        config.notificationsEnabled && lastSyncedAt != null;
    final List<IntegrationItem> alertItems = items
        .where((IntegrationItem i) => i.reason == ItemReason.alert)
        .toList();

    final Set<String> previousIds = Set<String>.from(_seenAlertIds);
    final List<IntegrationItem> newAlerts = alertItems
        .where((IntegrationItem a) => !previousIds.contains(a.id))
        .toList();

    _seenAlertIds = <String>{
      ..._seenAlertIds,
      ...alertItems.map((IntegrationItem a) => a.id),
    };
    await _storage.saveSeenAlertIds(_seenAlertIds);

    if (allowNotifications) {
      for (final IntegrationItem alert in newAlerts.take(5)) {
        try {
          await _notificationsService.showAlertNotification(
            SlackAlert(
              id: alert.id,
              channel: alert.meta<String>('channel') ?? '',
              title: alert.title,
              message: alert.meta<String>('message') ?? '',
              createdAt: alert.timestamp,
              severity: AlertSeverity.values.firstWhere(
                (AlertSeverity s) => s.name == alert.meta<String>('severity'),
                orElse: () => AlertSeverity.info,
              ),
              url: alert.url,
            ),
          );
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Failed to show alert notification: $error');
          }
        }
      }
    }
  }

  Future<void> updateConfig(ConnectorConfig nextConfig) async {
    config = nextConfig;
    await _storage.saveConfig(config);
    _setupSyncTimers();
    notifyListeners();
    await refreshAll();
  }

  Future<bool> requestNotificationPermissions() async {
    final bool granted = await _notificationsService.requestPermissions();
    if (granted && !config.notificationsEnabled) {
      config = config.copyWith(notificationsEnabled: true);
      await _storage.saveConfig(config);
      notifyListeners();
    }
    return granted;
  }

  Future<void> _syncAllReminders() async {
    for (final TodoItem todo in todos) {
      await _scheduleOrCancelReminder(todo);
    }
  }

  Future<void> _scheduleOrCancelReminder(TodoItem todo) async {
    if (todo.completed || todo.reminderDate == null) {
      await _notificationsService.cancelTodoReminder(todo.id);
      return;
    }
    try {
      await _notificationsService.scheduleTodoReminder(
        todoId: todo.id,
        title: todo.title,
        scheduledDate: todo.reminderDate!,
        subtitle: todo.subtitle.isNotEmpty ? todo.subtitle : null,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Failed to schedule reminder: $error');
    }
  }

  Future<void> resolveItem(String id) async {
    _resolvedItemIds = <String>{..._resolvedItemIds, id};
    await _storage.saveResolvedItemIds(_resolvedItemIds);
    notifyListeners();
  }

  Future<void> unresolveItem(String id) async {
    _resolvedItemIds = Set<String>.from(_resolvedItemIds)..remove(id);
    await _storage.saveResolvedItemIds(_resolvedItemIds);
    notifyListeners();
  }

  Future<bool> addToTodo({
    required String title,
    required String subtitle,
    required String sourceLabel,
    String sourceUrl = '',
  }) async {
    final bool alreadyExists = sourceUrl.isNotEmpty &&
        todos.any(
          (TodoItem item) =>
              item.sourceUrl.isNotEmpty && item.sourceUrl == sourceUrl,
        );
    if (alreadyExists) return false;

    final DateTime now = DateTime.now();
    final TodoItem todo = TodoItem(
      id: '${now.microsecondsSinceEpoch}',
      title: title.trim(),
      subtitle: subtitle.trim(),
      sourceLabel: sourceLabel.trim(),
      sourceUrl: sourceUrl.trim(),
      createdAt: now,
    );

    todos = <TodoItem>[todo, ...todos];
    await _storage.saveTodos(todos);
    notifyListeners();
    return true;
  }

  Future<bool> addItemToTodo(IntegrationItem item) {
    return addToTodo(
      title: item.title,
      subtitle: item.subtitle,
      sourceLabel: item.providerId,
      sourceUrl: item.url,
    );
  }

  Future<void> toggleTodo(TodoItem item, bool completed) async {
    final TodoItem toggled = item.copyWith(completed: completed);
    todos = todos
        .map(
          (TodoItem candidate) => candidate.id == item.id ? toggled : candidate,
        )
        .toList();
    await _storage.saveTodos(todos);
    await _scheduleOrCancelReminder(toggled);
    notifyListeners();
  }

  Future<void> deleteTodo(String id) async {
    await _notificationsService.cancelTodoReminder(id);
    todos = todos.where((TodoItem item) => item.id != id).toList();
    await _storage.saveTodos(todos);
    notifyListeners();
  }

  Future<void> updateTodo(TodoItem updated) async {
    todos = todos
        .map((TodoItem item) => item.id == updated.id ? updated : item)
        .toList();
    await _storage.saveTodos(todos);
    await _scheduleOrCancelReminder(updated);
    notifyListeners();
  }

  Future<NoteItem> createNote() async {
    final DateTime now = DateTime.now();
    final NoteItem note = NoteItem(
      id: '${now.microsecondsSinceEpoch}',
      title: 'Untitled note',
      body: '',
      createdAt: now,
      updatedAt: now,
    );
    notes = <NoteItem>[note, ...notes];
    await _storage.saveNotes(notes);
    notifyListeners();
    return note;
  }

  Future<void> upsertNote(NoteItem note) async {
    final List<NoteItem> updated = List<NoteItem>.from(notes);
    final int index = updated.indexWhere((NoteItem item) => item.id == note.id);
    if (index >= 0) {
      updated[index] = note;
    } else {
      updated.insert(0, note);
    }
    notes = updated;
    await _storage.saveNotes(notes);
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    notes = notes.where((NoteItem note) => note.id != id).toList();
    await _storage.saveNotes(notes);
    notifyListeners();
  }

  AiReviewResult? reviewFor(String pullRequestId) =>
      aiReviewCache[pullRequestId];

  Map<String, String> _reviewProviderCache = <String, String>{};

  String? reviewProviderFor(String itemId) => _reviewProviderCache[itemId];

  Future<AiReviewResult> reviewPullRequest(
    IntegrationItem item, {
    required String providerId,
  }) async {
    final GithubPullRequest pr = GitHubProvider.pullRequestFromItem(item);

    if (!config.isGitHubConfigured) {
      throw ServiceException('GitHub must be configured to fetch PR context.');
    }
    final AiProvider? aiProvider = AiProviderRegistry.byId(providerId);
    if (aiProvider == null || !aiProvider.isConfigured(config)) {
      throw ServiceException('AI provider "$providerId" is not configured.');
    }

    activeReviewPrId = item.id;
    notifyListeners();

    try {
      final PullRequestContext context = await _githubProvider.service
          .fetchPullRequestContext(pullRequest: pr, token: config.githubToken);
      final AiReviewResult review = await aiProvider.reviewPullRequest(
        context: context,
        config: config,
        client: _httpClient,
      );
      aiReviewCache = <String, AiReviewResult>{
        ...aiReviewCache,
        item.id: review,
      };
      _reviewProviderCache = <String, String>{
        ..._reviewProviderCache,
        item.id: providerId,
      };
      return review;
    } finally {
      activeReviewPrId = null;
      notifyListeners();
    }
  }

  Future<String> postPrComment(IntegrationItem item, String body) async {
    return _githubProvider.service.postPrComment(
      owner: item.meta<String>('owner') ?? '',
      repo: item.meta<String>('repo') ?? '',
      number: item.meta<int>('number') ?? 0,
      token: config.githubToken,
      body: body,
    );
  }

  /// Fetches lightweight PR details (commits count, changed files, body) for
  /// display in the expanded view without running a full AI review.
  Future<({int commits, int changedFiles, String body})> fetchPrDetails(
    IntegrationItem item,
  ) async {
    final GithubPullRequest pr = GitHubProvider.pullRequestFromItem(item);
    if (!config.isGitHubConfigured) {
      return (commits: 0, changedFiles: pr.changedFiles, body: pr.body);
    }
    try {
      final PullRequestContext context = await _githubProvider.service
          .fetchPullRequestContext(pullRequest: pr, token: config.githubToken);
      return (
        commits: context.commits,
        changedFiles: context.changedFiles,
        body: context.body.isNotEmpty ? context.body : pr.body,
      );
    } catch (_) {
      return (
        commits: pr.commits,
        changedFiles: pr.changedFiles,
        body: pr.body,
      );
    }
  }

  Future<List<AiChatMessage>> loadAiChat(String prId) =>
      _storage.loadAiChat(prId);

  Future<void> saveAiChat(String prId, List<AiChatMessage> messages) =>
      _storage.saveAiChat(prId, messages);

  Future<String?> exportConfig() async {
    final String json = const JsonEncoder.withIndent(
      '  ',
    ).convert(config.toExportJson());
    final Uint8List bytes = Uint8List.fromList(utf8.encode(json));

    final String? initialDir = await _resolveExportDir();
    final String suggestedName = _versionedFileName(
      'engitrack-integrations',
      initialDir,
    );

    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save integrations config',
      fileName: suggestedName,
      initialDirectory: initialDir,
      type: FileType.any,
      bytes: bytes,
    );

    if (outputPath != null) {
      _lastExportDir = File(outputPath).parent.path;
    }
    return outputPath;
  }

  String? _lastExportDir;

  Future<String?> _resolveExportDir() async {
    if (Platform.isAndroid || Platform.isIOS) return null;

    if (_lastExportDir != null) {
      try {
        if (Directory(_lastExportDir!).existsSync()) return _lastExportDir;
      } catch (_) {}
    }
    final String home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (home.isEmpty) return null;
    try {
      final String downloads = '$home${Platform.pathSeparator}Downloads';
      if (Directory(downloads).existsSync()) return downloads;
      final String docs = '$home${Platform.pathSeparator}Documents';
      if (Directory(docs).existsSync()) return docs;
    } catch (_) {
      return null;
    }
    return home;
  }

  String _versionedFileName(String baseName, String? dirPath) {
    if (dirPath == null) return '$baseName.json';

    try {
      final Directory dir = Directory(dirPath);
      if (!dir.existsSync()) return '$baseName.json';

      final Set<String> existing = dir
          .listSync()
          .whereType<File>()
          .map((File f) => f.uri.pathSegments.last)
          .toSet();

      if (!existing.contains('$baseName.json')) {
        return '$baseName.json';
      }

      int version = 1;
      while (existing.contains('$baseName-v$version.json')) {
        version++;
      }
      return '$baseName-v$version.json';
    } catch (_) {
      return '$baseName.json';
    }
  }

  Future<ConnectorConfig?> importConfig() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import integrations config',
      type: FileType.custom,
      allowedExtensions: <String>['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final PlatformFile picked = result.files.first;
    late final String contents;
    if (picked.bytes != null) {
      contents = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      contents = await File(picked.path!).readAsString();
    } else {
      throw const FormatException('Could not read selected file.');
    }

    final dynamic decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid config file format.');
    }
    if (decoded['_format'] != 'engitrack_integrations_v1') {
      throw const FormatException(
        'Unrecognized file. Expected an EngiTrack integrations export.',
      );
    }

    final ConnectorConfig imported = ConnectorConfig.fromExportJson(decoded);
    await updateConfig(imported);
    return imported;
  }

  Future<AiChatMessage> chatAboutReview({
    required IntegrationItem item,
    required AiReviewResult review,
    required List<AiChatMessage> history,
    required String userMessage,
  }) async {
    final GithubPullRequest pr = GitHubProvider.pullRequestFromItem(item);
    final PullRequestContext context = await _githubProvider.service
        .fetchPullRequestContext(pullRequest: pr, token: config.githubToken);

    final String providerId =
        _reviewProviderCache[item.id] ?? configuredAiProviders.first.id;
    final AiProvider aiProvider =
        AiProviderRegistry.byId(providerId) ?? configuredAiProviders.first;

    return aiProvider.chatAboutReview(
      context: context,
      review: review,
      history: history,
      userMessage: userMessage,
      config: config,
      client: _httpClient,
    );
  }
}

class EngiTrackScope extends InheritedNotifier<EngiTrackController> {
  const EngiTrackScope({
    super.key,
    required EngiTrackController controller,
    required super.child,
  }) : super(notifier: controller);

  static EngiTrackController of(BuildContext context) {
    final EngiTrackScope? scope =
        context.dependOnInheritedWidgetOfExactType<EngiTrackScope>();
    assert(scope != null, 'EngiTrackScope not found in the widget tree.');
    return scope!.notifier!;
  }
}
