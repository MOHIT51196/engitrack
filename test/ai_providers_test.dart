import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:engitrack/src/ai/openai_provider.dart';
import 'package:engitrack/src/ai/gemini_provider.dart';
import 'package:engitrack/src/ai/claude_provider.dart';
import 'package:engitrack/src/ai/grok_provider.dart';
import 'package:engitrack/src/ai/cursor_provider.dart';
import 'package:engitrack/src/models.dart';
import 'package:engitrack/src/services.dart';

class MockHttpClient extends Mock implements http.Client {}

PullRequestContext _makeContext() {
  final pr = GithubPullRequest(
    id: 'o/r#1',
    owner: 'o',
    repo: 'r',
    number: 1,
    title: 'Add feature',
    author: 'alice',
    url: 'https://github.com/o/r/pull/1',
    updatedAt: DateTime.utc(2025),
  );
  return PullRequestContext(
    pullRequest: pr,
    body: 'PR desc',
    baseBranch: 'main',
    headBranch: 'feat',
    changedFiles: 1,
    files: const <PullRequestFile>[
      PullRequestFile(
        filename: 'a.dart',
        status: 'modified',
        additions: 5,
        deletions: 1,
        patch: '+new line',
      ),
    ],
  );
}

String _chatCompletionResponse(String content) {
  return jsonEncode(<String, dynamic>{
    'choices': <Map<String, dynamic>>[
      <String, dynamic>{
        'message': <String, dynamic>{'content': content},
      },
    ],
  });
}

String _validReviewJson() {
  return jsonEncode(<String, dynamic>{
    'verdict': 'Approve',
    'concerns': <dynamic>[],
    'mergeConfidence': 'High',
    'executiveSummary': 'Clean code',
  });
}

String _cursorAgentCreateResponse() {
  return jsonEncode(<String, dynamic>{
    'agent': <String, dynamic>{
      'id': 'bc-1',
      'status': 'ACTIVE',
      'latestRunId': 'run-1',
    },
    'run': <String, dynamic>{
      'id': 'run-1',
      'agentId': 'bc-1',
      'status': 'CREATING',
    },
  });
}

String _cursorRunResponse(String status, {String? result}) {
  return jsonEncode(<String, dynamic>{
    'id': 'run-1',
    'agentId': 'bc-1',
    'status': status,
    if (result != null) 'result': result,
  });
}

