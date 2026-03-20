import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import '../services.dart';
import '../theme.dart';
import 'ai_provider.dart';
import 'ai_review_helpers.dart';

class OpenAiProvider extends AiProvider {
  @override
  String get id => 'openai';

  @override
  String get displayName => 'OpenAI';

  @override
  IconData get icon => Icons.auto_awesome_rounded;

  @override
  Color get brandColor => AppColors.openai;

  @override
  Color get brandColorLight => AppColors.openaiLight;

  @override
  bool isConfigured(ConnectorConfig config) =>
      config.openAiEnabled &&
      (config.openAiProxyUrl.trim().isNotEmpty || config.openAiApiKey.trim().isNotEmpty);

  @override
  String apiKey(ConnectorConfig config) => config.openAiApiKey.trim();

  @override
  String model(ConnectorConfig config) =>
      config.openAiModel.trim().isEmpty ? 'gpt-4.1-mini' : config.openAiModel.trim();

  @override
  Uri get chatCompletionsUri => Uri.https('api.openai.com', '/v1/chat/completions');

  @override
  Future<AiReviewResult> reviewPullRequest({
    required PullRequestContext context,
    required ConnectorConfig config,
    required http.Client client,
  }) async {
    if (config.openAiProxyUrl.trim().isNotEmpty) {
      return _reviewViaProxy(context: context, config: config, client: client);
    }
    if (apiKey(config).isEmpty) {
      throw ServiceException('OpenAI API key is missing.');
    }
    return _reviewDirect(context: context, config: config, client: client);
  }

  Future<AiReviewResult> _reviewDirect({
    required PullRequestContext context,
    required ConnectorConfig config,
    required http.Client client,
  }) async {
    final String prompt = buildReviewPrompt(context);
    final http.Response response = await postChatCompletion(
      uri: chatCompletionsUri,
      apiKey: apiKey(config),
      model: model(config),
      messages: <Map<String, String>>[
        <String, String>{'role': 'user', 'content': prompt},
      ],
      client: client,
      tag: displayName,
    );

    final Map<String, dynamic> json = decodeJsonBody(response);
    final String output = extractChatCompletionText(json).trim();
    if (output.isEmpty) {
      throw ServiceException('OpenAI returned an empty review.');
    }
    return parseStructuredReview(output);
  }

  Future<AiReviewResult> _reviewViaProxy({
    required PullRequestContext context,
    required ConnectorConfig config,
    required http.Client client,
  }) async {
    final Uri uri = Uri.parse(config.openAiProxyUrl.trim());
    final http.Response response = await client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (apiKey(config).isNotEmpty)
          'Authorization': 'Bearer ${apiKey(config)}',
      },
      body: jsonEncode(<String, dynamic>{
        'model': model(config),
        'prompt': buildReviewPrompt(context),
        'pullRequest': context.toJson(),
      }),
    );

    final Map<String, dynamic> json = decodeJsonBody(response);
    final String output = (
      json['review'] as String? ??
      json['output_text'] as String? ??
      _extractProxyText(json)
    ).trim();
    if (output.isEmpty) {
      throw ServiceException('The AI review proxy returned an empty review.');
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
      <String, String>{
        'role': 'system',
        'content': buildChatSystemPrompt(context: context, review: review),
      },
      for (final AiChatMessage msg in history)
        <String, String>{'role': msg.role, 'content': msg.content},
      <String, String>{'role': 'user', 'content': userMessage},
    ];

    late final String responseText;
    if (config.openAiProxyUrl.trim().isNotEmpty) {
      final Uri uri = Uri.parse(config.openAiProxyUrl.trim());
      final http.Response response = await client.post(uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (apiKey(config).isNotEmpty) 'Authorization': 'Bearer ${apiKey(config)}',
        },
        body: jsonEncode(<String, dynamic>{'model': model(config), 'messages': messages}),
      );
      final Map<String, dynamic> json = decodeJsonBody(response);
      responseText = json['review'] as String? ?? json['output_text'] as String? ?? _extractProxyText(json);
    } else {
      final http.Response response = await postChatCompletion(
        uri: chatCompletionsUri,
        apiKey: apiKey(config),
        model: model(config),
        messages: messages,
        client: client,
        tag: '$displayName Chat',
      );
      final Map<String, dynamic> json = decodeJsonBody(response);
      responseText = extractChatCompletionText(json).trim();
    }

    return AiChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      role: 'assistant',
      content: responseText,
      timestamp: DateTime.now(),
    );
  }

  String _extractProxyText(Map<String, dynamic> json) {
    final List<dynamic> output = json['output'] as List<dynamic>? ?? const <dynamic>[];
    final StringBuffer buffer = StringBuffer();
    for (final dynamic item in output) {
      final Map<String, dynamic> map = item as Map<String, dynamic>;
      final List<dynamic> content = map['content'] as List<dynamic>? ?? const <dynamic>[];
      for (final dynamic piece in content) {
        final Map<String, dynamic> contentMap = piece as Map<String, dynamic>;
        final String text = contentMap['text'] as String? ?? '';
        if (text.trim().isNotEmpty) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.write(text.trim());
        }
      }
    }
    if (buffer.isNotEmpty) return buffer.toString();
    return extractChatCompletionText(json);
  }
}
