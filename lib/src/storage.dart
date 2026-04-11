import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppStorage {
  AppStorage({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
  })  : _preferences = preferences ?? SharedPreferencesAsync(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;

  static const String _configKey = 'engitrack.config.v1';
  static const String _todosKey = 'engitrack.todos.v1';
  static const String _notesKey = 'engitrack.notes.v1';
  static const String _seenAlertsKey = 'engitrack.seenAlerts.v1';
  static const String _resolvedItemsKey = 'engitrack.resolvedItems.v1';
  static const String _aiChatPrefix = 'engitrack.aiChat.';

  static const String _githubTokenKey = 'engitrack.secret.githubToken';
  static const String _jiraEmailKey = 'engitrack.secret.jiraEmail';
  static const String _jiraApiTokenKey = 'engitrack.secret.jiraApiToken';
  static const String _slackTokenKey = 'engitrack.secret.slackToken';
  static const String _slackRefreshTokenKey =
      'engitrack.secret.slackRefreshToken';
  static const String _slackClientIdKey = 'engitrack.secret.slackClientId';
  static const String _slackClientSecretKey =
      'engitrack.secret.slackClientSecret';
  static const String _openAiApiKeyKey = 'engitrack.secret.openAiApiKey';
  static const String _geminiApiKeyKey = 'engitrack.secret.geminiApiKey';
  static const String _claudeApiKeyKey = 'engitrack.secret.claudeApiKey';
  static const String _grokApiKeyKey = 'engitrack.secret.grokApiKey';

  Future<ConnectorConfig> loadConfig() async {
    final rawConfig = await _preferences.getString(_configKey);
    final decoded = rawConfig == null
        ? <String, dynamic>{}
        : jsonDecode(rawConfig) as Map<String, dynamic>;

    return ConnectorConfig.fromStorage(
      json: decoded,
      githubToken: await _secureStorage.read(key: _githubTokenKey) ?? '',
      jiraEmail: await _secureStorage.read(key: _jiraEmailKey) ?? '',
      jiraApiToken: await _secureStorage.read(key: _jiraApiTokenKey) ?? '',
      slackToken: await _secureStorage.read(key: _slackTokenKey) ?? '',
      slackRefreshToken:
          await _secureStorage.read(key: _slackRefreshTokenKey) ?? '',
      slackClientId: await _secureStorage.read(key: _slackClientIdKey) ?? '',
      slackClientSecret:
          await _secureStorage.read(key: _slackClientSecretKey) ?? '',
      openAiApiKey: await _secureStorage.read(key: _openAiApiKeyKey) ?? '',
      geminiApiKey: await _secureStorage.read(key: _geminiApiKeyKey) ?? '',
      claudeApiKey: await _secureStorage.read(key: _claudeApiKeyKey) ?? '',
      grokApiKey: await _secureStorage.read(key: _grokApiKeyKey) ?? '',
    );
  }

  Future<void> saveConfig(ConnectorConfig config) async {
    await _preferences.setString(
      _configKey,
      jsonEncode(config.toPreferencesJson()),
    );
    await Future.wait(<Future<void>>[
      _secureStorage.write(key: _githubTokenKey, value: config.githubToken),
      _secureStorage.write(key: _jiraEmailKey, value: config.jiraEmail),
      _secureStorage.write(key: _jiraApiTokenKey, value: config.jiraApiToken),
      _secureStorage.write(key: _slackTokenKey, value: config.slackToken),
      _secureStorage.write(
        key: _slackRefreshTokenKey,
        value: config.slackRefreshToken,
      ),
      _secureStorage.write(key: _slackClientIdKey, value: config.slackClientId),
      _secureStorage.write(
        key: _slackClientSecretKey,
        value: config.slackClientSecret,
      ),
      _secureStorage.write(key: _openAiApiKeyKey, value: config.openAiApiKey),
      _secureStorage.write(key: _geminiApiKeyKey, value: config.geminiApiKey),
      _secureStorage.write(key: _claudeApiKeyKey, value: config.claudeApiKey),
      _secureStorage.write(key: _grokApiKeyKey, value: config.grokApiKey),
    ]);
  }

  Future<List<TodoItem>> loadTodos() async {
    final raw = await _preferences.getString(_todosKey);
    if (raw == null || raw.isEmpty) {
      return <TodoItem>[];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((dynamic item) => TodoItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTodos(List<TodoItem> todos) async {
    final payload = todos.map((TodoItem todo) => todo.toJson()).toList();
    await _preferences.setString(_todosKey, jsonEncode(payload));
  }

  Future<List<NoteItem>> loadNotes() async {
    final raw = await _preferences.getString(_notesKey);
    if (raw == null || raw.isEmpty) {
      return <NoteItem>[];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((dynamic item) => NoteItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveNotes(List<NoteItem> notes) async {
    final payload = notes.map((NoteItem note) => note.toJson()).toList();
    await _preferences.setString(_notesKey, jsonEncode(payload));
  }

  Future<Set<String>> loadSeenAlertIds() async {
    final raw = await _preferences.getString(_seenAlertsKey);
    if (raw == null || raw.isEmpty) {
      return <String>{};
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((dynamic item) => item.toString()).toSet();
  }

  Future<void> saveSeenAlertIds(Set<String> ids) async {
    await _preferences.setString(_seenAlertsKey, jsonEncode(ids.toList()));
  }

  Future<Set<String>> loadResolvedItemIds() async {
    final raw = await _preferences.getString(_resolvedItemsKey);
    if (raw == null || raw.isEmpty) return <String>{};
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((dynamic item) => item.toString()).toSet();
  }

  Future<void> saveResolvedItemIds(Set<String> ids) async {
    await _preferences.setString(_resolvedItemsKey, jsonEncode(ids.toList()));
  }

  Future<List<AiChatMessage>> loadAiChat(String prId) async {
    final String key = '$_aiChatPrefix${prId.hashCode}';
    final raw = await _preferences.getString(key);
    if (raw == null || raw.isEmpty) return <AiChatMessage>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (dynamic item) =>
              AiChatMessage.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> saveAiChat(String prId, List<AiChatMessage> messages) async {
    final String key = '$_aiChatPrefix${prId.hashCode}';
    final capped = messages.length > 50
        ? messages.sublist(messages.length - 50)
        : messages;
    await _preferences.setString(
      key,
      jsonEncode(capped.map((AiChatMessage m) => m.toJson()).toList()),
    );
  }
}
