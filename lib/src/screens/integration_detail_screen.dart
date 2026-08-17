import 'dart:async';

import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

// ---------------------------------------------------------------------------
// Integration descriptors shared by the hub and the detail screen
// ---------------------------------------------------------------------------

class IntegrationSpec {
  const IntegrationSpec({
    required this.id,
    required this.name,
    required this.subtitle,
    this.logoAsset,
    this.icon,
    required this.color,
    required this.bgColor,
  });

  final String id;
  final String name;
  final String subtitle;
  final String? logoAsset;
  final IconData? icon;
  final Color color;
  final Color bgColor;

  static IntegrationSpec byId(String id) =>
      kIntegrationSpecs.firstWhere((IntegrationSpec spec) => spec.id == id);
}

const List<IntegrationSpec> kIntegrationSpecs = <IntegrationSpec>[
  IntegrationSpec(
    id: 'github',
    name: 'GitHub',
    subtitle: 'Pull request reviews & AI code analysis',
    logoAsset: 'assets/logos/github.svg',
    color: AppColors.github,
    bgColor: AppColors.githubLight,
  ),
  IntegrationSpec(
    id: 'jira',
    name: 'Jira',
    subtitle: 'Track assigned tickets via JQL queries',
    logoAsset: 'assets/logos/jira.svg',
    color: AppColors.jira,
    bgColor: AppColors.jiraLight,
  ),
  IntegrationSpec(
    id: 'slack',
    name: 'Slack',
    subtitle: 'Review channels, alerts & DM mentions',
    logoAsset: 'assets/logos/slack.svg',
    color: AppColors.slack,
    bgColor: AppColors.slackLight,
  ),
  IntegrationSpec(
    id: 'openai',
    name: 'OpenAI',
    subtitle: 'AI-powered pull request review',
    icon: Icons.auto_awesome_rounded,
    color: AppColors.openai,
    bgColor: AppColors.openaiLight,
  ),
  IntegrationSpec(
    id: 'gemini',
    name: 'Google Gemini',
    subtitle: 'AI-powered pull request review',
    icon: Icons.diamond_outlined,
    color: AppColors.gemini,
    bgColor: AppColors.geminiLight,
  ),
  IntegrationSpec(
    id: 'claude',
    name: 'Anthropic Claude',
    subtitle: 'AI-powered pull request review',
    icon: Icons.psychology_rounded,
    color: AppColors.claude,
    bgColor: AppColors.claudeLight,
  ),
  IntegrationSpec(
    id: 'grok',
    name: 'xAI Grok',
    subtitle: 'AI-powered pull request review',
    icon: Icons.bolt_rounded,
    color: AppColors.grok,
    bgColor: AppColors.grokLight,
  ),
  IntegrationSpec(
    id: 'cursor',
    name: 'Cursor',
    subtitle: 'Cloud agent reviews PRs in a Cursor-hosted VM',
    icon: Icons.computer_rounded,
    color: AppColors.cursor,
    bgColor: AppColors.cursorLight,
  ),
];

const Set<String> kAiIntegrationIds = <String>{
  'openai',
  'gemini',
  'claude',
  'grok',
  'cursor',
};

const Set<String> kSyncIntegrationIds = <String>{'github', 'jira', 'slack'};

bool integrationEnabled(ConnectorConfig config, String id) {
  switch (id) {
    case 'github':
      return config.githubEnabled;
    case 'jira':
      return config.jiraEnabled;
    case 'slack':
      return config.slackEnabled;
    case 'openai':
      return config.openAiEnabled;
    case 'gemini':
      return config.geminiEnabled;
    case 'claude':
      return config.claudeEnabled;
    case 'grok':
      return config.grokEnabled;
    case 'cursor':
      return config.cursorEnabled;
    default:
      return false;
  }
}

