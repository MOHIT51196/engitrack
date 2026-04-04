import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

class ServiceException implements Exception {
  ServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotificationsService {
  NotificationsService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const AndroidNotificationDetails _reminderAndroidDetails =
      AndroidNotificationDetails(
    'engitrack_reminders',
    'ToDo reminders',
    channelDescription: 'Notifications for ToDo reminder times.',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    category: AndroidNotificationCategory.reminder,
  );

  static const DarwinNotificationDetails _reminderDarwinDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  static const NotificationDetails _reminderDetails = NotificationDetails(
    android: _reminderAndroidDetails,
    iOS: _reminderDarwinDetails,
    macOS: _reminderDarwinDetails,
  );

  Future<void> initialize() async {
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings: settings);

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    const AndroidNotificationChannel alertsChannel = AndroidNotificationChannel(
      'engitrack_alerts',
      'EngiTrack alerts',
      description: 'Slack alert notifications surfaced by EngiTrack.',
      importance: Importance.max,
    );
    await androidPlugin?.createNotificationChannel(alertsChannel);

    const AndroidNotificationChannel remindersChannel =
        AndroidNotificationChannel(
      'engitrack_reminders',
      'ToDo reminders',
      description: 'Notifications for ToDo reminder times.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin?.createNotificationChannel(remindersChannel);
  }

  Future<bool> requestPermissions() async {
    final bool androidGranted = await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        true;
    final bool iosGranted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;
    final bool macGranted = await _plugin
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;
    return androidGranted && iosGranted && macGranted;
  }

  Future<void> showAlertNotification(SlackAlert alert) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'engitrack_alerts',
      'EngiTrack alerts',
      channelDescription: 'Slack alert notifications surfaced by EngiTrack.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(
      id: alert.id.hashCode & 0x7fffffff,
      title: alert.title,
      body: alert.message,
      notificationDetails: details,
      payload: alert.url,
    );
  }

  int _notificationId(String todoId) => todoId.hashCode & 0x7fffffff;

  Future<void> scheduleTodoReminder({
    required String todoId,
    required String title,
    required DateTime scheduledDate,
    String? subtitle,
  }) async {
    final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
      await _plugin.show(
        id: _notificationId(todoId),
        title: title,
        body: subtitle ?? 'Your ToDo reminder is due.',
        notificationDetails: _reminderDetails,
      );
      return;
    }

    await _plugin.zonedSchedule(
      id: _notificationId(todoId),
      title: title,
      body: subtitle ?? 'Your ToDo reminder is due.',
      scheduledDate: tzDate,
      notificationDetails: _reminderDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  Future<void> cancelTodoReminder(String todoId) async {
    await _plugin.cancel(id: _notificationId(todoId));
  }

  Future<void> cancelAllTodoReminders() async {
    await _plugin.cancelAll();
  }
}

class GitHubService {
  GitHubService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<GithubPullRequest>> fetchPendingReviews({
    required String username,
    required String token,
  }) async {
    final Uri uri = Uri.https(
      'api.github.com',
      '/search/issues',
      <String, String>{
        'q': 'is:open is:pr archived:false review-requested:${username.trim()}',
        'sort': 'updated',
        'order': 'desc',
        'per_page': '20',
      },
    );

    final http.Response response = await _client.get(
      uri,
      headers: _headers(token),
    );
    final Map<String, dynamic> json = _decodeJsonBody(response);
    final List<dynamic> items =
        json['items'] as List<dynamic>? ?? const <dynamic>[];

    return items.map((dynamic item) {
      final Map<String, dynamic> map = item as Map<String, dynamic>;
      final String repositoryUrl = map['repository_url'] as String? ?? '';
      final List<String> segments =
          Uri.tryParse(repositoryUrl)?.pathSegments ?? <String>[];
      final String owner = segments.length >= 2 ? segments[1] : 'repo-owner';
      final String repo = segments.length >= 3 ? segments[2] : 'repository';
      final int number = map['number'] as int? ?? 0;
      final List<String> labels =
          (map['labels'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic label) =>
                  (label as Map<String, dynamic>)['name'] as String? ?? '')
              .where((String name) => name.isNotEmpty)
              .toList();

      return GithubPullRequest(
        id: '$owner/$repo#$number',
        owner: owner,
        repo: repo,
        number: number,
        title: map['title'] as String? ?? 'Untitled pull request',
        author: (map['user'] as Map<String, dynamic>? ??
                const <String, dynamic>{})['login'] as String? ??
            'Unknown',
        url: map['html_url'] as String? ?? '',
        updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
            DateTime.now(),
        draft: map['draft'] as bool? ?? labels.contains('draft'),
        labels: labels,
        body: map['body'] as String? ?? '',
      );
    }).toList();
  }

