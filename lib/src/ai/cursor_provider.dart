import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import '../services.dart';
import '../theme.dart';
import 'ai_provider.dart';
import 'ai_review_helpers.dart';

/// AI provider backed by the Cursor Cloud Agents API.
///
/// Unlike the chat-completion providers, Cursor has no synchronous completions
/// endpoint. Instead this provider launches a cloud agent on the pull
/// request's repository (`POST /v1/agents` with `repos[0].prUrl`), polls the
/// run until it terminates, and reads the final assistant reply from the
/// run's `result` field. Follow-up chat reuses the same agent via
/// `POST /v1/agents/{id}/runs`, so the conversation keeps its workspace state.
class CursorProvider extends AiProvider {
  CursorProvider({Duration? pollInterval})
      : _pollInterval = pollInterval ?? const Duration(seconds: 5);

  static const String _host = 'api.cursor.com';
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Duration _runTimeout = Duration(minutes: 10);

  /// Legacy placeholder model id from before the Cloud Agents integration.
  /// It is not a valid agent model, so it is treated as "use account default".
  static const String _legacyPlaceholderModel = 'cursor-small';

  final Duration _pollInterval;

  /// Cloud agent id per pull request id, so follow-up chat continues the same
  /// agent conversation. In-memory only: after an app restart a new agent is
  /// created on the next chat message.
  final Map<String, String> _agentIdByPr = <String, String>{};

  @override
  String get id => 'cursor';

  @override
  String get displayName => 'Cursor';

  @override
  IconData get icon => Icons.computer_rounded;

  @override
  Color get brandColor => AppColors.cursor;

  @override
  Color get brandColorLight => AppColors.cursorLight;

  @override
  bool isConfigured(ConnectorConfig config) =>
      config.cursorEnabled && config.cursorApiKey.trim().isNotEmpty;

  @override
  String apiKey(ConnectorConfig config) => config.cursorApiKey.trim();

  @override
  String model(ConnectorConfig config) => config.cursorModel.trim().isEmpty
      ? _legacyPlaceholderModel
      : config.cursorModel.trim();

  @override
  String modelLabel(ConnectorConfig config) {
    final String selected = model(config);
    return selected == _legacyPlaceholderModel
        ? 'Auto (account default)'
        : selected;
  }

  /// Base endpoint of the Cloud Agents API. Cursor has no chat-completions
  /// endpoint; this satisfies the [AiProvider] interface only.
  @override
  Uri get chatCompletionsUri => Uri.https(_host, '/v1/agents');

  @override
  Future<AiReviewResult> reviewPullRequest({
    required PullRequestContext context,
    required ConnectorConfig config,
    required http.Client client,
  }) async {
    final ({String agentId, String runId}) launched = await launchReviewAgent(
      context: context,
      config: config,
      client: client,
    );
    return awaitReviewResult(
      agentId: launched.agentId,
      runId: launched.runId,
      config: config,
      client: client,
    );
  }

  /// Launches the review agent and returns immediately with the ids needed
  /// to poll (or later resume) the run. The caller is expected to persist
  /// them so the review survives app restarts.
  Future<({String agentId, String runId})> launchReviewAgent({
    required PullRequestContext context,
    required ConnectorConfig config,
    required http.Client client,
  }) async {
    if (apiKey(config).isEmpty) {
      throw ServiceException('Cursor API key is missing.');
    }
    final ({String agentId, String runId}) launched = await _createAgent(
      client: client,
      key: apiKey(config),
      config: config,
      context: context,
      promptText: buildCloudAgentReviewPrompt(context),
      name: _agentName(context),
    );
    _agentIdByPr[context.pullRequest.id] = launched.agentId;
    return launched;
  }

  /// Polls a launched (or resumed) run to completion and parses the review.
  Future<AiReviewResult> awaitReviewResult({
    required String agentId,
    required String runId,
    required ConnectorConfig config,
    required http.Client client,
  }) async {
    final String output = await _awaitRunResult(
      client: client,
      key: apiKey(config),
      agentId: agentId,
      runId: runId,
    );
    return parseStructuredReview(output);
  }

