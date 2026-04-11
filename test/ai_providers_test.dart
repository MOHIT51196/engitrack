import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:engitrack/src/ai/openai_provider.dart';
import 'package:engitrack/src/ai/gemini_provider.dart';
import 'package:engitrack/src/ai/claude_provider.dart';
import 'package:engitrack/src/ai/grok_provider.dart';
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
}
