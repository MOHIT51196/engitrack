import 'dart:convert';

enum SlackReviewKind { pr, doc }

enum AlertSeverity { critical, high, medium, info }

class ConnectorConfig {
  const ConnectorConfig({
    this.notificationsEnabled = false,
    this.githubEnabled = false,
    this.jiraEnabled = false,
    this.slackEnabled = false,
    this.openAiEnabled = false,
    this.geminiEnabled = false,
    this.claudeEnabled = false,
    this.githubUsername = '',
    this.githubToken = '',
    this.jiraBaseUrl = '',
    this.jiraEmail = '',
    this.jiraApiToken = '',
    this.slackReviewChannels = const <String>[],
    this.slackAlertChannel = '',
    this.slackToken = '',
    this.slackRefreshToken = '',
    this.slackClientId = '',
    this.slackClientSecret = '',
    this.openAiApiKey = '',
    this.openAiProxyUrl = '',
    this.openAiModel = 'gpt-4.1-mini',
    this.geminiApiKey = '',
    this.geminiModel = 'gemini-2.0-flash',
    this.claudeApiKey = '',
    this.claudeModel = 'claude-sonnet-4-20250514',
    this.githubSyncMinutes = 5,
    this.jiraSyncMinutes = 5,
    this.slackSyncMinutes = 5,
  });

  final bool notificationsEnabled;
  final bool githubEnabled;
  final bool jiraEnabled;
  final bool slackEnabled;
  final bool openAiEnabled;
  final bool geminiEnabled;
  final bool claudeEnabled;
  final String githubUsername;
  final String githubToken;
  final String jiraBaseUrl;
  final String jiraEmail;
  final String jiraApiToken;
  final List<String> slackReviewChannels;
  final String slackAlertChannel;
  final String slackToken;
  final String slackRefreshToken;
  final String slackClientId;
  final String slackClientSecret;
  final String openAiApiKey;
  final String openAiProxyUrl;
  final String openAiModel;
  final String geminiApiKey;
  final String geminiModel;
  final String claudeApiKey;
  final String claudeModel;
  final int githubSyncMinutes;
  final int jiraSyncMinutes;
  final int slackSyncMinutes;

  ConnectorConfig copyWith({
    bool? notificationsEnabled,
    bool? githubEnabled,
    bool? jiraEnabled,
    bool? slackEnabled,
    bool? openAiEnabled,
    bool? geminiEnabled,
    bool? claudeEnabled,
    String? githubUsername,
    String? githubToken,
    String? jiraBaseUrl,
    String? jiraEmail,
    String? jiraApiToken,
    List<String>? slackReviewChannels,
    String? slackAlertChannel,
    String? slackToken,
    String? slackRefreshToken,
    String? slackClientId,
    String? slackClientSecret,
    String? openAiApiKey,
    String? openAiProxyUrl,
    String? openAiModel,
    String? geminiApiKey,
    String? geminiModel,
    String? claudeApiKey,
    String? claudeModel,
    int? githubSyncMinutes,
    int? jiraSyncMinutes,
    int? slackSyncMinutes,
  }) {
    return ConnectorConfig(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      githubEnabled: githubEnabled ?? this.githubEnabled,
      jiraEnabled: jiraEnabled ?? this.jiraEnabled,
      slackEnabled: slackEnabled ?? this.slackEnabled,
      openAiEnabled: openAiEnabled ?? this.openAiEnabled,
      geminiEnabled: geminiEnabled ?? this.geminiEnabled,
      claudeEnabled: claudeEnabled ?? this.claudeEnabled,
      githubUsername: githubUsername ?? this.githubUsername,
      githubToken: githubToken ?? this.githubToken,
      jiraBaseUrl: jiraBaseUrl ?? this.jiraBaseUrl,
      jiraEmail: jiraEmail ?? this.jiraEmail,
      jiraApiToken: jiraApiToken ?? this.jiraApiToken,
      slackReviewChannels: slackReviewChannels ?? this.slackReviewChannels,
      slackAlertChannel: slackAlertChannel ?? this.slackAlertChannel,
      slackToken: slackToken ?? this.slackToken,
      slackRefreshToken: slackRefreshToken ?? this.slackRefreshToken,
      slackClientId: slackClientId ?? this.slackClientId,
      slackClientSecret: slackClientSecret ?? this.slackClientSecret,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      openAiProxyUrl: openAiProxyUrl ?? this.openAiProxyUrl,
      openAiModel: openAiModel ?? this.openAiModel,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      claudeApiKey: claudeApiKey ?? this.claudeApiKey,
      claudeModel: claudeModel ?? this.claudeModel,
      githubSyncMinutes: githubSyncMinutes ?? this.githubSyncMinutes,
      jiraSyncMinutes: jiraSyncMinutes ?? this.jiraSyncMinutes,
      slackSyncMinutes: slackSyncMinutes ?? this.slackSyncMinutes,
    );
  }

