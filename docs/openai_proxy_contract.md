# EngiTrack AI Proxy Contract

EngiTrack supports an optional backend proxy for PR review instead of calling OpenAI directly from the Flutter client.

## Request

`POST /review-pr`

```json
{
  "model": "gpt-5-mini",
  "prompt": "...generated prompt...",
  "pullRequest": {
    "pullRequest": {
      "id": "airbnb/engitrack#142",
      "repository": "airbnb/engitrack",
      "number": 142,
      "title": "Refactor reviewer queue to support batched priority scoring",
      "author": "nina.s",
      "url": "https://github.com/airbnb/engitrack/pull/142"
    },
    "body": "PR description",
    "baseBranch": "main",
    "headBranch": "feature/reviewer-priority-score",
    "changedFiles": 9,
    "files": [
      {
        "filename": "lib/reviewer_queue.dart",
        "status": "modified",
        "additions": 42,
        "deletions": 11,
        "patch": "@@ ..."
      }
    ]
  }
}
```

## Response

The proxy can return either of these shapes:

```json
{ "review": "Verdict\n- ..." }
```

or

```json
{ "output_text": "Verdict\n- ..." }
```

## Why use a proxy?

- keeps API keys out of the shipped mobile app
- lets you apply org auth or OAuth in your own backend
- gives you control over logging, rate limiting, model policy, and prompt hardening
