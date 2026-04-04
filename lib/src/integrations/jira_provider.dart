import '../models.dart';
import '../services.dart';
import 'integration_provider.dart';

class JiraProvider implements IntegrationProvider {
  JiraProvider({JiraService? service}) : _service = service ?? JiraService();

  final JiraService _service;

  @override
  String get id => 'jira';

  @override
  String get displayName => 'Jira';

  @override
  IntegrationCategory get category => IntegrationCategory.issueTracker;

  @override
  String get logoAsset => 'assets/logos/jira.svg';

  @override
  bool isConfigured(ConnectorConfig config) => config.isJiraConfigured;

  @override
  Future<List<IntegrationItem>> fetchItems(ConnectorConfig config) async {
    final List<JiraIssue> assigned = await _service.fetchAssignedIssues(
      baseUrl: config.normalizedJiraBaseUrl,
      email: config.jiraEmail,
      apiToken: config.jiraApiToken,
    );

    List<JiraIssue> mentioned = <JiraIssue>[];
    try {
      mentioned = await _service.fetchMentionedIssues(
        baseUrl: config.normalizedJiraBaseUrl,
        email: config.jiraEmail,
        apiToken: config.jiraApiToken,
      );
    } catch (_) {
      // Comment-based search may not be supported on all Jira instances.
    }

    final Map<String, IntegrationItem> merged = <String, IntegrationItem>{};

    for (final JiraIssue issue in assigned) {
      merged[issue.key] = _mapIssue(issue, ItemReason.assigned);
    }
    for (final JiraIssue issue in mentioned) {
      merged.putIfAbsent(issue.key, () => _mapIssue(issue, ItemReason.tagged));
    }

    return merged.values.toList()
      ..sort((IntegrationItem a, IntegrationItem b) =>
          b.timestamp.compareTo(a.timestamp));
  }

  JiraService get service => _service;

  static IntegrationItem _mapIssue(JiraIssue issue, ItemReason reason) {
    return IntegrationItem(
      id: issue.id,
      providerId: 'jira',
      category: IntegrationCategory.issueTracker,
      title: issue.title,
      subtitle: '${issue.key} · ${issue.projectName}',
      url: issue.url,
      timestamp: issue.updatedAt,
      reason: reason,
      metadata: <String, dynamic>{
        'key': issue.key,
        'status': issue.status,
        'priority': issue.priority,
        'issueType': issue.issueType,
        'projectName': issue.projectName,
        'assignee': issue.assignee,
        'parentKey': issue.parentKey,
        'parentTitle': issue.parentTitle,
        'dueDate': issue.dueDate?.toIso8601String(),
        'description': issue.description,
      },
    );
  }

  static JiraIssue issueFromItem(IntegrationItem item) {
    return JiraIssue(
      id: item.id,
      key: item.meta<String>('key') ?? '',
      title: item.title,
      status: item.meta<String>('status') ?? '',
      priority: item.meta<String>('priority') ?? '',
      url: item.url,
      updatedAt: item.timestamp,
      issueType: item.meta<String>('issueType') ?? '',
      projectName: item.meta<String>('projectName') ?? '',
      assignee: item.meta<String>('assignee') ?? '',
      parentKey: item.meta<String>('parentKey') ?? '',
      parentTitle: item.meta<String>('parentTitle') ?? '',
      dueDate: DateTime.tryParse(item.meta<String>('dueDate') ?? ''),
      description: item.meta<String>('description') ?? '',
    );
  }
}