  Map<String, dynamic> toPreferencesJson() {
    return <String, dynamic>{
      'notificationsEnabled': notificationsEnabled,
      'githubEnabled': githubEnabled,
      'jiraEnabled': jiraEnabled,
      'slackEnabled': slackEnabled,
      'openAiEnabled': openAiEnabled,
      'geminiEnabled': geminiEnabled,
      'claudeEnabled': claudeEnabled,
      'githubUsername': githubUsername,
      'jiraBaseUrl': jiraBaseUrl,
      'slackReviewChannels': slackReviewChannels,
      'slackAlertChannel': slackAlertChannel,
      'openAiProxyUrl': openAiProxyUrl,
      'openAiModel': openAiModel,
      'geminiModel': geminiModel,
      'claudeModel': claudeModel,
      'githubSyncMinutes': githubSyncMinutes,
      'jiraSyncMinutes': jiraSyncMinutes,
      'slackSyncMinutes': slackSyncMinutes,
    };
  }

  factory ConnectorConfig.fromStorage({
    Map<String, dynamic>? json,
    String githubToken = '',
    String jiraEmail = '',
    String jiraApiToken = '',
    String slackToken = '',
    String slackRefreshToken = '',
    String slackClientId = '',
    String slackClientSecret = '',
    String openAiApiKey = '',
    String geminiApiKey = '',
    String claudeApiKey = '',
  }) {
    final data = json ?? <String, dynamic>{};
    return ConnectorConfig(
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? false,
      githubEnabled: data['githubEnabled'] as bool? ?? false,
      jiraEnabled: data['jiraEnabled'] as bool? ?? false,
      slackEnabled: data['slackEnabled'] as bool? ?? false,
      openAiEnabled: data['openAiEnabled'] as bool? ?? false,
      geminiEnabled: data['geminiEnabled'] as bool? ?? false,
      claudeEnabled: data['claudeEnabled'] as bool? ?? false,
      githubUsername: data['githubUsername'] as String? ?? '',
      githubToken: githubToken,
      jiraBaseUrl: data['jiraBaseUrl'] as String? ?? '',
      jiraEmail: jiraEmail,
      jiraApiToken: jiraApiToken,
      slackReviewChannels: (data['slackReviewChannels'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(),
      slackAlertChannel: data['slackAlertChannel'] as String? ?? '',
      slackToken: slackToken,
      slackRefreshToken: slackRefreshToken,
      slackClientId: slackClientId,
      slackClientSecret: slackClientSecret,
      openAiApiKey: openAiApiKey,
      openAiProxyUrl: data['openAiProxyUrl'] as String? ?? '',
      openAiModel: data['openAiModel'] as String? ?? 'gpt-4.1-mini',
      geminiApiKey: geminiApiKey,
      geminiModel: data['geminiModel'] as String? ?? 'gemini-2.0-flash',
      claudeApiKey: claudeApiKey,
      claudeModel: data['claudeModel'] as String? ?? 'claude-sonnet-4-20250514',
      githubSyncMinutes: data['githubSyncMinutes'] as int? ?? 5,
      jiraSyncMinutes: data['jiraSyncMinutes'] as int? ?? 5,
      slackSyncMinutes: data['slackSyncMinutes'] as int? ?? 5,
    );
  }

  static List<String> parseChannelsInput(String raw) {
    return raw
        .split(RegExp(r'[,\n]'))
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toExportJson() {
    return <String, dynamic>{
      '_format': 'engitrack_integrations_v1',
      'notificationsEnabled': notificationsEnabled,
      'githubEnabled': githubEnabled,
      'jiraEnabled': jiraEnabled,
      'slackEnabled': slackEnabled,
      'openAiEnabled': openAiEnabled,
      'githubUsername': githubUsername,
      'githubToken': githubToken,
      'jiraBaseUrl': jiraBaseUrl,
      'jiraEmail': jiraEmail,
      'jiraApiToken': jiraApiToken,
      'slackReviewChannels': slackReviewChannels,
      'slackAlertChannel': slackAlertChannel,
      'slackToken': slackToken,
      'slackRefreshToken': slackRefreshToken,
      'slackClientId': slackClientId,
      'slackClientSecret': slackClientSecret,
      'openAiApiKey': openAiApiKey,
      'openAiProxyUrl': openAiProxyUrl,
      'openAiModel': openAiModel,
      'geminiEnabled': geminiEnabled,
      'geminiApiKey': geminiApiKey,
      'geminiModel': geminiModel,
      'claudeEnabled': claudeEnabled,
      'claudeApiKey': claudeApiKey,
      'claudeModel': claudeModel,
      'githubSyncMinutes': githubSyncMinutes,
      'jiraSyncMinutes': jiraSyncMinutes,
      'slackSyncMinutes': slackSyncMinutes,
    };
  }

  factory ConnectorConfig.fromExportJson(Map<String, dynamic> json) {
    return ConnectorConfig(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      githubEnabled: json['githubEnabled'] as bool? ?? true,
      jiraEnabled: json['jiraEnabled'] as bool? ?? true,
      slackEnabled: json['slackEnabled'] as bool? ?? true,
      openAiEnabled: json['openAiEnabled'] as bool? ?? true,
      githubUsername: json['githubUsername'] as String? ?? '',
      githubToken: json['githubToken'] as String? ?? '',
      jiraBaseUrl: json['jiraBaseUrl'] as String? ?? '',
      jiraEmail: json['jiraEmail'] as String? ?? '',
      jiraApiToken: json['jiraApiToken'] as String? ?? '',
      slackReviewChannels: (json['slackReviewChannels'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
      slackAlertChannel: json['slackAlertChannel'] as String? ?? '',
      slackToken: json['slackToken'] as String? ?? '',
      slackRefreshToken: json['slackRefreshToken'] as String? ?? '',
      slackClientId: json['slackClientId'] as String? ?? '',
      slackClientSecret: json['slackClientSecret'] as String? ?? '',
      openAiApiKey: json['openAiApiKey'] as String? ?? '',
      openAiProxyUrl: json['openAiProxyUrl'] as String? ?? '',
      openAiModel: json['openAiModel'] as String? ?? 'gpt-4.1-mini',
      geminiEnabled: json['geminiEnabled'] as bool? ?? false,
      geminiApiKey: json['geminiApiKey'] as String? ?? '',
      geminiModel: json['geminiModel'] as String? ?? 'gemini-2.0-flash',
      claudeEnabled: json['claudeEnabled'] as bool? ?? false,
      claudeApiKey: json['claudeApiKey'] as String? ?? '',
      claudeModel: json['claudeModel'] as String? ?? 'claude-sonnet-4-20250514',
      githubSyncMinutes: json['githubSyncMinutes'] as int? ?? 5,
      jiraSyncMinutes: json['jiraSyncMinutes'] as int? ?? 5,
      slackSyncMinutes: json['slackSyncMinutes'] as int? ?? 5,
    );
  }

  String get normalizedJiraBaseUrl {
    final trimmed = jiraBaseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String get slackReviewChannelsDisplay => slackReviewChannels.join('\n');

  bool get isGitHubConfigured =>
      githubEnabled && githubUsername.trim().isNotEmpty && githubToken.trim().isNotEmpty;

  bool get isJiraConfigured =>
      jiraEnabled &&
      normalizedJiraBaseUrl.isNotEmpty &&
      jiraEmail.trim().isNotEmpty &&
      jiraApiToken.trim().isNotEmpty;

  bool get isSlackTokenRotating => slackToken.trim().startsWith('xoxe.');

  bool get isSlackRefreshConfigured =>
      isSlackTokenRotating &&
      slackRefreshToken.trim().isNotEmpty &&
      slackClientId.trim().isNotEmpty &&
      slackClientSecret.trim().isNotEmpty;

  bool get isSlackConfigured =>
      slackEnabled &&
      slackToken.trim().isNotEmpty &&
      (slackReviewChannels.isNotEmpty || slackAlertChannel.trim().isNotEmpty);

  bool get isOpenAiConfigured =>
      openAiEnabled &&
      (openAiProxyUrl.trim().isNotEmpty || openAiApiKey.trim().isNotEmpty);

  bool get isGeminiConfigured =>
      geminiEnabled && geminiApiKey.trim().isNotEmpty;

  bool get isClaudeConfigured =>
      claudeEnabled && claudeApiKey.trim().isNotEmpty;

  bool get hasAnyIntegrationEnabled =>
      githubEnabled || jiraEnabled || slackEnabled;
}

class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.sourceLabel,
    required this.createdAt,
    this.sourceUrl = '',
    this.completed = false,
    this.reminderDate,
    this.reminderRepeat = 'none',
  });

  final String id;
  final String title;
  final String subtitle;
  final String sourceLabel;
  final String sourceUrl;
  final DateTime createdAt;
  final bool completed;
  final DateTime? reminderDate;
  final String reminderRepeat;

  TodoItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? sourceLabel,
    String? sourceUrl,
    DateTime? createdAt,
    bool? completed,
    DateTime? reminderDate,
    String? reminderRepeat,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      completed: completed ?? this.completed,
      reminderDate: reminderDate ?? this.reminderDate,
      reminderRepeat: reminderRepeat ?? this.reminderRepeat,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'sourceLabel': sourceLabel,
      'sourceUrl': sourceUrl,
      'createdAt': createdAt.toIso8601String(),
      'completed': completed,
      if (reminderDate != null) 'reminderDate': reminderDate!.toIso8601String(),
      'reminderRepeat': reminderRepeat,
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      sourceLabel: json['sourceLabel'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      completed: json['completed'] as bool? ?? false,
      reminderDate: json['reminderDate'] != null ? DateTime.tryParse(json['reminderDate'] as String) : null,
      reminderRepeat: json['reminderRepeat'] as String? ?? 'none',
    );
  }
}

class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteItem copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get preview {
    final text = body.trim();
    if (text.isEmpty) {
      return 'No content yet';
    }
    final compact = text.replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= 120) {
      return compact;
    }
    return '${compact.substring(0, 117)}...';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class GithubPullRequest {
  const GithubPullRequest({
    required this.id,
    required this.owner,
    required this.repo,
    required this.number,
    required this.title,
    required this.author,
    required this.url,
    required this.updatedAt,
    this.draft = false,
    this.headBranch,
    this.changedFiles = 0,
    this.additions = 0,
    this.deletions = 0,
    this.labels = const <String>[],
    this.summary,
  });

  final String id;
  final String owner;
  final String repo;
  final int number;
  final String title;
  final String author;
  final String url;
  final DateTime updatedAt;
  final bool draft;
  final String? headBranch;
  final int changedFiles;
  final int additions;
  final int deletions;
  final List<String> labels;
  final String? summary;

  String get repository => '$owner/$repo';
}

class JiraIssue {
  const JiraIssue({
    required this.id,
    required this.key,
    required this.title,
    required this.status,
    required this.priority,
    required this.url,
    required this.updatedAt,
    required this.issueType,
    required this.projectName,
    this.assignee = '',
    this.parentKey = '',
    this.parentTitle = '',
    this.dueDate,
  });

  final String id;
  final String key;
  final String title;
  final String status;
  final String priority;
  final String url;
  final DateTime updatedAt;
  final String issueType;
  final String projectName;
  final String assignee;
  final String parentKey;
  final String parentTitle;
  final DateTime? dueDate;
}

class SlackReviewRequest {
  const SlackReviewRequest({
    required this.id,
    required this.channel,
    required this.kind,
    required this.title,
    required this.requester,
    required this.message,
    required this.createdAt,
    this.url = '',
    this.slackDeepLink = '',
    this.slackWebLink = '',
  });

  final String id;
  final String channel;
  final SlackReviewKind kind;
  final String title;
  final String requester;
  final String message;
  final String url;
  final DateTime createdAt;
  final String slackDeepLink;
  final String slackWebLink;
}

class SlackAlert {
  const SlackAlert({
    required this.id,
    required this.channel,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.severity,
    this.url = '',
    this.slackDeepLink = '',
    this.slackWebLink = '',
  });

  final String id;
  final String channel;
  final String title;
  final String message;
  final DateTime createdAt;
  final AlertSeverity severity;
  final String url;
  final String slackDeepLink;
  final String slackWebLink;
}

class PullRequestFile {
  const PullRequestFile({
    required this.filename,
    required this.status,
    required this.additions,
    required this.deletions,
    this.patch,
  });

  final String filename;
  final String status;
  final int additions;
  final int deletions;
  final String? patch;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'filename': filename,
      'status': status,
      'additions': additions,
      'deletions': deletions,
      'patch': patch,
    };
  }
}

