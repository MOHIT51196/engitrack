import 'dart:convert';

import '../models.dart';

enum IntegrationCategory { codeReview, issueTracker, messaging }

enum ItemReason { assigned, tagged, reviewRequested, alert, mention }

abstract class IntegrationProvider {
  String get id;
  String get displayName;
  IntegrationCategory get category;
  String get logoAsset;

  bool isConfigured(ConnectorConfig config);
  Future<List<IntegrationItem>> fetchItems(ConnectorConfig config);
}

class IntegrationItem {
  const IntegrationItem({
    required this.id,
    required this.providerId,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.url,
    required this.timestamp,
    required this.reason,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String providerId;
  final IntegrationCategory category;
  final String title;
  final String subtitle;
  final String url;
  final DateTime timestamp;
  final ItemReason reason;
  final Map<String, dynamic> metadata;

  T? meta<T>(String key) {
    final dynamic value = metadata[key];
    return value is T ? value : null;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'providerId': providerId,
      'category': category.name,
      'title': title,
      'subtitle': subtitle,
      'url': url,
      'timestamp': timestamp.toIso8601String(),
      'reason': reason.name,
      'metadata': metadata,
    };
  }

  factory IntegrationItem.fromJson(Map<String, dynamic> json) {
    return IntegrationItem(
      id: json['id'] as String,
      providerId: json['providerId'] as String? ?? '',
      category: IntegrationCategory.values.firstWhere(
        (IntegrationCategory c) => c.name == json['category'],
        orElse: () => IntegrationCategory.codeReview,
      ),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      url: json['url'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      reason: ItemReason.values.firstWhere(
        (ItemReason r) => r.name == json['reason'],
        orElse: () => ItemReason.assigned,
      ),
      metadata: (json['metadata'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
    );
  }

  String toJsonString() => const JsonEncoder().convert(toJson());
}

extension ItemReasonLabel on ItemReason {
  String get label {
    switch (this) {
      case ItemReason.assigned:
        return 'Assigned';
      case ItemReason.tagged:
        return 'Tagged';
      case ItemReason.reviewRequested:
        return 'Review requested';
      case ItemReason.alert:
        return 'Alert';
      case ItemReason.mention:
        return 'Mentioned';
    }
  }
}

extension IntegrationCategoryLabel on IntegrationCategory {
  String get label {
    switch (this) {
      case IntegrationCategory.codeReview:
        return 'Code Review';
      case IntegrationCategory.issueTracker:
        return 'Issue Tracker';
      case IntegrationCategory.messaging:
        return 'Messaging';
    }
  }
}
