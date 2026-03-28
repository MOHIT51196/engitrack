import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:engitrack/src/ai/ai_review_helpers.dart';
import 'package:engitrack/src/models.dart';
import 'package:engitrack/src/services.dart';

PullRequestContext _makeContext({
  String body = 'PR description',
  int fileCount = 1,
}) {
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
    body: body,
    baseBranch: 'main',
    headBranch: 'feature/x',
    changedFiles: fileCount,
    files: List<PullRequestFile>.generate(
      fileCount,
      (i) => PullRequestFile(
        filename: 'file_$i.dart',
        status: 'modified',
        additions: 5 + i,
        deletions: i,
        patch: '@@ -1,3 +1,${5 + i} @@\n+added line $i',
      ),
    ),
  );
}

void main() {
  group('buildReviewPrompt', () {
    test('includes PR metadata', () {
      final prompt = buildReviewPrompt(_makeContext());
      expect(prompt, contains('Repository: o/r'));
      expect(prompt, contains('PR: #1'));
      expect(prompt, contains('Title: Add feature'));
      expect(prompt, contains('Author: alice'));
      expect(prompt, contains('Base branch: main'));
      expect(prompt, contains('Head branch: feature/x'));
    });

    test('includes PR description', () {
      final prompt = buildReviewPrompt(_makeContext(body: 'My changes'));
      expect(prompt, contains('My changes'));
    });

    test('uses placeholder for empty description', () {
      final prompt = buildReviewPrompt(_makeContext(body: ''));
      expect(prompt, contains('No PR description was provided'));
    });

    test('includes file diffs', () {
      final prompt = buildReviewPrompt(_makeContext(fileCount: 2));
      expect(prompt, contains('FILE: file_0.dart'));
      expect(prompt, contains('FILE: file_1.dart'));
      expect(prompt, contains('STATUS: modified'));
    });

    test('caps files at 12', () {
      final prompt = buildReviewPrompt(_makeContext(fileCount: 20));
      final fileCount =
          RegExp(r'FILE: file_\d+\.dart').allMatches(prompt).length;
      expect(fileCount, 12);
    });

    test('includes JSON schema instruction', () {
      final prompt = buildReviewPrompt(_makeContext());
      expect(prompt, contains('"verdict"'));
      expect(prompt, contains('"concerns"'));
      expect(prompt, contains('"mergeConfidence"'));
      expect(prompt, contains('"executiveSummary"'));
    });
  });

  group('buildChatSystemPrompt', () {
    test('includes PR info and review context', () {
      final context = _makeContext();
      final review = AiReviewResult(
        generatedAt: DateTime.utc(2025),
        verdict: 'Approve with nits',
        executiveSummary: 'Clean PR',
        mergeConfidence: 'High',
      );

      final prompt = buildChatSystemPrompt(context: context, review: review);
      expect(prompt, contains('o/r #1'));
      expect(prompt, contains('Add feature'));
      expect(prompt, contains('Approve with nits'));
      expect(prompt, contains('Clean PR'));
      expect(prompt, contains('High'));
    });
  });

  group('parseStructuredReview', () {
    test('parses valid JSON review', () {
      final jsonStr = jsonEncode(<String, dynamic>{
        'verdict': 'Approve',
        'concerns': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'Naming',
            'severity': 'nitpick',
            'description': 'Consider renaming',
          },
        ],
        'mergeConfidence': 'High - looks good',
        'executiveSummary': 'Clean PR with minor nits',
      });

      final result = parseStructuredReview(jsonStr);
      expect(result.verdict, 'Approve');
      expect(result.concerns, hasLength(1));
      expect(result.concerns.first.title, 'Naming');
      expect(result.mergeConfidence, 'High - looks good');
      expect(result.executiveSummary, 'Clean PR with minor nits');
      expect(result.rawReview, jsonStr);
    });

    test('extracts JSON from markdown fenced block', () {
      final raw = '''Here is the review:
```json
{
  "verdict": "Needs changes",
  "concerns": [],
  "mergeConfidence": "Low",
  "executiveSummary": "Missing tests"
}
```
End of review.''';

      final result = parseStructuredReview(raw);
      expect(result.verdict, 'Needs changes');
      expect(result.executiveSummary, 'Missing tests');
    });

    test('returns raw fallback for invalid JSON', () {
      const raw = 'This is plain text, not JSON at all';
      final result = parseStructuredReview(raw);
      expect(result.rawReview, raw);
      expect(result.verdict, isEmpty);
      expect(result.concerns, isEmpty);
    });

    test('handles JSON with surrounding prose', () {
      const raw =
          'Sure, here is my review:\n{"verdict":"OK","concerns":[],"mergeConfidence":"High","executiveSummary":"All good"}\nEnd.';
      final result = parseStructuredReview(raw);
      expect(result.verdict, 'OK');
    });
  });

  group('extractChatCompletionText', () {
    test('extracts from standard choices format', () {
      final json = <String, dynamic>{
        'choices': <Map<String, dynamic>>[
          <String, dynamic>{
            'message': <String, dynamic>{'content': 'Hello'},
          },
        ],
      };
      expect(extractChatCompletionText(json), 'Hello');
    });

    test('falls back to output_text', () {
      final json = <String, dynamic>{
        'choices': <dynamic>[],
        'output_text': 'Fallback text',
      };
      expect(extractChatCompletionText(json), 'Fallback text');
    });

    test('returns empty when nothing available', () {
      expect(extractChatCompletionText(<String, dynamic>{}), '');
    });

    test('handles missing message in choice', () {
      final json = <String, dynamic>{
        'choices': <Map<String, dynamic>>[
          <String, dynamic>{},
        ],
      };
      expect(extractChatCompletionText(json), '');
    });
  });

  group('decodeJsonBody (ai_review_helpers)', () {
    test('returns parsed JSON on 200', () {
      final response = http.Response('{"key":"value"}', 200);
      final result = decodeJsonBody(response);
      expect(result['key'], 'value');
    });

    test('throws ServiceException on non-2xx', () {
      final response = http.Response('{"error":"bad"}', 500);
      expect(
        () => decodeJsonBody(response),
        throwsA(isA<ServiceException>()),
      );
    });

    test('throws ServiceException for non-object response', () {
      final response = http.Response('"just a string"', 200);
      expect(
        () => decodeJsonBody(response),
        throwsA(isA<ServiceException>()),
      );
    });

    test('handles empty body gracefully', () {
      final response = http.Response('', 200);
      final result = decodeJsonBody(response);
      expect(result, isEmpty);
    });
  });
}
