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
      final fileCount = RegExp(
        r'FILE: file_\d+\.dart',
      ).allMatches(prompt).length;
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

    test('parses a long list of concerns', () {
      final jsonStr = jsonEncode(<String, dynamic>{
        'verdict': 'Request changes',
        'concerns': List<Map<String, dynamic>>.generate(
          15,
          (int i) => <String, dynamic>{
            'title': 'Concern $i',
            'severity': i < 5 ? 'critical' : 'suggestion',
            'description': 'Description $i',
          },
        ),
        'mergeConfidence': 'Low',
        'executiveSummary': 'Many blockers',
      });

      final result = parseStructuredReview(jsonStr);
      expect(result.concerns, hasLength(15));
    });

    test('tolerates string entries in concerns list', () {
      final jsonStr = jsonEncode(<String, dynamic>{
        'verdict': 'Needs work',
        'concerns': <dynamic>[
          <String, dynamic>{
            'title': 'Real concern',
            'severity': 'critical',
            'description': 'Detail',
          },
          'Missing null check in parser\nCould crash on empty input',
          42,
        ],
        'mergeConfidence': 'Low',
        'executiveSummary': 'Mixed entries',
      });

      final result = parseStructuredReview(jsonStr);
      expect(result.concerns, hasLength(2));
      expect(result.concerns.first.title, 'Real concern');
      expect(
        result.concerns.last.title,
        'Missing null check in parser',
      );
      expect(result.concerns.last.severity, 'suggestion');
    });
  });

  group('buildConsolidatedReviewComment', () {
    final review = AiReviewResult(
      generatedAt: DateTime.utc(2026),
      verdict: 'Request changes',
      concerns: const <AiReviewConcern>[
        AiReviewConcern(
          title: 'Minor naming',
          severity: 'nitpick',
          description: 'Rename x to count',
        ),
        AiReviewConcern(
          title: 'SQL injection',
          severity: 'critical',
          description: 'Query is concatenated',
          filePath: 'lib/db.dart',
          lineNumber: 42,
        ),
      ],
      mergeConfidence: 'Low',
      executiveSummary: 'Fix the injection first.',
    );

    test('builds one markdown message with critical concerns first', () {
      final body = buildConsolidatedReviewComment(
        review: review,
        concerns: review.concerns,
      );

      expect(body, contains('**Verdict:** Request changes'));
      expect(body, contains('### Concerns'));
      expect(body, contains('1. **[critical] SQL injection**'));
      expect(body, contains('2. **[nitpick] Minor naming**'));
      expect(body, contains('`lib/db.dart:42`'));
      expect(body, contains('**Merge confidence:** Low'));
      expect(body, contains('**Summary:** Fix the injection first.'));
      expect(body, endsWith('<sub>Posted via EngiTrack</sub>'));
    });

    test('includes only the selected concerns', () {
      final body = buildConsolidatedReviewComment(
        review: review,
        concerns: <AiReviewConcern>[review.concerns.first],
      );

      expect(body, contains('Minor naming'));
      expect(body, isNot(contains('SQL injection')));
    });

    test('falls back to raw review when nothing structured', () {
      final rawOnly = AiReviewResult(
        generatedAt: DateTime.utc(2026),
        rawReview: 'Free-form review text',
      );
      final body = buildConsolidatedReviewComment(
        review: rawOnly,
        concerns: const <AiReviewConcern>[],
      );
      expect(body, 'Free-form review text\n\n<sub>Posted via EngiTrack</sub>');
    });

    test('returns empty string when there is nothing to post', () {
      final empty = AiReviewResult(generatedAt: DateTime.utc(2026));
      final body = buildConsolidatedReviewComment(
        review: empty,
        concerns: const <AiReviewConcern>[],
      );
      expect(body, isEmpty);
    });
  });

  group('sortConcernsBySeverity', () {
    test('orders critical first, preserving order within severity', () {
      const concerns = <AiReviewConcern>[
        AiReviewConcern(title: 'nit A', severity: 'nitpick', description: ''),
        AiReviewConcern(
            title: 'sug A', severity: 'suggestion', description: ''),
        AiReviewConcern(title: 'crit A', severity: 'critical', description: ''),
        AiReviewConcern(
            title: 'sug B', severity: 'suggestion', description: ''),
        AiReviewConcern(title: 'crit B', severity: 'Critical', description: ''),
      ];

      final sorted = sortConcernsBySeverity(concerns);
      expect(
        sorted.map((AiReviewConcern c) => c.title).toList(),
        <String>['crit A', 'crit B', 'sug A', 'sug B', 'nit A'],
      );
      // Original list is untouched.
      expect(concerns.first.title, 'nit A');
    });

    test('places unknown severities after critical', () {
      const concerns = <AiReviewConcern>[
        AiReviewConcern(title: 'odd', severity: 'blocker', description: ''),
        AiReviewConcern(title: 'crit', severity: 'critical', description: ''),
        AiReviewConcern(title: 'sug', severity: 'suggestion', description: ''),
      ];

      final sorted = sortConcernsBySeverity(concerns);
      expect(
        sorted.map((AiReviewConcern c) => c.title).toList(),
        <String>['crit', 'odd', 'sug'],
      );
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
        'choices': <Map<String, dynamic>>[<String, dynamic>{}],
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
      expect(() => decodeJsonBody(response), throwsA(isA<ServiceException>()));
    });

    test('throws ServiceException for non-object response', () {
      final response = http.Response('"just a string"', 200);
      expect(() => decodeJsonBody(response), throwsA(isA<ServiceException>()));
    });

    test('handles empty body gracefully', () {
      final response = http.Response('', 200);
      final result = decodeJsonBody(response);
      expect(result, isEmpty);
    });
  });
}
