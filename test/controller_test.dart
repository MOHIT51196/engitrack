import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:engitrack/src/controller.dart';
import 'package:engitrack/src/integrations/integration_provider.dart';
import 'package:engitrack/src/models.dart';
import 'package:engitrack/src/services.dart';
import 'package:engitrack/src/storage.dart';

class MockAppStorage extends Mock implements AppStorage {}

class MockNotificationsService extends Mock implements NotificationsService {}

class MockGitHubService extends Mock implements GitHubService {}

class MockJiraService extends Mock implements JiraService {}

class MockSlackService extends Mock implements SlackService {}

void main() {
  late MockAppStorage mockStorage;
  late MockNotificationsService mockNotifications;
  late MockGitHubService mockGitHub;
  late MockJiraService mockJira;
  late MockSlackService mockSlack;

  ConnectorConfig defaultConfig() => const ConnectorConfig();

  setUpAll(() {
    registerFallbackValue(const ConnectorConfig());
    registerFallbackValue(<TodoItem>[]);
    registerFallbackValue(<NoteItem>[]);
    registerFallbackValue(<String>{});
  });

  setUp(() {
    mockStorage = MockAppStorage();
    mockNotifications = MockNotificationsService();
    mockGitHub = MockGitHubService();
    mockJira = MockJiraService();
    mockSlack = MockSlackService();
  });

  EngiTrackController createController({ConnectorConfig? initialConfig}) {
    when(
      () => mockStorage.loadConfig(),
    ).thenAnswer((_) async => initialConfig ?? defaultConfig());
    when(() => mockStorage.loadTodos()).thenAnswer((_) async => <TodoItem>[]);
    when(() => mockStorage.loadNotes()).thenAnswer((_) async => <NoteItem>[]);
    when(
      () => mockStorage.loadSeenAlertIds(),
    ).thenAnswer((_) async => <String>{});
    when(
      () => mockStorage.loadResolvedItemIds(),
    ).thenAnswer((_) async => <String>{});
    when(() => mockStorage.saveTodos(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveNotes(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveConfig(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveSeenAlertIds(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveResolvedItemIds(any())).thenAnswer((_) async {});

    when(() => mockNotifications.initialize()).thenAnswer((_) async {});
    when(
      () => mockNotifications.cancelTodoReminder(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockNotifications.cancelAllTodoReminders(),
    ).thenAnswer((_) async {});
    when(
      () => mockNotifications.scheduleTodoReminder(
        todoId: any(named: 'todoId'),
        title: any(named: 'title'),
        scheduledDate: any(named: 'scheduledDate'),
        subtitle: any(named: 'subtitle'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockGitHub.fetchPendingReviews(
        username: any(named: 'username'),
        token: any(named: 'token'),
      ),
    ).thenAnswer((_) async => <GithubPullRequest>[]);

    when(
      () => mockJira.fetchAssignedIssues(
        baseUrl: any(named: 'baseUrl'),
        email: any(named: 'email'),
        apiToken: any(named: 'apiToken'),
      ),
    ).thenAnswer((_) async => <JiraIssue>[]);

    when(
      () => mockJira.fetchMentionedIssues(
        baseUrl: any(named: 'baseUrl'),
        email: any(named: 'email'),
        apiToken: any(named: 'apiToken'),
      ),
    ).thenAnswer((_) async => <JiraIssue>[]);

    when(
      () => mockSlack.fetchReviewRequests(
        token: any(named: 'token'),
        channels: any(named: 'channels'),
      ),
    ).thenAnswer((_) async => <SlackReviewRequest>[]);

    when(
      () => mockSlack.fetchAlerts(
        token: any(named: 'token'),
        channel: any(named: 'channel'),
      ),
    ).thenAnswer((_) async => <SlackAlert>[]);

    when(
      () => mockSlack.fetchDmMentions(token: any(named: 'token')),
    ).thenAnswer((_) async => <SlackReviewRequest>[]);

    return EngiTrackController(
      storage: mockStorage,
      notificationsService: mockNotifications,
      gitHubService: mockGitHub,
      jiraService: mockJira,
      slackService: mockSlack,
    );
  }

  group('Todo CRUD', () {
    test('addToTodo adds a todo and persists', () async {
      final controller = createController();

      final added = await controller.addToTodo(
        title: 'Fix bug',
        subtitle: 'In auth module',
        sourceLabel: 'github',
        sourceUrl: 'https://github.com/o/r/issues/1',
      );

      expect(added, isTrue);
      expect(controller.todos, hasLength(1));
      expect(controller.todos.first.title, 'Fix bug');
      verify(() => mockStorage.saveTodos(any())).called(1);
    });

    test('addToTodo rejects duplicate sourceUrl', () async {
      final controller = createController();

      await controller.addToTodo(
        title: 'Fix',
        subtitle: 'desc',
        sourceLabel: 'gh',
        sourceUrl: 'https://github.com/o/r/issues/1',
      );

      final duplicate = await controller.addToTodo(
        title: 'Fix again',
        subtitle: 'desc',
        sourceLabel: 'gh',
        sourceUrl: 'https://github.com/o/r/issues/1',
      );

      expect(duplicate, isFalse);
      expect(controller.todos, hasLength(1));
    });

    test('addToTodo allows empty sourceUrl duplicates', () async {
      final controller = createController();

      await controller.addToTodo(
        title: 'A',
        subtitle: '',
        sourceLabel: 'manual',
      );
      final second = await controller.addToTodo(
        title: 'B',
        subtitle: '',
        sourceLabel: 'manual',
      );

      expect(second, isTrue);
      expect(controller.todos, hasLength(2));
    });

    test('toggleTodo updates completion state', () async {
      final controller = createController();
      await controller.addToTodo(title: 'T', subtitle: 'S', sourceLabel: 'x');

      final todo = controller.todos.first;
      expect(todo.completed, isFalse);

      await controller.toggleTodo(todo, true);
      expect(controller.todos.first.completed, isTrue);

      await controller.toggleTodo(controller.todos.first, false);
      expect(controller.todos.first.completed, isFalse);
    });

    test('deleteTodo removes and cancels reminder', () async {
      final controller = createController();
      await controller.addToTodo(title: 'T', subtitle: 'S', sourceLabel: 'x');
      final id = controller.todos.first.id;

      await controller.deleteTodo(id);
      expect(controller.todos, isEmpty);
      verify(() => mockNotifications.cancelTodoReminder(id)).called(1);
    });

    test('updateTodo modifies in place', () async {
      final controller = createController();
      await controller.addToTodo(title: 'Old', subtitle: 'S', sourceLabel: 'x');

      final original = controller.todos.first;
      final updated = original.copyWith(title: 'New');
      await controller.updateTodo(updated);

      expect(controller.todos.first.title, 'New');
    });
  });

  group('sortedTodos', () {
    test('incomplete before complete, newest first', () async {
      final controller = createController();

      await controller.addToTodo(title: 'A', subtitle: '', sourceLabel: 'x');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await controller.addToTodo(title: 'B', subtitle: '', sourceLabel: 'x');

      await controller.toggleTodo(
        controller.todos.firstWhere((t) => t.title == 'A'),
        true,
      );

      final sorted = controller.sortedTodos;
      expect(sorted.first.title, 'B');
      expect(sorted.last.title, 'A');
      expect(sorted.last.completed, isTrue);
    });
  });

  group('Note CRUD', () {
    test('createNote adds with default title', () async {
      final controller = createController();
      final note = await controller.createNote();

      expect(note.title, 'Untitled note');
      expect(note.body, isEmpty);
      expect(controller.notes, hasLength(1));
      verify(() => mockStorage.saveNotes(any())).called(1);
    });

    test('upsertNote updates existing note', () async {
      final controller = createController();
      final note = await controller.createNote();

      final updated = note.copyWith(title: 'Updated', body: 'Content');
      await controller.upsertNote(updated);

      expect(controller.notes, hasLength(1));
      expect(controller.notes.first.title, 'Updated');
    });

    test('upsertNote inserts new note', () async {
      final controller = createController();

      final note = NoteItem(
        id: 'new-id',
        title: 'New',
        body: 'Body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await controller.upsertNote(note);

      expect(controller.notes, hasLength(1));
      expect(controller.notes.first.id, 'new-id');
    });

    test('deleteNote removes note', () async {
      final controller = createController();
      final note = await controller.createNote();

      await controller.deleteNote(note.id);
      expect(controller.notes, isEmpty);
    });
  });

  group('sortedNotes', () {
    test('sorted by updatedAt descending', () async {
      final controller = createController();
      await controller.createNote();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await controller.createNote();

      final sorted = controller.sortedNotes;
      expect(sorted.first.updatedAt.isAfter(sorted.last.updatedAt), isTrue);
    });
  });

  group('resolveItem / unresolveItem', () {
    test('resolveItem marks item as resolved', () async {
      final controller = createController();
      await controller.resolveItem('item-1');

      expect(controller.isResolved('item-1'), isTrue);
      verify(() => mockStorage.saveResolvedItemIds(any())).called(1);
    });

    test('unresolveItem removes resolved mark', () async {
      final controller = createController();
      await controller.resolveItem('item-1');
      await controller.unresolveItem('item-1');

      expect(controller.isResolved('item-1'), isFalse);
    });

    test('resolvedItemCount reflects state', () async {
      final controller = createController();
      expect(controller.resolvedItemCount, 0);

      await controller.resolveItem('a');
      await controller.resolveItem('b');
      expect(controller.resolvedItemCount, 2);

      await controller.unresolveItem('a');
      expect(controller.resolvedItemCount, 1);
    });
  });

  group('reviewFor / reviewProviderFor', () {
    test('reviewFor returns null for unknown PR', () {
      final controller = createController();
      expect(controller.reviewFor('unknown'), isNull);
    });

    test('reviewProviderFor returns null for unknown item', () {
      final controller = createController();
      expect(controller.reviewProviderFor('unknown'), isNull);
    });
  });

  group('canRunAiReview', () {
    test('false when GitHub not configured', () {
      final controller = createController();
      expect(controller.canRunAiReview, isFalse);
    });

    test('false when no AI providers configured', () {
      final controller = createController(
        initialConfig: const ConnectorConfig(
          githubEnabled: true,
          githubUsername: 'u',
          githubToken: 't',
        ),
      );
      expect(controller.canRunAiReview, isFalse);
    });
  });

  group('allActiveItems', () {
    test('empty by default', () {
      final controller = createController();
      expect(controller.allActiveItems, isEmpty);
      expect(controller.totalActionableCount, 0);
    });
  });

  group('category item getters', () {
    test('codeReviewItems, issueTrackerItems, messagingItems all empty', () {
      final controller = createController();
      expect(controller.codeReviewItems, isEmpty);
      expect(controller.issueTrackerItems, isEmpty);
      expect(controller.messagingItems, isEmpty);
    });

    test('slackAlertItems and slackReviewItems empty', () {
      final controller = createController();
      expect(controller.slackAlertItems, isEmpty);
      expect(controller.slackReviewItems, isEmpty);
    });
  });

  group('providers list', () {
    test('has 3 providers', () {
      final controller = createController();
      expect(controller.providers, hasLength(3));
      final ids = controller.providers.map((p) => p.id).toSet();
      expect(ids, containsAll(['github', 'jira', 'slack']));
    });
  });

  group('addItemToTodo', () {
    test('delegates to addToTodo with item fields', () async {
      final controller = createController();

      final item = IntegrationItem(
        id: 'gh-1',
        providerId: 'github',
        category: IntegrationCategory.codeReview,
        title: 'Review PR',
        subtitle: 'org/repo #1',
        url: 'https://github.com/org/repo/pull/1',
        timestamp: DateTime.utc(2025),
        reason: ItemReason.reviewRequested,
      );

      final added = await controller.addItemToTodo(item);
      expect(added, isTrue);
      expect(controller.todos.first.title, 'Review PR');
      expect(controller.todos.first.sourceLabel, 'github');
      expect(controller.todos.first.sourceUrl, item.url);
    });
  });

  group('dispose', () {
    test('can be called without error', () {
      final controller = createController();
      expect(() => controller.dispose(), returnsNormally);
    });
  });
}
