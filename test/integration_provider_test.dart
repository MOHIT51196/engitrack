import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:engitrack/src/integrations/integration_provider.dart';
import 'package:engitrack/src/integrations/github_provider.dart';
import 'package:engitrack/src/integrations/jira_provider.dart';
import 'package:engitrack/src/integrations/slack_provider.dart';
import 'package:engitrack/src/models.dart';
import 'package:engitrack/src/services.dart';

class MockGitHubService extends Mock implements GitHubService {}

class MockJiraService extends Mock implements JiraService {}

class MockSlackService extends Mock implements SlackService {}

void main() {
  group('IntegrationItem', () {
    final now = DateTime.utc(2025, 6, 15);

    IntegrationItem makeItem() {
      return IntegrationItem(
        id: 'item-1',
        providerId: 'github',
        category: IntegrationCategory.codeReview,
        title: 'Fix auth',
        subtitle: 'org/repo #42',
        url: 'https://github.com/org/repo/pull/42',
        timestamp: now,
        reason: ItemReason.reviewRequested,
        metadata: <String, dynamic>{
          'owner': 'org',
          'repo': 'repo',
          'number': 42,
          'draft': false,
          'labels': <String>['bug'],
        },
      );
    }

    test('toJson / fromJson roundtrip', () {
      final item = makeItem();
      final json = item.toJson();
      final restored = IntegrationItem.fromJson(json);

      expect(restored.id, 'item-1');
      expect(restored.providerId, 'github');
      expect(restored.category, IntegrationCategory.codeReview);
      expect(restored.title, 'Fix auth');
      expect(restored.url, contains('pull/42'));
      expect(restored.reason, ItemReason.reviewRequested);
      expect(restored.timestamp, now);
    });

    test('toJsonString produces valid JSON', () {
      final item = makeItem();
      final decoded = jsonDecode(item.toJsonString()) as Map<String, dynamic>;
      expect(decoded['id'], 'item-1');
    });

    test('meta<T> returns typed value', () {
      final item = makeItem();
      expect(item.meta<String>('owner'), 'org');
      expect(item.meta<int>('number'), 42);
      expect(item.meta<bool>('draft'), isFalse);
    });

    test('meta<T> returns null for wrong type', () {
      final item = makeItem();
      expect(item.meta<int>('owner'), isNull);
    });

    test('meta<T> returns null for missing key', () {
      final item = makeItem();
      expect(item.meta<String>('nonexistent'), isNull);
    });

    test('fromJson handles unknown category/reason gracefully', () {
      final item = IntegrationItem.fromJson(<String, dynamic>{
        'id': 'x',
        'category': 'unknown',
        'reason': 'unknown',
      });
      expect(item.category, IntegrationCategory.codeReview);
      expect(item.reason, ItemReason.assigned);
    });
  });

  group('ItemReason extension', () {
    test('labels', () {
      expect(ItemReason.assigned.label, 'Assigned');
      expect(ItemReason.tagged.label, 'Tagged');
      expect(ItemReason.reviewRequested.label, 'Review requested');
      expect(ItemReason.alert.label, 'Alert');
      expect(ItemReason.mention.label, 'Mentioned');
    });
  });

  group('IntegrationCategory extension', () {
    test('labels', () {
      expect(IntegrationCategory.codeReview.label, 'Code Review');
      expect(IntegrationCategory.issueTracker.label, 'Issue Tracker');
      expect(IntegrationCategory.messaging.label, 'Messaging');
    });
  });

  group('GitHubProvider', () {
    late MockGitHubService mockService;
    late GitHubProvider provider;

    setUp(() {
      mockService = MockGitHubService();
      provider = GitHubProvider(service: mockService);
    });

    test('id, displayName, category, logoAsset', () {
      expect(provider.id, 'github');
      expect(provider.displayName, 'GitHub');
      expect(provider.category, IntegrationCategory.codeReview);
      expect(provider.logoAsset, contains('github'));
    });

    test('isConfigured delegates to config', () {
      expect(
        provider.isConfigured(const ConnectorConfig(
          githubEnabled: true,
          githubUsername: 'u',
          githubToken: 't',
        )),
        isTrue,
      );
      expect(
        provider.isConfigured(const ConnectorConfig()),
        isFalse,
      );
    });

    test('fetchItems maps PRs to IntegrationItems', () async {
      when(() => mockService.fetchPendingReviews(
            username: any(named: 'username'),
            token: any(named: 'token'),
          )).thenAnswer((_) async => <GithubPullRequest>[
            GithubPullRequest(
              id: 'alice/proj#1',
              owner: 'alice',
              repo: 'proj',
              number: 1,
              title: 'Add feat',
              author: 'bob',
              url: 'https://github.com/alice/proj/pull/1',
              updatedAt: DateTime.utc(2025, 6, 15),
              draft: true,
              labels: <String>['wip'],
            ),
          ]);

      final items = await provider.fetchItems(const ConnectorConfig(
        githubEnabled: true,
        githubUsername: 'alice',
        githubToken: 'tok',
      ));

      expect(items, hasLength(1));
      expect(items.first.id, 'alice/proj#1');
      expect(items.first.providerId, 'github');
      expect(items.first.reason, ItemReason.reviewRequested);
      expect(items.first.meta<bool>('draft'), isTrue);
      expect(items.first.subtitle, 'alice/proj #1');
    });

    test('pullRequestFromItem roundtrips metadata', () {
      final item = IntegrationItem(
        id: 'o/r#5',
        providerId: 'github',
        category: IntegrationCategory.codeReview,
        title: 'PR Title',
        subtitle: 'o/r #5',
        url: 'https://github.com/o/r/pull/5',
        timestamp: DateTime.utc(2025),
        reason: ItemReason.reviewRequested,
        metadata: <String, dynamic>{
          'owner': 'o',
          'repo': 'r',
          'number': 5,
          'author': 'a',
          'draft': false,
          'headBranch': 'feat',
          'changedFiles': 3,
          'additions': 10,
          'deletions': 2,
          'labels': <String>['bug'],
        },
      );

      final pr = GitHubProvider.pullRequestFromItem(item);
      expect(pr.owner, 'o');
      expect(pr.repo, 'r');
      expect(pr.number, 5);
      expect(pr.headBranch, 'feat');
      expect(pr.changedFiles, 3);
      expect(pr.labels, ['bug']);
    });
  });

  group('JiraProvider', () {
    late MockJiraService mockService;
    late JiraProvider provider;

    setUp(() {
      mockService = MockJiraService();
      provider = JiraProvider(service: mockService);
    });

    test('id, displayName, category', () {
      expect(provider.id, 'jira');
      expect(provider.displayName, 'Jira');
      expect(provider.category, IntegrationCategory.issueTracker);
    });

    test('isConfigured delegates to config', () {
      expect(
        provider.isConfigured(const ConnectorConfig(
          jiraEnabled: true,
          jiraBaseUrl: 'https://x.atlassian.net',
          jiraEmail: 'a@b.com',
          jiraApiToken: 'tok',
        )),
        isTrue,
      );
      expect(provider.isConfigured(const ConnectorConfig()), isFalse);
    });

    test('fetchItems merges assigned and mentioned issues', () async {
      final assignedIssue = JiraIssue(
        id: '1',
        key: 'PROJ-1',
        title: 'Assigned issue',
        status: 'To Do',
        priority: 'High',
        url: 'https://x.atlassian.net/browse/PROJ-1',
        updatedAt: DateTime.utc(2025, 6, 15),
        issueType: 'Task',
        projectName: 'Project',
      );

      final mentionedIssue = JiraIssue(
        id: '2',
        key: 'PROJ-2',
        title: 'Mentioned issue',
        status: 'Done',
        priority: 'Low',
        url: 'https://x.atlassian.net/browse/PROJ-2',
        updatedAt: DateTime.utc(2025, 6, 14),
        issueType: 'Bug',
        projectName: 'Project',
      );

      when(() => mockService.fetchAssignedIssues(
            baseUrl: any(named: 'baseUrl'),
            email: any(named: 'email'),
            apiToken: any(named: 'apiToken'),
          )).thenAnswer((_) async => <JiraIssue>[assignedIssue]);

      when(() => mockService.fetchMentionedIssues(
            baseUrl: any(named: 'baseUrl'),
            email: any(named: 'email'),
            apiToken: any(named: 'apiToken'),
          )).thenAnswer((_) async => <JiraIssue>[mentionedIssue]);

      final items = await provider.fetchItems(const ConnectorConfig(
        jiraEnabled: true,
        jiraBaseUrl: 'https://x.atlassian.net',
        jiraEmail: 'a@b.com',
        jiraApiToken: 'tok',
      ));

      expect(items, hasLength(2));
      final reasons = items.map((i) => i.reason).toSet();
      expect(reasons, contains(ItemReason.assigned));
      expect(reasons, contains(ItemReason.tagged));
    });

    test('fetchItems handles mentioned issues failure gracefully', () async {
      when(() => mockService.fetchAssignedIssues(
            baseUrl: any(named: 'baseUrl'),
            email: any(named: 'email'),
            apiToken: any(named: 'apiToken'),
          )).thenAnswer((_) async => <JiraIssue>[]);

      when(() => mockService.fetchMentionedIssues(
            baseUrl: any(named: 'baseUrl'),
            email: any(named: 'email'),
            apiToken: any(named: 'apiToken'),
          )).thenThrow(Exception('Not supported'));

      final items = await provider.fetchItems(const ConnectorConfig(
        jiraEnabled: true,
        jiraBaseUrl: 'https://x.atlassian.net',
        jiraEmail: 'a@b.com',
        jiraApiToken: 'tok',
      ));

      expect(items, isEmpty);
    });

    test('issueFromItem extracts fields', () {
      final item = IntegrationItem(
        id: '100',
        providerId: 'jira',
        category: IntegrationCategory.issueTracker,
        title: 'Bug fix',
        subtitle: 'PROJ-10 · Project',
        url: 'https://x.atlassian.net/browse/PROJ-10',
        timestamp: DateTime.utc(2025),
        reason: ItemReason.assigned,
        metadata: <String, dynamic>{
          'key': 'PROJ-10',
          'status': 'In Progress',
          'priority': 'Medium',
          'issueType': 'Bug',
          'projectName': 'Project',
          'assignee': 'Alice',
          'parentKey': 'PROJ-1',
          'parentTitle': 'Epic',
          'dueDate': '2025-07-01T00:00:00.000Z',
        },
      );

      final issue = JiraProvider.issueFromItem(item);
      expect(issue.key, 'PROJ-10');
      expect(issue.status, 'In Progress');
      expect(issue.parentKey, 'PROJ-1');
      expect(issue.dueDate, isNotNull);
    });
  });

  group('SlackProvider', () {
    late MockSlackService mockService;
    late SlackProvider provider;

    setUp(() {
      mockService = MockSlackService();
      provider = SlackProvider(service: mockService);
    });

    test('id, displayName, category', () {
      expect(provider.id, 'slack');
      expect(provider.displayName, 'Slack');
      expect(provider.category, IntegrationCategory.messaging);
    });

    test('isConfigured delegates to config', () {
      expect(
        provider.isConfigured(const ConnectorConfig(
          slackEnabled: true,
          slackToken: 'xoxb-tok',
          slackReviewChannels: <String>['ch'],
        )),
        isTrue,
      );
      expect(provider.isConfigured(const ConnectorConfig()), isFalse);
    });

    test('fetchItems combines reviews and alerts', () async {
      when(() => mockService.fetchReviewRequests(
            token: any(named: 'token'),
            channels: any(named: 'channels'),
          )).thenAnswer((_) async => <SlackReviewRequest>[
            SlackReviewRequest(
              id: 'rev-1',
              channel: '#pr-reviews',
              kind: SlackReviewKind.pr,
              title: 'Review PR',
              requester: 'U1',
              message: 'Please review',
              createdAt: DateTime.utc(2025, 6, 15),
              url: 'https://github.com/o/r/pull/1',
            ),
          ]);

      when(() => mockService.fetchAlerts(
            token: any(named: 'token'),
            channel: any(named: 'channel'),
          )).thenAnswer((_) async => <SlackAlert>[
            SlackAlert(
              id: 'alert-1',
              channel: '#alerts',
              title: 'DB down',
              message: 'Critical incident',
              createdAt: DateTime.utc(2025, 6, 15),
              severity: AlertSeverity.critical,
            ),
          ]);

      when(() => mockService.fetchDmMentions(
            token: any(named: 'token'),
          )).thenAnswer((_) async => <SlackReviewRequest>[]);

      final items = await provider.fetchItems(const ConnectorConfig(
        slackEnabled: true,
        slackToken: 'xoxb-tok',
        slackReviewChannels: <String>['pr-reviews'],
        slackAlertChannel: 'alerts',
      ));

      expect(items, hasLength(2));
      final reasons = items.map((i) => i.reason).toSet();
      expect(reasons, contains(ItemReason.reviewRequested));
      expect(reasons, contains(ItemReason.alert));
    });

    test('reviewFromItem extracts SlackReviewRequest', () {
      final item = IntegrationItem(
        id: 'rev-1',
        providerId: 'slack',
        category: IntegrationCategory.messaging,
        title: 'Review PR',
        subtitle: '#ch · U1',
        url: 'https://github.com/o/r/pull/1',
        timestamp: DateTime.utc(2025),
        reason: ItemReason.reviewRequested,
        metadata: <String, dynamic>{
          'channel': '#ch',
          'kind': 'pr',
          'requester': 'U1',
          'message': 'Please review',
          'slackDeepLink': 'slack://link',
          'slackWebLink': 'https://app.slack.com/link',
        },
      );

      final review = SlackProvider.reviewFromItem(item);
      expect(review.channel, '#ch');
      expect(review.kind, SlackReviewKind.pr);
      expect(review.requester, 'U1');
    });

    test('alertFromItem extracts SlackAlert', () {
      final item = IntegrationItem(
        id: 'alert-1',
        providerId: 'slack',
        category: IntegrationCategory.messaging,
        title: 'DB down',
        subtitle: '#alerts · Critical',
        url: '',
        timestamp: DateTime.utc(2025),
        reason: ItemReason.alert,
        metadata: <String, dynamic>{
          'channel': '#alerts',
          'severity': 'critical',
          'message': 'DB down',
        },
      );

      final alert = SlackProvider.alertFromItem(item);
      expect(alert.channel, '#alerts');
      expect(alert.severity, AlertSeverity.critical);
    });
  });
}