  /// Re-links a pull request to an existing cloud agent (e.g. after an app
  /// restart) so follow-up chat continues the same agent conversation.
  void registerAgentForPr(String pullRequestId, String agentId) {
    if (pullRequestId.isEmpty || agentId.isEmpty) return;
    _agentIdByPr[pullRequestId] = agentId;
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
    if (apiKey(config).isEmpty) {
      throw ServiceException('Cursor API key is missing.');
    }

    final String? cachedAgentId = _agentIdByPr[context.pullRequest.id];
    ({String agentId, String runId})? launched;

    if (cachedAgentId != null) {
      try {
        final String runId = await _createFollowUpRun(
          client: client,
          key: apiKey(config),
          agentId: cachedAgentId,
          promptText: 'Answer in plain text (not JSON): $userMessage',
        );
        launched = (agentId: cachedAgentId, runId: runId);
      } on ServiceException catch (error) {
        if (error.statusCode == 409) {
          throw ServiceException(
            'The Cursor agent is still working on a previous request. '
            'Wait for it to finish and try again.',
          );
        }
        // The agent may have been deleted or expired -- start a fresh one.
        if (error.statusCode != 404) rethrow;
        _agentIdByPr.remove(context.pullRequest.id);
      }
    }

    launched ??= await _createAgent(
      client: client,
      key: apiKey(config),
      config: config,
      context: context,
      promptText: _chatBootstrapPrompt(
        context: context,
        review: review,
        userMessage: userMessage,
      ),
      name: _agentName(context),
    );
    _agentIdByPr[context.pullRequest.id] = launched.agentId;

    final String output = await _awaitRunResult(
      client: client,
      key: apiKey(config),
      agentId: launched.agentId,
      runId: launched.runId,
    );

    return AiChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      role: 'assistant',
      content: output,
      timestamp: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------
  // Cloud Agents API calls
  // ---------------------------------------------------------------------

  Future<({String agentId, String runId})> _createAgent({
    required http.Client client,
    required String key,
    required ConnectorConfig config,
    required PullRequestContext context,
    required String promptText,
    required String name,
  }) async {
    final GithubPullRequest pr = context.pullRequest;
    final Map<String, dynamic> repo = <String, dynamic>{
      'url': 'https://github.com/${pr.owner}/${pr.repo}',
      if (pr.url.trim().isNotEmpty)
        'prUrl': pr.url.trim()
      else
        'startingRef': context.headBranch,
    };

    final String selectedModel = model(config);
    final Map<String, dynamic> body = <String, dynamic>{
      'prompt': <String, dynamic>{'text': promptText},
      'repos': <Map<String, dynamic>>[repo],
      'autoCreatePR': false,
      'name': name,
      // The legacy placeholder is not a valid Cloud Agents model id; omitting
      // `model` lets Cursor resolve the account's default model.
      if (selectedModel != _legacyPlaceholderModel)
        'model': <String, dynamic>{'id': selectedModel},
    };

    if (kDebugMode) {
      debugPrint(
        '[Cursor] Creating cloud agent for ${pr.repository}#${pr.number} '
        '(model: ${selectedModel == _legacyPlaceholderModel ? 'account default' : selectedModel})',
      );
    }

    final http.Response response = await _send(
      () => client.post(
        Uri.https(_host, '/v1/agents'),
        headers: _headers(key),
        body: jsonEncode(body),
      ),
    );

    final Map<String, dynamic> json;
    try {
      json = _decodeCursorResponse(response);
    } on ServiceException catch (error) {
      if (kDebugMode) debugPrint('[Cursor] Agent creation failed: $error');
      final int status = error.statusCode ?? 0;
      if (status == 400 || status == 404 || status == 422) {
        throw ServiceException(
          '${error.message} Make sure this repository is connected to '
          "Cursor's GitHub integration and Cloud Agents are available on "
          'your plan (cursor.com/dashboard).',
          statusCode: error.statusCode,
        );
      }
      rethrow;
    }

    final Map<String, dynamic> agent =
        json['agent'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final Map<String, dynamic> run =
        json['run'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final String agentId = agent['id'] as String? ?? '';
    final String runId =
        run['id'] as String? ?? agent['latestRunId'] as String? ?? '';

    if (agentId.isEmpty || runId.isEmpty) {
      throw ServiceException(
        'Cursor did not return an agent id. '
        'Check that the repository is connected to Cursor '
        '(cursor.com/dashboard).',
      );
    }
    if (kDebugMode) {
      debugPrint('[Cursor] Agent $agentId created, run $runId enqueued');
    }
    return (agentId: agentId, runId: runId);
  }

  Future<String> _createFollowUpRun({
    required http.Client client,
    required String key,
    required String agentId,
    required String promptText,
  }) async {
    final http.Response response = await _send(
      () => client.post(
        Uri.https(_host, '/v1/agents/$agentId/runs'),
        headers: _headers(key),
        body: jsonEncode(<String, dynamic>{
          'prompt': <String, dynamic>{'text': promptText},
        }),
      ),
    );
    final Map<String, dynamic> json = _decodeCursorResponse(response);
    final Map<String, dynamic> run =
        json['run'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final String runId = run['id'] as String? ?? '';
    if (runId.isEmpty) {
      throw ServiceException('Cursor did not return a run id.');
    }
    return runId;
  }

  /// Polls the run until it reaches a terminal state and returns the final
  /// assistant reply. Transient poll failures are tolerated until the
  /// deadline; auth/permission errors fail immediately.
  Future<String> _awaitRunResult({
    required http.Client client,
    required String key,
    required String agentId,
    required String runId,
  }) async {
    final DateTime deadline = DateTime.now().add(_runTimeout);
    String lastLoggedStatus = '';

    while (true) {
      Map<String, dynamic>? run;
      try {
        final http.Response response = await _send(
          () => client.get(
            Uri.https(_host, '/v1/agents/$agentId/runs/$runId'),
            headers: _headers(key),
          ),
        );
        run = _decodeCursorResponse(response);
      } on ServiceException catch (error) {
        final int status = error.statusCode ?? 0;
        if (status >= 400 && status < 500) {
          if (kDebugMode) debugPrint('[Cursor] Run poll failed: $error');
          rethrow;
        }
        // 5xx / network / timeout: keep polling until the deadline.
        if (kDebugMode) {
          debugPrint('[Cursor] Transient poll error, retrying: $error');
        }
      }

      if (run != null) {
        final String status = (run['status'] as String? ?? '').toUpperCase();
        if (kDebugMode && status != lastLoggedStatus) {
          debugPrint('[Cursor] Run $runId status: $status');
          lastLoggedStatus = status;
        }
        if (status == 'FINISHED') {
          final String result = (run['result'] as String? ?? '').trim();
          if (result.isEmpty) {
            throw ServiceException(
              'The Cursor agent finished without a reply.',
            );
          }
          return result;
        }
        if (status == 'ERROR' || status == 'CANCELLED' || status == 'EXPIRED') {
          throw ServiceException(
            'The Cursor agent run ended with status $status. '
            'Open cursor.com/agents for details.',
          );
        }
      }

      if (DateTime.now().isAfter(deadline)) {
        throw ServiceException(
          'Timed out after ${_runTimeout.inMinutes} minutes waiting for the '
          'Cursor agent. It may still be running -- tap AI Review again to '
          'resume, or check cursor.com/agents.',
        );
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw ServiceException(
        'Cursor request timed out. Check your network connection.',
      );
    } on http.ClientException catch (error) {
      throw ServiceException(
        'Could not reach Cursor. Check your network connection. '
        '(${error.message})',
      );
    }
  }

  Map<String, dynamic> _decodeCursorResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ServiceException(
        'Cursor rejected the API key. Generate a key under '
        'cursor.com/dashboard -> API Keys and update it in settings.',
        statusCode: response.statusCode,
      );
    }
    return decodeJsonBody(response);
  }

  Map<String, String> _headers(String key) => <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      };

  String _agentName(PullRequestContext context) {
    final String name = 'EngiTrack review: '
        '${context.pullRequest.repository} #${context.pullRequest.number}';
    return name.length <= 100 ? name : name.substring(0, 100);
  }

  String _chatBootstrapPrompt({
    required PullRequestContext context,
    required AiReviewResult review,
    required String userMessage,
  }) {
    return '''
${buildChatSystemPrompt(context: context, review: review)}

STRICT RULES:
- Read-only: do NOT modify files, commit, push, or open pull requests.
- Answer in plain text (not JSON).

User question:
$userMessage
''';
  }
}
