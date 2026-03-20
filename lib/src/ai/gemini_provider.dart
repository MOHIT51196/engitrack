import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import '../services.dart';
import '../theme.dart';
import 'ai_provider.dart';
import 'ai_review_helpers.dart';

class GeminiProvider extends AiProvider {
  @override
  String get id => 'gemini';

  @override
  String get displayName => 'Google Gemini';

  @override
  IconData get icon => Icons.diamond_outlined;

  @override
  Color get brandColor => AppColors.gemini;

  @override
  Color get brandColorLight => AppColors.geminiLight;

  @override
  bool isConfigured(ConnectorConfig config) =>
      config.geminiEnabled && config.geminiApiKey.trim().isNotEmpty;

  @override
  String apiKey(ConnectorConfig config) => config.geminiApiKey.trim();

  @override
  String model(ConnectorConfig config) =>
      config.geminiModel.trim().isEmpty ? 'gemini-2.0-flash' : config.geminiModel.trim();

  @override
  Uri get chatCompletionsUri =>
      Uri.https('generativelanguage.googleapis.com', '/v1beta/openai/chat/completions');

  @override
  Future<AiReviewResult> reviewPullRequest({
    required PullRequestContext context,
    required ConnectorConfig config,
    required http.Client client,
  }) async {
    if (apiKey(config).isEmpty) {
      throw ServiceException('Gemini API key is missing.');
    }
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
      throw ServiceException('Gemini returned an empty review.');
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

    final http.Response response = await postChatCompletion(
      uri: chatCompletionsUri,
      apiKey: apiKey(config),
      model: model(config),
      messages: messages,
      client: client,
      tag: '$displayName Chat',
    );

    final Map<String, dynamic> json = decodeJsonBody(response);
    final String responseText = extractChatCompletionText(json).trim();

    return AiChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      role: 'assistant',
      content: responseText,
      timestamp: DateTime.now(),
    );
  }
}