class PullRequestContext {
  const PullRequestContext({
    required this.pullRequest,
    required this.body,
    required this.baseBranch,
    required this.headBranch,
    required this.changedFiles,
    required this.files,
  });

  final GithubPullRequest pullRequest;
  final String body;
  final String baseBranch;
  final String headBranch;
  final int changedFiles;
  final List<PullRequestFile> files;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pullRequest': <String, dynamic>{
        'id': pullRequest.id,
        'repository': pullRequest.repository,
        'number': pullRequest.number,
        'title': pullRequest.title,
        'author': pullRequest.author,
        'url': pullRequest.url,
      },
      'body': body,
      'baseBranch': baseBranch,
      'headBranch': headBranch,
      'changedFiles': changedFiles,
      'files': files.map((PullRequestFile file) => file.toJson()).toList(),
    };
  }

  String toCondensedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class AiReviewConcern {
  const AiReviewConcern({
    required this.title,
    required this.severity,
    required this.description,
    this.filePath,
    this.lineNumber,
  });

  final String title;
  final String severity;
  final String description;
  final String? filePath;
  final int? lineNumber;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'severity': severity,
      'description': description,
      if (filePath != null) 'filePath': filePath,
      if (lineNumber != null) 'lineNumber': lineNumber,
    };
  }

  factory AiReviewConcern.fromJson(Map<String, dynamic> json) {
    return AiReviewConcern(
      title: json['title'] as String? ?? '',
      severity: json['severity'] as String? ?? 'suggestion',
      description: json['description'] as String? ?? '',
      filePath: json['filePath'] as String?,
      lineNumber: json['lineNumber'] as int?,
    );
  }
}