  Future<PullRequestContext> fetchPullRequestContext({
    required GithubPullRequest pullRequest,
    required String token,
  }) async {
    final Uri detailsUri = Uri.https(
      'api.github.com',
      '/repos/${pullRequest.owner}/${pullRequest.repo}/pulls/${pullRequest.number}',
    );
    final Uri filesUri = Uri.https(
      'api.github.com',
      '/repos/${pullRequest.owner}/${pullRequest.repo}/pulls/${pullRequest.number}/files',
      <String, String>{'per_page': '100'},
    );

    final http.Response detailsResponse =
        await _client.get(detailsUri, headers: _headers(token));
    final http.Response filesResponse =
        await _client.get(filesUri, headers: _headers(token));

    final Map<String, dynamic> details = _decodeJsonBody(detailsResponse);
    final List<dynamic> filesJson = _decodeJsonListBody(filesResponse);

    final List<PullRequestFile> files = filesJson.map((dynamic file) {
      final Map<String, dynamic> map = file as Map<String, dynamic>;
      return PullRequestFile(
        filename: map['filename'] as String? ?? 'unknown_file',
        status: map['status'] as String? ?? 'modified',
        additions: map['additions'] as int? ?? 0,
        deletions: map['deletions'] as int? ?? 0,
        patch: map['patch'] as String?,
      );
    }).toList();

    return PullRequestContext(
      pullRequest: pullRequest,
      body: details['body'] as String? ?? '',
      baseBranch: ((details['base'] as Map<String, dynamic>? ??
              const <String, dynamic>{})['ref'] as String?) ??
          'main',
      headBranch: ((details['head'] as Map<String, dynamic>? ??
              const <String, dynamic>{})['ref'] as String?) ??
          pullRequest.headBranch ??
          'feature/unknown',
      changedFiles:
          details['changed_files'] as int? ?? pullRequest.changedFiles,
      commits: details['commits'] as int? ?? 0,
      files: files,
    );
  }

  Future<String> postPrComment({
    required String owner,
    required String repo,
    required int number,
    required String token,
    required String body,
  }) async {
    final Uri uri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repo/issues/$number/comments',
    );
    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        ..._headers(token),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{'body': body}),
    );
    final Map<String, dynamic> json = _decodeJsonBody(response);
    return json['html_url'] as String? ?? '';
  }

  Map<String, String> _headers(String token) {
    return <String, String>{
      'Accept': 'application/vnd.github+json',
      'Authorization': 'Bearer ${token.trim()}',
      'X-GitHub-Api-Version': '2022-11-28',
    };
  }
}

class JiraService {
  JiraService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _cachedAccountId;

  String _basicAuth(String email, String apiToken) =>
      base64Encode(utf8.encode('${email.trim()}:${apiToken.trim()}'));

  Future<String> _resolveAccountId({
    required String baseUrl,
    required String email,
    required String apiToken,
  }) async {
    if (_cachedAccountId != null) {
      debugPrint('[Jira:myself] Using cached accountId: $_cachedAccountId');
      return _cachedAccountId!;
    }

    final String normalizedBase = baseUrl.trim().endsWith('/')
        ? baseUrl.trim().substring(0, baseUrl.trim().length - 1)
        : baseUrl.trim();

    final String url = '$normalizedBase/rest/api/3/myself';
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Basic ${_basicAuth(email, apiToken)}',
    };
    debugPrint('[Jira:myself] GET $url');
    debugPrint(
        '[Jira:myself] Headers: Accept=${headers['Accept']}, Authorization=Basic <${_basicAuth(email, apiToken).length} chars>');

