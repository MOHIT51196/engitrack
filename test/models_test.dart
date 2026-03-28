import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:engitrack/src/models.dart';

void main() {
  group('ConnectorConfig', () {
    test('default constructor sets expected defaults', () {
      const config = ConnectorConfig();
      expect(config.githubEnabled, isFalse);
      expect(config.jiraEnabled, isFalse);
      expect(config.slackEnabled, isFalse);
      expect(config.openAiEnabled, isFalse);
      expect(config.geminiEnabled, isFalse);
      expect(config.claudeEnabled, isFalse);
      expect(config.grokEnabled, isFalse);
      expect(config.githubSyncMinutes, 5);
      expect(config.jiraSyncMinutes, 5);
      expect(config.slackSyncMinutes, 5);
      expect(config.openAiModel, 'gpt-4.1-mini');
      expect(config.geminiModel, 'gemini-2.0-flash');
      expect(config.claudeModel, 'claude-sonnet-4-20250514');
      expect(config.grokModel, 'grok-3-mini-fast');
      expect(config.slackReviewChannels, isEmpty);
    });

    test('copyWith preserves unmodified fields', () {
      const original = ConnectorConfig(
        githubEnabled: true,
        githubUsername: 'user',
        githubToken: 'tok',
      );
      final copied = original.copyWith(githubUsername: 'newuser');
      expect(copied.githubEnabled, isTrue);
      expect(copied.githubUsername, 'newuser');
      expect(copied.githubToken, 'tok');
    });

    test('toPreferencesJson excludes secrets', () {
      const config = ConnectorConfig(
        githubEnabled: true,
        githubToken: 'secret-token',
        openAiApiKey: 'sk-key',
      );
      final json = config.toPreferencesJson();
      expect(json.containsKey('githubToken'), isFalse);
      expect(json.containsKey('openAiApiKey'), isFalse);
      expect(json['githubEnabled'], isTrue);
    });

    test('fromStorage roundtrips with toPreferencesJson', () {
      const original = ConnectorConfig(
        githubEnabled: true,
        githubUsername: 'alice',
        jiraEnabled: true,
        jiraBaseUrl: 'https://team.atlassian.net/',
        slackReviewChannels: <String>['pr-reviews', 'code-review'],
        githubSyncMinutes: 10,
        openAiModel: 'gpt-4o',
      );
      final prefsJson = original.toPreferencesJson();
      final restored = ConnectorConfig.fromStorage(
        json: prefsJson,
        githubToken: 'tok123',
        jiraEmail: 'a@b.com',
        jiraApiToken: 'jira-tok',
      );
      expect(restored.githubEnabled, isTrue);
      expect(restored.githubUsername, 'alice');
      expect(restored.githubToken, 'tok123');
      expect(restored.jiraBaseUrl, 'https://team.atlassian.net/');
      expect(restored.slackReviewChannels, ['pr-reviews', 'code-review']);
      expect(restored.githubSyncMinutes, 10);
      expect(restored.openAiModel, 'gpt-4o');
    });

    test('fromStorage with null json returns defaults', () {
      final config = ConnectorConfig.fromStorage();
      expect(config.githubEnabled, isFalse);
      expect(config.openAiModel, 'gpt-4.1-mini');
    });

    test('toExportJson / fromExportJson roundtrip preserves all fields', () {
      const config = ConnectorConfig(
        notificationsEnabled: true,
        githubEnabled: true,
        githubUsername: 'alice',
        githubToken: 'gh-tok',
        jiraEnabled: true,
        jiraBaseUrl: 'https://x.atlassian.net',
        jiraEmail: 'a@b.com',
        jiraApiToken: 'jira-tok',
        slackEnabled: true,
        slackReviewChannels: <String>['ch1'],
        slackAlertChannel: 'alerts',
        slackToken: 'xoxb-token',
        openAiEnabled: true,
        openAiApiKey: 'sk-key',
        openAiModel: 'gpt-4o',
        geminiEnabled: true,
        geminiApiKey: 'gem-key',
        claudeEnabled: true,
        claudeApiKey: 'cl-key',
        grokEnabled: true,
        grokApiKey: 'grok-key',
        githubSyncMinutes: 3,
        jiraSyncMinutes: 7,
        slackSyncMinutes: 2,
      );
      final exportJson = config.toExportJson();
      expect(exportJson['_format'], 'engitrack_integrations_v1');

      final restored = ConnectorConfig.fromExportJson(exportJson);
      expect(restored.githubUsername, 'alice');
      expect(restored.githubToken, 'gh-tok');
      expect(restored.jiraEmail, 'a@b.com');
      expect(restored.slackReviewChannels, ['ch1']);
      expect(restored.openAiModel, 'gpt-4o');
      expect(restored.githubSyncMinutes, 3);
      expect(restored.grokEnabled, isTrue);
    });

    test('fromExportJson uses correct defaults when fields missing', () {
      final config = ConnectorConfig.fromExportJson(<String, dynamic>{});
      expect(config.githubEnabled, isTrue);
      expect(config.openAiModel, 'gpt-4.1-mini');
      expect(config.geminiEnabled, isFalse);
    });

    group('parseChannelsInput', () {
      test('splits on comma', () {
        expect(
          ConnectorConfig.parseChannelsInput('a, b, c'),
          ['a', 'b', 'c'],
        );
      });

      test('splits on newline', () {
        expect(
          ConnectorConfig.parseChannelsInput('alpha\nbeta\n'),
          ['alpha', 'beta'],
        );
      });

      test('handles mixed delimiters and empty tokens', () {
        expect(
          ConnectorConfig.parseChannelsInput('x,,y\n\nz,'),
          ['x', 'y', 'z'],
        );
      });

      test('returns empty list for blank input', () {
        expect(ConnectorConfig.parseChannelsInput(''), isEmpty);
        expect(ConnectorConfig.parseChannelsInput('  '), isEmpty);
      });
    });

    group('normalizedJiraBaseUrl', () {
      test('strips trailing slash', () {
        const config = ConnectorConfig(jiraBaseUrl: 'https://x.atlassian.net/');
        expect(config.normalizedJiraBaseUrl, 'https://x.atlassian.net');
      });

      test('preserves url without trailing slash', () {
        const config = ConnectorConfig(jiraBaseUrl: 'https://x.atlassian.net');
        expect(config.normalizedJiraBaseUrl, 'https://x.atlassian.net');
      });

      test('trims whitespace', () {
        const config =
            ConnectorConfig(jiraBaseUrl: '  https://x.atlassian.net/  ');
        expect(config.normalizedJiraBaseUrl, 'https://x.atlassian.net');
      });
    });

    test('slackReviewChannelsDisplay joins with newlines', () {
      const config = ConnectorConfig(slackReviewChannels: ['a', 'b', 'c']);
      expect(config.slackReviewChannelsDisplay, 'a\nb\nc');
    });

    group('isGitHubConfigured', () {
      test('true when enabled with username and token', () {
        const config = ConnectorConfig(
          githubEnabled: true,
          githubUsername: 'user',
          githubToken: 'tok',
        );
        expect(config.isGitHubConfigured, isTrue);
      });

      test('false when disabled', () {
        const config = ConnectorConfig(
          githubEnabled: false,
          githubUsername: 'user',
          githubToken: 'tok',
        );
        expect(config.isGitHubConfigured, isFalse);
      });

      test('false when username blank', () {
        const config = ConnectorConfig(
          githubEnabled: true,
          githubUsername: '  ',
          githubToken: 'tok',
        );
        expect(config.isGitHubConfigured, isFalse);
      });
    });

    group('isJiraConfigured', () {
      test('true when all fields present', () {
        const config = ConnectorConfig(
          jiraEnabled: true,
          jiraBaseUrl: 'https://x.atlassian.net',
          jiraEmail: 'a@b.com',
          jiraApiToken: 'tok',
        );
        expect(config.isJiraConfigured, isTrue);
      });

      test('false when base url empty', () {
        const config = ConnectorConfig(
          jiraEnabled: true,
          jiraBaseUrl: '',
          jiraEmail: 'a@b.com',
          jiraApiToken: 'tok',
        );
        expect(config.isJiraConfigured, isFalse);
      });
    });

    group('isSlackConfigured', () {
      test('true with token and review channels', () {
        const config = ConnectorConfig(
          slackEnabled: true,
          slackToken: 'xoxb-tok',
          slackReviewChannels: <String>['ch1'],
        );
        expect(config.isSlackConfigured, isTrue);
      });

      test('true with token and alert channel', () {
        const config = ConnectorConfig(
          slackEnabled: true,
          slackToken: 'xoxb-tok',
          slackAlertChannel: 'alerts',
        );
        expect(config.isSlackConfigured, isTrue);
      });

      test('false without any channels', () {
        const config = ConnectorConfig(
          slackEnabled: true,
          slackToken: 'xoxb-tok',
        );
        expect(config.isSlackConfigured, isFalse);
      });
    });

    group('isSlackTokenRotating / isSlackRefreshConfigured', () {
      test('detects rotating xoxe. token', () {
        const config = ConnectorConfig(slackToken: 'xoxe.some-token');
        expect(config.isSlackTokenRotating, isTrue);
      });

      test('non-rotating token', () {
        const config = ConnectorConfig(slackToken: 'xoxb-some-token');
        expect(config.isSlackTokenRotating, isFalse);
      });

      test('refresh configured when all fields present', () {
        const config = ConnectorConfig(
          slackToken: 'xoxe.tok',
          slackRefreshToken: 'xoxe.ref',
          slackClientId: 'cid',
          slackClientSecret: 'csec',
        );
        expect(config.isSlackRefreshConfigured, isTrue);
      });
    });

    group('AI configured checks', () {
      test('isOpenAiConfigured with api key', () {
        const config = ConnectorConfig(
          openAiEnabled: true,
          openAiApiKey: 'sk-key',
        );
        expect(config.isOpenAiConfigured, isTrue);
      });

      test('isOpenAiConfigured with proxy url', () {
        const config = ConnectorConfig(
          openAiEnabled: true,
          openAiProxyUrl: 'https://proxy.example.com',
        );
        expect(config.isOpenAiConfigured, isTrue);
      });

      test('isGeminiConfigured', () {
        expect(
          const ConnectorConfig(geminiEnabled: true, geminiApiKey: 'k')
              .isGeminiConfigured,
          isTrue,
        );
        expect(
          const ConnectorConfig(geminiEnabled: false, geminiApiKey: 'k')
              .isGeminiConfigured,
          isFalse,
        );
      });

      test('isClaudeConfigured', () {
        expect(
          const ConnectorConfig(claudeEnabled: true, claudeApiKey: 'k')
              .isClaudeConfigured,
          isTrue,
        );
      });

      test('isGrokConfigured', () {
        expect(
          const ConnectorConfig(grokEnabled: true, grokApiKey: 'k')
              .isGrokConfigured,
          isTrue,
        );
      });
    });

    test('hasAnyIntegrationEnabled', () {
      expect(const ConnectorConfig().hasAnyIntegrationEnabled, isFalse);
      expect(
        const ConnectorConfig(githubEnabled: true).hasAnyIntegrationEnabled,
        isTrue,
      );
      expect(
        const ConnectorConfig(slackEnabled: true).hasAnyIntegrationEnabled,
        isTrue,
      );
    });
  });

  group('TodoItem', () {
    final now = DateTime.utc(2025, 6, 15, 10, 30);
    final reminderDate = DateTime.utc(2025, 6, 16, 9, 0);

    TodoItem makeTodo({bool completed = false, DateTime? reminder}) {
      return TodoItem(
        id: 'todo-1',
        title: 'Fix bug',
        subtitle: 'Null check issue',
        sourceLabel: 'github',
        sourceUrl: 'https://github.com/repo/issues/1',
        createdAt: now,
        completed: completed,
        reminderDate: reminder,
        reminderRepeat: 'daily',
      );
    }

    test('toJson / fromJson roundtrip', () {
      final todo = makeTodo(reminder: reminderDate);
      final json = todo.toJson();
      final restored = TodoItem.fromJson(json);

      expect(restored.id, 'todo-1');
      expect(restored.title, 'Fix bug');
      expect(restored.subtitle, 'Null check issue');
      expect(restored.sourceLabel, 'github');
      expect(restored.sourceUrl, 'https://github.com/repo/issues/1');
      expect(restored.createdAt, now);
      expect(restored.completed, isFalse);
      expect(restored.reminderDate, reminderDate);
      expect(restored.reminderRepeat, 'daily');
    });

    test('toJson omits reminderDate when null', () {
      final todo = makeTodo();
      final json = todo.toJson();
      expect(json.containsKey('reminderDate'), isFalse);
    });

    test('fromJson handles missing optional fields', () {
      final todo = TodoItem.fromJson(<String, dynamic>{
        'id': 'x',
      });
      expect(todo.title, '');
      expect(todo.completed, isFalse);
      expect(todo.reminderDate, isNull);
      expect(todo.reminderRepeat, 'none');
    });

    test('copyWith creates independent copy', () {
      final original = makeTodo();
      final toggled = original.copyWith(completed: true);
      expect(toggled.completed, isTrue);
      expect(toggled.title, 'Fix bug');
      expect(original.completed, isFalse);
    });
  });

  group('NoteItem', () {
    final now = DateTime.utc(2025, 6, 15);
    final updated = DateTime.utc(2025, 6, 16);

    NoteItem makeNote({String body = 'Some content here'}) {
      return NoteItem(
        id: 'note-1',
        title: 'My Note',
        body: body,
        createdAt: now,
        updatedAt: updated,
      );
    }

    test('toJson / fromJson roundtrip', () {
      final note = makeNote();
      final json = note.toJson();
      final restored = NoteItem.fromJson(json);

      expect(restored.id, 'note-1');
      expect(restored.title, 'My Note');
      expect(restored.body, 'Some content here');
      expect(restored.createdAt, now);
      expect(restored.updatedAt, updated);
    });

    test('preview returns body when short', () {
      expect(makeNote(body: 'Short text').preview, 'Short text');
    });

    test('preview collapses whitespace', () {
      expect(makeNote(body: 'a  b\n\nc').preview, 'a b c');
    });

    test('preview truncates at 120 chars', () {
      final long = 'x' * 200;
      final preview = makeNote(body: long).preview;
      expect(preview.length, 120);
      expect(preview.endsWith('...'), isTrue);
    });

    test('preview returns placeholder for empty body', () {
      expect(makeNote(body: '').preview, 'No content yet');
      expect(makeNote(body: '   ').preview, 'No content yet');
    });

    test('copyWith creates modified copy', () {
      final original = makeNote();
      final modified = original.copyWith(title: 'Updated');
      expect(modified.title, 'Updated');
      expect(modified.body, 'Some content here');
    });
  });

  group('GithubPullRequest', () {
    test('repository getter combines owner/repo', () {
      final pr = GithubPullRequest(
        id: 'x',
        owner: 'alice',
        repo: 'proj',
        number: 42,
        title: 'PR title',
        author: 'bob',
        url: 'https://github.com/alice/proj/pull/42',
        updatedAt: DateTime.utc(2025),
      );
      expect(pr.repository, 'alice/proj');
    });
  });

  group('PullRequestFile', () {
    test('toJson roundtrip', () {
      const file = PullRequestFile(
        filename: 'lib/main.dart',
        status: 'modified',
        additions: 10,
        deletions: 3,
        patch: '@@ -1,3 +1,10 @@',
      );
      final json = file.toJson();
      expect(json['filename'], 'lib/main.dart');
      expect(json['additions'], 10);
      expect(json['patch'], '@@ -1,3 +1,10 @@');
    });
  });

  group('PullRequestContext', () {
    test('toCondensedJson produces valid indented JSON', () {
      final pr = GithubPullRequest(
        id: 'o/r#1',
        owner: 'o',
        repo: 'r',
        number: 1,
        title: 'T',
        author: 'A',
        url: 'https://github.com/o/r/pull/1',
        updatedAt: DateTime.utc(2025),
      );
      final ctx = PullRequestContext(
        pullRequest: pr,
        body: 'desc',
        baseBranch: 'main',
        headBranch: 'feat',
        changedFiles: 2,
        files: const <PullRequestFile>[
          PullRequestFile(
            filename: 'a.dart',
            status: 'added',
            additions: 5,
            deletions: 0,
          ),
        ],
      );
      final jsonStr = ctx.toCondensedJson();
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['baseBranch'], 'main');
      expect(decoded['headBranch'], 'feat');
      expect((decoded['files'] as List).length, 1);
    });
  });

  group('AiReviewConcern', () {
    test('fromJson / toJson roundtrip', () {
      final json = <String, dynamic>{
        'title': 'Missing null check',
        'severity': 'critical',
        'description': 'Could NPE',
        'filePath': 'lib/foo.dart',
        'lineNumber': 42,
      };
      final concern = AiReviewConcern.fromJson(json);
      expect(concern.title, 'Missing null check');
      expect(concern.severity, 'critical');
      expect(concern.filePath, 'lib/foo.dart');
      expect(concern.lineNumber, 42);

      final exported = concern.toJson();
      expect(exported['filePath'], 'lib/foo.dart');
    });

    test('fromJson handles missing optional fields', () {
      final concern = AiReviewConcern.fromJson(<String, dynamic>{});
      expect(concern.title, '');
      expect(concern.severity, 'suggestion');
      expect(concern.filePath, isNull);
      expect(concern.lineNumber, isNull);
    });

    test('toJson omits null filePath and lineNumber', () {
      const concern = AiReviewConcern(
        title: 'T',
        severity: 'nitpick',
        description: 'D',
      );
      final json = concern.toJson();
      expect(json.containsKey('filePath'), isFalse);
      expect(json.containsKey('lineNumber'), isFalse);
    });
  });

  group('AiReviewResult', () {
    test('review getter returns rawReview when present', () {
      final result = AiReviewResult(
        generatedAt: DateTime.utc(2025),
        rawReview: 'Raw review text',
        verdict: 'Approve',
      );
      expect(result.review, 'Raw review text');
    });

    test('review getter synthesizes from structured fields', () {
      final result = AiReviewResult(
        generatedAt: DateTime.utc(2025),
        verdict: 'Needs changes',
        concerns: const <AiReviewConcern>[
          AiReviewConcern(
            title: 'Bug',
            severity: 'critical',
            description: 'Off by one',
          ),
        ],
        mergeConfidence: 'Low',
        executiveSummary: 'Risky PR',
      );
      final review = result.review;
      expect(review, contains('Verdict: Needs changes'));
      expect(review, contains('[critical] Bug: Off by one'));
      expect(review, contains('Merge confidence: Low'));
      expect(review, contains('Summary: Risky PR'));
    });

    test('review getter handles empty result', () {
      final result = AiReviewResult(generatedAt: DateTime.utc(2025));
      expect(result.review, isEmpty);
    });
  });

  group('AiChatMessage', () {
    test('toJson / fromJson roundtrip', () {
      final ts = DateTime.utc(2025, 3, 15, 12, 0);
      final msg = AiChatMessage(
        id: 'msg-1',
        role: 'assistant',
        content: 'Hello!',
        timestamp: ts,
      );
      final json = msg.toJson();
      final restored = AiChatMessage.fromJson(json);
      expect(restored.id, 'msg-1');
      expect(restored.role, 'assistant');
      expect(restored.content, 'Hello!');
      expect(restored.timestamp, ts);
    });

    test('fromJson defaults', () {
      final msg = AiChatMessage.fromJson(<String, dynamic>{});
      expect(msg.id, '');
      expect(msg.role, 'user');
      expect(msg.content, '');
    });
  });

  group('AlertSeverity extension', () {
    test('label values', () {
      expect(AlertSeverity.critical.label, 'Critical');
      expect(AlertSeverity.high.label, 'High');
      expect(AlertSeverity.medium.label, 'Medium');
      expect(AlertSeverity.info.label, 'Info');
    });
  });

  group('SlackReviewKind extension', () {
    test('label values', () {
      expect(SlackReviewKind.pr.label, 'PR');
      expect(SlackReviewKind.doc.label, 'Doc');
    });
  });
}
