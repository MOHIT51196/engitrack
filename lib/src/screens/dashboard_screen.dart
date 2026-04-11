import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../controller.dart';
import '../integrations/integration_provider.dart';
import '../theme.dart';
import '../widgets.dart';
import 'item_detail_screen.dart';
import 'resolved_items_screen.dart';

enum _DashFilter { pr, jira, slackReview, slackAlert }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _DashFilter? _activeFilter;

  void _toggleFilter(_DashFilter filter) {
    setState(() => _activeFilter = _activeFilter == filter ? null : filter);
  }

  bool _showSection(_DashFilter section) =>
      _activeFilter == null || _activeFilter == section;

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final bool hasIntegrations = controller.config.hasAnyIntegrationEnabled;

    return SingleChildScrollView(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hasIntegrations) _HeroCard(controller: controller),
          if (hasIntegrations && controller.resolvedItemCount > 0) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ResolvedItemsScreen(),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                label: Text('View resolved (${controller.resolvedItemCount})'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondaryInk,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
          if (controller.errorMessage != null) ...<Widget>[
            const SizedBox(height: 10),
            _ErrorBanner(message: controller.errorMessage!),
          ],
          if (!hasIntegrations) ...<Widget>[
            const SizedBox(height: 24),
            _OnboardingCard(),
          ],
          if (hasIntegrations) ...<Widget>[
            const SizedBox(height: 16),
            _MetricsRow(
              controller: controller,
              activeFilter: _activeFilter,
              onFilterTap: _toggleFilter,
            ),
          ],
          if (_activeFilter != null) ...<Widget>[
            const SizedBox(height: 10),
            _ActiveFilterChip(
              label: _filterLabel(_activeFilter!),
              onClear: () => setState(() => _activeFilter = null),
            ),
          ],
          if (controller.config.githubEnabled &&
              _showSection(_DashFilter.pr)) ...<Widget>[
            const SizedBox(height: 24),
            _SectionBlock(
              title: 'Pull Requests',
              subtitle: 'Waiting for your review',
              logoAsset: 'assets/logos/github.svg',
              logoBg: AppColors.githubLight,
              accentColor: AppColors.github,
              count: controller.codeReviewItems.length,
              child: controller.codeReviewItems.isEmpty
                  ? const EmptyStateCard(
                      title: 'No pending reviews',
                      message:
                          'You\'re all caught up, or GitHub hasn\'t been configured yet.',
                      icon: Icons.done_all_rounded,
                    )
                  : Column(
                      children: controller.codeReviewItems
                          .map(
                            (IntegrationItem item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _BriefItemCard(item: item),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
          if (controller.config.jiraEnabled &&
              _showSection(_DashFilter.jira)) ...<Widget>[
            const SizedBox(height: 20),
            _SectionBlock(
              title: 'Jira Tickets',
              subtitle: 'Assigned or tagged',
              logoAsset: 'assets/logos/jira.svg',
              logoBg: AppColors.jiraLight,
              accentColor: AppColors.jira,
              count: controller.issueTrackerItems.length,
              child: controller.issueTrackerItems.isEmpty
                  ? const EmptyStateCard(
                      title: 'No open tickets',
                      message:
                          'Configure Jira in Integrations to pull your assigned issues.',
                      icon: Icons.assignment_turned_in_rounded,
                    )
                  : Column(
                      children: controller.issueTrackerItems
                          .map(
                            (IntegrationItem item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _BriefItemCard(item: item),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
          if (controller.config.slackEnabled) ...<Widget>[
            if (_showSection(_DashFilter.slackReview)) ...<Widget>[
              const SizedBox(height: 20),
              _SectionBlock(
                title: 'Slack Reviews',
                subtitle: 'From your review channels',
                logoAsset: 'assets/logos/slack.svg',
                logoBg: AppColors.slackLight,
                accentColor: AppColors.slack,
                count: controller.slackReviewItems.length,
                child: controller.slackReviewItems.isEmpty
                    ? const EmptyStateCard(
                        title: 'No review requests',
                        message:
                            'Configure Slack channels to surface review requests.',
                        icon: Icons.mark_chat_unread_rounded,
                      )
                    : Column(
                        children: controller.slackReviewItems
                            .map(
                              (IntegrationItem item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _BriefItemCard(item: item),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
            if (_showSection(_DashFilter.slackAlert)) ...<Widget>[
              const SizedBox(height: 20),
              _SectionBlock(
                title: 'Alerts',
                subtitle: 'Operational alerts',
                logoAsset: 'assets/logos/slack.svg',
                logoBg: AppColors.dangerLight,
                accentColor: AppColors.danger,
                count: controller.slackAlertItems.length,
                child: controller.slackAlertItems.isEmpty
                    ? const EmptyStateCard(
                        title: 'No active alerts',
                        message: 'All quiet on the operations front.',
                        icon: Icons.notifications_off_rounded,
                      )
                    : Column(
                        children: controller.slackAlertItems
                            .map(
                              (IntegrationItem item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _BriefItemCard(item: item),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _filterLabel(_DashFilter f) {
    switch (f) {
      case _DashFilter.pr:
        return 'PR reviews';
      case _DashFilter.jira:
        return 'Jira tickets';
      case _DashFilter.slackReview:
        return 'Slack reviews';
      case _DashFilter.slackAlert:
        return 'Alerts';
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller});
  final EngiTrackController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int count = controller.totalActionableCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0B1220),
            Color(0xFF172033),
            Color(0xFF1E2A40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0B1220).withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: SvgPicture.asset(
              'assets/branding/engitrack_logomark.svg',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Good ${_greeting()}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  count == 0
                      ? 'You\'re all caught up.'
                      : '$count item${count == 1 ? '' : 's'} need${count == 1 ? 's' : ''} attention',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (controller.config.hasAnyIntegrationEnabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'pending',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _greeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _OnboardingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0B1220),
            Color(0xFF172033),
            Color(0xFF1E2A40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0B1220).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
            child: SvgPicture.asset(
              'assets/branding/engitrack_logomark.svg',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Get started with EngiTrack',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF8FAFC),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              'Connect your tools to see PRs, tickets, and alerts in one place. Head to Integrations to enable GitHub, Jira, or Slack.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const _OnboardingStep(number: '1', label: 'Go to Integrations'),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const _OnboardingStep(number: '2', label: 'Enable & configure'),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const _OnboardingStep(number: '3', label: 'Save & sync'),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({required this.number, required this.label});
  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.controller,
    required this.activeFilter,
    required this.onFilterTap,
  });
  final EngiTrackController controller;
  final _DashFilter? activeFilter;
  final ValueChanged<_DashFilter> onFilterTap;

  @override
  Widget build(BuildContext context) {
    final List<_MetricDef> defs = <_MetricDef>[
      if (controller.config.githubEnabled)
        _MetricDef(
          filter: _DashFilter.pr,
          label: 'PR reviews',
          value: '${controller.codeReviewItems.length}',
          logoAsset: 'assets/logos/github.svg',
          accentColor: AppColors.github,
        ),
      if (controller.config.jiraEnabled)
        _MetricDef(
          filter: _DashFilter.jira,
          label: 'Jira tickets',
          value: '${controller.issueTrackerItems.length}',
          logoAsset: 'assets/logos/jira.svg',
          accentColor: AppColors.jira,
        ),
      if (controller.config.slackEnabled) ...<_MetricDef>[
        _MetricDef(
          filter: _DashFilter.slackReview,
          label: 'Slack reviews',
          value: '${controller.slackReviewItems.length}',
          logoAsset: 'assets/logos/slack.svg',
          accentColor: AppColors.slack,
        ),
        _MetricDef(
          filter: _DashFilter.slackAlert,
          label: 'Alerts',
          value: '${controller.slackAlertItems.length}',
          logoAsset: 'assets/logos/slack.svg',
          accentColor: AppColors.danger,
        ),
      ],
    ];

    if (defs.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int count = defs.length;
        final bool isWide = constraints.maxWidth >= 700 && count >= 3;
        const double gap = 8;
        final int columns = isWide ? count : 2;
        final double tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: defs
              .map(
                (_MetricDef d) => SizedBox(
                  width: tileWidth,
                  child: _MetricTileWithLogo(
                    label: d.label,
                    value: d.value,
                    logoAsset: d.logoAsset,
                    accentColor: d.accentColor,
                    selected: activeFilter == d.filter,
                    onTap: () => onFilterTap(d.filter),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricDef {
  const _MetricDef({
    required this.filter,
    required this.label,
    required this.value,
    required this.logoAsset,
    required this.accentColor,
  });
  final _DashFilter filter;
  final String label;
  final String value;
  final String logoAsset;
  final Color accentColor;
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.filter_list_rounded,
                size: 13,
                color: AppColors.accent,
              ),
              const SizedBox(width: 5),
              Text(
                'Showing: $label',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTileWithLogo extends StatelessWidget {
  const _MetricTileWithLogo({
    required this.label,
    required this.value,
    required this.logoAsset,
    this.accentColor,
    this.selected = false,
    this.onTap,
  });
  final String label;
  final String value;
  final String logoAsset;
  final Color? accentColor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = accentColor ?? AppColors.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? color.withValues(alpha: 0.5)
              : AppColors.outline.withValues(alpha: 0.12),
          width: selected ? 1.5 : 0.5,
        ),
        boxShadow: selected
            ? <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: color.withValues(alpha: 0.08),
          highlightColor: color.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                BrandLogo(
                  assetPath: logoAsset,
                  size: 38,
                  backgroundColor: color.withValues(alpha: 0.08),
                  padding: 8,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        value,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(label, style: theme.textTheme.labelMedium),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.filter_list_rounded,
                    size: 16,
                    color: color.withValues(alpha: 0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.subtitle,
    required this.logoAsset,
    required this.logoBg,
    required this.accentColor,
    required this.count,
    required this.child,
  });
  final String title;
  final String subtitle;
  final String logoAsset;
  final Color logoBg;
  final Color accentColor;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: <Widget>[
              BrandLogo(
                assetPath: logoAsset,
                size: 30,
                backgroundColor: logoBg,
                padding: 5,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 15),
                    ),
                    Text(subtitle, style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
              if (count > 0) CountBadge(count: count, color: accentColor),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _BriefItemCard extends StatelessWidget {
  const _BriefItemCard({required this.item});
  final IntegrationItem item;

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final ThemeData theme = Theme.of(context);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(item: item)),
      ),
      child: AppSurface(
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
                      ..._briefTags(),
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
            IconButton(
              onPressed: () async {
                await controller.resolveItem(item.id);
                if (!context.mounted) return;
                showInfoSnackBar(context, 'Item resolved.');
              },
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              style: IconButton.styleFrom(
                foregroundColor: AppColors.tertiaryInk,
                padding: EdgeInsets.zero,
                minimumSize: const Size(28, 28),
              ),
              tooltip: 'Resolve',
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _briefTags() {
    switch (item.category) {
      case IntegrationCategory.codeReview:
        return <Widget>[
          if (item.meta<bool>('draft') == true)
            const SoftTag(
              label: 'Draft',
              backgroundColor: AppColors.warningLight,
              foregroundColor: AppColors.warning,
              dense: true,
            ),
          SoftTag(
            label: item.meta<String>('author') ?? '',
            icon: Icons.person_outline_rounded,
            dense: true,
          ),
        ];
      case IntegrationCategory.issueTracker:
        final String status = item.meta<String>('status') ?? '';
        return <Widget>[
          if (status.isNotEmpty)
            SoftTag(
              label: status,
              icon: Icons.circle,
              foregroundColor: _statusColor(status),
              backgroundColor: _statusColor(status).withValues(alpha: 0.08),
              dense: true,
            ),
        ];
      case IntegrationCategory.messaging:
        final String channel = item.meta<String>('channel') ?? '';
        return <Widget>[
          if (channel.isNotEmpty)
            SoftTag(
              label: channel,
              icon: Icons.tag_rounded,
              backgroundColor: AppColors.slackLight,
              foregroundColor: AppColors.slack,
              dense: true,
            ),
        ];
    }
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return AppColors.info;
      case 'in review':
        return AppColors.accent;
      case 'done':
        return AppColors.success;
      default:
        return AppColors.tertiaryInk;
    }
  }
}
