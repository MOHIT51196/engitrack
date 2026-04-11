import 'package:flutter/material.dart';

import '../controller.dart';
import '../integrations/integration_provider.dart';
import '../theme.dart';
import '../widgets.dart';

class ResolvedItemsScreen extends StatelessWidget {
  const ResolvedItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final ThemeData theme = Theme.of(context);
    final List<IntegrationItem> items = controller.resolvedItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Resolved Items',
          style: theme.textTheme.titleLarge?.copyWith(fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: EmptyStateCard(
                    title: 'No resolved items',
                    message:
                        'Items you resolve from the dashboard will appear here.',
                    icon: Icons.check_circle_rounded,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (BuildContext context, int index) {
                  return _ResolvedItemCard(item: items[index]);
                },
              ),
      ),
    );
  }
}

class _ResolvedItemCard extends StatelessWidget {
  const _ResolvedItemCard({required this.item});
  final IntegrationItem item;

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final ThemeData theme = Theme.of(context);

    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BrandLogo(
            assetPath: _logoForProvider(item.providerId),
            size: 30,
            backgroundColor: _bgForProvider(item.providerId),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.subtitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: <Widget>[
                    SoftTag(
                      label: item.reason.label,
                      foregroundColor: _fgForReason(item.reason),
                      backgroundColor: _bgForReason(item.reason),
                      dense: true,
                    ),
                    const SoftTag(
                      label: 'Resolved',
                      icon: Icons.check_circle_rounded,
                      foregroundColor: AppColors.success,
                      backgroundColor: AppColors.successLight,
                      dense: true,
                    ),
                    SoftTag(
                      label: formatRelativeTime(item.timestamp),
                      icon: Icons.schedule_rounded,
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                onPressed: () async {
                  await controller.unresolveItem(item.id);
                  if (!context.mounted) return;
                  showInfoSnackBar(context, 'Item moved back to active.');
                },
                icon: const Icon(Icons.undo_rounded, size: 18),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                ),
                tooltip: 'Unresolve',
              ),
              if (item.url.isNotEmpty)
                IconButton(
                  onPressed: () => openExternalUrl(context, item.url),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.tertiaryInk,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(28, 28),
                  ),
                  tooltip: 'Open link',
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _logoForProvider(String providerId) {
    switch (providerId) {
      case 'github':
        return 'assets/logos/github.svg';
      case 'jira':
        return 'assets/logos/jira.svg';
      case 'slack':
        return 'assets/logos/slack.svg';
      default:
        return 'assets/logos/github.svg';
    }
  }

  Color _bgForProvider(String providerId) {
    switch (providerId) {
      case 'github':
        return AppColors.githubLight;
      case 'jira':
        return AppColors.jiraLight;
      case 'slack':
        return AppColors.slackLight;
      default:
        return AppColors.softSurface;
    }
  }

  Color _bgForReason(ItemReason reason) {
    switch (reason) {
      case ItemReason.assigned:
        return AppColors.infoLight;
      case ItemReason.tagged:
        return AppColors.warningLight;
      case ItemReason.reviewRequested:
        return AppColors.accentLight;
      case ItemReason.alert:
        return AppColors.dangerLight;
      case ItemReason.mention:
        return AppColors.slackLight;
    }
  }

  Color _fgForReason(ItemReason reason) {
    switch (reason) {
      case ItemReason.assigned:
        return AppColors.info;
      case ItemReason.tagged:
        return AppColors.warning;
      case ItemReason.reviewRequested:
        return AppColors.accent;
      case ItemReason.alert:
        return AppColors.danger;
      case ItemReason.mention:
        return AppColors.slack;
    }
  }
}
