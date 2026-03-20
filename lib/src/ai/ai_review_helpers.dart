import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import '../services.dart';

String buildReviewPrompt(PullRequestContext context) {
  final List<PullRequestFile> cappedFiles = context.files.take(12).toList();
  final StringBuffer diffBuffer = StringBuffer();
  for (final PullRequestFile file in cappedFiles) {
    diffBuffer.writeln('FILE: ${file.filename}');
    diffBuffer.writeln('STATUS: ${file.status}');
    diffBuffer.writeln('ADDITIONS: ${file.additions}, DELETIONS: ${file.deletions}');
    final String patch = (file.patch ?? '').trim();
    if (patch.isNotEmpty) {
      final String boundedPatch =
          patch.length > 1800 ? '${patch.substring(0, 1800)}\n... [truncated]' : patch;
      diffBuffer.writeln(boundedPatch);
    }
    diffBuffer.writeln('---');
  }

  return '''
You are reviewing a pull request for a senior software engineer.

Return your review as a JSON object with this exact schema:
{
  "verdict": "string - overall verdict",
  "concerns": [
    {
      "title": "string - short title of the concern",
      "severity": "critical|suggestion|nitpick",
      "description": "string - detailed explanation",
      "filePath": "string or null - file path if applicable",
      "lineNumber": "number or null - line number if applicable"
    }
  ],
  "mergeConfidence": "string - Low/Medium/High with brief rationale",
  "executiveSummary": "string - 1-2 sentence summary"
}

Be direct. Prioritize correctness, reliability, security, performance, migrations, concurrency, and rollback safety. Call out anything that deserves human verification.

Pull request metadata:
- Repository: ${context.pullRequest.repository}
- PR: #${context.pullRequest.number}
- Title: ${context.pullRequest.title}
- Author: ${context.pullRequest.author}
- Base branch: ${context.baseBranch}
- Head branch: ${context.headBranch}
- Changed files: ${context.changedFiles}

PR description:
${context.body.trim().isEmpty ? 'No PR description was provided.' : context.body.trim()}

Diff excerpts:
${diffBuffer.toString().trim()}
''';
}

String buildChatSystemPrompt({
  required PullRequestContext context,
  required AiReviewResult review,
}) {
  return '''You are an AI code reviewer assistant. The user has already received an AI review of a pull request and wants to discuss it.

PR: ${context.pullRequest.repository} #${context.pullRequest.number} - ${context.pullRequest.title}
Author: ${context.pullRequest.author}
Review verdict: ${review.verdict}
Review summary: ${review.executiveSummary}
Merge confidence: ${review.mergeConfidence}

Answer follow-up questions about the review. If the user asks you to re-analyze something, provide updated analysis. Be concise and technical.''';
}

AiReviewResult parseStructuredReview(String output) {
  try {
    String jsonStr = output;
    final int jsonStart = output.indexOf('{');
    final int jsonEnd = output.lastIndexOf('}');
    if (jsonStart >= 0 && jsonEnd > jsonStart) {
      jsonStr = output.substring(jsonStart, jsonEnd + 1);
    }
    final Map<String, dynamic> parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    final List<AiReviewConcern> concerns =
        (parsed['concerns'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic c) => AiReviewConcern.fromJson(c as Map<String, dynamic>))
            .toList();
    return AiReviewResult(
      verdict: parsed['verdict'] as String? ?? '',
      concerns: concerns,
      mergeConfidence: parsed['mergeConfidence'] as String? ?? '',
      executiveSummary: parsed['executiveSummary'] as String? ?? '',
      generatedAt: DateTime.now(),
      rawReview: output,
    );
  } catch (_) {
    return AiReviewResult(rawReview: output, generatedAt: DateTime.now());
  }
}

String extractChatCompletionText(Map<String, dynamic> json) {
  final List<dynamic> choices = json['choices'] as List<dynamic>? ?? const <dynamic>[];
  if (choices.isNotEmpty) {
    final Map<String, dynamic> firstChoice = choices.first as Map<String, dynamic>;
    final Map<String, dynamic> message =
        firstChoice['message'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return message['content'] as String? ?? '';
  }
  return json['output_text'] as String? ?? '';
}

Future<http.Response> postChatCompletion({
  required Uri uri,
  required String apiKey,
  required String model,
  required List<Map<String, String>> messages,
  required http.Client client,
  required String tag,
}) async {
  final String requestBody = jsonEncode(<String, dynamic>{
    'model': model,
    'messages': messages,
  });

  if (kDebugMode) {
    debugPrint('[$tag] POST $uri');
    debugPrint('[$tag] model=$model, messages=${messages.length}');
  }

  final http.Response response = await client.post(
    uri,
    headers: <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    },
    body: requestBody,
  );

  if (kDebugMode) {
    debugPrint('[$tag] Response status=${response.statusCode}');
    debugPrint('[$tag] Response body=${response.body.length > 500 ? '${response.body.substring(0, 500)}...' : response.body}');
  }

  return response;
}

Map<String, dynamic> decodeJsonBody(http.Response response) {
  final dynamic decoded = jsonDecode(response.body.isEmpty ? '{}' : response.body);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ServiceException('Request failed (${response.statusCode}): ${response.body}');
  }
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw ServiceException('Expected a JSON object response.');
}
