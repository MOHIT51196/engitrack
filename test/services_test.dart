import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:engitrack/src/models.dart';
import 'package:engitrack/src/services.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(
        http.Request('GET', Uri.parse('https://example.com')));
  });

  setUp(() {
    mockClient = MockHttpClient();
  });

  group('ServiceException', () {
    test('toString returns message', () {
      final e = ServiceException('boom');
      expect(e.toString(), 'boom');
      expect(e.message, 'boom');
    });
  });

  group('GitHubService', () {
    late GitHubService service;

    setUp(() {
      service = GitHubService(client: mockClient);
    });

    test('fetchPendingReviews parses response correctly', () async {
      final responseBody = jsonEncode(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'repository_url': 'https://api.github.com/repos/alice/project',
            'number': 42,
            'title': 'Add feature',
            'user': <String, dynamic>{'login': 'bob'},
            'html_url': 'https://github.com/alice/project/pull/42',
            'updated_at': '2025-06-15T10:00:00Z',
            'draft': false,
            'labels': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'enhancement'},
            ],
          },
        ],
      });

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responseBody, 200));

      final prs = await service.fetchPendingReviews(
        username: 'alice',
        token: 'tok',
      );

      expect(prs, hasLength(1));
      expect(prs.first.owner, 'alice');
      expect(prs.first.repo, 'project');
      expect(prs.first.number, 42);
      expect(prs.first.title, 'Add feature');
      expect(prs.first.author, 'bob');
      expect(prs.first.labels, ['enhancement']);
      expect(prs.first.draft, isFalse);
    });

    test('fetchPendingReviews handles empty items', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('{"items":[]}', 200));

      final prs = await service.fetchPendingReviews(
        username: 'u',
        token: 't',
      );
      expect(prs, isEmpty);
    });

    test('fetchPendingReviews throws on non-200', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('{"message":"bad"}', 401));

      expect(
        () => service.fetchPendingReviews(username: 'u', token: 't'),
        throwsA(isA<ServiceException>()),
      );
    });

    test('fetchPullRequestContext returns context', () async {
      final detailsBody = jsonEncode(<String, dynamic>{
        'body': 'PR description',
        'base': <String, dynamic>{'ref': 'main'},
        'head': <String, dynamic>{'ref': 'feature/x'},
        'changed_files': 3,
      });
      final filesBody = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'filename': 'lib/a.dart',
          'status': 'modified',
          'additions': 10,
          'deletions': 2,
          'patch': '@@ diff',
        },
      ]);

      int callCount = 0;
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return http.Response(detailsBody, 200);
        return http.Response(filesBody, 200);
      });

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

      final ctx = await service.fetchPullRequestContext(
        pullRequest: pr,
        token: 'tok',
      );

      expect(ctx.body, 'PR description');
      expect(ctx.baseBranch, 'main');
      expect(ctx.headBranch, 'feature/x');
      expect(ctx.changedFiles, 3);
      expect(ctx.files, hasLength(1));
      expect(ctx.files.first.filename, 'lib/a.dart');
    });

    test('postPrComment returns html_url', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode(<String, dynamic>{
              'html_url': 'https://github.com/o/r/issues/1#comment-123',
            }),
            201,
          ));

      final url = await service.postPrComment(
        owner: 'o',
        repo: 'r',
        number: 1,
        token: 'tok',
        body: 'LGTM',
      );
      expect(url, contains('comment-123'));
    });
  });

  group('JiraService', () {
    late JiraService service;

    setUp(() {
      service = JiraService(client: mockClient);
    });

    test('fetchAssignedIssues parses Jira response', () async {
      final myselfBody = jsonEncode(<String, dynamic>{
        'accountId': '12345:abc',
      });
      final searchBody = jsonEncode(<String, dynamic>{
        'issues': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '10001',
            'key': 'PROJ-42',
            'fields': <String, dynamic>{
              'summary': 'Fix login',
              'status': <String, dynamic>{'name': 'In Progress'},
              'priority': <String, dynamic>{'name': 'High'},
              'issuetype': <String, dynamic>{'name': 'Bug'},
              'project': <String, dynamic>{'name': 'Project'},
              'assignee': <String, dynamic>{'displayName': 'Alice'},
              'updated': '2025-06-15T10:00:00.000+0000',
              'parent': <String, dynamic>{
                'key': 'PROJ-1',
                'fields': <String, dynamic>{'summary': 'Epic'},
              },
              'duedate': '2025-07-01',
            },
          },
        ],
      });

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(myselfBody, 200));

      when(() => mockClient.send(any())).thenAnswer((_) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(searchBody)),
          200,
        );
      });

      final issues = await service.fetchAssignedIssues(
        baseUrl: 'https://x.atlassian.net',
        email: 'a@b.com',
        apiToken: 'tok',
      );

      expect(issues, hasLength(1));
      expect(issues.first.key, 'PROJ-42');
      expect(issues.first.title, 'Fix login');
      expect(issues.first.status, 'In Progress');
      expect(issues.first.priority, 'High');
      expect(issues.first.parentKey, 'PROJ-1');
      expect(issues.first.dueDate, isNotNull);
    });
  });

  group('SlackService', () {
    late SlackService service;

    setUp(() {
      service = SlackService(client: mockClient);
    });

    test('fetchReviewRequests returns empty for empty channels', () async {
      final result = await service.fetchReviewRequests(
        token: 'xoxb-tok',
        channels: <String>[],
      );
      expect(result, isEmpty);
    });

    test('fetchAlerts returns empty for blank channel', () async {
      final result = await service.fetchAlerts(
        token: 'xoxb-tok',
        channel: '',
      );
      expect(result, isEmpty);
    });

    test('fetchAlerts returns empty for whitespace channel', () async {
      final result = await service.fetchAlerts(
        token: 'xoxb-tok',
        channel: '   ',
      );
      expect(result, isEmpty);
    });

    test('buildSlackDeepLink formats correctly', () {
      final link = service.buildSlackDeepLink(
        teamId: 'T123',
        channelId: 'C456',
      );
      expect(link, 'slack://channel?team=T123&id=C456');
    });

    test('buildSlackWebLink formats correctly', () {
      final link = service.buildSlackWebLink(
        teamId: 'T123',
        channelId: 'C456',
      );
      expect(link, 'https://app.slack.com/client/T123/C456');
    });

    test('isRotatingToken detects xoxe prefix', () {
      expect(SlackService.isRotatingToken('xoxe.some-token'), isTrue);
      expect(SlackService.isRotatingToken('xoxb-some-token'), isFalse);
      expect(SlackService.isRotatingToken('  xoxe.tok'), isTrue);
    });

    test('fetchTeamId caches result', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode(<String, dynamic>{
                  'ok': true,
                  'team_id': 'T-CACHED',
                }),
                200,
              ));

      final first = await service.fetchTeamId(token: 'tok');
      final second = await service.fetchTeamId(token: 'tok');
      expect(first, 'T-CACHED');
      expect(second, 'T-CACHED');
      verify(() => mockClient.get(any(), headers: any(named: 'headers')))
          .called(1);
    });

    test('validateToken returns user_id', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode(<String, dynamic>{
                  'ok': true,
                  'user_id': 'U123',
                }),
                200,
              ));

      final userId = await service.validateToken(token: 'tok');
      expect(userId, 'U123');
    });

    test('refreshAccessToken returns tokens', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode(<String, dynamic>{
              'ok': true,
              'access_token': 'xoxe.new-access',
              'refresh_token': 'xoxe.new-refresh',
            }),
            200,
          ));

      final result = await service.refreshAccessToken(
        refreshToken: 'xoxe.old',
        clientId: 'cid',
        clientSecret: 'csec',
      );

      expect(result['access_token'], 'xoxe.new-access');
      expect(result['refresh_token'], 'xoxe.new-refresh');
    });

    test('throws ServiceException on Slack error response', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode(<String, dynamic>{
                  'ok': false,
                  'error': 'invalid_auth',
                }),
                200,
              ));

      expect(
        () => service.validateToken(token: 'bad-tok'),
        throwsA(isA<ServiceException>()),
      );
    });

    test('fetchReviewRequests with channel ID resolves directly', () async {
      final historyResponse = jsonEncode(<String, dynamic>{
        'ok': true,
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'text': 'Please review https://github.com/o/r/pull/1',
            'ts': '1718450000.000100',
            'user': 'U123',
          },
        ],
      });

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(historyResponse, 200));

      final results = await service.fetchReviewRequests(
        token: 'xoxb-tok',
        channels: <String>['C0001ABC'],
      );

      expect(results, hasLength(1));
      expect(results.first.kind, SlackReviewKind.pr);
      expect(results.first.url, contains('github.com'));
    });

    test('fetchAlerts detects severity keywords', () async {
      final historyResponse = jsonEncode(<String, dynamic>{
        'ok': true,
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'text': 'CRITICAL incident: database down sev0',
            'ts': '1718450000.000200',
            'user': 'U-BOT',
          },
          <String, dynamic>{
            'text': 'sev2 high latency on API gateway',
            'ts': '1718450000.000300',
            'user': 'U-BOT',
          },
          <String, dynamic>{
            'text': 'sev3 warning: disk usage 80%',
            'ts': '1718450000.000400',
            'user': 'U-BOT',
          },
          <String, dynamic>{
            'text': 'incident report from on-call',
            'ts': '1718450000.000500',
            'user': 'U-BOT',
          },
        ],
      });

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(historyResponse, 200));

      final alerts = await service.fetchAlerts(
        token: 'xoxb-tok',
        channel: 'C0001ABC',
      );

      expect(alerts.length, greaterThanOrEqualTo(3));
      final severities = alerts.map((SlackAlert a) => a.severity).toSet();
      expect(severities, contains(AlertSeverity.critical));
      expect(severities, contains(AlertSeverity.high));
    });
  });

  group('AiModelService', () {
    late AiModelService service;

    setUp(() {
      service = AiModelService(client: mockClient);
    });

    test('fetchOpenAiModels filters and sorts', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode(<String, dynamic>{
                  'data': <Map<String, dynamic>>[
                    <String, dynamic>{'id': 'gpt-4o'},
                    <String, dynamic>{'id': 'gpt-4.1-mini'},
                    <String, dynamic>{'id': 'dall-e-3'},
                    <String, dynamic>{'id': 'gpt-4o-realtime'},
                    <String, dynamic>{'id': 'o1-preview'},
                  ],
                }),
                200,
              ));

      final models = await service.fetchOpenAiModels(apiKey: 'sk-test');
      final ids = models.map((m) => m.value).toList();

      expect(ids, contains('gpt-4o'));
      expect(ids, contains('gpt-4.1-mini'));
      expect(ids, contains('o1-preview'));
      expect(ids, isNot(contains('dall-e-3')));
      expect(ids, isNot(contains('gpt-4o-realtime')));
      expect(ids, List<String>.from(ids)..sort());
    });

    test('fetchGeminiModels filters by generateContent', () async {
      when(() => mockClient.get(any())).thenAnswer((_) async => http.Response(
            jsonEncode(<String, dynamic>{
              'models': <Map<String, dynamic>>[
                <String, dynamic>{
                  'name': 'models/gemini-2.0-flash',
                  'displayName': 'Gemini 2.0 Flash',
                  'supportedGenerationMethods': ['generateContent'],
                },
                <String, dynamic>{
                  'name': 'models/embedding-001',
                  'displayName': 'Embedding',
                  'supportedGenerationMethods': ['embedContent'],
                },
              ],
            }),
            200,
          ));

      final models = await service.fetchGeminiModels(apiKey: 'gem-key');
      expect(models, hasLength(1));
      expect(models.first.value, 'gemini-2.0-flash');
      expect(models.first.label, 'Gemini 2.0 Flash');
    });

    test('fetchClaudeModels returns models', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode(<String, dynamic>{
                  'data': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'claude-sonnet-4-20250514',
                      'display_name': 'Claude Sonnet 4',
                    },
                  ],
                }),
                200,
              ));

      final models = await service.fetchClaudeModels(apiKey: 'cl-key');
      expect(models, hasLength(1));
      expect(models.first.value, 'claude-sonnet-4-20250514');
      expect(models.first.label, 'Claude Sonnet 4');
    });

    test('fetchGrokModels filters grok prefix', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode(<String, dynamic>{
                  'data': <Map<String, dynamic>>[
                    <String, dynamic>{'id': 'grok-3-mini-fast'},
                    <String, dynamic>{'id': 'grok-3'},
                    <String, dynamic>{'id': 'other-model'},
                  ],
                }),
                200,
              ));

      final models = await service.fetchGrokModels(apiKey: 'grok-key');
      final ids = models.map((m) => m.value).toList();
      expect(ids, contains('grok-3-mini-fast'));
      expect(ids, contains('grok-3'));
      expect(ids, isNot(contains('other-model')));
    });
  });
}
