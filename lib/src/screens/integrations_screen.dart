import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  bool _didHydrate = false;
  bool _notificationsEnabled = false;

  bool _githubEnabled = false;
  bool _jiraEnabled = false;
  bool _slackEnabled = false;
  bool _openAiEnabled = false;
  bool _geminiEnabled = false;
  bool _claudeEnabled = false;
  bool _grokEnabled = false;

  late final TextEditingController _githubUsernameController;
  late final TextEditingController _githubTokenController;
  late final TextEditingController _jiraBaseUrlController;
  late final TextEditingController _jiraEmailController;
  late final TextEditingController _jiraApiTokenController;
  late final TextEditingController _slackAlertChannelController;
  late final TextEditingController _slackTokenController;
  late final TextEditingController _slackRefreshTokenController;
  late final TextEditingController _slackClientIdController;
  late final TextEditingController _slackClientSecretController;
  late final TextEditingController _openAiApiKeyController;
  late final TextEditingController _geminiApiKeyController;
  late final TextEditingController _claudeApiKeyController;
  late final TextEditingController _grokApiKeyController;

  bool _slackTokenIsRotating = false;
  String _selectedModel = 'gpt-4.1-mini';
  String _selectedGeminiModel = 'gemini-2.0-flash';
  String _selectedClaudeModel = 'claude-sonnet-4-20250514';
  String _selectedGrokModel = 'grok-3-mini-fast';

  List<({String value, String label})> _openAiModels =
      <({String value, String label})>[];
  List<({String value, String label})> _geminiModelList =
      <({String value, String label})>[];
  List<({String value, String label})> _claudeModelList =
      <({String value, String label})>[];
  List<({String value, String label})> _grokModelList =
      <({String value, String label})>[];
  bool _loadingOpenAiModels = false;
  bool _loadingGeminiModels = false;
  bool _loadingClaudeModels = false;
  bool _loadingGrokModels = false;

  int _githubSyncMinutes = 5;
  int _jiraSyncMinutes = 5;
  int _slackSyncMinutes = 5;

  List<String> _slackReviewChannels = <String>[];
  Map<String, String>? _cachedChannelList;
  bool _loadingChannels = false;

  final AiModelService _aiModelService = AiModelService();

  @override
  void initState() {
    super.initState();
    _githubUsernameController = TextEditingController();
    _githubTokenController = TextEditingController();
    _jiraBaseUrlController = TextEditingController();
    _jiraEmailController = TextEditingController();
    _jiraApiTokenController = TextEditingController();
    _slackAlertChannelController = TextEditingController();
    _slackTokenController = TextEditingController();
    _slackRefreshTokenController = TextEditingController();
    _slackClientIdController = TextEditingController();
    _slackClientSecretController = TextEditingController();
    _openAiApiKeyController = TextEditingController();
    _geminiApiKeyController = TextEditingController();
    _claudeApiKeyController = TextEditingController();
    _grokApiKeyController = TextEditingController();

    _slackTokenController.addListener(_onSlackTokenChanged);
  }

  void _onSlackTokenChanged() {
    final bool rotating = _slackTokenController.text.trim().startsWith('xoxe.');
    if (rotating != _slackTokenIsRotating) {
      setState(() => _slackTokenIsRotating = rotating);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didHydrate) return;

    final ConnectorConfig config = EngiTrackScope.of(context).config;
    _notificationsEnabled = config.notificationsEnabled;
    _githubEnabled = config.githubEnabled;
    _jiraEnabled = config.jiraEnabled;
    _slackEnabled = config.slackEnabled;
    _openAiEnabled = config.openAiEnabled;
    _geminiEnabled = config.geminiEnabled;
    _claudeEnabled = config.claudeEnabled;
    _grokEnabled = config.grokEnabled;
    _githubUsernameController.text = config.githubUsername;
    _githubTokenController.text = config.githubToken;
    _jiraBaseUrlController.text = config.jiraBaseUrl;
    _jiraEmailController.text = config.jiraEmail;
    _jiraApiTokenController.text = config.jiraApiToken;
    _slackReviewChannels = List<String>.from(config.slackReviewChannels);
    _slackAlertChannelController.text = config.slackAlertChannel;
    _slackTokenController.text = config.slackToken;
    _slackRefreshTokenController.text = config.slackRefreshToken;
    _slackClientIdController.text = config.slackClientId;
    _slackClientSecretController.text = config.slackClientSecret;
    _slackTokenIsRotating = config.isSlackTokenRotating;
    _openAiApiKeyController.text = config.openAiApiKey;
    _selectedModel =
        config.openAiModel.isNotEmpty ? config.openAiModel : 'gpt-4.1-mini';
    _geminiApiKeyController.text = config.geminiApiKey;
    _selectedGeminiModel =
        config.geminiModel.isNotEmpty ? config.geminiModel : 'gemini-2.0-flash';
    _claudeApiKeyController.text = config.claudeApiKey;
    _selectedClaudeModel = config.claudeModel.isNotEmpty
        ? config.claudeModel
        : 'claude-sonnet-4-20250514';
    _grokApiKeyController.text = config.grokApiKey;
    _selectedGrokModel =
        config.grokModel.isNotEmpty ? config.grokModel : 'grok-3-mini-fast';
    _githubSyncMinutes = config.githubSyncMinutes;
    _jiraSyncMinutes = config.jiraSyncMinutes;
    _slackSyncMinutes = config.slackSyncMinutes;
    _didHydrate = true;

    if (config.openAiApiKey.trim().isNotEmpty) _fetchOpenAiModels();
    if (config.geminiApiKey.trim().isNotEmpty) _fetchGeminiModels();
    if (config.claudeApiKey.trim().isNotEmpty) _fetchClaudeModels();
    if (config.grokApiKey.trim().isNotEmpty) _fetchGrokModels();
  }

  @override
  void dispose() {
    _githubUsernameController.dispose();
    _githubTokenController.dispose();
    _jiraBaseUrlController.dispose();
    _jiraEmailController.dispose();
    _jiraApiTokenController.dispose();
    _slackAlertChannelController.dispose();
    _slackTokenController.removeListener(_onSlackTokenChanged);
    _slackTokenController.dispose();
    _slackRefreshTokenController.dispose();
    _slackClientIdController.dispose();
    _slackClientSecretController.dispose();
    _openAiApiKeyController.dispose();
    _geminiApiKeyController.dispose();
    _claudeApiKeyController.dispose();
    _grokApiKeyController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Model fetching
  // ---------------------------------------------------------------------------

  Future<void> _fetchOpenAiModels() async {
    final String key = _openAiApiKeyController.text.trim();
    if (key.isEmpty) return;
    setState(() => _loadingOpenAiModels = true);
    try {
      final List<({String value, String label})> models =
          await _aiModelService.fetchOpenAiModels(apiKey: key);
      if (mounted) {
        setState(() {
          _openAiModels = models;
          if (models.isNotEmpty &&
              !models.any((m) => m.value == _selectedModel)) {
            _selectedModel = models.first.value;
          }
        });
      }
    } catch (_) {
      if (mounted) showInfoSnackBar(context, 'Could not fetch OpenAI models.');
    } finally {
      if (mounted) setState(() => _loadingOpenAiModels = false);
    }
  }

  Future<void> _fetchGeminiModels() async {
    final String key = _geminiApiKeyController.text.trim();
    if (key.isEmpty) return;
    setState(() => _loadingGeminiModels = true);
    try {
      final List<({String value, String label})> models =
          await _aiModelService.fetchGeminiModels(apiKey: key);
      if (mounted) {
        setState(() {
          _geminiModelList = models;
          if (models.isNotEmpty &&
              !models.any((m) => m.value == _selectedGeminiModel)) {
            _selectedGeminiModel = models.first.value;
          }
        });
      }
    } catch (_) {
      if (mounted) showInfoSnackBar(context, 'Could not fetch Gemini models.');
    } finally {
      if (mounted) setState(() => _loadingGeminiModels = false);
    }
  }

  Future<void> _fetchClaudeModels() async {
    final String key = _claudeApiKeyController.text.trim();
    if (key.isEmpty) return;
    setState(() => _loadingClaudeModels = true);
    try {
      final List<({String value, String label})> models =
          await _aiModelService.fetchClaudeModels(apiKey: key);
      if (mounted) {
        setState(() {
          _claudeModelList = models;
          if (models.isNotEmpty &&
              !models.any((m) => m.value == _selectedClaudeModel)) {
            _selectedClaudeModel = models.first.value;
          }
        });
      }
    } catch (_) {
      if (mounted) showInfoSnackBar(context, 'Could not fetch Claude models.');
    } finally {
      if (mounted) setState(() => _loadingClaudeModels = false);
    }
  }

  Future<void> _fetchGrokModels() async {
    final String key = _grokApiKeyController.text.trim();
    if (key.isEmpty) return;
    setState(() => _loadingGrokModels = true);
    try {
      final List<({String value, String label})> models =
          await _aiModelService.fetchGrokModels(apiKey: key);
      if (mounted) {
        setState(() {
          _grokModelList = models;
          if (models.isNotEmpty &&
              !models.any((m) => m.value == _selectedGrokModel)) {
            _selectedGrokModel = models.first.value;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final String msg = e.toString();
        if (msg.contains('credits') ||
            msg.contains('license') ||
            msg.contains('permission')) {
          showInfoSnackBar(
            context,
            'Grok: Activate API credits at console.x.ai',
          );
        } else {
          showInfoSnackBar(context, 'Could not fetch Grok models.');
        }
      }
    } finally {
      if (mounted) setState(() => _loadingGrokModels = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Auto-save
  // ---------------------------------------------------------------------------

  Future<void> _saveCurrentConfig() async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final ConnectorConfig nextConfig = controller.config.copyWith(
      notificationsEnabled: _notificationsEnabled,
      githubEnabled: _githubEnabled,
      jiraEnabled: _jiraEnabled,
      slackEnabled: _slackEnabled,
      openAiEnabled: _openAiEnabled,
      geminiEnabled: _geminiEnabled,
      claudeEnabled: _claudeEnabled,
      grokEnabled: _grokEnabled,
      githubUsername: _githubUsernameController.text.trim(),
      githubToken: _githubTokenController.text.trim(),
      jiraBaseUrl: _jiraBaseUrlController.text.trim(),
      jiraEmail: _jiraEmailController.text.trim(),
      jiraApiToken: _jiraApiTokenController.text.trim(),
      slackReviewChannels: _slackReviewChannels,
      slackAlertChannel: _slackAlertChannelController.text.trim(),
      slackToken: _slackTokenController.text.trim(),
      slackRefreshToken: _slackRefreshTokenController.text.trim(),
      slackClientId: _slackClientIdController.text.trim(),
      slackClientSecret: _slackClientSecretController.text.trim(),
      openAiApiKey: _openAiApiKeyController.text.trim(),
      openAiModel: _selectedModel,
      geminiApiKey: _geminiApiKeyController.text.trim(),
      geminiModel: _selectedGeminiModel,
      claudeApiKey: _claudeApiKeyController.text.trim(),
      claudeModel: _selectedClaudeModel,
      grokApiKey: _grokApiKeyController.text.trim(),
      grokModel: _selectedGrokModel,
      githubSyncMinutes: _githubSyncMinutes,
      jiraSyncMinutes: _jiraSyncMinutes,
      slackSyncMinutes: _slackSyncMinutes,
    );

    try {
      await controller.updateConfig(nextConfig);
    } catch (_) {}
  }

  void _onFieldSubmitted(String value) {
    _saveCurrentConfig();
    if (mounted) showInfoSnackBar(context, 'Saved.');
  }

  // ---------------------------------------------------------------------------
  // Can-enable checks
  // ---------------------------------------------------------------------------

  bool get _canEnableGithub =>
      _githubUsernameController.text.trim().isNotEmpty &&
      _githubTokenController.text.trim().isNotEmpty;

  bool get _canEnableJira =>
      _jiraBaseUrlController.text.trim().isNotEmpty &&
      _jiraEmailController.text.trim().isNotEmpty &&
      _jiraApiTokenController.text.trim().isNotEmpty;

  bool get _canEnableSlack => _slackTokenController.text.trim().isNotEmpty;

  bool get _canEnableOpenAi => _openAiApiKeyController.text.trim().isNotEmpty;

  bool get _canEnableGemini => _geminiApiKeyController.text.trim().isNotEmpty;

  bool get _canEnableClaude => _claudeApiKeyController.text.trim().isNotEmpty;

  bool get _canEnableGrok => _grokApiKeyController.text.trim().isNotEmpty;

  // ---------------------------------------------------------------------------
  // Slack channels
  // ---------------------------------------------------------------------------

  Future<void> _fetchSlackChannels() async {
    final String token = _slackTokenController.text.trim();
    if (token.isEmpty) return;
    setState(() => _loadingChannels = true);
    try {
      final EngiTrackController controller = EngiTrackScope.of(context);
      final Map<String, String> channels =
          await controller.slackProvider.service.fetchChannelList(token: token);
      if (mounted) setState(() => _cachedChannelList = channels);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingChannels = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final ThemeData theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
            child: _ExportImportButtons(
              onExport: () => _exportConfig(context),
              onImport: () => _importConfig(context),
              compact: true,
            ),
          ),

          _GeneralSettingsCard(
            theme: theme,
            notificationsEnabled: _notificationsEnabled,
            onNotificationsChanged: (bool v) {
              setState(() => _notificationsEnabled = v);
              _saveCurrentConfig();
            },
            onRequestNotifications: () async {
              final bool granted =
                  await controller.requestNotificationPermissions();
              if (!mounted) return;
              if (granted) setState(() => _notificationsEnabled = true);
              if (!context.mounted) return;
              showInfoSnackBar(
                context,
                granted ? 'Permission granted.' : 'Permission not granted.',
              );
            },
          ),

          // ----------------------------------------------------------------
          // Git
          // ----------------------------------------------------------------
          const SizedBox(height: 16),
          const _CategoryHeader(icon: Icons.code_rounded, label: 'Git'),

          const SizedBox(height: 8),
          _CollapsibleIntegration(
            brandName: 'GitHub',
            brandSubtitle: 'Pull request reviews & AI code analysis',
            logoAsset: 'assets/logos/github.svg',
            brandColor: AppColors.github,
            brandBg: AppColors.githubLight,
            enabled: _githubEnabled,
            canEnable: _canEnableGithub,
            isConfigured: controller.config.isGitHubConfigured,
            connectionState: controller.connectionStateFor('github'),
            onEnabledChanged: (bool v) {
              setState(() => _githubEnabled = v);
              _saveCurrentConfig();
            },
            onTestConnection: () =>
                controller.testProviderConnection('github'),
            syncMinutes: _githubSyncMinutes,
            onSyncMinutesChanged: (int v) {
              setState(() => _githubSyncMinutes = v);
              _saveCurrentConfig();
            },
            fieldCount: 2,
            filledCount: _countFilled(<String>[
              _githubUsernameController.text,
              _githubTokenController.text,
            ]),
            children: <Widget>[
              _LabeledField(
                controller: _githubUsernameController,
                label: 'Username',
                hint: 'your-username',
                prefixIcon: Icons.person_outline_rounded,
                onSubmitted: _onFieldSubmitted,
              ),
              const SizedBox(height: 10),
              _SecretField(
                controller: _githubTokenController,
                label: 'Personal access token',
                hint: 'ghp_...',
                onSubmitted: _onFieldSubmitted,
              ),
            ],
          ),

          // ----------------------------------------------------------------
          // Management
          // ----------------------------------------------------------------
          const SizedBox(height: 16),
          const _CategoryHeader(
            icon: Icons.assignment_rounded,
            label: 'Management',
          ),

          const SizedBox(height: 8),
          _CollapsibleIntegration(
            brandName: 'Jira',
            brandSubtitle: 'Track assigned tickets via JQL queries',
            logoAsset: 'assets/logos/jira.svg',
            brandColor: AppColors.jira,
            brandBg: AppColors.jiraLight,
            enabled: _jiraEnabled,
            canEnable: _canEnableJira,
            isConfigured: controller.config.isJiraConfigured,
            connectionState: controller.connectionStateFor('jira'),
            onEnabledChanged: (bool v) {
              setState(() => _jiraEnabled = v);
              _saveCurrentConfig();
            },
            onTestConnection: () =>
                controller.testProviderConnection('jira'),
            syncMinutes: _jiraSyncMinutes,
            onSyncMinutesChanged: (int v) {
              setState(() => _jiraSyncMinutes = v);
              _saveCurrentConfig();
            },
            fieldCount: 3,
            filledCount: _countFilled(<String>[
              _jiraBaseUrlController.text,
              _jiraEmailController.text,
              _jiraApiTokenController.text,
            ]),
            children: <Widget>[
              _LabeledField(
                controller: _jiraBaseUrlController,
                label: 'Atlassian site URL',
                hint: 'https://your-team.atlassian.net',
                keyboardType: TextInputType.url,
                prefixIcon: Icons.link_rounded,
                onSubmitted: _onFieldSubmitted,
              ),
              const SizedBox(height: 10),
              _LabeledField(
                controller: _jiraEmailController,
                label: 'Email',
                hint: 'you@company.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                onSubmitted: _onFieldSubmitted,
              ),
              const SizedBox(height: 10),
              _SecretField(
                controller: _jiraApiTokenController,
                label: 'API token',
                hint: 'Atlassian API token',
                onSubmitted: _onFieldSubmitted,
              ),
            ],
          ),

          // ----------------------------------------------------------------
          // Messaging
          // ----------------------------------------------------------------
          const SizedBox(height: 16),
          const _CategoryHeader(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messaging',
          ),

          const SizedBox(height: 8),
          _CollapsibleIntegration(
            brandName: 'Slack',
            brandSubtitle: 'Review channels, alerts & DM mentions',
            logoAsset: 'assets/logos/slack.svg',
            brandColor: AppColors.slack,
            brandBg: AppColors.slackLight,
            enabled: _slackEnabled,
            canEnable: _canEnableSlack,
            isConfigured: controller.config.isSlackConfigured,
            connectionState: controller.connectionStateFor('slack'),
            onEnabledChanged: (bool v) {
              setState(() => _slackEnabled = v);
              _saveCurrentConfig();
            },
            onTestConnection: () =>
                controller.testProviderConnection('slack'),
            syncMinutes: _slackSyncMinutes,
            onSyncMinutesChanged: (int v) {
              setState(() => _slackSyncMinutes = v);
              _saveCurrentConfig();
            },
            fieldCount: _slackTokenIsRotating ? 6 : 3,
            filledCount: _countFilled(<String>[
              _slackTokenController.text,
              _slackReviewChannels.join(','),
              _slackAlertChannelController.text,
              if (_slackTokenIsRotating) ...<String>[
                _slackRefreshTokenController.text,
                _slackClientIdController.text,
                _slackClientSecretController.text,
              ],
            ]),
            children: <Widget>[
              _SecretField(
                controller: _slackTokenController,
                label: 'Bot token',
                hint: 'xoxb-... or xoxe.xoxp-...',
                onSubmitted: _onFieldSubmitted,
              ),
              if (_slackTokenIsRotating) ...<Widget>[
                const SizedBox(height: 8),
                const _InfoBanner(
                  icon: Icons.autorenew_rounded,
                  color: AppColors.warning,
                  bgColor: AppColors.warningLight,
                  text:
                      'Rotating token detected. Provide refresh credentials for auto-renewal.',
                ),
                const SizedBox(height: 10),
                _SecretField(
                  controller: _slackRefreshTokenController,
                  label: 'Refresh token',
                  hint: 'xoxe-1-...',
                  onSubmitted: _onFieldSubmitted,
                ),
                const SizedBox(height: 10),
                _LabeledField(
                  controller: _slackClientIdController,
                  label: 'Client ID',
                  hint: '1234567890.1234567890',
                  prefixIcon: Icons.badge_outlined,
                  onSubmitted: _onFieldSubmitted,
                ),
                const SizedBox(height: 10),
                _SecretField(
                  controller: _slackClientSecretController,
                  label: 'Client secret',
                  hint: 'f2f77b...',
                  onSubmitted: _onFieldSubmitted,
                ),
              ],
              const SizedBox(height: 12),
              _SectionLabel(
                label: 'Review channels',
                trailing: _loadingChannels
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _SmallAction(
                        label: 'Load channels',
                        icon: Icons.refresh_rounded,
                        onTap: _fetchSlackChannels,
                      ),
              ),
              const SizedBox(height: 6),
              _ChannelChipInput(
                selectedChannels: _slackReviewChannels,
                cachedChannels: _cachedChannelList,
                onChanged: (List<String> channels) {
                  setState(() => _slackReviewChannels = channels);
                  _saveCurrentConfig();
                },
              ),
              const SizedBox(height: 10),
              _LabeledField(
                controller: _slackAlertChannelController,
                label: 'Alert channel',
                hint: '#ops-alerts',
                prefixIcon: Icons.notifications_outlined,
                onSubmitted: _onFieldSubmitted,
              ),
            ],
          ),

          // ----------------------------------------------------------------
          // AI Services
          // ----------------------------------------------------------------
          const SizedBox(height: 16),
          const _CategoryHeader(
            icon: Icons.auto_awesome_rounded,
            label: 'AI Services',
          ),

          const SizedBox(height: 8),
          _CollapsibleIntegration(
            brandName: 'OpenAI',
            brandSubtitle: 'AI-powered pull request review',
            logoAsset: null,
            brandIcon: Icons.auto_awesome_rounded,
            brandColor: AppColors.openai,
            brandBg: AppColors.openaiLight,
            enabled: _openAiEnabled,
            canEnable: _canEnableOpenAi,
            isConfigured: controller.config.isOpenAiConfigured,
            connectionState: controller.config.isOpenAiConfigured
                ? const ConnectionState(status: ConnectionStatus.connected)
                : const ConnectionState(),
            onEnabledChanged: (bool v) {
              setState(() => _openAiEnabled = v);
              _saveCurrentConfig();
            },
            fieldCount: 1,
            filledCount: _countFilled(<String>[_openAiApiKeyController.text]),
            children: <Widget>[
              _SecretField(
                controller: _openAiApiKeyController,
                label: 'API key',
                hint: 'sk-...',
                onSubmitted: (String v) {
                  _onFieldSubmitted(v);
                  _fetchOpenAiModels();
                },
              ),
              _RevealModelSection(
                visible: _openAiApiKeyController.text.trim().isNotEmpty,
                loading: _loadingOpenAiModels,
                child: _DynamicModelDropdown(
                  value: _selectedModel,
                  models: _openAiModels,
                  loading: _loadingOpenAiModels,
                  theme: theme,
                  onChanged: (String v) {
                    setState(() => _selectedModel = v);
                    _saveCurrentConfig();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          _CollapsibleIntegration(
            brandName: 'Google Gemini',
            brandSubtitle: 'AI-powered pull request review',
            logoAsset: null,
            brandIcon: Icons.diamond_outlined,
            brandColor: AppColors.gemini,
            brandBg: AppColors.geminiLight,
            enabled: _geminiEnabled,
            canEnable: _canEnableGemini,
            isConfigured: controller.config.isGeminiConfigured,
            connectionState: controller.config.isGeminiConfigured
                ? const ConnectionState(status: ConnectionStatus.connected)
                : const ConnectionState(),
            onEnabledChanged: (bool v) {
              setState(() => _geminiEnabled = v);
              _saveCurrentConfig();
            },
            fieldCount: 1,
            filledCount: _countFilled(<String>[_geminiApiKeyController.text]),
            children: <Widget>[
              _SecretField(
                controller: _geminiApiKeyController,
                label: 'API key',
                hint: 'AIza...',
                onSubmitted: (String v) {
                  _onFieldSubmitted(v);
                  _fetchGeminiModels();
                },
              ),
              _RevealModelSection(
                visible: _geminiApiKeyController.text.trim().isNotEmpty,
                loading: _loadingGeminiModels,
                child: _DynamicModelDropdown(
                  value: _selectedGeminiModel,
                  models: _geminiModelList,
                  loading: _loadingGeminiModels,
                  theme: theme,
                  onChanged: (String v) {
                    setState(() => _selectedGeminiModel = v);
                    _saveCurrentConfig();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          _CollapsibleIntegration(
            brandName: 'Anthropic Claude',
            brandSubtitle: 'AI-powered pull request review',
            logoAsset: null,
            brandIcon: Icons.psychology_rounded,
            brandColor: AppColors.claude,
            brandBg: AppColors.claudeLight,
            enabled: _claudeEnabled,
            canEnable: _canEnableClaude,
            isConfigured: controller.config.isClaudeConfigured,
            connectionState: controller.config.isClaudeConfigured
                ? const ConnectionState(status: ConnectionStatus.connected)
                : const ConnectionState(),
            onEnabledChanged: (bool v) {
              setState(() => _claudeEnabled = v);
              _saveCurrentConfig();
            },
            fieldCount: 1,
            filledCount: _countFilled(<String>[_claudeApiKeyController.text]),
            children: <Widget>[
              _SecretField(
                controller: _claudeApiKeyController,
                label: 'API key',
                hint: 'sk-ant-...',
                onSubmitted: (String v) {
                  _onFieldSubmitted(v);
                  _fetchClaudeModels();
                },
              ),
              _RevealModelSection(
                visible: _claudeApiKeyController.text.trim().isNotEmpty,
                loading: _loadingClaudeModels,
                child: _DynamicModelDropdown(
                  value: _selectedClaudeModel,
                  models: _claudeModelList,
                  loading: _loadingClaudeModels,
                  theme: theme,
                  onChanged: (String v) {
                    setState(() => _selectedClaudeModel = v);
                    _saveCurrentConfig();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          _CollapsibleIntegration(
            brandName: 'xAI Grok',
            brandSubtitle: 'AI-powered pull request review',
            logoAsset: null,
            brandIcon: Icons.bolt_rounded,
            brandColor: AppColors.grok,
            brandBg: AppColors.grokLight,
            enabled: _grokEnabled,
            canEnable: _canEnableGrok,
            isConfigured: controller.config.isGrokConfigured,
            connectionState: controller.config.isGrokConfigured
                ? const ConnectionState(status: ConnectionStatus.connected)
                : const ConnectionState(),
            onEnabledChanged: (bool v) {
              setState(() => _grokEnabled = v);
              _saveCurrentConfig();
            },
            fieldCount: 1,
            filledCount: _countFilled(<String>[_grokApiKeyController.text]),
            children: <Widget>[
              _SecretField(
                controller: _grokApiKeyController,
                label: 'API key',
                hint: 'xai-...',
                onSubmitted: (String v) {
                  _onFieldSubmitted(v);
                  _fetchGrokModels();
                },
              ),
              _RevealModelSection(
                visible: _grokApiKeyController.text.trim().isNotEmpty,
                loading: _loadingGrokModels,
                child: _DynamicModelDropdown(
                  value: _selectedGrokModel,
                  models: _grokModelList,
                  loading: _loadingGrokModels,
                  theme: theme,
                  onChanged: (String v) {
                    setState(() => _selectedGrokModel = v);
                    _saveCurrentConfig();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  int _countFilled(List<String> values) =>
      values.where((String v) => v.trim().isNotEmpty).length;

  Future<void> _exportConfig(BuildContext ctx) async {
    final EngiTrackController controller = EngiTrackScope.of(ctx);
    try {
      final String? path = await controller.exportConfig();
      if (!mounted) return;
      if (path != null) {
        if (!ctx.mounted) return;
        showInfoSnackBar(ctx, 'Config exported successfully.');
      }
    } catch (error) {
      if (!mounted) return;
      if (!ctx.mounted) return;
      showInfoSnackBar(ctx, 'Export failed: $error');
    }
  }

  Future<void> _importConfig(BuildContext ctx) async {
    final EngiTrackController controller = EngiTrackScope.of(ctx);
    try {
      final imported = await controller.importConfig();
      if (!mounted) return;
      if (imported == null) return;

      _didHydrate = false;
      didChangeDependencies();
      setState(() {});
      if (!ctx.mounted) return;
      showInfoSnackBar(ctx, 'Config imported and applied.');
    } on FormatException catch (error) {
      if (!mounted) return;
      if (!ctx.mounted) return;
      showInfoSnackBar(ctx, error.message);
    } catch (error) {
      if (!mounted) return;
      if (!ctx.mounted) return;
      showInfoSnackBar(ctx, 'Import failed: $error');
    }
  }
}

// ---------------------------------------------------------------------------
// Export / Import buttons
// ---------------------------------------------------------------------------

class _ExportImportButtons extends StatelessWidget {
  const _ExportImportButtons({
    required this.onExport,
    required this.onImport,
    required this.compact,
  });

  final VoidCallback onExport;
  final VoidCallback onImport;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.upload_rounded, size: 16),
              label: const Text('Export'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondaryInk,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                side: BorderSide(
                  color: AppColors.outline.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Import'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondaryInk,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                side: BorderSide(
                  color: AppColors.outline.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.upload_rounded, size: 16),
          label: const Text('Export'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.secondaryInk,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            side: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Import'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.secondaryInk,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            side: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category header separator
// ---------------------------------------------------------------------------

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: AppColors.secondaryInk),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryInk,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated reveal wrapper for the model section
// ---------------------------------------------------------------------------

class _RevealModelSection extends StatelessWidget {
  const _RevealModelSection({
    required this.visible,
    required this.loading,
    required this.child,
  });

  final bool visible;
  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionLabel(
            label: 'Model',
            trailing: loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dynamic model dropdown
// ---------------------------------------------------------------------------

class _DynamicModelDropdown extends StatelessWidget {
  const _DynamicModelDropdown({
    required this.value,
    required this.models,
    required this.loading,
    required this.theme,
    required this.onChanged,
  });

  final String value;
  final List<({String value, String label})> models;
  final bool loading;
  final ThemeData theme;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool disabled = loading || models.isEmpty;
    final String displayValue = models.any((m) => m.value == value)
        ? value
        : (models.isNotEmpty ? models.first.value : value);

    if (disabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.softSurface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.psychology_outlined,
              size: 18,
              color: AppColors.tertiaryInk,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loading ? 'Loading models...' : 'Enter API key to load models',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: AppColors.tertiaryInk,
                ),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: displayValue,
      icon: const Icon(Icons.unfold_more_rounded, size: 18),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.softSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        prefixIcon: const Icon(Icons.psychology_outlined, size: 18),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      isExpanded: true,
      selectedItemBuilder: (BuildContext ctx) => models
          .map(
            (m) => Align(
              alignment: Alignment.centerLeft,
              child: Text(m.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      items: models
          .map(
            (m) => DropdownMenuItem<String>(
              value: m.value,
              child: Text(
                m.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (String? v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// General settings card
// ---------------------------------------------------------------------------

class _GeneralSettingsCard extends StatelessWidget {
  const _GeneralSettingsCard({
    required this.theme,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    required this.onRequestNotifications,
  });

  final ThemeData theme;
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;
  final VoidCallback onRequestNotifications;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: AppColors.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Alert notifications',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 13),
                ),
                Text(
                  'Slack alerts as local notifications',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: FittedBox(
              child: Switch.adaptive(
                value: notificationsEnabled,
                onChanged: onNotificationsChanged,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 30,
            width: 30,
            child: IconButton(
              onPressed: onRequestNotifications,
              icon: const Icon(Icons.notifications_active_rounded, size: 16),
              padding: EdgeInsets.zero,
              tooltip: 'Request permissions',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.softSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsible integration card
// ---------------------------------------------------------------------------

class _CollapsibleIntegration extends StatefulWidget {
  const _CollapsibleIntegration({
    required this.brandName,
    required this.brandSubtitle,
    this.logoAsset,
    this.brandIcon,
    required this.brandColor,
    required this.brandBg,
    required this.enabled,
    required this.canEnable,
    required this.isConfigured,
    required this.connectionState,
    required this.onEnabledChanged,
    required this.children,
    this.syncMinutes,
    this.onSyncMinutesChanged,
    this.onTestConnection,
    this.fieldCount = 0,
    this.filledCount = 0,
  });

  final String brandName;
  final String brandSubtitle;
  final String? logoAsset;
  final IconData? brandIcon;
  final Color brandColor;
  final Color brandBg;
  final bool enabled;
  final bool canEnable;
  final bool isConfigured;
  final ConnectionState connectionState;
  final ValueChanged<bool> onEnabledChanged;
  final List<Widget> children;
  final int? syncMinutes;
  final ValueChanged<int>? onSyncMinutesChanged;
  final VoidCallback? onTestConnection;
  final int fieldCount;
  final int filledCount;

  @override
  State<_CollapsibleIntegration> createState() =>
      _CollapsibleIntegrationState();
}

class _CollapsibleIntegrationState extends State<_CollapsibleIntegration>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double progress =
        widget.fieldCount > 0 ? widget.filledCount / widget.fieldCount : 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.enabled
              ? (widget.connectionState.status == ConnectionStatus.error
                  ? AppColors.error.withValues(alpha: 0.35)
                  : widget.connectionState.status ==
                          ConnectionStatus.connected
                      ? AppColors.success.withValues(alpha: 0.25)
                      : widget.brandColor.withValues(alpha: 0.15))
              : AppColors.outline.withValues(alpha: 0.4),
          width: 0.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.enabled ? 0.04 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: <Widget>[
                  _BrandAvatar(
                    logoAsset: widget.logoAsset,
                    brandIcon: widget.brandIcon,
                    brandColor: widget.brandColor,
                    brandBg: widget.brandBg,
                    enabled: widget.enabled,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              widget.brandName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 14,
                                color: widget.enabled
                                    ? AppColors.ink
                                    : AppColors.tertiaryInk,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(
                              enabled: widget.enabled,
                              isConfigured: widget.isConfigured,
                              connectionState: widget.connectionState,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.brandSubtitle,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: widget.enabled
                                ? AppColors.secondaryInk
                                : AppColors.tertiaryInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    child: FittedBox(
                      child: Switch.adaptive(
                        value: widget.enabled,
                        onChanged:
                            widget.canEnable ? widget.onEnabledChanged : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 22,
                      color: widget.enabled
                          ? AppColors.secondaryInk
                          : AppColors.tertiaryInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.enabled) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.connectionState.status ==
                                ConnectionStatus.error
                            ? AppColors.error
                            : widget.connectionState.status ==
                                    ConnectionStatus.connected
                                ? AppColors.success
                                : widget.brandColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Text(
                        '${widget.filledCount}/${widget.fieldCount} fields',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      if (widget.syncMinutes != null &&
                          widget.onSyncMinutesChanged != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.sync_rounded,
                              size: 11,
                              color: AppColors.tertiaryInk,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'every ',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontSize: 10,
                              ),
                            ),
                            _SyncIntervalDropdown(
                              value: widget.syncMinutes!,
                              onChanged: widget.onSyncMinutesChanged!,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 8),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.softSurface,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.children,
                    ),
                  ),
                  if (widget.isConfigured &&
                      widget.onTestConnection != null) ...<Widget>[
                    const SizedBox(height: 10),
                    _TestConnectionButton(
                      connectionState: widget.connectionState,
                      onPressed: widget.onTestConnection!,
                      brandColor: widget.brandColor,
                    ),
                  ],
                  if (widget.connectionState.status ==
                          ConnectionStatus.error &&
                      widget.connectionState.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 14,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.connectionState.errorMessage!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small reusable widgets
// ---------------------------------------------------------------------------

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({
    required this.logoAsset,
    required this.brandIcon,
    required this.brandColor,
    required this.brandBg,
    required this.enabled,
  });

  final String? logoAsset;
  final IconData? brandIcon;
  final Color brandColor;
  final Color brandBg;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final double opacity = enabled ? 1.0 : 0.4;
    if (logoAsset != null) {
      return Opacity(
        opacity: opacity,
        child: BrandLogo(
          assetPath: logoAsset!,
          size: 38,
          backgroundColor: brandBg,
          padding: 8,
        ),
      );
    }
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: brandBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          brandIcon ?? Icons.extension_rounded,
          color: brandColor,
          size: 18,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.enabled,
    required this.isConfigured,
    required this.connectionState,
  });

  final bool enabled;
  final bool isConfigured;
  final ConnectionState connectionState;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _buildChip(
        'Disabled',
        AppColors.tertiaryInk,
        AppColors.softSurface,
      );
    }
    if (!isConfigured) {
      return _buildChip(
        'Not set up',
        AppColors.warning,
        AppColors.warningLight,
      );
    }
    switch (connectionState.status) {
      case ConnectionStatus.connected:
        return _buildChip(
          'Connected',
          AppColors.success,
          AppColors.successLight,
        );
      case ConnectionStatus.error:
        return _buildChip('Error', AppColors.error, AppColors.errorLight);
      case ConnectionStatus.testing:
        return _buildChip(
          'Testing...',
          AppColors.tertiaryInk,
          AppColors.softSurface,
        );
      case ConnectionStatus.untested:
        return _buildChip(
          'Not verified',
          AppColors.warning,
          AppColors.warningLight,
        );
    }
  }

  Widget _buildChip(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _TestConnectionButton extends StatelessWidget {
  const _TestConnectionButton({
    required this.connectionState,
    required this.onPressed,
    required this.brandColor,
  });

  final ConnectionState connectionState;
  final VoidCallback onPressed;
  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    final bool isTesting =
        connectionState.status == ConnectionStatus.testing;

    return SizedBox(
      width: double.infinity,
      height: 34,
      child: OutlinedButton.icon(
        onPressed: isTesting ? null : onPressed,
        icon: isTesting
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            : Icon(
                connectionState.status == ConnectionStatus.connected
                    ? Icons.check_circle_outline_rounded
                    : Icons.wifi_tethering_rounded,
                size: 14,
              ),
        label: Text(
          isTesting
              ? 'Testing...'
              : connectionState.status == ConnectionStatus.connected
                  ? 'Re-test connection'
                  : 'Test connection',
          style: const TextStyle(fontSize: 11),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: brandColor,
          side: BorderSide(color: brandColor.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 12,
                color: AppColors.secondaryInk,
              ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncIntervalDropdown extends StatelessWidget {
  const _SyncIntervalDropdown({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const List<int> _options = <int>[1, 2, 5, 10, 15, 30];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.outline, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _options.contains(value) ? value : 5,
          isDense: true,
          style: const TextStyle(fontSize: 11, color: AppColors.ink),
          items: _options
              .map(
                (int v) =>
                    DropdownMenuItem<int>(value: v, child: Text('$v min')),
              )
              .toList(),
          onChanged: (int? v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Channel chip input
// ---------------------------------------------------------------------------

class _ChannelChipInput extends StatefulWidget {
  const _ChannelChipInput({
    required this.selectedChannels,
    required this.cachedChannels,
    required this.onChanged,
  });

  final List<String> selectedChannels;
  final Map<String, String>? cachedChannels;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ChannelChipInput> createState() => _ChannelChipInputState();
}

class _ChannelChipInputState extends State<_ChannelChipInput> {
  final TextEditingController _textController = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _addChannel(String channel) {
    final String cleaned = channel.trim().replaceFirst('#', '');
    if (cleaned.isEmpty) return;

    if (widget.cachedChannels != null &&
        !widget.cachedChannels!.containsKey(cleaned)) {
      setState(
        () => _validationError = '"$cleaned" not found in your workspace',
      );
      return;
    }

    if (widget.selectedChannels.contains(cleaned)) return;

    setState(() => _validationError = null);
    widget.onChanged(<String>[...widget.selectedChannels, cleaned]);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.selectedChannels.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              for (final String ch in widget.selectedChannels)
                InputChip(
                  label: Text('#$ch', style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    final List<String> updated = List<String>.from(
                      widget.selectedChannels,
                    )..remove(ch);
                    widget.onChanged(updated);
                  },
                  backgroundColor: AppColors.slackLight,
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (widget.cachedChannels != null)
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue value) {
              if (value.text.trim().isEmpty) {
                return const Iterable<String>.empty();
              }
              final String query =
                  value.text.trim().replaceFirst('#', '').toLowerCase();
              return widget.cachedChannels!.keys
                  .where((String name) => name.toLowerCase().contains(query))
                  .take(15);
            },
            displayStringForOption: (String option) => '#$option',
            onSelected: _addChannel,
            fieldViewBuilder: (
              BuildContext ctx,
              TextEditingController ctrl,
              FocusNode node,
              VoidCallback onSubmit,
            ) {
              return TextField(
                controller: ctrl,
                focusNode: node,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search channels...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: AppColors.tertiaryInk,
                  ),
                  fillColor: AppColors.surface,
                  isDense: true,
                ),
                onSubmitted: (_) {
                  if (ctrl.text.trim().isNotEmpty) _addChannel(ctrl.text);
                },
              );
            },
          )
        else
          TextField(
            controller: _textController,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: '#eng-reviews (load channels for autocomplete)',
              prefixIcon: Icon(
                Icons.tag_rounded,
                size: 16,
                color: AppColors.tertiaryInk,
              ),
              fillColor: AppColors.surface,
            ),
            onSubmitted: (String value) {
              for (final String ch in ConnectorConfig.parseChannelsInput(
                value,
              )) {
                _addChannel(ch);
              }
            },
          ),
        if (_validationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _validationError!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.danger,
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Form field helpers
// ---------------------------------------------------------------------------

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.prefixIcon,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 16, color: AppColors.tertiaryInk)
            : null,
        fillColor: AppColors.surface,
      ),
      onSubmitted: onSubmitted,
    );
  }
}

class _SecretField extends StatefulWidget {
  const _SecretField({
    required this.controller,
    required this.label,
    required this.hint,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: const Icon(
          Icons.key_rounded,
          size: 16,
          color: AppColors.tertiaryInk,
        ),
        fillColor: AppColors.surface,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            size: 16,
            color: AppColors.tertiaryInk,
          ),
        ),
      ),
      onSubmitted: widget.onSubmitted,
    );
  }
}
