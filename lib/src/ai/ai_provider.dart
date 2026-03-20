import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models.dart';

abstract class AiProvider {
  String get id;
  String get displayName;
  IconData get icon;
  Color get brandColor;
  Color get brandColorLight;

  bool isConfigured(ConnectorConfig config);
  String apiKey(ConnectorConfig config);
  String model(ConnectorConfig config);
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
}
