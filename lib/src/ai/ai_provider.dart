import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import '../services.dart';

abstract class AiProvider {
  String get id;
  String get displayName;
  IconData get icon;
  Color get brandColor;
  Color get brandColorLight;

  bool isConfigured(ConnectorConfig config);
  String apiKey(ConnectorConfig config);
  String model(ConnectorConfig config);

  /// Human-readable model label for display. Defaults to [model]; providers
  /// can override when the raw value is not what actually runs.
  String modelLabel(ConnectorConfig config) => model(config);

  Uri get chatCompletionsUri;

  Future<AiReviewResult> reviewPullRequest({
    required PullRequestContext context,
    required ConnectorConfig config,
    required http.Client client,
  });

  Future<AiChatMessage> chatAboutReview({
    required PullRequestContext context,
    required AiReviewResult review,
    required List<AiChatMessage> history,
    required String userMessage,
    required ConnectorConfig config,
    required http.Client client,
  });

  /// Free-form chat against the provider's synchronous chat endpoint using a
  /// caller-supplied system prompt. Providers without such an endpoint (e.g.
  /// the Cursor cloud agent, which works inside a cloned repository) do not
  /// support this.
  Future<AiChatMessage> chatWithSystemPrompt({
    required String systemPrompt,
    required List<AiChatMessage> history,
    required String userMessage,
    required ConnectorConfig config,
    required http.Client client,
  }) {
    throw ServiceException('$displayName does not support standalone chat.');
  }
}
