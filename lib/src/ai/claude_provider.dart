import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import '../services.dart';
import '../theme.dart';
import 'ai_provider.dart';
import 'ai_review_helpers.dart';

class ClaudeProvider extends AiProvider {
  @override
  String get id => 'claude';

  @override
  String get displayName => 'Anthropic Claude';

  @override
  IconData get icon => Icons.psychology_rounded;

  @override
  Color get brandColor => AppColors.claude;

  @override
  Color get brandColorLight => AppColors.claudeLight;

  @override
  bool isConfigured(ConnectorConfig config) =>
      config.claudeEnabled && config.claudeApiKey.trim().isNotEmpty;

  @override
  String apiKey(ConnectorConfig config) => config.claudeApiKey.trim();

  @override
  String model(ConnectorConfig config) =>
      config.claudeModel.trim().isEmpty ? 'claude-sonnet-4-20250514' : config.claudeModel.trim();

  @override
  Uri get chatCompletionsUri => Uri.https('api.anthropic.com', '/v1/messages');

  @override
  Future<AiReviewResult> reviewPullRequest({
    required PullRequestContext context,
    required ConnectorConfig config,
    required http.Client client,
  }) async {
    if (apiKey(config).isEmpty) {
      throw ServiceException('Claude API key is missing.');
    }

    final String prompt = buildReviewPrompt(context);
    final http.Response response = await _postMessages(
      model: model(config),
      messages: <Map<String, String>>[
        <String, String>{'role': 'user', 'content': prompt},
      ],
      config: config,
      client: client,
      tag: displayName,
    );

    final Map<String, dynamic> json = decodeJsonBody(response);
    final String output = _extractClaudeText(json).trim();
    if (output.isEmpty) {
      throw ServiceException('Claude returned an empty review.');
    }
    return parseStructuredReview(output);
  }

  @override
  Future<AiChatMessage> chatAboutReview({
    required PullRequestContext context,
    required AiReviewResult review,
    required List<AiChatMessage> history,
    required String userMessage,
    required ConnectorConfig config,
    required http.Client client,
  }) async {
    final List<Map<String, String>> messages = <Map<String, String>>[
      for (final AiChatMessage msg in history)
        <String, String>{'role': msg.role, 'content': msg.content},
      <String, String>{'role': 'user', 'content': userMessage},
    ];

    final http.Response response = await _postMessages(
      model: model(config),
      messages: messages,
      systemPrompt: buildChatSystemPrompt(context: context, review: review),
      config: config,
      client: client,
      tag: '$displayName Chat',
    );

    final Map<String, dynamic> json = decodeJsonBody(response);
    final String responseText = _extractClaudeText(json).trim();

    return AiChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      role: 'assistant',
      content: responseText,
      timestamp: DateTime.now(),
    );
  }

  Future<http.Response> _postMessages({
    required String model,
    required List<Map<String, String>> messages,
    String? systemPrompt,
    required ConnectorConfig config,
    required http.Client client,
    required String tag,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'model': model,
      'max_tokens': 4096,
      'messages': messages,
      if (systemPrompt != null) 'system': systemPrompt,
    };

    if (kDebugMode) {
      debugPrint('[$tag] POST $chatCompletionsUri');
      debugPrint('[$tag] model=$model, messages=${messages.length}');
    }

    final http.Response response = await client.post(
      chatCompletionsUri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'x-api-key': apiKey(config),
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode(body),
    );

    if (kDebugMode) {
      debugPrint('[$tag] Response status=${response.statusCode}');
      debugPrint('[$tag] Response body=${response.body.length > 500 ? '${response.body.substring(0, 500)}...' : response.body}');
    }

    return response;
  }

  String _extractClaudeText(Map<String, dynamic> json) {
    final List<dynamic> content = json['content'] as List<dynamic>? ?? const <dynamic>[];
    final StringBuffer buffer = StringBuffer();
    for (final dynamic block in content) {
      final Map<String, dynamic> map = block as Map<String, dynamic>;
      if (map['type'] == 'text') {
        final String text = map['text'] as String? ?? '';
        if (text.trim().isNotEmpty) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.write(text.trim());
        }
      }
    }
    return buffer.toString();
  }
}