/// Whether the required fields exist so the enable switch can be turned on.
bool integrationCanEnable(ConnectorConfig config, String id) {
  switch (id) {
    case 'github':
      return config.githubUsername.trim().isNotEmpty &&
          config.githubToken.trim().isNotEmpty;
    case 'jira':
      return config.jiraBaseUrl.trim().isNotEmpty &&
          config.jiraEmail.trim().isNotEmpty &&
          config.jiraApiToken.trim().isNotEmpty;
    case 'slack':
      return config.slackToken.trim().isNotEmpty;
    case 'openai':
      return config.openAiApiKey.trim().isNotEmpty ||
          config.openAiProxyUrl.trim().isNotEmpty;
    case 'gemini':
      return config.geminiApiKey.trim().isNotEmpty;
    case 'claude':
      return config.claudeApiKey.trim().isNotEmpty;
    case 'grok':
      return config.grokApiKey.trim().isNotEmpty;
    case 'cursor':
      return config.cursorApiKey.trim().isNotEmpty;
    default:
      return false;
  }
}

bool integrationIsConfigured(ConnectorConfig config, String id) {
  switch (id) {
    case 'github':
      return config.isGitHubConfigured;
    case 'jira':
      return config.isJiraConfigured;
    case 'slack':
      return config.isSlackConfigured;
    case 'openai':
      return config.isOpenAiConfigured;
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

// ---------------------------------------------------------------------------
// Status chip (used by the hub rows and the detail screen)
// ---------------------------------------------------------------------------

class IntegrationStatusChip extends StatelessWidget {
  const IntegrationStatusChip({
    super.key,
    required this.enabled,
    required this.isConfigured,
    required this.health,
  });

  final bool enabled;
  final bool isConfigured;
  final IntegrationHealth health;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _chip('Disabled', AppColors.tertiaryInk, AppColors.softSurface);
    }
    if (!isConfigured) {
      return _chip('Setup required', AppColors.warning, AppColors.warningLight);
    }
    switch (health.status) {
      case IntegrationStatus.checking:
        return _chip(
          'Verifying...',
          AppColors.info,
          AppColors.infoLight,
          spinner: true,
        );
      case IntegrationStatus.connected:
        return _chip('Connected', AppColors.success, AppColors.successLight);
      case IntegrationStatus.error:
        return _chip(
          'Connection failed',
          AppColors.danger,
          AppColors.dangerLight,
        );
      case IntegrationStatus.unknown:
        return _chip(
          'Not verified',
          AppColors.secondaryInk,
          AppColors.softSurface,
        );
    }
  }

  Widget _chip(String label, Color fg, Color bg, {bool spinner = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (spinner) ...<Widget>[
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(strokeWidth: 1.4, color: fg),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class IntegrationAvatar extends StatelessWidget {
  const IntegrationAvatar({
    super.key,
    required this.spec,
    required this.enabled,
    this.size = 38,
  });

  final IntegrationSpec spec;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = spec.logoAsset != null
        ? BrandLogo(
            assetPath: spec.logoAsset!,
            size: size,
            backgroundColor: spec.bgColor,
            padding: size * 0.21,
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: spec.bgColor,
              borderRadius: BorderRadius.circular(size * 0.26),
            ),
            child: Icon(
              spec.icon ?? Icons.extension_rounded,
              color: spec.color,
              size: size * 0.47,
            ),
          );
    return Opacity(opacity: enabled ? 1.0 : 0.4, child: avatar);
  }
}

// ---------------------------------------------------------------------------
// Detail screen
// ---------------------------------------------------------------------------

class IntegrationDetailScreen extends StatefulWidget {
  const IntegrationDetailScreen({super.key, required this.integrationId});

  final String integrationId;

  @override
  State<IntegrationDetailScreen> createState() =>
      _IntegrationDetailScreenState();
}

class _IntegrationDetailScreenState extends State<IntegrationDetailScreen> {
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};
  final AiModelService _aiModelService = AiModelService();

  bool _didHydrate = false;
  bool _slackTokenIsRotating = false;
  int _syncMinutes = 5;

  String _selectedModel = '';
  List<({String value, String label})> _models =
      <({String value, String label})>[];
  bool _loadingModels = false;
  String? _modelsError;

  List<String> _slackReviewChannels = <String>[];
  Map<String, String>? _cachedChannelList;
  bool _loadingChannels = false;

  String get _id => widget.integrationId;
  IntegrationSpec get _spec => IntegrationSpec.byId(_id);
  bool get _isAi => kAiIntegrationIds.contains(_id);
  bool get _isSync => kSyncIntegrationIds.contains(_id);

  TextEditingController _field(String key) =>
      _fields.putIfAbsent(key, TextEditingController.new);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didHydrate) return;
    _didHydrate = true;

    final ConnectorConfig config = EngiTrackScope.of(context).config;
    switch (_id) {
      case 'github':
        _field('username').text = config.githubUsername;
        _field('token').text = config.githubToken;
        _syncMinutes = config.githubSyncMinutes;
      case 'jira':
        _field('baseUrl').text = config.jiraBaseUrl;
        _field('email').text = config.jiraEmail;
        _field('apiToken').text = config.jiraApiToken;
        _syncMinutes = config.jiraSyncMinutes;
      case 'slack':
        _field('token').text = config.slackToken;
        _field('refreshToken').text = config.slackRefreshToken;
        _field('clientId').text = config.slackClientId;
        _field('clientSecret').text = config.slackClientSecret;
        _field('alertChannel').text = config.slackAlertChannel;
        _slackReviewChannels = List<String>.from(config.slackReviewChannels);
        _slackTokenIsRotating = config.isSlackTokenRotating;
        _syncMinutes = config.slackSyncMinutes;
        _field('token').addListener(_onSlackTokenChanged);
      case 'openai':
        _field('apiKey').text = config.openAiApiKey;
        _selectedModel = config.openAiModel;
      case 'gemini':
        _field('apiKey').text = config.geminiApiKey;
        _selectedModel = config.geminiModel;
      case 'claude':
        _field('apiKey').text = config.claudeApiKey;
        _selectedModel = config.claudeModel;
      case 'grok':
        _field('apiKey').text = config.grokApiKey;
        _selectedModel = config.grokModel;
      case 'cursor':
        _field('apiKey').text = config.cursorApiKey;
        _selectedModel = config.cursorModel;
    }

    // Passive model load: only for an enabled provider with a key. Failures
    // surface inline, never as a toast.
    if (_isAi &&
        integrationEnabled(config, _id) &&
        _field('apiKey').text.trim().isNotEmpty) {
      _fetchModels();
    }
  }

  void _onSlackTokenChanged() {
    final bool rotating = _field('token').text.trim().startsWith('xoxe.');
    if (rotating != _slackTokenIsRotating) {
      setState(() => _slackTokenIsRotating = rotating);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Saving
  // ---------------------------------------------------------------------

  ConnectorConfig _applyFields(ConnectorConfig config) {
    switch (_id) {
      case 'github':
        return config.copyWith(
          githubUsername: _field('username').text.trim(),
          githubToken: _field('token').text.trim(),
          githubSyncMinutes: _syncMinutes,
        );
      case 'jira':
        return config.copyWith(
          jiraBaseUrl: _field('baseUrl').text.trim(),
          jiraEmail: _field('email').text.trim(),
          jiraApiToken: _field('apiToken').text.trim(),
          jiraSyncMinutes: _syncMinutes,
        );
      case 'slack':
        return config.copyWith(
          slackToken: _field('token').text.trim(),
          slackRefreshToken: _field('refreshToken').text.trim(),
          slackClientId: _field('clientId').text.trim(),
          slackClientSecret: _field('clientSecret').text.trim(),
          slackAlertChannel: _field('alertChannel').text.trim(),
          slackReviewChannels: _slackReviewChannels,
          slackSyncMinutes: _syncMinutes,
        );
      case 'openai':
        return config.copyWith(
          openAiApiKey: _field('apiKey').text.trim(),
          openAiModel: _selectedModel,
        );
      case 'gemini':
        return config.copyWith(
          geminiApiKey: _field('apiKey').text.trim(),
          geminiModel: _selectedModel,
        );
      case 'claude':
        return config.copyWith(
          claudeApiKey: _field('apiKey').text.trim(),
          claudeModel: _selectedModel,
        );
      case 'grok':
        return config.copyWith(
          grokApiKey: _field('apiKey').text.trim(),
          grokModel: _selectedModel,
        );
      case 'cursor':
        return config.copyWith(
          cursorApiKey: _field('apiKey').text.trim(),
          cursorModel: _selectedModel,
        );
      default:
        return config;
    }
  }

  /// Persists the current form values. Changed credentials of an *enabled*
  /// integration are verified by the controller; disabled ones are only
  /// stored -- no network call happens for them.
  Future<void> _save({bool showToast = true}) async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    try {
      await controller.updateConfig(
        _applyFields(controller.config),
        refresh: false,
      );
    } catch (_) {}
    if (showToast && mounted) showInfoSnackBar(context, 'Saved.');
  }

  void _onFieldSubmitted(String value) {
    _save();
    if (_isAi && integrationEnabled(EngiTrackScope.of(context).config, _id)) {
      _fetchModels();
    }
  }

  // ---------------------------------------------------------------------
  // Enable / disable
  // ---------------------------------------------------------------------

  Future<void> _setEnabled(bool value) async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    // Persist edits first so verification uses the latest values.
    await controller.updateConfig(
      _applyFields(controller.config),
      refresh: false,
      verifyChanged: false,
    );
    if (!mounted) return;

    final bool ok = await controller.setIntegrationEnabled(_id, value);
    if (!mounted) return;
    if (value && !ok) {
      final String message = controller.healthFor(_id).message;
      showInfoSnackBar(
        context,
        message.isEmpty ? '${_spec.name} connection failed.' : message,
      );
    }
    if (value && ok && _isAi) {
      unawaited(_fetchModels());
    }
  }

  // ---------------------------------------------------------------------
  // AI model loading
  // ---------------------------------------------------------------------

  Future<List<({String value, String label})>> _fetchModelsForProvider(
    String apiKey,
  ) {
    switch (_id) {
      case 'openai':
        return _aiModelService.fetchOpenAiModels(apiKey: apiKey);
      case 'gemini':
        return _aiModelService.fetchGeminiModels(apiKey: apiKey);
      case 'claude':
        return _aiModelService.fetchClaudeModels(apiKey: apiKey);
      case 'grok':
        return _aiModelService.fetchGrokModels(apiKey: apiKey);
      case 'cursor':
        return _aiModelService.fetchCursorModels(apiKey: apiKey);
      default:
        throw ServiceException('Not an AI integration.');
    }
  }

  Future<void> _fetchModels({bool userInitiated = false}) async {
    final String key = _field('apiKey').text.trim();
    if (key.isEmpty) return;
    if (!integrationEnabled(EngiTrackScope.of(context).config, _id)) return;

    setState(() => _loadingModels = true);
    try {
      final List<({String value, String label})> models =
          await _fetchModelsForProvider(key);
      if (!mounted) return;
      setState(() {
        _models = models;
        _modelsError = null;
        if (models.isNotEmpty &&
            !models.any((m) => m.value == _selectedModel)) {
          _selectedModel = models.first.value;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _modelsError = _friendlyModelsError(error));
      if (userInitiated) showInfoSnackBar(context, _modelsError!);
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  String _friendlyModelsError(Object error) {
    final String message = error.toString();
    if (_id == 'grok' &&
        (message.contains('credits') ||
            message.contains('license') ||
            message.contains('permission'))) {
      return 'Activate API credits at console.x.ai to load models.';
    }
    return 'Could not load models. ${message.length > 120 ? '' : message}'
        .trim();
  }

  // ---------------------------------------------------------------------
  // Slack channels
  // ---------------------------------------------------------------------

  Future<void> _fetchSlackChannels() async {
    final String token = _field('token').text.trim();
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

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final ConnectorConfig config = controller.config;
    final bool enabled = integrationEnabled(config, _id);
    final bool canEnable = integrationCanEnable(config, _id);
    final IntegrationHealth health = controller.healthFor(_id);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            IntegrationAvatar(spec: _spec, enabled: true, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _spec.name,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          SizedBox(
            height: 28,
            child: FittedBox(
              child: Switch.adaptive(
                value: enabled,
                onChanged: (enabled || canEnable) ? _setEnabled : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _StatusCard(
                spec: _spec,
                enabled: enabled,
                isConfigured: integrationIsConfigured(config, _id),
                health: health,
              ),
              const SizedBox(height: 12),
              AppSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const FieldSectionLabel(label: 'Credentials'),
                    const SizedBox(height: 12),
                    ..._buildCredentialFields(),
                  ],
                ),
              ),
              if (_isAi) ...<Widget>[
                const SizedBox(height: 12),
                _buildModelSection(enabled),
              ],
              if (_id == 'slack') ...<Widget>[
                const SizedBox(height: 12),
                _buildSlackChannelsSection(),
              ],
              if (_isSync) ...<Widget>[
                const SizedBox(height: 12),
                _buildSyncIntervalSection(),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCredentialFields() {
    switch (_id) {
      case 'github':
        return <Widget>[
          LabeledTextField(
            controller: _field('username'),
            label: 'Username',
            hint: 'your-username',
            prefixIcon: Icons.person_outline_rounded,
            onSubmitted: _onFieldSubmitted,
          ),
          const SizedBox(height: 10),
          SecretTextField(
            controller: _field('token'),
            label: 'Personal access token',
            hint: 'ghp_...',
            onSubmitted: _onFieldSubmitted,
          ),
        ];
      case 'jira':
        return <Widget>[
          LabeledTextField(
            controller: _field('baseUrl'),
            label: 'Atlassian site URL',
            hint: 'https://your-team.atlassian.net',
            keyboardType: TextInputType.url,
            prefixIcon: Icons.link_rounded,
            onSubmitted: _onFieldSubmitted,
          ),
          const SizedBox(height: 10),
          LabeledTextField(
            controller: _field('email'),
            label: 'Email',
            hint: 'you@company.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            onSubmitted: _onFieldSubmitted,
          ),
          const SizedBox(height: 10),
          SecretTextField(
            controller: _field('apiToken'),
            label: 'API token',
            hint: 'Atlassian API token',
            onSubmitted: _onFieldSubmitted,
          ),
        ];
      case 'slack':
        return <Widget>[
          SecretTextField(
            controller: _field('token'),
            label: 'Bot token',
            hint: 'xoxb-... or xoxe.xoxp-...',
            onSubmitted: _onFieldSubmitted,
          ),
          if (_slackTokenIsRotating) ...<Widget>[
            const SizedBox(height: 10),
            SecretTextField(
              controller: _field('refreshToken'),
              label: 'Refresh token',
              hint: 'xoxe-1-...',
              onSubmitted: _onFieldSubmitted,
            ),
            const SizedBox(height: 10),
            LabeledTextField(
              controller: _field('clientId'),
              label: 'Client ID',
              hint: '1234567890.1234567890',
              prefixIcon: Icons.badge_outlined,
              onSubmitted: _onFieldSubmitted,
            ),
            const SizedBox(height: 10),
            SecretTextField(
              controller: _field('clientSecret'),
              label: 'Client secret',
              hint: 'f2f77b...',
              onSubmitted: _onFieldSubmitted,
            ),
          ],
        ];
      default:
        return <Widget>[
          SecretTextField(
            controller: _field('apiKey'),
            label: 'API key',
            hint: _apiKeyHint(),
            onSubmitted: _onFieldSubmitted,
          ),
        ];
    }
  }

  String _apiKeyHint() {
    switch (_id) {
      case 'openai':
        return 'sk-...';
      case 'gemini':
        return 'AIza...';
      case 'claude':
        return 'sk-ant-...';
      case 'grok':
        return 'xai-...';
      case 'cursor':
        return 'key_...';
      default:
        return 'API key';
    }
  }

  Widget _buildModelSection(bool enabled) {
    final ThemeData theme = Theme.of(context);

    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FieldSectionLabel(
            label: 'Model',
            trailing: _loadingModels
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _InlineAction(
                    label: 'Refresh models',
                    icon: Icons.refresh_rounded,
                    onTap: enabled
                        ? () async {
                            await _save(showToast: false);
                            await _fetchModels(userInitiated: true);
                          }
                        : null,
                  ),
          ),
          const SizedBox(height: 10),
          if (!enabled)
            Text(
              'Enable ${_spec.name} to load and pick a model.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: AppColors.tertiaryInk,
              ),
            )
          else if (_modelsError != null)
            Text(
              _modelsError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: AppColors.danger,
              ),
            )
          else if (_models.isEmpty)
            Text(
              _loadingModels
                  ? 'Loading models...'
                  : 'Models load automatically after the API key is saved.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: AppColors.tertiaryInk,
              ),
            )
          else
            _ModelDropdown(
              value: _selectedModel,
              models: _models,
              theme: theme,
              onChanged: (String value) {
                setState(() => _selectedModel = value);
                _save(showToast: false);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSlackChannelsSection() {
    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FieldSectionLabel(
            label: 'Review channels',
            trailing: _loadingChannels
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _InlineAction(
                    label: 'Load channels',
                    icon: Icons.refresh_rounded,
                    onTap: _fetchSlackChannels,
                  ),
          ),
          const SizedBox(height: 8),
          _ChannelChipInput(
            selectedChannels: _slackReviewChannels,
            cachedChannels: _cachedChannelList,
            onChanged: (List<String> channels) {
              setState(() => _slackReviewChannels = channels);
              _save(showToast: false);
            },
          ),
          const SizedBox(height: 12),
          LabeledTextField(
            controller: _field('alertChannel'),
            label: 'Alert channel',
            hint: '#ops-alerts',
            prefixIcon: Icons.notifications_outlined,
            onSubmitted: _onFieldSubmitted,
          ),
        ],
      ),
    );
  }

  Widget _buildSyncIntervalSection() {
    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          const Expanded(child: FieldSectionLabel(label: 'Sync interval')),
          _SyncIntervalDropdown(
            value: _syncMinutes,
            onChanged: (int value) {
              setState(() => _syncMinutes = value);
              _save(showToast: false);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status card
// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.spec,
    required this.enabled,
    required this.isConfigured,
    required this.health,
  });

  final IntegrationSpec spec;
  final bool enabled;
  final bool isConfigured;
  final IntegrationHealth health;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool showMessage = enabled &&
        health.message.isNotEmpty &&
        (health.isError || health.isConnected);

    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(spec.subtitle, style: theme.textTheme.labelMedium),
              ),
              const SizedBox(width: 8),
              IntegrationStatusChip(
                enabled: enabled,
                isConfigured: isConfigured,
                health: health,
              ),
            ],
          ),
          if (showMessage) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              health.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color:
                    health.isError ? AppColors.danger : AppColors.secondaryInk,
              ),
            ),
          ],
          if (enabled && health.checkedAt != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Checked ${formatRelativeTime(health.checkedAt!)}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.tertiaryInk,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color color =
        onTap == null ? AppColors.tertiaryInk : AppColors.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({
    required this.value,
    required this.models,
    required this.theme,
    required this.onChanged,
  });

  final String value;
  final List<({String value, String label})> models;
  final ThemeData theme;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final String displayValue =
        models.any((m) => m.value == value) ? value : models.first.value;

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

class _SyncIntervalDropdown extends StatelessWidget {
  const _SyncIntervalDropdown({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const List<int> _options = <int>[1, 2, 5, 10, 15, 30];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _options.contains(value) ? value : 5,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: AppColors.ink),
          items: _options
              .map(
                (int v) => DropdownMenuItem<int>(
                  value: v,
                  child: Text('every $v min'),
                ),
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