void main() {
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockClient = MockHttpClient();
  });

  group('OpenAiProvider', () {
    final provider = OpenAiProvider();

    test('metadata', () {
      expect(provider.id, 'openai');
      expect(provider.displayName, 'OpenAI');
      expect(
        provider.chatCompletionsUri.toString(),
        contains('api.openai.com'),
      );
    });

    test('isConfigured with API key', () {
      expect(
        provider.isConfigured(
          const ConnectorConfig(openAiEnabled: true, openAiApiKey: 'sk-key'),
        ),
        isTrue,
      );
    });

    test('isConfigured with proxy URL', () {
      expect(
        provider.isConfigured(
          const ConnectorConfig(
            openAiEnabled: true,
            openAiProxyUrl: 'https://proxy.example.com',
          ),
        ),
        isTrue,
      );
    });

    test('isConfigured false when disabled', () {
      expect(
        provider.isConfigured(
          const ConnectorConfig(openAiEnabled: false, openAiApiKey: 'sk-key'),
        ),
        isFalse,
      );
    });

    test('apiKey and model extraction', () {
      const config = ConnectorConfig(
        openAiApiKey: ' sk-key ',
        openAiModel: 'gpt-4o',
      );
      expect(provider.apiKey(config), 'sk-key');
      expect(provider.model(config), 'gpt-4o');
    });

    test('model defaults when empty', () {
      const config = ConnectorConfig(openAiModel: '');
      expect(provider.model(config), 'gpt-4.1-mini');
    });

    test('reviewPullRequest via direct API', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async =>
            http.Response(_chatCompletionResponse(_validReviewJson()), 200),
      );

      final result = await provider.reviewPullRequest(
        context: _makeContext(),
        config: const ConnectorConfig(
          openAiEnabled: true,
          openAiApiKey: 'sk-key',
          openAiModel: 'gpt-4o',
        ),
        client: mockClient,
      );

      expect(result.verdict, 'Approve');
      expect(result.mergeConfidence, 'High');
    });

    test('reviewPullRequest throws when API key missing and no proxy', () {
      expect(
        () => provider.reviewPullRequest(
          context: _makeContext(),
          config: const ConnectorConfig(openAiEnabled: true),
          client: mockClient,
        ),
        throwsA(isA<ServiceException>()),
      );
    });

    test('reviewPullRequest via proxy', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{'review': _validReviewJson()}),
          200,
        ),
      );

      final result = await provider.reviewPullRequest(
        context: _makeContext(),
        config: const ConnectorConfig(
          openAiEnabled: true,
          openAiProxyUrl: 'https://proxy.example.com/review',
          openAiModel: 'gpt-4o',
        ),
        client: mockClient,
      );

      expect(result.verdict, 'Approve');
    });
  });

  group('GeminiProvider', () {
    final provider = GeminiProvider();

    test('metadata', () {
      expect(provider.id, 'gemini');
      expect(provider.displayName, 'Google Gemini');
      expect(
        provider.chatCompletionsUri.toString(),
        contains('generativelanguage.googleapis.com'),
      );
    });

    test('isConfigured', () {
      expect(
        provider.isConfigured(
          const ConnectorConfig(geminiEnabled: true, geminiApiKey: 'key'),
        ),
        isTrue,
      );
      expect(
        provider.isConfigured(const ConnectorConfig(geminiEnabled: true)),
        isFalse,
      );
    });

    test('model defaults when empty', () {
      expect(
        provider.model(const ConnectorConfig(geminiModel: '')),
        'gemini-2.0-flash',
      );
    });

    test('reviewPullRequest throws when key missing', () {
      expect(
        () => provider.reviewPullRequest(
          context: _makeContext(),
          config: const ConnectorConfig(geminiEnabled: true),
          client: mockClient,
        ),
        throwsA(isA<ServiceException>()),
      );
    });

    test('reviewPullRequest succeeds with mock', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async =>
            http.Response(_chatCompletionResponse(_validReviewJson()), 200),
      );

      final result = await provider.reviewPullRequest(
        context: _makeContext(),
        config: const ConnectorConfig(
          geminiEnabled: true,
          geminiApiKey: 'gem-key',
        ),
        client: mockClient,
      );

      expect(result.verdict, 'Approve');
    });
  });

  group('ClaudeProvider', () {
    final provider = ClaudeProvider();

    test('metadata', () {
      expect(provider.id, 'claude');
      expect(provider.displayName, 'Anthropic Claude');
      expect(
        provider.chatCompletionsUri.toString(),
        contains('api.anthropic.com'),
      );
    });

    test('isConfigured', () {
      expect(
        provider.isConfigured(
          const ConnectorConfig(claudeEnabled: true, claudeApiKey: 'key'),
        ),
        isTrue,
      );
    });

    test('model defaults when empty', () {
      expect(
        provider.model(const ConnectorConfig(claudeModel: '')),
        'claude-sonnet-4-20250514',
      );
    });

    test('reviewPullRequest throws when key missing', () {
      expect(
        () => provider.reviewPullRequest(
          context: _makeContext(),
          config: const ConnectorConfig(claudeEnabled: true),
          client: mockClient,
        ),
        throwsA(isA<ServiceException>()),
      );
    });

    test('reviewPullRequest succeeds with mock', () async {
      final claudeResponse = jsonEncode(<String, dynamic>{
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'text', 'text': _validReviewJson()},
        ],
      });

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(claudeResponse, 200));

      final result = await provider.reviewPullRequest(
        context: _makeContext(),
        config: const ConnectorConfig(
          claudeEnabled: true,
          claudeApiKey: 'cl-key',
        ),
        client: mockClient,
      );

      expect(result.verdict, 'Approve');
    });
  });

  group('GrokProvider', () {
    final provider = GrokProvider();

    test('metadata', () {
      expect(provider.id, 'grok');
      expect(provider.displayName, 'xAI Grok');
      expect(provider.chatCompletionsUri.toString(), contains('api.x.ai'));
    });

    test('isConfigured', () {
      expect(
        provider.isConfigured(
          const ConnectorConfig(grokEnabled: true, grokApiKey: 'key'),
        ),
        isTrue,
      );
    });

    test('model defaults when empty', () {
      expect(
        provider.model(const ConnectorConfig(grokModel: '')),
        'grok-3-mini-fast',
      );
    });

    test('reviewPullRequest throws when key missing', () {
      expect(
        () => provider.reviewPullRequest(
          context: _makeContext(),
          config: const ConnectorConfig(grokEnabled: true),
          client: mockClient,
        ),
        throwsA(isA<ServiceException>()),
      );
    });

    test('reviewPullRequest succeeds with mock', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async =>
            http.Response(_chatCompletionResponse(_validReviewJson()), 200),
      );

      final result = await provider.reviewPullRequest(
        context: _makeContext(),
        config: const ConnectorConfig(
          grokEnabled: true,
          grokApiKey: 'grok-key',
        ),
        client: mockClient,
      );

      expect(result.verdict, 'Approve');
    });
  });

  group('CursorProvider', () {
    final provider = CursorProvider();

    test('metadata', () {
      expect(provider.id, 'cursor');
      expect(provider.displayName, 'Cursor');
      expect(
        provider.chatCompletionsUri.toString(),
        contains('api.cursor.com'),
      );
    });

    test('isConfigured', () {
      expect(
        provider.isConfigured(
          const ConnectorConfig(cursorEnabled: true, cursorApiKey: 'key'),
        ),
        isTrue,
      );
    });

    test('model defaults when empty', () {
      expect(
        provider.model(const ConnectorConfig(cursorModel: '')),
        'cursor-small',
      );
    });

    test('modelLabel maps legacy placeholder to account default', () {
      expect(
        provider.modelLabel(const ConnectorConfig(cursorModel: '')),
        'Auto (account default)',
      );
      expect(
        provider.modelLabel(
          const ConnectorConfig(cursorModel: 'claude-fable-5'),
        ),
        'claude-fable-5',
      );
    });

    test('reviewPullRequest throws when key missing', () {
      expect(
        () => provider.reviewPullRequest(
          context: _makeContext(),
          config: const ConnectorConfig(cursorEnabled: true),
          client: mockClient,
        ),
        throwsA(isA<ServiceException>()),
      );
    });

    test('reviewPullRequest launches a cloud agent on the PR and polls',
        () async {
      final freshProvider = CursorProvider(pollInterval: Duration.zero);
      final List<String> postedBodies = <String>[];
      int pollCount = 0;

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((Invocation invocation) async {
        postedBodies.add(invocation.namedArguments[#body] as String);
        return http.Response(_cursorAgentCreateResponse(), 200);
      });

      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        pollCount++;
        if (pollCount == 1) {
          return http.Response(_cursorRunResponse('RUNNING'), 200);
        }
        return http.Response(
          _cursorRunResponse('FINISHED', result: _validReviewJson()),
          200,
        );
      });

      final result = await freshProvider.reviewPullRequest(
        context: _makeContext(),
        config: const ConnectorConfig(
          cursorEnabled: true,
          cursorApiKey: 'key_test',
        ),
        client: mockClient,
      );

      expect(result.verdict, 'Approve');
      expect(pollCount, 2);

      final Map<String, dynamic> body =
          jsonDecode(postedBodies.single) as Map<String, dynamic>;
      final List<dynamic> repos = body['repos'] as List<dynamic>;
      expect(
        (repos.single as Map<String, dynamic>)['prUrl'],
        'https://github.com/o/r/pull/1',
      );
      expect(body['autoCreatePR'], isFalse);
      // Legacy placeholder model must be omitted so the account default runs.
      expect(body.containsKey('model'), isFalse);
      final String promptText =
          ((body['prompt'] as Map<String, dynamic>)['text'] as String);
      expect(promptText, contains('READ-ONLY'));
    });

    test('reviewPullRequest passes the selected model id', () async {
      final freshProvider = CursorProvider(pollInterval: Duration.zero);
      final List<String> postedBodies = <String>[];

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((Invocation invocation) async {
        postedBodies.add(invocation.namedArguments[#body] as String);
        return http.Response(_cursorAgentCreateResponse(), 200);
      });
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          _cursorRunResponse('FINISHED', result: _validReviewJson()),
          200,
        ),
      );

      await freshProvider.reviewPullRequest(
        context: _makeContext(),
        config: const ConnectorConfig(
          cursorEnabled: true,
          cursorApiKey: 'key_test',
          cursorModel: 'composer-2',
        ),
        client: mockClient,
      );

      final Map<String, dynamic> body =
          jsonDecode(postedBodies.single) as Map<String, dynamic>;
      expect((body['model'] as Map<String, dynamic>)['id'], 'composer-2');
    });

    test('reviewPullRequest surfaces a failed run', () async {
      final freshProvider = CursorProvider(pollInterval: Duration.zero);

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(_cursorAgentCreateResponse(), 200),
      );
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(_cursorRunResponse('ERROR'), 200),
      );

      expect(
        () => freshProvider.reviewPullRequest(
          context: _makeContext(),
          config: const ConnectorConfig(
            cursorEnabled: true,
            cursorApiKey: 'key_test',
          ),
          client: mockClient,
        ),
        throwsA(
          isA<ServiceException>().having(
            (ServiceException e) => e.message,
            'message',
            contains('ERROR'),
          ),
        ),
      );
    });

    test('chatAboutReview reuses the review agent for follow-ups', () async {
      final freshProvider = CursorProvider(pollInterval: Duration.zero);
      final List<Uri> postedUris = <Uri>[];

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((Invocation invocation) async {
        final Uri uri = invocation.positionalArguments.first as Uri;
        postedUris.add(uri);
        if (uri.path == '/v1/agents') {
          return http.Response(_cursorAgentCreateResponse(), 200);
        }
        return http.Response(
          jsonEncode(<String, dynamic>{
            'run': <String, dynamic>{
              'id': 'run-2',
              'agentId': 'bc-1',
              'status': 'CREATING',
            },
          }),
          200,
        );
      });

      int pollCount = 0;
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        pollCount++;
        return http.Response(
          _cursorRunResponse(
            'FINISHED',
            result: pollCount == 1 ? _validReviewJson() : 'Plain answer',
          ),
          200,
        );
      });

      const ConnectorConfig config = ConnectorConfig(
        cursorEnabled: true,
        cursorApiKey: 'key_test',
      );

      final review = await freshProvider.reviewPullRequest(
        context: _makeContext(),
        config: config,
        client: mockClient,
      );

      final message = await freshProvider.chatAboutReview(
        context: _makeContext(),
        review: review,
        history: const <AiChatMessage>[],
        userMessage: 'Why is merge confidence high?',
        config: config,
        client: mockClient,
      );

      expect(message.content, 'Plain answer');
      expect(message.role, 'assistant');
      expect(postedUris.last.path, '/v1/agents/bc-1/runs');
    });

    test('registerAgentForPr re-links an agent for follow-up chat', () async {
      final freshProvider = CursorProvider(pollInterval: Duration.zero);
      final List<Uri> postedUris = <Uri>[];

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((Invocation invocation) async {
        postedUris.add(invocation.positionalArguments.first as Uri);
        return http.Response(
          jsonEncode(<String, dynamic>{
            'run': <String, dynamic>{
              'id': 'run-9',
              'agentId': 'bc-restored',
              'status': 'CREATING',
            },
          }),
          200,
        );
      });
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          _cursorRunResponse('FINISHED', result: 'Resumed answer'),
          200,
        ),
      );

      // Simulates the controller re-linking a persisted agent after restart.
      freshProvider.registerAgentForPr('o/r#1', 'bc-restored');

      final message = await freshProvider.chatAboutReview(
        context: _makeContext(),
        review: AiReviewResult(generatedAt: DateTime.utc(2026)),
        history: const <AiChatMessage>[],
        userMessage: 'Anything else?',
        config: const ConnectorConfig(
          cursorEnabled: true,
          cursorApiKey: 'key_test',
        ),
        client: mockClient,
      );

      expect(message.content, 'Resumed answer');
      expect(postedUris.single.path, '/v1/agents/bc-restored/runs');
    });

    test('launchReviewAgent returns ids without polling', () async {
      final freshProvider = CursorProvider(pollInterval: Duration.zero);

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(_cursorAgentCreateResponse(), 200),
      );

      final launched = await freshProvider.launchReviewAgent(
        context: _makeContext(),
        config: const ConnectorConfig(
          cursorEnabled: true,
          cursorApiKey: 'key_test',
        ),
        client: mockClient,
      );

      expect(launched.agentId, 'bc-1');
      expect(launched.runId, 'run-1');
      // No GET polling must have happened yet.
      verifyNever(() => mockClient.get(any(), headers: any(named: 'headers')));
    });

    test('awaitReviewResult resumes a run by id', () async {
      final freshProvider = CursorProvider(pollInterval: Duration.zero);
      final List<Uri> polledUris = <Uri>[];

      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((Invocation invocation) async {
        polledUris.add(invocation.positionalArguments.first as Uri);
        return http.Response(
          _cursorRunResponse('FINISHED', result: _validReviewJson()),
          200,
        );
      });

      final review = await freshProvider.awaitReviewResult(
        agentId: 'bc-persisted',
        runId: 'run-persisted',
        config: const ConnectorConfig(
          cursorEnabled: true,
          cursorApiKey: 'key_test',
        ),
        client: mockClient,
      );

      expect(review.verdict, 'Approve');
      expect(
        polledUris.single.path,
        '/v1/agents/bc-persisted/runs/run-persisted',
      );
    });

    test('chatAboutReview creates a fresh agent when none is cached', () async {
      final freshProvider = CursorProvider(pollInterval: Duration.zero);
      final List<Uri> postedUris = <Uri>[];

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((Invocation invocation) async {
        postedUris.add(invocation.positionalArguments.first as Uri);
        return http.Response(_cursorAgentCreateResponse(), 200);
      });
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          _cursorRunResponse('FINISHED', result: 'Fresh answer'),
          200,
        ),
      );

      final message = await freshProvider.chatAboutReview(
        context: _makeContext(),
        review: AiReviewResult(generatedAt: DateTime.utc(2026)),
        history: const <AiChatMessage>[],
        userMessage: 'What changed?',
        config: const ConnectorConfig(
          cursorEnabled: true,
          cursorApiKey: 'key_test',
        ),
        client: mockClient,
      );

      expect(message.content, 'Fresh answer');
      expect(postedUris.single.path, '/v1/agents');
    });

    test('reviewPullRequest adds repo-connection hint on 404', () async {
      final freshProvider = CursorProvider(pollInterval: Duration.zero);

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"error":{"code":"repository_not_found"}}',
          404,
        ),
      );

      expect(
        () => freshProvider.reviewPullRequest(
          context: _makeContext(),
          config: const ConnectorConfig(
            cursorEnabled: true,
            cursorApiKey: 'key_test',
          ),
          client: mockClient,
        ),
        throwsA(
          isA<ServiceException>().having(
            (ServiceException e) => e.message,
            'message',
            contains("connected to Cursor's GitHub integration"),
          ),
        ),
      );
    });

    test('reviewPullRequest maps 401 to a friendly key error', () async {
      final freshProvider = CursorProvider(pollInterval: Duration.zero);

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response('{"error":"unauthorized"}', 401),
      );

      expect(
        () => freshProvider.reviewPullRequest(
          context: _makeContext(),
          config: const ConnectorConfig(
            cursorEnabled: true,
            cursorApiKey: 'bad-key',
          ),
          client: mockClient,
        ),
        throwsA(
          isA<ServiceException>().having(
            (ServiceException e) => e.message,
            'message',
            contains('rejected the API key'),
          ),
        ),
      );
    });
  });
}
