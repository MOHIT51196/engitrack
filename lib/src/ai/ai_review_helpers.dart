import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import '../services.dart';

const String reviewJsonSchemaInstructions =
    '''Return your review as a JSON object with this exact schema:
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

Be direct. Prioritize correctness, reliability, security, performance, migrations, concurrency, and rollback safety. Call out anything that deserves human verification.''';

String buildReviewPrompt(PullRequestContext context) {
  final List<PullRequestFile> cappedFiles = context.files.take(12).toList();
  final StringBuffer diffBuffer = StringBuffer();
  for (final PullRequestFile file in cappedFiles) {
    diffBuffer.writeln('FILE: ${file.filename}');
    diffBuffer.writeln('STATUS: ${file.status}');
    diffBuffer.writeln(
      'ADDITIONS: ${file.additions}, DELETIONS: ${file.deletions}',
    );
    final String patch = (file.patch ?? '').trim();
    if (patch.isNotEmpty) {
      final String boundedPatch = patch.length > 1800
          ? '${patch.substring(0, 1800)}\n... [truncated]'
          : patch;
      diffBuffer.writeln(boundedPatch);
    }
    diffBuffer.writeln('---');
  }

  return '''
You are reviewing a pull request for a senior software engineer.

$reviewJsonSchemaInstructions

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

/// Prompt for a Cursor Cloud Agent. Unlike the chat-completion providers, the
/// agent has the PR's repository checked out in its workspace, so it inspects
/// the diff itself instead of relying on inlined patch excerpts.
String buildCloudAgentReviewPrompt(PullRequestContext context) {
  final StringBuffer fileList = StringBuffer();
  for (final PullRequestFile file in context.files.take(50)) {
    fileList.writeln(
      '- ${file.filename} (${file.status}, '
      '+${file.additions}/-${file.deletions})',
    );
  }

  return '''
You are reviewing GitHub pull request #${context.pullRequest.number} ("${context.pullRequest.title}") in ${context.pullRequest.repository}. The repository is checked out in this workspace on the pull request's branch.

STRICT RULES:
- This is a READ-ONLY review. Do NOT modify files, run formatters, commit, push, or open pull requests.
- Inspect the changes with read-only commands such as `git diff origin/${context.baseBranch}...HEAD` and `git log`, and by reading the changed files.

$reviewJsonSchemaInstructions

Your final assistant message must contain ONLY that JSON object.

Pull request metadata:
- Repository: ${context.pullRequest.repository}
- PR: #${context.pullRequest.number}
- Author: ${context.pullRequest.author}
- Base branch: ${context.baseBranch}
- Head branch: ${context.headBranch}
- Changed files: ${context.changedFiles}

PR description:
${context.body.trim().isEmpty ? 'No PR description was provided.' : context.body.trim()}

Changed files according to GitHub:
${fileList.toString().trim()}
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

/// Canned first message that kicks off the Jira discovery assist chat.
const String jiraAssistKickoffMessage =
    'Analyze this ticket and give me the breakdown.';

/// Whether a Jira issue type denotes a spike / research ticket.
bool isSpikeIssueType(String issueType) =>
    issueType.trim().toLowerCase().contains('spike');

/// System prompt for the Jira discovery assist chat. Built purely from the
/// ticket fields the Jira sync already stores -- the model gets no codebase,
/// GitHub, or repository access of any kind.
String buildJiraAssistSystemPrompt({
  required String issueKey,
  required String title,
  required String issueType,
  required String status,
  required String priority,
  required String projectName,
  required String parentSummary,
  required String description,
}) {
  final bool spike = isSpikeIssueType(issueType);

  final String task = spike
      ? '''
This ticket is a SPIKE (time-boxed research). For the initial analysis, respond with a well-formatted spike breakdown using exactly these sections:
Objective -- one or two sentences on what the spike must establish.
Key questions to answer -- numbered list of the concrete questions the spike should resolve.
Investigation plan -- ordered steps for carrying out the research.
Suggested timebox -- a realistic effort estimate with a one-line rationale.
Expected deliverables -- what should exist when the spike is done (notes, decision, proof of concept, follow-up tickets).
Risks and open questions -- anything that could invalidate the findings or needs stakeholder input.'''
      : '''
This ticket describes work to implement. For the initial analysis, explain the code change that needs to happen using exactly these sections:
Requirement summary -- restate what is being asked in one or two sentences.
Proposed approach -- how the change should be implemented at a conceptual level.
Components likely affected -- the kinds of modules, layers, or systems that typically need touching for this change (reason from the ticket, not from code you have not seen).
Edge cases -- inputs, states, or failure modes the implementation must handle.
Acceptance and testing checklist -- bullet list of checks that prove the change is done.''';

  return '''
You are a senior software engineer helping a teammate with discovery on a Jira ticket.

STRICT CONSTRAINTS:
- You have NO access to any codebase, GitHub, or repository. Never claim to have read code, and never cite file names or line numbers as if they were real.
- This is discovery and analysis only. Do not offer to open pull requests or modify anything.
- Base everything on the ticket fields below and on what the user tells you in chat.
- Format answers as structured plain text: short section headings on their own line, hyphen bullets, and numbered steps. Do not use markdown tables or code fences unless quoting text the user provided.

Ticket:
- Key: ${issueKey.isEmpty ? 'unknown' : issueKey}
- Title: $title
- Type: ${issueType.isEmpty ? 'unknown' : issueType}
- Status: ${status.isEmpty ? 'unknown' : status}
- Priority: ${priority.isEmpty ? 'unknown' : priority}
- Project: ${projectName.isEmpty ? 'unknown' : projectName}${parentSummary.isEmpty ? '' : '\n- Parent: $parentSummary'}

Ticket description:
${description.trim().isEmpty ? 'No description was provided.' : description.trim()}

$task

For follow-up questions, answer conversationally but keep the same constraints and stay concise and technical.''';
}

AiReviewResult parseStructuredReview(String output) {
  try {
    String jsonStr = output;
    final int jsonStart = output.indexOf('{');
    final int jsonEnd = output.lastIndexOf('}');
    if (jsonStart >= 0 && jsonEnd > jsonStart) {
      jsonStr = output.substring(jsonStart, jsonEnd + 1);
    }
    final Map<String, dynamic> parsed =
        jsonDecode(jsonStr) as Map<String, dynamic>;
    // Tolerate imperfect entries: models sometimes emit concerns as plain
    // strings or mix malformed entries into an otherwise valid list. Keep
    // everything usable instead of discarding the whole structure.
    final List<AiReviewConcern> concerns = <AiReviewConcern>[];
    for (final dynamic entry
        in parsed['concerns'] as List<dynamic>? ?? const <dynamic>[]) {
      if (entry is Map<String, dynamic>) {
        concerns.add(AiReviewConcern.fromJson(entry));
      } else if (entry is String && entry.trim().isNotEmpty) {
        concerns.add(
          AiReviewConcern(
            title: entry.trim().split('\n').first,
            severity: 'suggestion',
            description: entry.trim(),
          ),
        );
      }
    }
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

/// Builds a single consolidated GitHub review comment (markdown) from the
/// selected concerns plus the review's verdict/confidence/summary.
String buildConsolidatedReviewComment({
  required AiReviewResult review,
  required List<AiReviewConcern> concerns,
}) {
  final StringBuffer buffer = StringBuffer();

  if (review.verdict.isNotEmpty) {
    buffer.writeln('**Verdict:** ${review.verdict}');
    buffer.writeln();
  }

  final List<AiReviewConcern> ordered = sortConcernsBySeverity(concerns);
  if (ordered.isNotEmpty) {
    buffer.writeln('### Concerns');
    for (int i = 0; i < ordered.length; i++) {
      final AiReviewConcern concern = ordered[i];
      buffer.writeln('${i + 1}. **[${concern.severity}] ${concern.title}**');
      if (concern.description.trim().isNotEmpty) {
        buffer.writeln('   ${concern.description.trim()}');
      }
      if (concern.filePath != null) {
        buffer.writeln(
          '   `${concern.filePath}'
          '${concern.lineNumber != null ? ':${concern.lineNumber}' : ''}`',
        );
      }
    }
    buffer.writeln();
  }

  if (review.mergeConfidence.isNotEmpty) {
    buffer.writeln('**Merge confidence:** ${review.mergeConfidence}');
    buffer.writeln();
  }
  if (review.executiveSummary.isNotEmpty) {
    buffer.writeln('**Summary:** ${review.executiveSummary}');
  }

  final String result = buffer.toString().trim();
  final String content = result.isEmpty ? review.rawReview.trim() : result;
  if (content.isEmpty) return '';
  // <sub> renders as small text on GitHub -- an unobtrusive footer.
  return '$content\n\n<sub>Posted via EngiTrack</sub>';
}

/// Sorts concerns for triage: critical first, then suggestions, then
/// nitpicks, preserving the model's order within each severity.
List<AiReviewConcern> sortConcernsBySeverity(List<AiReviewConcern> concerns) {
  int rank(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 0;
      case 'suggestion':
        return 2;
      case 'nitpick':
        return 3;
      default:
        return 1;
    }
  }

  final List<AiReviewConcern> sorted = List<AiReviewConcern>.from(concerns);
  final Map<AiReviewConcern, int> originalIndex = <AiReviewConcern, int>{
    for (int i = 0; i < concerns.length; i++) concerns[i]: i,
  };
  sorted.sort((AiReviewConcern a, AiReviewConcern b) {
    final int bySeverity = rank(a.severity).compareTo(rank(b.severity));
    if (bySeverity != 0) return bySeverity;
    return (originalIndex[a] ?? 0).compareTo(originalIndex[b] ?? 0);
  });
  return sorted;
}

String extractChatCompletionText(Map<String, dynamic> json) {
  final List<dynamic> choices =
      json['choices'] as List<dynamic>? ?? const <dynamic>[];
  if (choices.isNotEmpty) {
    final Map<String, dynamic> firstChoice =
        choices.first as Map<String, dynamic>;
    final Map<String, dynamic> message =
        firstChoice['message'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
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
    // Log status only -- bodies contain PR code and review content.
    debugPrint('[$tag] Response status=${response.statusCode}');
  }

  return response;
}

Map<String, dynamic> decodeJsonBody(http.Response response) {
  // Check the status before decoding: error bodies are not always JSON.
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ServiceException(
      'Request failed (${response.statusCode}): ${response.body}',
      statusCode: response.statusCode,
    );
  }
  final dynamic decoded;
  try {
    decoded = jsonDecode(response.body.isEmpty ? '{}' : response.body);
  } on FormatException {
    throw ServiceException('The AI provider returned a malformed response.');
  }
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw ServiceException('Expected a JSON object response.');
}
