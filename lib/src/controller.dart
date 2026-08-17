import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'ai/ai_provider.dart';
import 'ai/ai_provider_registry.dart';
import 'ai/ai_review_helpers.dart';
import 'ai/cursor_provider.dart';
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
    AiModelService? aiModelService,
    http.Client? httpClient,
  })  : _storage = storage,
        _notificationsService = notificationsService,
        _aiModelService = aiModelService ?? AiModelService(),
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
  final AiModelService _aiModelService;
  final http.Client _httpClient;

  late final GitHubProvider _githubProvider;
  late final JiraProvider _jiraProvider;
  late final SlackProvider _slackProvider;
  late final List<IntegrationProvider> _providers;

  static const List<String> _aiIntegrationIds = <String>[
    'openai',
    'gemini',
    'claude',
    'grok',
    'cursor',
  ];
  static const List<String> _allIntegrationIds = <String>[
    'github',
    'jira',
    'slack',
    ..._aiIntegrationIds,
  ];

  final Map<String, Timer> _syncTimers = <String, Timer>{};
  Set<String> _resolvedItemIds = <String>{};
  Map<String, IntegrationHealth> _integrationHealth =
      <String, IntegrationHealth>{};

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

  /// Live connection health per integration id. Only reports `connected`
  /// after a real API call succeeded (verification or sync).
  IntegrationHealth healthFor(String integrationId) =>
      _integrationHealth[integrationId] ?? IntegrationHealth.initial;

  void _setHealth(String integrationId, IntegrationHealth health) {
    _integrationHealth = <String, IntegrationHealth>{
      ..._integrationHealth,
      integrationId: health,
    };
  }

  bool _canVerify(String integrationId) {
    switch (integrationId) {
      case 'github':
        return config.isGitHubConfigured;
      case 'jira':
        return config.isJiraConfigured;
      case 'slack':
        return config.slackEnabled && config.slackToken.trim().isNotEmpty;
      case 'openai':
        return config.openAiEnabled && config.openAiApiKey.trim().isNotEmpty;
      case 'gemini':
        return config.isGeminiConfigured;
      case 'claude':
        return config.isClaudeConfigured;
      case 'grok':
        return config.isGrokConfigured;
      case 'cursor':
        return config.isCursorConfigured;
      default:
        return false;
    }
  }

  /// Verifies an integration with a real credential check against its API and
  /// records the outcome. Returns true when the connection is healthy.
  Future<bool> verifyIntegration(String integrationId) async {
    if (integrationId == 'openai' &&
        config.openAiApiKey.trim().isEmpty &&
        config.openAiProxyUrl.trim().isNotEmpty) {
      _setHealth(
        'openai',
        const IntegrationHealth(
          message: 'Proxy endpoint configured -- cannot verify automatically.',
        ),
      );
      notifyListeners();
      return false;
    }
    if (!_canVerify(integrationId)) {
      _setHealth(
        integrationId,
        IntegrationHealth.failure(
          'Integration is not fully configured. Fill in all fields first.',
        ),
      );
      notifyListeners();
      return false;
    }

    _setHealth(integrationId, healthFor(integrationId).asChecking());
    notifyListeners();

    try {
      final String detail = await _runVerification(integrationId);
      _setHealth(integrationId, IntegrationHealth.connected(detail));
      return true;
    } on ServiceException catch (error) {
      _setHealth(integrationId, IntegrationHealth.failure(error.message));
      return false;
    } catch (error) {
      _setHealth(
        integrationId,
        IntegrationHealth.failure('Verification failed: $error'),
      );
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<String> _runVerification(String integrationId) async {
    switch (integrationId) {
      case 'github':
        final String login = await _githubProvider.service.verifyCredentials(
          username: config.githubUsername,
          token: config.githubToken,
        );
        return 'Authenticated as $login';
      case 'jira':
        final String name = await _jiraProvider.service.verifyCredentials(
          baseUrl: config.normalizedJiraBaseUrl,
          email: config.jiraEmail,
          apiToken: config.jiraApiToken,
        );
        return 'Authenticated as $name';
      case 'slack':
        try {
          await _slackProvider.service.validateToken(token: config.slackToken);
        } on ServiceException catch (error) {
          if (!_isSlackTokenExpired(error) ||
              !await _attemptSlackTokenRefresh()) {
            rethrow;
          }
          await _slackProvider.service.validateToken(token: config.slackToken);
        }
        return 'Workspace token verified';
      // AI providers: a successful models call proves the key works. The
      // status chip already says "Connected", so no extra message is needed.
      case 'openai':
        await _aiModelService.fetchOpenAiModels(apiKey: config.openAiApiKey);
        return '';
      case 'gemini':
        await _aiModelService.fetchGeminiModels(apiKey: config.geminiApiKey);
        return '';
      case 'claude':
        await _aiModelService.fetchClaudeModels(apiKey: config.claudeApiKey);
        return '';
      case 'grok':
        await _aiModelService.fetchGrokModels(apiKey: config.grokApiKey);
        return '';
      case 'cursor':
        await _aiModelService.fetchCursorModels(apiKey: config.cursorApiKey);
        return '';
      default:
        throw ServiceException('Unknown integration "$integrationId".');
    }
  }

  String _credentialSignature(String integrationId, ConnectorConfig c) {
    switch (integrationId) {
      case 'github':
        return '${c.githubEnabled}|${c.githubUsername.trim()}'
            '|${c.githubToken.trim()}';
      case 'jira':
        return '${c.jiraEnabled}|${c.normalizedJiraBaseUrl}'
            '|${c.jiraEmail.trim()}|${c.jiraApiToken.trim()}';
      case 'slack':
        return '${c.slackEnabled}|${c.slackToken.trim()}';
      case 'openai':
        return '${c.openAiEnabled}|${c.openAiApiKey.trim()}'
            '|${c.openAiProxyUrl.trim()}';
      case 'gemini':
        return '${c.geminiEnabled}|${c.geminiApiKey.trim()}';
      case 'claude':
        return '${c.claudeEnabled}|${c.claudeApiKey.trim()}';
      case 'grok':
        return '${c.grokEnabled}|${c.grokApiKey.trim()}';
      case 'cursor':
        return '${c.cursorEnabled}|${c.cursorApiKey.trim()}';
      default:
        return '';
    }
  }

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
    _resolvedItemIds = await _storage.loadResolvedItemIds();
    _pendingCursorRuns = await _storage.loadPendingCursorRuns();

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

    // AI providers are not part of the sync loop; verify them at startup so
    // their connection status reflects reality instead of stored config.
    for (final String id in _aiIntegrationIds) {
      if (_canVerify(id)) {
        unawaited(verifyIntegration(id));
      }
    }

    // Cloud agent reviews keep running on Cursor's side while the app is
    // suspended or closed; re-attach to any run we launched earlier.
    unawaited(_resumePendingCursorRuns());
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
      _setHealth(providerId, IntegrationHealth.connected(_syncDetail(items)));
    } on ServiceException catch (error) {
      if (providerId == 'slack' && _isSlackTokenExpired(error)) {
        final bool refreshed = await _attemptSlackTokenRefresh();
        if (refreshed) {
          return refreshProvider(providerId, silent: silent);
        }
      }
      _setHealth(providerId, IntegrationHealth.failure(error.message));
      if (kDebugMode) debugPrint('$providerId sync failed: $error');
    } catch (error) {
      _setHealth(providerId, IntegrationHealth.failure('Sync failed: $error'));
      if (kDebugMode) debugPrint('$providerId sync failed: $error');
    }
    // Always notify: background timer syncs must still surface new items.
    // `silent` only means the caller did not want an eager spinner update.
    notifyListeners();
  }

  String _syncDetail(List<IntegrationItem> items) =>
      'Synced ${items.length} item${items.length == 1 ? '' : 's'}';

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
          _setHealth(
            provider.id,
            IntegrationHealth.connected(_syncDetail(items)),
          );
        } on ServiceException catch (error) {
          if (provider.id == 'slack' && _isSlackTokenExpired(error)) {
            final bool refreshed = await _attemptSlackTokenRefresh();
            if (refreshed) {
              try {
                final List<IntegrationItem> retryItems =
                    await provider.fetchItems(config);
                _itemsByProvider[provider.id] = retryItems;
                _setHealth(
                  provider.id,
                  IntegrationHealth.connected(_syncDetail(retryItems)),
                );
                continue;
              } catch (_) {}
            }
          }
          _itemsByProvider[provider.id] = previous;
          _setHealth(provider.id, IntegrationHealth.failure(error.message));
          errors.add(provider.displayName);
          if (kDebugMode) {
            debugPrint('${provider.displayName} sync failed: $error');
          }
        } catch (error) {
          _itemsByProvider[provider.id] = previous;
          _setHealth(
            provider.id,
            IntegrationHealth.failure('Sync failed: $error'),
          );
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

  Future<void> updateConfig(
    ConnectorConfig nextConfig, {
    bool refresh = true,
    bool verifyChanged = true,
  }) async {
    final ConnectorConfig previous = config;
    config = nextConfig;
    await _storage.saveConfig(config);

    final List<String> changed = _allIntegrationIds
        .where(
          (String id) =>
              _credentialSignature(id, previous) !=
              _credentialSignature(id, nextConfig),
        )
        .toList();
    for (final String id in changed) {
      _setHealth(id, IntegrationHealth.initial);
    }

    _setupSyncTimers();
    notifyListeners();

    if (refresh) {
      await refreshAll();
    }
    if (verifyChanged) {
      // Sync outcomes above already updated github/jira/slack health;
      // run the strict credential check for anything whose secrets changed.
      // _canVerify gates on the enable flag, so disabled integrations are
      // never contacted.
      for (final String id in changed) {
        if (_canVerify(id)) {
          unawaited(verifyIntegration(id));
        }
      }
    }
  }

  static const Set<String> _syncProviderIds = <String>{
    'github',
    'jira',
    'slack',
  };

  /// Flips an integration's enable switch. When enabling, runs the credential
  /// check so the status reflects reality and kicks off a data sync for the
  /// sync providers. Returns false when enabling failed verification (the
  /// failure reason is in [healthFor]).
  Future<bool> setIntegrationEnabled(String integrationId, bool enabled) async {
    await updateConfig(
      _withIntegrationEnabled(config, integrationId, enabled),
      refresh: false,
      verifyChanged: false,
    );
    if (!enabled) {
      if (_syncProviderIds.contains(integrationId)) {
        _itemsByProvider[integrationId] = <IntegrationItem>[];
        notifyListeners();
      }
      return true;
    }

    final bool ok = await verifyIntegration(integrationId);
    if (ok && _syncProviderIds.contains(integrationId)) {
      unawaited(refreshProvider(integrationId));
    }
    return ok;
  }

  ConnectorConfig _withIntegrationEnabled(
    ConnectorConfig base,
    String integrationId,
    bool enabled,
  ) {
    switch (integrationId) {
      case 'github':
        return base.copyWith(githubEnabled: enabled);
      case 'jira':
        return base.copyWith(jiraEnabled: enabled);
      case 'slack':
        return base.copyWith(slackEnabled: enabled);
      case 'openai':
        return base.copyWith(openAiEnabled: enabled);
      case 'gemini':
        return base.copyWith(geminiEnabled: enabled);
      case 'claude':
        return base.copyWith(claudeEnabled: enabled);
      case 'grok':
        return base.copyWith(grokEnabled: enabled);
      case 'cursor':
        return base.copyWith(cursorEnabled: enabled);
      default:
        return base;
    }
  }

  /// Requests the notification (and exact alarm) permissions ToDo reminders
  /// need. Called from the reminder flow, not from settings.
  Future<bool> requestNotificationPermissions() =>
      _notificationsService.requestPermissions();

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
    DateTime? reminderDate,
    String reminderRepeat = 'none',
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
      reminderDate: reminderDate,
      reminderRepeat: reminderRepeat,
    );

    todos = <TodoItem>[todo, ...todos];
    await _storage.saveTodos(todos);
    if (reminderDate != null) {
      await _scheduleOrCancelReminder(todo);
    }
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
  Map<String, PendingCursorRun> _pendingCursorRuns =
      <String, PendingCursorRun>{};

  String? reviewProviderFor(String itemId) => _reviewProviderCache[itemId];

  /// Whether a Cursor cloud agent review was launched for this item and can
  /// be resumed instead of starting a new agent.
  bool hasPendingCursorRun(String itemId) =>
      _pendingCursorRuns.containsKey(itemId);

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
      AiReviewResult review;
      if (aiProvider is CursorProvider) {
        review = await _runCursorReview(
          prId: item.id,
          provider: aiProvider,
          contextForLaunch: hasPendingCursorRun(item.id)
              ? null
              : await _githubProvider.service.fetchPullRequestContext(
                  pullRequest: pr,
                  token: config.githubToken,
                ),
        );
      } else {
        final PullRequestContext context =
            await _githubProvider.service.fetchPullRequestContext(
          pullRequest: pr,
          token: config.githubToken,
        );
        review = await aiProvider.reviewPullRequest(
          context: context,
          config: config,
          client: _httpClient,
        );
      }
      if (review.providerId.isEmpty) {
        review = review.copyWith(
          providerId: aiProvider.id,
          model: aiProvider.modelLabel(config),
        );
      }
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

  /// Runs (or resumes) a Cursor cloud agent review. The agent/run ids are
  /// persisted immediately after launch so the run survives backgrounding
  /// and app restarts; they are cleared once the run reaches a terminal
  /// outcome.
  Future<AiReviewResult> _runCursorReview({
    required String prId,
    required CursorProvider provider,
    PullRequestContext? contextForLaunch,
  }) async {
    PendingCursorRun? pending = _pendingCursorRuns[prId];

    if (pending == null) {
      if (contextForLaunch == null) {
        throw ServiceException('No pending Cursor run to resume.');
      }
      final ({String agentId, String runId}) launched =
          await provider.launchReviewAgent(
        context: contextForLaunch,
        config: config,
        client: _httpClient,
      );
      pending = PendingCursorRun(
        prId: prId,
        agentId: launched.agentId,
        runId: launched.runId,
        startedAt: DateTime.now(),
        model: provider.modelLabel(config),
      );
      await _setPendingCursorRun(pending);
    } else {
      // Re-link the agent for follow-up chat after a restart.
      provider.registerAgentForPr(prId, pending.agentId);
    }

    try {
      final AiReviewResult review = await provider.awaitReviewResult(
        agentId: pending.agentId,
        runId: pending.runId,
        config: config,
        client: _httpClient,
      );
      await _clearPendingCursorRun(prId);
      return review.copyWith(
        providerId: provider.id,
        model: pending.model.isNotEmpty
            ? pending.model
            : provider.modelLabel(config),
      );
    } on ServiceException catch (error) {
      // Keep the pending run for network blips and poll timeouts so it can
      // be resumed; clear it for terminal outcomes (auth errors, run
      // ended/expired, agent deleted).
      if (!_isRecoverableCursorFailure(error)) {
        await _clearPendingCursorRun(prId);
      }
      rethrow;
    }
  }

  bool _isRecoverableCursorFailure(ServiceException error) {
    if (error.statusCode != null) return false;
    final String message = error.message.toLowerCase();
    return message.contains('timed out') || message.contains('could not reach');
  }

  Future<void> _setPendingCursorRun(PendingCursorRun run) async {
    _pendingCursorRuns = <String, PendingCursorRun>{
      ..._pendingCursorRuns,
      run.prId: run,
    };
    await _storage.savePendingCursorRuns(_pendingCursorRuns);
    notifyListeners();
  }

  Future<void> _clearPendingCursorRun(String prId) async {
    if (!_pendingCursorRuns.containsKey(prId)) return;
    _pendingCursorRuns = Map<String, PendingCursorRun>.from(_pendingCursorRuns)
      ..remove(prId);
    await _storage.savePendingCursorRuns(_pendingCursorRuns);
    notifyListeners();
  }

  static const Duration _maxPendingCursorRunAge = Duration(hours: 6);

  Future<void> _resumePendingCursorRuns() async {
    if (_pendingCursorRuns.isEmpty) return;
    final AiProvider? provider = AiProviderRegistry.byId('cursor');
    if (provider is! CursorProvider) return;

    for (final PendingCursorRun pending
        in List<PendingCursorRun>.of(_pendingCursorRuns.values)) {
      if (!provider.isConfigured(config)) return;
      if (DateTime.now().difference(pending.startedAt) >
          _maxPendingCursorRunAge) {
        await _clearPendingCursorRun(pending.prId);
        continue;
      }

      activeReviewPrId = pending.prId;
      notifyListeners();
      try {
        final AiReviewResult review = await _runCursorReview(
          prId: pending.prId,
          provider: provider,
        );
        aiReviewCache = <String, AiReviewResult>{
          ...aiReviewCache,
          pending.prId: review,
        };
        _reviewProviderCache = <String, String>{
          ..._reviewProviderCache,
          pending.prId: 'cursor',
        };
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[Cursor] Resume of ${pending.prId} failed: $error');
        }
      } finally {
        activeReviewPrId = null;
        notifyListeners();
      }
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

  Map<String, PrReviewDecision> _postedReviewDecisions =
      <String, PrReviewDecision>{};

  /// The review state last posted to GitHub for this item, if any.
  PrReviewDecision? postedReviewDecisionFor(String itemId) =>
      _postedReviewDecisions[itemId];

  /// Submits a GitHub pull request review with the chosen state
  /// (comment / request changes / approve) and remembers the decision.
  Future<String> submitPrReview(
    IntegrationItem item, {
    required String body,
    required PrReviewDecision decision,
  }) async {
    final String url = await _githubProvider.service.submitPrReview(
      owner: item.meta<String>('owner') ?? '',
      repo: item.meta<String>('repo') ?? '',
      number: item.meta<int>('number') ?? 0,
      token: config.githubToken,
      body: body,
      event: decision.githubEvent,
    );
    _postedReviewDecisions = <String, PrReviewDecision>{
      ..._postedReviewDecisions,
      item.id: decision,
    };
    notifyListeners();
    return url;
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

  // ---------------------------------------------------------------------
  // Jira discovery assist
  // ---------------------------------------------------------------------

  /// AI providers usable for the Jira discovery assist. Cursor is excluded:
  /// its cloud agent clones the GitHub repository, and the assist must never
  /// touch GitHub.
  List<AiProvider> get jiraAssistProviders => configuredAiProviders
      .where((AiProvider provider) => provider.id != 'cursor')
      .toList();

  Map<String, String> _assistProviderCache = <String, String>{};

  /// The AI provider last used to assist on this item, if any.
  String? assistProviderFor(String itemId) => _assistProviderCache[itemId];

  /// Chat-based discovery on a Jira item, built purely from the ticket
  /// metadata the Jira sync already stores. No GitHub or repository access
  /// of any kind.
  Future<AiChatMessage> chatAboutJiraItem({
    required IntegrationItem item,
    required List<AiChatMessage> history,
    required String userMessage,
    String? providerId,
  }) async {
    final List<AiProvider> available = jiraAssistProviders;
    final String resolvedId = providerId ??
        _assistProviderCache[item.id] ??
        (available.isNotEmpty ? available.first.id : '');
    final AiProvider? aiProvider =
        resolvedId.isEmpty ? null : AiProviderRegistry.byId(resolvedId);
    if (aiProvider == null ||
        aiProvider.id == 'cursor' ||
        !aiProvider.isConfigured(config)) {
      throw ServiceException(
        'No AI provider is available for Jira assist. '
        'Enable OpenAI, Gemini, Claude, or Grok in Integrations.',
      );
    }

    final String parentKey = item.meta<String>('parentKey') ?? '';
    final String parentTitle = item.meta<String>('parentTitle') ?? '';
    final String systemPrompt = buildJiraAssistSystemPrompt(
      issueKey: item.meta<String>('key') ?? '',
      title: item.title,
      issueType: item.meta<String>('issueType') ?? '',
      status: item.meta<String>('status') ?? '',
      priority: item.meta<String>('priority') ?? '',
      projectName: item.meta<String>('projectName') ?? '',
      parentSummary: parentKey.isEmpty
          ? ''
          : (parentTitle.isEmpty ? parentKey : '$parentKey: $parentTitle'),
      description: item.meta<String>('description') ?? '',
    );

    final AiChatMessage response = await aiProvider.chatWithSystemPrompt(
      systemPrompt: systemPrompt,
      history: history,
      userMessage: userMessage,
      config: config,
      client: _httpClient,
    );
    _assistProviderCache = <String, String>{
      ..._assistProviderCache,
      item.id: resolvedId,
    };
    return response;
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
