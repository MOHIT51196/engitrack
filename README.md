# EngiTrack

![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-7.0+-3DDC84?logo=android&logoColor=white)
![Material 3](https://img.shields.io/badge/Material_3-Design-757575?logo=materialdesign&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/CI-GitHub_Actions-2088FF?logo=githubactions&logoColor=white)
![License](https://img.shields.io/badge/License-Private-red)

[![GitHub](https://img.shields.io/badge/Integration-GitHub-181717?logo=github&logoColor=white)](https://github.com)
[![Jira](https://img.shields.io/badge/Integration-Jira-0052CC?logo=jira&logoColor=white)](https://www.atlassian.com/software/jira)
[![Slack](https://img.shields.io/badge/Integration-Slack-4A154B?logo=slack&logoColor=white)](https://slack.com)
[![OpenAI](https://img.shields.io/badge/AI-OpenAI-412991?logo=openai&logoColor=white)](https://openai.com)
[![Gemini](https://img.shields.io/badge/AI-Gemini-8E75B2?logo=googlegemini&logoColor=white)](https://deepmind.google/technologies/gemini/)
[![Claude](https://img.shields.io/badge/AI-Claude-D97757?logo=anthropic&logoColor=white)](https://www.anthropic.com)

A productivity cockpit for software engineers. EngiTrack consolidates pull requests, tickets, review requests, alerts, and AI-powered code reviews into a single interface — so you spend less time context-switching between tools and more time shipping.

## Why EngiTrack

Engineers routinely juggle GitHub, Jira, Slack, and multiple browser tabs just to figure out what needs attention right now. EngiTrack solves this by pulling only the actionable items from each tool into one unified dashboard, filtering out the noise and surfacing what matters.

## Features

### Unified Dashboard

A single screen that shows everything that needs your attention — pull requests awaiting your review, Jira tickets assigned to you, Slack review requests, and operational alerts. Each item shows contextual metadata (author, priority, time, status) so you can triage without opening a browser. A greeting card with actionable count gives you an instant pulse on your workload.

### GitHub Integration

Automatically fetches PRs where your review is requested. See the PR title, author, branch, changed files count, additions/deletions, labels, and a summary — all without leaving the app. Tap to open the full PR externally, or trigger an AI review right from the detail screen.

### Jira Integration

Pulls tickets assigned to you with status, priority, issue type, project, parent epic, and due date. Also surfaces issues where you're mentioned in comments. Uses standard JQL under the hood so the results match what you'd see in Jira's own filters.

### Slack Integration

Monitors configured review channels for PR and document review requests. Detects review-related messages, identifies the requester, and links back to both the Slack message and the referenced resource. A dedicated alert channel watches for incident and outage signals with automatic severity classification (Critical, High, Medium, Info).

### AI-Powered Code Review

Connect OpenAI, Google Gemini, or Anthropic Claude to get instant code reviews on any PR. The AI analyzes the diff (metadata, description, changed files) and returns a structured review with a verdict, merge confidence score, executive summary, and a list of concerns — each tagged with severity (critical, suggestion, nitpick), file path, and line number. Follow up with conversational Q&A about the review, or post an AI-generated concern directly as a comment on the GitHub PR.

### ToDo Workspace

A built-in task manager that lives alongside your integrations. Create tasks manually or promote any dashboard item (PR, ticket, review request) into a todo with one tap. Supports reminders with date/time picker, repeat schedules (daily, weekly, monthly), completion tracking, search, and swipe-to-delete. A progress bar shows your completion rate at a glance.

### Local Notifications

Opt-in push notifications for Slack alerts. When a new critical or high-severity alert arrives, you get notified even when the app is in the background — no need to keep Slack open.

### Configuration Management

All integrations are configurable from a single settings screen with collapsible sections, connection status badges, and adjustable sync intervals (1–60 minutes per integration). Sensitive credentials (tokens, API keys) are stored using platform-level secure storage. Export and import your entire configuration as JSON for backup or team sharing.

### Resolve and Triage

Mark any item as resolved to clear it from the dashboard. Resolved items are persisted locally and accessible from a dedicated screen where you can unresolve if needed. This gives you a lightweight triage workflow without affecting the upstream tool.

### Responsive Layout

The UI adapts to screen size — bottom navigation on phones, sidebar navigation on tablets and desktops. Built with Material 3 and a polished custom theme.

## Versioning

EngiTrack follows [Semantic Versioning (SemVer)](https://semver.org/).

**Current version:** `1.0.0+1`

Version format: `MAJOR.MINOR.PATCH+BUILD`

| Segment | Meaning |
|---------|---------|
| MAJOR | Breaking changes to integrations, data model, or configuration format |
| MINOR | New features, integrations, or non-breaking enhancements |
| PATCH | Bug fixes, performance improvements, dependency updates |
| BUILD | CI build number, auto-incremented by GitHub Actions (`github.run_number`) |

The version is declared in `pubspec.yaml` and propagated to Android builds via the Flutter Gradle plugin (`versionCode` / `versionName`). CI builds override the build number with the workflow run number.

### Version Matrix

| Component | Version / Constraint |
|-----------|---------------------|
| EngiTrack | 1.0.0+1 |
| Flutter SDK | >= 3.24.0 |
| Dart SDK | >= 3.5.0 < 4.0.0 |
| Android compileSdk | 36 |
| Android minSdk | 24 (Android 7.0) |
| Gradle | 8.7 |
| Java (CI) | 17 (Temurin) |
| Kotlin | Android Gradle Plugin default |
| NDK | 25.1.8937393 |

### Key Dependencies

| Package | Version |
|---------|---------|
| http | ^1.6.0 |
| flutter_secure_storage | ^10.0.0 |
| flutter_local_notifications | ^19.5.0 |
| flutter_svg | ^2.0.17 |
| shared_preferences | ^2.5.3 |
| url_launcher | ^6.3.1 |
| intl | ^0.20.2 |
| file_picker | ^8.0.0 |
| flutter_timezone | ^4.1.1 |

### Release Process

1. Update the `version` field in `pubspec.yaml`.
2. Tag the commit: `git tag v<MAJOR>.<MINOR>.<PATCH>`.
3. Push the tag: `git push origin v<MAJOR>.<MINOR>.<PATCH>`.
4. The CI pipeline triggers on `v*` tags, builds production APKs, and uploads artifacts.

## Getting Started

### Prerequisites

- Flutter SDK >= 3.24.0
- Dart SDK >= 3.5.0
- Android SDK with compileSdk 36 (for Android builds)

### Setup

```bash
make setup
make run
```

Run `make help` to see all available commands.

### Integration Setup

Open the Integrations screen in the app and configure each service:

| Integration | Required Credentials |
|-------------|---------------------|
| GitHub | Username, Personal Access Token |
| Jira | Site URL, Email, API Token |
| Slack | Bot Token, Channel IDs (optionally: refresh token, client ID/secret for rotating tokens) |
| OpenAI | API Key or Proxy URL |
| Gemini | API Key |
| Claude | API Key |

All credentials are stored in platform secure storage and never leave the device.

## CI/CD

The project includes a GitHub Actions pipeline (`.github/workflows/ci.yml`) with:

- Static analysis and formatting checks
- Dependency vulnerability scanning (OSV-Scanner, TruffleHog)
- Production Android APK builds (split per ABI + universal)
- Downloadable build artifacts with 30-day retention

## Contributing

Contributions are welcome! Whether it's a bug fix, new feature, documentation improvement, or a question — we appreciate your interest in making EngiTrack better.

### Before You Start

- **Check existing issues** — search [open issues](../../issues) to see if your bug or feature has already been reported. If it has, add a reaction or comment instead of opening a duplicate.
- **Open an issue first for large changes** — if you're planning a significant feature or architectural change, open an issue to discuss it before writing code. This avoids wasted effort if the direction doesn't align with the project roadmap.

### Development Setup

1. Fork the repository and clone your fork:

```bash
git clone https://github.com/<your-username>/engitrack.git
cd engitrack
```

2. Install dependencies and set up git hooks:

```bash
make setup
```

3. Create a feature branch from `main`:

```bash
git checkout -b feat/your-feature-name
```

4. Verify the project builds:

```bash
make check
make run
```

### Branch Naming Convention

| Prefix | Purpose |
|--------|---------|
| `feat/` | New features |
| `fix/` | Bug fixes |
| `docs/` | Documentation changes |
| `refactor/` | Code refactoring (no behavior change) |
| `chore/` | Dependency updates, CI changes, tooling |
| `test/` | Adding or updating tests |

### Coding Standards

- **Formatting** — run `dart format .` before committing. The pre-commit hook and CI both enforce this.
- **Static analysis** — run `flutter analyze` and resolve all warnings. The pre-commit hook and CI both enforce this.
- **Lint rules** — the project uses `flutter_lints` with additional rules in `analysis_options.yaml`. Do not disable lint rules without justification.
- **No hardcoded secrets** — never commit API keys, tokens, or credentials. Use `flutter_secure_storage` for sensitive data at runtime.

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

<optional body>

<optional footer>
```

Examples:

```
feat(dashboard): add pull request label filtering
fix(slack): handle expired bot token gracefully
docs(readme): add contributing guidelines
chore(deps): bump flutter_secure_storage to ^10.0.0
```

### Pull Request Process

1. **Ensure your branch is up to date** with `main`:

```bash
git fetch origin
git rebase origin/main
```

2. **Run the full check suite locally** before pushing (this runs automatically via git hooks if you ran `make setup`, but you can also run it manually):

```bash
make check
```

3. **Push your branch** and open a pull request against `main`.

4. **Fill out the PR template** — every PR should include:
   - A clear title following the conventional commit format.
   - A summary of what changed and why.
   - Steps to test or verify the change.
   - Screenshots or screen recordings for UI changes.
   - A note on any breaking changes.

5. **CI must pass** — the pipeline runs formatting checks, static analysis, security scanning, and a production Android build. PRs with failing checks will not be merged.

6. **Code review** — at least one maintainer review is required. Address review feedback by pushing additional commits (do not force-push during review).

7. **Merge** — maintainers will squash-merge approved PRs into `main`.

### Reporting Bugs

Open an issue with:

- A clear, descriptive title.
- Steps to reproduce.
- Expected vs. actual behavior.
- Flutter version (`flutter --version`), device/OS, and app version.
- Logs or screenshots if applicable.

### Requesting Features

Open an issue with:

- A description of the problem the feature solves.
- Your proposed solution (if any).
- Alternatives you've considered.

## License

Private — not open source.
