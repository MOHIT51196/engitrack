import '../models.dart';
import '../services.dart';
import 'integration_provider.dart';

class SlackProvider implements IntegrationProvider {
  SlackProvider({SlackService? service}) : _service = service ?? SlackService();

  final SlackService _service;

  @override
  String get id => 'slack';

  @override
  String get displayName => 'Slack';

  @override
  IntegrationCategory get category => IntegrationCategory.messaging;

  @override
  String get logoAsset => 'assets/logos/slack.svg';

  @override
  bool isConfigured(ConnectorConfig config) => config.isSlackConfigured;

  @override
  Future<List<IntegrationItem>> fetchItems(ConnectorConfig config) async {
    final List<IntegrationItem> results = <IntegrationItem>[];

    if (config.slackReviewChannels.isNotEmpty) {
      final List<SlackReviewRequest> reviews =
          await _service.fetchReviewRequests(
        token: config.slackToken,
        channels: config.slackReviewChannels,
      );
      results.addAll(reviews.map(_mapReview));
    }

    if (config.slackAlertChannel.trim().isNotEmpty) {
      final List<SlackAlert> alerts = await _service.fetchAlerts(
        token: config.slackToken,
        channel: config.slackAlertChannel,
      );
      results.addAll(alerts.map(_mapAlert));
    }

    try {
      final List<SlackReviewRequest> dmMentions =
          await _service.fetchDmMentions(token: config.slackToken);
      results.addAll(
        dmMentions.map(
          (SlackReviewRequest r) => _mapReview(r, reason: ItemReason.mention),
        ),
      );
    } catch (_) {
      // DM monitoring may fail if scopes are missing.
    }

    results.sort(
      (IntegrationItem a, IntegrationItem b) =>
          b.timestamp.compareTo(a.timestamp),
    );
    return results;
  }

  SlackService get service => _service;

  static IntegrationItem _mapReview(
    SlackReviewRequest review, {
    ItemReason reason = ItemReason.reviewRequested,
  }) {
    return IntegrationItem(
      id: review.id,
      providerId: 'slack',
      category: IntegrationCategory.messaging,
      title: review.title,
      subtitle: '${review.channel} · ${review.requester}',
      url: review.url,
      timestamp: review.createdAt,
      reason: reason,
      metadata: <String, dynamic>{
        'channel': review.channel,
        'kind': review.kind.name,
        'requester': review.requester,
        'message': review.message,
        'slackDeepLink': review.slackDeepLink,
        'slackWebLink': review.slackWebLink,
        'itemType': 'review',
      },
    );
  }

  static IntegrationItem _mapAlert(SlackAlert alert) {
    return IntegrationItem(
      id: alert.id,
      providerId: 'slack',
      category: IntegrationCategory.messaging,
      title: alert.title,
      subtitle: '${alert.channel} · ${alert.severity.label}',
      url: alert.url,
      timestamp: alert.createdAt,
      reason: ItemReason.alert,
      metadata: <String, dynamic>{
        'channel': alert.channel,
        'severity': alert.severity.name,
        'message': alert.message,
        'slackDeepLink': alert.slackDeepLink,
        'slackWebLink': alert.slackWebLink,
        'itemType': 'alert',
      },
    );
  }

  static SlackReviewRequest reviewFromItem(IntegrationItem item) {
    return SlackReviewRequest(
      id: item.id,
      channel: item.meta<String>('channel') ?? '',
      kind: SlackReviewKind.values.firstWhere(
        (SlackReviewKind k) => k.name == item.meta<String>('kind'),
        orElse: () => SlackReviewKind.pr,
      ),
      title: item.title,
      requester: item.meta<String>('requester') ?? '',
      message: item.meta<String>('message') ?? '',
      createdAt: item.timestamp,
      url: item.url,
      slackDeepLink: item.meta<String>('slackDeepLink') ?? '',
      slackWebLink: item.meta<String>('slackWebLink') ?? '',
    );
  }

  static SlackAlert alertFromItem(IntegrationItem item) {
    return SlackAlert(
      id: item.id,
      channel: item.meta<String>('channel') ?? '',
      title: item.title,
      message: item.meta<String>('message') ?? '',
      createdAt: item.timestamp,
      severity: AlertSeverity.values.firstWhere(
        (AlertSeverity s) => s.name == item.meta<String>('severity'),
        orElse: () => AlertSeverity.info,
      ),
      url: item.url,
      slackDeepLink: item.meta<String>('slackDeepLink') ?? '',
      slackWebLink: item.meta<String>('slackWebLink') ?? '',
    );
  }
}