    try {
      final http.Response response = await _client.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint('[Jira:myself] Response status=${response.statusCode}');
      debugPrint(
          '[Jira:myself] Response body: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> json =
            jsonDecode(response.body) as Map<String, dynamic>;
        final String accountId = json['accountId'] as String? ?? '';
        if (accountId.isNotEmpty) {
          _cachedAccountId = accountId;
          debugPrint('[Jira:myself] Resolved accountId: $accountId');
          return accountId;
        }
        debugPrint('[Jira:myself] accountId was empty in response');
      }
    } catch (e) {
      debugPrint('[Jira:myself] Exception: $e');
    }

    debugPrint('[Jira:myself] Falling back to email: $email');
    return email;
  }

  Future<List<JiraIssue>> fetchAssignedIssues({
    required String baseUrl,
    required String email,
    required String apiToken,
  }) async {
    final String identity = await _resolveAccountId(
      baseUrl: baseUrl,
      email: email,
      apiToken: apiToken,
    );
    final bool isAccountId = identity.contains(':');
    final String assigneeValue = isAccountId ? identity : '"$identity"';
    return _fetchIssuesWithJql(
      baseUrl: baseUrl,
      email: email,
      apiToken: apiToken,
      jql:
          'assignee = $assigneeValue AND statusCategory != Done ORDER BY updated DESC',
    );
  }

  Future<List<JiraIssue>> fetchMentionedIssues({
    required String baseUrl,
    required String email,
    required String apiToken,
  }) async {
    final String identity = await _resolveAccountId(
      baseUrl: baseUrl,
      email: email,
      apiToken: apiToken,
    );
    final bool isAccountId = identity.contains(':');
    final String identityValue = isAccountId ? identity : '"$identity"';
    return _fetchIssuesWithJql(
      baseUrl: baseUrl,
      email: email,
      apiToken: apiToken,
      jql: 'comment ~ $identityValue ORDER BY updated DESC',
    );
  }

  Future<List<JiraIssue>> _fetchIssuesWithJql({
    required String baseUrl,
    required String email,
    required String apiToken,
    required String jql,
  }) async {
    final String normalizedBase = baseUrl.trim().endsWith('/')
        ? baseUrl.trim().substring(0, baseUrl.trim().length - 1)
        : baseUrl.trim();

    final String jqlEncoded = Uri.encodeComponent(jql).replaceAll('%20', '+');
    final String urlStr = '$normalizedBase/rest/api/3/search/jql'
        '?jql=$jqlEncoded'
        '&maxResults=25'
        '&fields=summary,status,priority,issuetype,project,assignee,updated,parent,duedate,description';

    debugPrint('[Jira:search] JQL: $jql');
    debugPrint('[Jira:search] GET $urlStr');
    debugPrint(
        '[Jira:search] email="$email" tokenLen=${apiToken.length} base64Len=${_basicAuth(email, apiToken).length}');

    final http.Request request = http.Request('GET', Uri.parse(urlStr));
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Basic ${_basicAuth(email, apiToken)}';

    debugPrint('[Jira:search] Final request URL: ${request.url}');

    final http.StreamedResponse streamed = await _client.send(request);
    final http.Response response = await http.Response.fromStream(streamed);

    debugPrint('[Jira:search] Response status=${response.statusCode}');
    debugPrint('[Jira:search] Response headers: ${response.headers}');
    debugPrint(
        '[Jira:search] Response body (first 800): ${response.body.length > 800 ? response.body.substring(0, 800) : response.body}');

    final Map<String, dynamic> json = _decodeJsonBody(response);
    final List<dynamic> issues =
        json['issues'] as List<dynamic>? ?? const <dynamic>[];
    debugPrint('[Jira:search] Parsed ${issues.length} issues');

    return issues.map((dynamic issue) {
      final Map<String, dynamic> map = issue as Map<String, dynamic>;
      final Map<String, dynamic> fields =
          map['fields'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      final Map<String, dynamic> status =
          fields['status'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      final Map<String, dynamic> priority =
          fields['priority'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      final Map<String, dynamic> issueType =
          fields['issuetype'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      final Map<String, dynamic> project =
          fields['project'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      final Map<String, dynamic> assignee =
          fields['assignee'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      final Map<String, dynamic> parent =
          fields['parent'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      final Map<String, dynamic> parentFields =
          parent['fields'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      final String key = map['key'] as String? ?? 'UNKNOWN';

      final String description =
          _extractAdfText(fields['description']).trim();

      return JiraIssue(
        id: map['id'] as String? ?? key,
        key: key,
        title: fields['summary'] as String? ?? 'Untitled Jira issue',
        status: status['name'] as String? ?? 'Unknown',
        priority: priority['name'] as String? ?? 'Unknown',
        url: '$normalizedBase/browse/$key',
        updatedAt: DateTime.tryParse(fields['updated'] as String? ?? '') ??
            DateTime.now(),
        issueType: issueType['name'] as String? ?? 'Issue',
        projectName: project['name'] as String? ?? 'Project',
        assignee: assignee['displayName'] as String? ?? '',
        parentKey: parent['key'] as String? ?? '',
        parentTitle: parentFields['summary'] as String? ?? '',
        dueDate: DateTime.tryParse(fields['duedate'] as String? ?? ''),
        description: description,
      );
    }).toList();
  }
}

class SlackService {
  SlackService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _cachedTeamId;
  Map<String, String>? _channelCache;
  DateTime? _channelCacheTime;

  Future<List<SlackReviewRequest>> fetchReviewRequests({
    required String token,
    required List<String> channels,
  }) async {
    if (channels.isEmpty) {
      return <SlackReviewRequest>[];
    }

    final List<SlackReviewRequest> results = <SlackReviewRequest>[];
    for (final String channel in channels) {
      final _ResolvedSlackChannel resolved =
          await _resolveChannel(token, channel);
      final List<Map<String, dynamic>> messages =
          await _fetchConversationMessages(
              token: token, channelId: resolved.id);
      for (final Map<String, dynamic> message in messages) {
        final SlackReviewRequest? review = _extractReviewRequest(
            message: message, channel: resolved.displayName);
        if (review != null) {
          results.add(review);
        }
      }
    }

    results.sort(
      (SlackReviewRequest a, SlackReviewRequest b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    return results;
  }

  Future<List<SlackAlert>> fetchAlerts({
    required String token,
    required String channel,
  }) async {
    if (channel.trim().isEmpty) {
      return <SlackAlert>[];
    }

    final _ResolvedSlackChannel resolved =
        await _resolveChannel(token, channel);
    final List<Map<String, dynamic>> messages =
        await _fetchConversationMessages(
            token: token, channelId: resolved.id, limit: 25);

    final List<SlackAlert> alerts = messages
        .map(
          (Map<String, dynamic> message) =>
              _extractAlert(message: message, channel: resolved.displayName),
        )
        .whereType<SlackAlert>()
        .toList()
      ..sort(
          (SlackAlert a, SlackAlert b) => b.createdAt.compareTo(a.createdAt));

    return alerts;
  }

  Future<_ResolvedSlackChannel> _resolveChannel(
      String token, String rawChannel) async {
    final String cleaned = rawChannel.trim().replaceFirst('#', '');
    if (cleaned.isEmpty) {
      throw ServiceException('Slack channel cannot be empty.');
    }

    if (RegExp(r'^[CGD][A-Z0-9]+$').hasMatch(cleaned)) {
      return _ResolvedSlackChannel(id: cleaned, displayName: '#$cleaned');
    }

    String? cursor;
    do {
      final Uri uri = Uri.https(
        'slack.com',
        '/api/conversations.list',
        <String, String>{
          'exclude_archived': 'true',
          'limit': '500',
          'types': 'public_channel,private_channel',
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      );
      final http.Response response = await _client.get(
        uri,
        headers: _slackHeaders(token),
      );
      final Map<String, dynamic> json = _decodeJsonBody(response);
      _throwIfSlackError(json);
      final List<dynamic> channels =
          json['channels'] as List<dynamic>? ?? const <dynamic>[];
      for (final dynamic channel in channels) {
        final Map<String, dynamic> map = channel as Map<String, dynamic>;
        final String name = map['name'] as String? ?? '';
        if (name.toLowerCase() == cleaned.toLowerCase()) {
          return _ResolvedSlackChannel(
            id: map['id'] as String? ?? cleaned,
            displayName: '#$name',
          );
        }
      }
      cursor = (json['response_metadata'] as Map<String, dynamic>? ??
          const <String, dynamic>{})['next_cursor'] as String?;
    } while (cursor != null && cursor.isNotEmpty);

    throw ServiceException('Could not resolve Slack channel "$rawChannel".');
  }

  Future<List<Map<String, dynamic>>> _fetchConversationMessages({
    required String token,
    required String channelId,
    int limit = 40,
  }) async {
    final Uri uri = Uri.https(
      'slack.com',
      '/api/conversations.history',
      <String, String>{
        'channel': channelId,
        'limit': '$limit',
      },
    );
    final http.Response response =
        await _client.get(uri, headers: _slackHeaders(token));
    final Map<String, dynamic> json = _decodeJsonBody(response);
    _throwIfSlackError(json);
    return (json['messages'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
  }

  SlackReviewRequest? _extractReviewRequest({
    required Map<String, dynamic> message,
    required String channel,
  }) {
    final String text = _cleanSlackText(message['text'] as String? ?? '');
    if (text.isEmpty) {
      return null;
    }

    final bool hasPrUrl = RegExp(r'https?://[^\s>]+/pull/\d+').hasMatch(text);
    final bool hasDocUrl = RegExp(r'https?://[^\s>]+').hasMatch(text) &&
        (text.contains('docs.google.com') ||
            text.contains('notion.so') ||
            text.contains('/doc'));
    final bool looksLikeReview = hasPrUrl ||
        hasDocUrl ||
        RegExp(
          r'(need (?:eyes|review)|please review|review request|can someone review|feedback requested|doc review)',
          caseSensitive: false,
        ).hasMatch(text);

    if (!looksLikeReview) {
      return null;
    }

    final SlackReviewKind kind =
        hasPrUrl ? SlackReviewKind.pr : SlackReviewKind.doc;
    final String url = _extractFirstUrl(text);
    final DateTime createdAt = _timestampFromSlackTs(message['ts'] as String?);
    final String requester =
        (message['user'] as String? ?? 'Slack teammate').trim();
    final String title = _compactTitle(text);

    return SlackReviewRequest(
      id: 'review-${channel.replaceAll('#', '')}-${message['ts']}',
      channel: channel,
      kind: kind,
      title: title,
      requester: requester,
      message: text,
      url: url,
      createdAt: createdAt,
    );
  }

  SlackAlert? _extractAlert({
    required Map<String, dynamic> message,
    required String channel,
  }) {
    final String text = _cleanSlackText(message['text'] as String? ?? '');
    if (text.isEmpty) {
      return null;
    }

    final AlertSeverity severity = _detectSeverity(text);
    final bool looksActionable = severity != AlertSeverity.info ||
        RegExp(r'(incident|outage|latency|degraded|failing|rollback|backlog)',
                caseSensitive: false)
            .hasMatch(text);

    if (!looksActionable) {
      return null;
    }

    return SlackAlert(
      id: 'alert-${channel.replaceAll('#', '')}-${message['ts']}',
      channel: channel,
      title: _compactTitle(text),
      message: text,
      createdAt: _timestampFromSlackTs(message['ts'] as String?),
      severity: severity,
      url: _extractFirstUrl(text),
    );
  }

  AlertSeverity _detectSeverity(String text) {
    final String lowered = text.toLowerCase();
    if (lowered.contains('sev0') ||
        lowered.contains('sev1') ||
        lowered.contains('critical') ||
        lowered.contains('p0')) {
      return AlertSeverity.critical;
    }
    if (lowered.contains('sev2') ||
        lowered.contains('high') ||
        lowered.contains('p1')) {
      return AlertSeverity.high;
    }
    if (lowered.contains('sev3') ||
        lowered.contains('medium') ||
        lowered.contains('warning')) {
      return AlertSeverity.medium;
    }
    return AlertSeverity.info;
  }

  String _extractFirstUrl(String text) {
    final Match? match = RegExp(r'https?://[^\s>|]+').firstMatch(text);
    return match?.group(0) ?? '';
  }

  String _cleanSlackText(String text) {
    final String normalized = text.replaceAllMapped(
      RegExp(r'<(https?://[^>|]+)\|[^>]+>'),
      (Match match) => match.group(1) ?? match.group(0) ?? '',
    );
    return normalized
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  DateTime _timestampFromSlackTs(String? ts) {
    final double value = double.tryParse(ts ?? '') ?? 0;
    return DateTime.fromMillisecondsSinceEpoch((value * 1000).round());
  }

  String _compactTitle(String text) {
    final String singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 84) {
      return singleLine;
    }
    return '${singleLine.substring(0, 81)}...';
  }

  Map<String, String> _slackHeaders(String token) {
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };
  }

  void _throwIfSlackError(Map<String, dynamic> json) {
    if (json['ok'] == false) {
      throw ServiceException(
          'Slack error: ${json['error'] ?? 'unknown_error'}');
    }
  }

  Future<String> fetchTeamId({required String token}) async {
    if (_cachedTeamId != null) return _cachedTeamId!;

    final Uri uri = Uri.https('slack.com', '/api/auth.test');
    final http.Response response =
        await _client.get(uri, headers: _slackHeaders(token));
    final Map<String, dynamic> json = _decodeJsonBody(response);
    _throwIfSlackError(json);
    _cachedTeamId = json['team_id'] as String? ?? '';
    return _cachedTeamId!;
  }

  Future<Map<String, String>> fetchChannelList({required String token}) async {
    final bool cacheValid = _channelCache != null &&
        _channelCacheTime != null &&
        DateTime.now().difference(_channelCacheTime!).inMinutes < 10;
    if (cacheValid) return _channelCache!;

    final Map<String, String> channels = <String, String>{};
    String? cursor;
    do {
      final Uri uri =
          Uri.https('slack.com', '/api/conversations.list', <String, String>{
        'exclude_archived': 'true',
        'limit': '500',
        'types': 'public_channel,private_channel',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      });
      final http.Response response =
          await _client.get(uri, headers: _slackHeaders(token));
      final Map<String, dynamic> json = _decodeJsonBody(response);
      _throwIfSlackError(json);
      for (final dynamic ch
          in json['channels'] as List<dynamic>? ?? const <dynamic>[]) {
        final Map<String, dynamic> map = ch as Map<String, dynamic>;
        channels[map['name'] as String? ?? ''] = map['id'] as String? ?? '';
      }
      cursor = (json['response_metadata'] as Map<String, dynamic>? ??
          const <String, dynamic>{})['next_cursor'] as String?;
    } while (cursor != null && cursor.isNotEmpty);

    _channelCache = channels;
    _channelCacheTime = DateTime.now();
    return channels;
  }

  String buildSlackDeepLink(
      {required String teamId, required String channelId}) {
    return 'slack://channel?team=$teamId&id=$channelId';
  }

  String buildSlackWebLink(
      {required String teamId, required String channelId}) {
    return 'https://app.slack.com/client/$teamId/$channelId';
  }

  static bool isRotatingToken(String token) => token.trim().startsWith('xoxe.');

  /// Exchanges a rotating refresh token for a fresh access + refresh pair.
  /// Returns `{access_token, refresh_token}` on success.
  Future<Map<String, String>> refreshAccessToken({
    required String refreshToken,
    required String clientId,
    required String clientSecret,
  }) async {
    final Uri uri = Uri.https('slack.com', '/api/oauth.v2.access');
    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: <String, String>{
        'grant_type': 'refresh_token',
        'client_id': clientId.trim(),
        'client_secret': clientSecret.trim(),
        'refresh_token': refreshToken.trim(),
      },
    );
    final Map<String, dynamic> json = _decodeJsonBody(response);
    _throwIfSlackError(json);
    return <String, String>{
      'access_token': json['access_token'] as String? ?? '',
      'refresh_token': json['refresh_token'] as String? ?? '',
    };
  }

  /// Validates a token by calling auth.test. Returns the user ID on success.
  Future<String> validateToken({required String token}) async {
    final Uri uri = Uri.https('slack.com', '/api/auth.test');
    final http.Response response =
        await _client.get(uri, headers: _slackHeaders(token));
    final Map<String, dynamic> json = _decodeJsonBody(response);
    _throwIfSlackError(json);
    return json['user_id'] as String? ?? '';
  }

  Future<List<SlackReviewRequest>> fetchDmMentions(
      {required String token}) async {
    final Uri uri =
        Uri.https('slack.com', '/api/conversations.list', <String, String>{
      'types': 'im',
      'limit': '50',
    });
    final http.Response response =
        await _client.get(uri, headers: _slackHeaders(token));
    final Map<String, dynamic> json = _decodeJsonBody(response);
    _throwIfSlackError(json);

    final List<SlackReviewRequest> results = <SlackReviewRequest>[];
    final List<dynamic> channels =
        json['channels'] as List<dynamic>? ?? const <dynamic>[];

    for (final dynamic ch in channels.take(10)) {
      final Map<String, dynamic> map = ch as Map<String, dynamic>;
      final String channelId = map['id'] as String? ?? '';
      final String userId = map['user'] as String? ?? '';
      if (channelId.isEmpty) continue;

      final List<Map<String, dynamic>> messages =
          await _fetchConversationMessages(
              token: token, channelId: channelId, limit: 10);
      for (final Map<String, dynamic> msg in messages) {
        final SlackReviewRequest? review =
            _extractReviewRequest(message: msg, channel: 'DM with $userId');
        if (review != null) results.add(review);
      }
    }

    results.sort((SlackReviewRequest a, SlackReviewRequest b) =>
        b.createdAt.compareTo(a.createdAt));
    return results;
  }
}

class AiModelService {
  AiModelService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<({String value, String label})>> fetchOpenAiModels({
    required String apiKey,
  }) async {
    final Uri uri = Uri.https('api.openai.com', '/v1/models');
    final http.Response response =
        await _client.get(uri, headers: <String, String>{
      'Authorization': 'Bearer ${apiKey.trim()}',
    });
    final Map<String, dynamic> json = _decodeJsonBody(response);
    final List<dynamic> data =
        json['data'] as List<dynamic>? ?? const <dynamic>[];
    final List<({String value, String label})> models =
        <({String value, String label})>[];
    for (final dynamic item in data) {
      final Map<String, dynamic> map = item as Map<String, dynamic>;
      final String id = map['id'] as String? ?? '';
      if (id.isEmpty) continue;
      if (!id.startsWith('gpt-') &&
          !id.startsWith('o1') &&
          !id.startsWith('o3') &&
          !id.startsWith('o4')) {
        continue;
      }
      if (id.contains('realtime') ||
          id.contains('audio') ||
          id.contains('search') ||
          id.contains('transcribe')) {
        continue;
      }
      models.add((value: id, label: id));
    }
    models.sort((a, b) => a.label.compareTo(b.label));
    return models;
  }

  Future<List<({String value, String label})>> fetchGeminiModels({
    required String apiKey,
  }) async {
    final Uri uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models',
      <String, String>{'key': apiKey.trim()},
    );
    final http.Response response = await _client.get(uri);
    final Map<String, dynamic> json = _decodeJsonBody(response);
    final List<dynamic> data =
        json['models'] as List<dynamic>? ?? const <dynamic>[];
    final List<({String value, String label})> models =
        <({String value, String label})>[];
    for (final dynamic item in data) {
      final Map<String, dynamic> map = item as Map<String, dynamic>;
      final String name = map['name'] as String? ?? '';
      final String displayName = map['displayName'] as String? ?? '';
      final List<dynamic> methods =
          map['supportedGenerationMethods'] as List<dynamic>? ??
              const <dynamic>[];
      if (!methods.contains('generateContent')) continue;
      final String modelId =
          name.startsWith('models/') ? name.substring(7) : name;
      if (modelId.isEmpty) continue;
      models.add((
        value: modelId,
        label: displayName.isNotEmpty ? displayName : modelId
      ));
    }
    models.sort((a, b) => a.label.compareTo(b.label));
    return models;
  }

  Future<List<({String value, String label})>> fetchClaudeModels({
    required String apiKey,
  }) async {
    final Uri uri = Uri.https('api.anthropic.com', '/v1/models');
    final http.Response response =
        await _client.get(uri, headers: <String, String>{
      'x-api-key': apiKey.trim(),
      'anthropic-version': '2023-06-01',
    });
    final Map<String, dynamic> json = _decodeJsonBody(response);
    final List<dynamic> data =
        json['data'] as List<dynamic>? ?? const <dynamic>[];
    final List<({String value, String label})> models =
        <({String value, String label})>[];
    for (final dynamic item in data) {
      final Map<String, dynamic> map = item as Map<String, dynamic>;
      final String id = map['id'] as String? ?? '';
      final String displayName = map['display_name'] as String? ?? id;
      if (id.isEmpty) continue;
      models.add((value: id, label: displayName));
    }
    models.sort((a, b) => a.label.compareTo(b.label));
    return models;
  }

  Future<List<({String value, String label})>> fetchGrokModels({
    required String apiKey,
  }) async {
    final Uri uri = Uri.https('api.x.ai', '/v1/models');
    final http.Response response =
        await _client.get(uri, headers: <String, String>{
      'Authorization': 'Bearer ${apiKey.trim()}',
    });
    final Map<String, dynamic> json = _decodeJsonBody(response);
    final List<dynamic> data =
        json['data'] as List<dynamic>? ?? const <dynamic>[];
    final List<({String value, String label})> models =
        <({String value, String label})>[];
    for (final dynamic item in data) {
      final Map<String, dynamic> map = item as Map<String, dynamic>;
      final String id = map['id'] as String? ?? '';
      if (id.isEmpty) continue;
      if (!id.startsWith('grok')) continue;
      models.add((value: id, label: id));
    }
    models.sort((a, b) => a.label.compareTo(b.label));
    return models;
  }
}

Map<String, dynamic> _decodeJsonBody(http.Response response) {
  final dynamic decoded =
      jsonDecode(response.body.isEmpty ? '{}' : response.body);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ServiceException(
        'Request failed (${response.statusCode}): ${response.body}');
  }
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw ServiceException('Expected a JSON object response.');
}

List<dynamic> _decodeJsonListBody(http.Response response) {
  final dynamic decoded =
      jsonDecode(response.body.isEmpty ? '[]' : response.body);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ServiceException(
        'Request failed (${response.statusCode}): ${response.body}');
  }
  if (decoded is List<dynamic>) {
    return decoded;
  }
  throw ServiceException('Expected a JSON array response.');
}

class _ResolvedSlackChannel {
  const _ResolvedSlackChannel({required this.id, required this.displayName});

  final String id;
  final String displayName;
}

/// Extracts plain text from Atlassian Document Format (ADF) JSON.
String _extractAdfText(dynamic node) {
  if (node == null) return '';
  if (node is String) return node;
  if (node is Map<String, dynamic>) {
    final String type = node['type'] as String? ?? '';
    if (type == 'text') return node['text'] as String? ?? '';
    final List<dynamic>? content = node['content'] as List<dynamic>?;
    if (content == null) return '';
    final StringBuffer buf = StringBuffer();
    for (final dynamic child in content) {
      final String childText = _extractAdfText(child);
      if (childText.isNotEmpty) {
        if (buf.isNotEmpty && (type == 'paragraph' || type == 'bulletList' || type == 'orderedList' || type == 'heading')) {
          buf.write('\n');
        }
        buf.write(childText);
      }
    }
    return buf.toString();
  }
  return '';
}