class AiReviewResult {
  const AiReviewResult({
    required this.generatedAt,
    this.verdict = '',
    this.concerns = const <AiReviewConcern>[],
    this.mergeConfidence = '',
    this.executiveSummary = '',
    this.rawReview = '',
  });

  final String verdict;
  final List<AiReviewConcern> concerns;
  final String mergeConfidence;
  final String executiveSummary;
  final DateTime generatedAt;
  final String rawReview;

  String get review {
    if (rawReview.isNotEmpty) return rawReview;
    final StringBuffer buf = StringBuffer();
    if (verdict.isNotEmpty) buf.writeln('Verdict: $verdict');
    for (final AiReviewConcern c in concerns) {
      buf.writeln('- [${c.severity}] ${c.title}: ${c.description}');
    }
    if (mergeConfidence.isNotEmpty) buf.writeln('Merge confidence: $mergeConfidence');
    if (executiveSummary.isNotEmpty) buf.writeln('Summary: $executiveSummary');
    return buf.toString().trim();
  }
}

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final String id;
  final String role;
  final String content;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

extension AlertSeverityLabel on AlertSeverity {
  String get label {
    switch (this) {
      case AlertSeverity.critical:
        return 'Critical';
      case AlertSeverity.high:
        return 'High';
      case AlertSeverity.medium:
        return 'Medium';
      case AlertSeverity.info:
        return 'Info';
    }
  }
}

extension SlackReviewKindLabel on SlackReviewKind {
  String get label {
    switch (this) {
      case SlackReviewKind.pr:
        return 'PR';
      case SlackReviewKind.doc:
        return 'Doc';
    }
  }
}
