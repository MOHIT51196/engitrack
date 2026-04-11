import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ai/ai_provider.dart';
import '../controller.dart';
import '../integrations/integration_provider.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.item});

  final IntegrationItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            BrandLogo(assetPath: _logoForProvider(item.providerId), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.subtitle,
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (item.category !=
                  IntegrationCategory.issueTracker) ...<Widget>[
                Text(item.title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
              ],
              _buildMetaTags(context),
              const SizedBox(height: 16),
              _buildCategoryContent(context),
              const SizedBox(height: 16),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaTags(BuildContext context) {
    if (item.category == IntegrationCategory.issueTracker) {
      return _buildIssueTrackerRows(context);
    }

    final List<Widget> tags = <Widget>[];

    tags.add(
      SoftTag(
        label: item.reason.label,
        icon: _iconForReason(item.reason),
        backgroundColor: _bgForReason(item.reason),
        foregroundColor: _fgForReason(item.reason),
        dense: true,
      ),
    );

    tags.add(
      SoftTag(
        label: formatRelativeTime(item.timestamp),
        icon: Icons.schedule_rounded,
        dense: true,
      ),
    );

    tags.add(
      SoftTag(
        label: formatCompactTimestamp(item.timestamp),
        icon: Icons.calendar_today_rounded,
        dense: true,
      ),
    );

    switch (item.category) {
      case IntegrationCategory.codeReview:
        _addCodeReviewTags(tags);
      case IntegrationCategory.issueTracker:
        break;
      case IntegrationCategory.messaging:
        _addMessagingTags(tags);
    }

    return Wrap(spacing: 4, runSpacing: 4, children: tags);
  }

  Widget _buildIssueTrackerRows(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String status = item.meta<String>('status') ?? '';
    final String priority = item.meta<String>('priority') ?? '';
    final String issueType = item.meta<String>('issueType') ?? '';
    final String assignee = item.meta<String>('assignee') ?? '';
    final String parentKey = item.meta<String>('parentKey') ?? '';
    final String parentTitle = item.meta<String>('parentTitle') ?? '';
    final String date = DateFormat('MMM d, y').format(item.timestamp);
    final String time = DateFormat('h:mm a').format(item.timestamp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Row 1: jira title (wrapping)
        Text(
          item.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // Row 2: reason, date, time
        Row(
          children: <Widget>[
            SoftTag(
              label: item.reason.label,
              icon: _iconForReason(item.reason),
              backgroundColor: _bgForReason(item.reason),
              foregroundColor: _fgForReason(item.reason),
              dense: true,
            ),
            const SizedBox(width: 4),
            SoftTag(
              label: date,
              icon: Icons.calendar_today_rounded,
              dense: true,
            ),
            const SizedBox(width: 4),
            SoftTag(label: time, icon: Icons.schedule_rounded, dense: true),
          ],
        ),
        const SizedBox(height: 6),
        // Row 3: jira tracker type + parent tracker
        Row(
          children: <Widget>[
            if (issueType.isNotEmpty)
              SoftTag(
                label: issueType,
                icon: Icons.category_rounded,
                dense: true,
              ),
            if (parentKey.isNotEmpty) ...<Widget>[
              if (issueType.isNotEmpty) const SizedBox(width: 4),
              SoftTag(
                label: parentTitle.isEmpty
                    ? parentKey
                    : '$parentKey: $parentTitle',
                icon: Icons.account_tree_rounded,
                backgroundColor: AppColors.accentLight,
                foregroundColor: AppColors.accent,
                dense: true,
                shrinkable: true,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        // Row 4: status, priority
        Row(
          children: <Widget>[
            if (status.isNotEmpty)
              SoftTag(
                label: status,
                icon: Icons.circle,
                foregroundColor: _statusColor(status),
                backgroundColor: _statusColor(status).withValues(alpha: 0.08),
                dense: true,
              ),
            if (status.isNotEmpty && priority.isNotEmpty)
              const SizedBox(width: 4),
            if (priority.isNotEmpty)
              SoftTag(
                label: priority,
                icon: Icons.arrow_upward_rounded,
                foregroundColor: _priorityColor(priority),
                backgroundColor: _priorityColor(
                  priority,
                ).withValues(alpha: 0.08),
                dense: true,
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Row 5: assignee
        SoftTag(
          label: assignee.isEmpty ? 'Unassigned' : assignee,
          icon: Icons.person_outline_rounded,
          foregroundColor: assignee.isEmpty ? AppColors.warning : null,
          backgroundColor: assignee.isEmpty ? AppColors.warningLight : null,
          dense: true,
        ),
        // Row 6: due date (if present)
        if (_dueDateTag() case final Widget tag) ...<Widget>[
          const SizedBox(height: 6),
          tag,
        ],
      ],
    );
  }

  Widget? _dueDateTag() {
    final String dueDateStr = item.meta<String>('dueDate') ?? '';
    if (dueDateStr.isEmpty) return null;
    final DateTime? dueDate = DateTime.tryParse(dueDateStr);
    if (dueDate == null) return null;
    final bool overdue = dueDate.isBefore(DateTime.now());
    return SoftTag(
      label: 'Due ${formatCompactTimestamp(dueDate)}',
      icon: Icons.event_rounded,
      foregroundColor: overdue ? AppColors.danger : AppColors.info,
      backgroundColor: overdue ? AppColors.dangerLight : AppColors.infoLight,
      dense: true,
    );
  }

  void _addCodeReviewTags(List<Widget> tags) {
    final String author = item.meta<String>('author') ?? '';
    if (author.isNotEmpty) {
      tags.add(
        SoftTag(label: author, icon: Icons.person_outline_rounded, dense: true),
      );
    }
    final int files = item.meta<int>('changedFiles') ?? 0;
    if (files > 0) {
      tags.add(
        SoftTag(
          label: '$files files',
          icon: Icons.description_outlined,
          dense: true,
        ),
      );
    }
    final int adds = item.meta<int>('additions') ?? 0;
    final int dels = item.meta<int>('deletions') ?? 0;
    if (adds > 0 || dels > 0) {
      tags.add(SoftTag(label: '+$adds -$dels', dense: true));
    }
    if (item.meta<bool>('draft') == true) {
      tags.add(
        const SoftTag(
          label: 'Draft',
          icon: Icons.edit_note_rounded,
          backgroundColor: AppColors.warningLight,
          foregroundColor: AppColors.warning,
          dense: true,
        ),
      );
    }
    final String branch = item.meta<String>('headBranch') ?? '';
    if (branch.isNotEmpty) {
      tags.add(
        SoftTag(label: branch, icon: Icons.fork_right_rounded, dense: true),
      );
    }
    final List<dynamic> labels =
        item.metadata['labels'] as List<dynamic>? ?? const <dynamic>[];
    for (final dynamic l in labels.take(3)) {
      tags.add(
        SoftTag(
          label: l.toString(),
          backgroundColor: AppColors.accentLight,
          foregroundColor: AppColors.accent,
          dense: true,
        ),
      );
    }
  }

  void _addMessagingTags(List<Widget> tags) {
    final String channel = item.meta<String>('channel') ?? '';
    if (channel.isNotEmpty) {
      tags.add(
        SoftTag(
          label: channel,
          icon: Icons.tag_rounded,
          backgroundColor: AppColors.slackLight,
          foregroundColor: AppColors.slack,
          dense: true,
        ),
      );
    }
    final String kind = item.meta<String>('kind') ?? '';
    if (kind.isNotEmpty) {
      tags.add(
        SoftTag(
          label: kind == 'pr'
              ? 'PR'
              : kind == 'doc'
                  ? 'Doc'
                  : kind,
          backgroundColor:
              kind == 'pr' ? AppColors.githubLight : AppColors.infoLight,
          foregroundColor: kind == 'pr' ? AppColors.github : AppColors.info,
          dense: true,
        ),
      );
    }
    final String severity = item.meta<String>('severity') ?? '';
    if (severity.isNotEmpty) {
      final AlertSeverity sev = AlertSeverity.values.firstWhere(
        (AlertSeverity s) => s.name == severity,
        orElse: () => AlertSeverity.info,
      );
      tags.add(
        SoftTag(
          label: sev.label,
          icon: _severityIcon(sev),
          foregroundColor: _severityFg(sev),
          backgroundColor: _severityBg(sev),
          dense: true,
        ),
      );
    }
    final String requester = item.meta<String>('requester') ?? '';
    if (requester.isNotEmpty) {
      tags.add(
        SoftTag(
          label: requester,
          icon: Icons.person_outline_rounded,
          dense: true,
        ),
      );
    }
  }

  Widget _buildCategoryContent(BuildContext context) {
    final List<Widget> content = <Widget>[];

    switch (item.category) {
      case IntegrationCategory.codeReview:
        content.add(_PrDetailsSection(item: item));
        content.add(const SizedBox(height: 12));
        content.add(_AiReviewSection(item: item));
      case IntegrationCategory.issueTracker:
        final String description = item.meta<String>('description') ?? '';
        if (description.isNotEmpty) {
          content.add(
            _DescriptionCard(label: 'Description', text: description),
          );
        }
      case IntegrationCategory.messaging:
        final String message = item.meta<String>('message') ?? '';
        if (message.isNotEmpty) {
          content.add(_DescriptionCard(label: 'Message', text: message));
        }
    }

    if (content.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content,
    );
  }

  Widget _buildActions(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final bool isCodeReview = item.category == IntegrationCategory.codeReview;
    final bool hasSlackLink =
        (item.meta<String>('slackDeepLink') ?? '').isNotEmpty ||
            (item.meta<String>('slackWebLink') ?? '').isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Row 1: Open  |  (Slack)  |  ToDo
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => openExternalUrl(context, item.url),
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Open'),
              ),
            ),
            if (hasSlackLink) ...<Widget>[
              const SizedBox(width: 8),
              Expanded(child: _SlackDeepLinkButton(item: item)),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final bool added = await controller.addItemToTodo(item);
                  if (!context.mounted) return;
                  showInfoSnackBar(
                    context,
                    added ? 'Added to ToDo.' : 'Already in ToDo.',
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('ToDo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: AI Review (PR only)  |  Resolve
        Row(
          children: <Widget>[
            if (isCodeReview) ...<Widget>[
              Expanded(child: _AiReviewButton(item: item)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await controller.resolveItem(item.id);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  showInfoSnackBar(context, 'Item resolved.');
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                label: const Text('Resolve'),
              ),
            ),
          ],
        ),
      ],
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

  IconData _iconForReason(ItemReason reason) {
    switch (reason) {
      case ItemReason.assigned:
        return Icons.assignment_ind_rounded;
      case ItemReason.tagged:
        return Icons.alternate_email_rounded;
      case ItemReason.reviewRequested:
        return Icons.rate_review_rounded;
      case ItemReason.alert:
        return Icons.warning_rounded;
      case ItemReason.mention:
        return Icons.chat_rounded;
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

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'highest':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.info;
      default:
        return AppColors.tertiaryInk;
    }
  }

  IconData _severityIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Icons.error_rounded;
      case AlertSeverity.high:
        return Icons.warning_rounded;
      case AlertSeverity.medium:
        return Icons.info_rounded;
      case AlertSeverity.info:
        return Icons.notifications_none_rounded;
    }
  }

  Color _severityFg(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return AppColors.danger;
      case AlertSeverity.high:
        return AppColors.warning;
      case AlertSeverity.medium:
        return AppColors.info;
      case AlertSeverity.info:
        return AppColors.tertiaryInk;
    }
  }

  Color _severityBg(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return AppColors.dangerLight;
      case AlertSeverity.high:
        return AppColors.warningLight;
      case AlertSeverity.medium:
        return AppColors.infoLight;
      case AlertSeverity.info:
        return AppColors.softSurface;
    }
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 11,
              color: AppColors.secondaryInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PrDetailsSection extends StatefulWidget {
  const _PrDetailsSection({required this.item});
  final IntegrationItem item;

  @override
  State<_PrDetailsSection> createState() => _PrDetailsSectionState();
}

class _PrDetailsSectionState extends State<_PrDetailsSection> {
  ({int commits, int changedFiles, String body})? _details;
  bool _loading = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final String initialBody = widget.item.meta<String>('body') ?? '';
    final int initialFiles = widget.item.meta<int>('changedFiles') ?? 0;
    final int initialCommits = widget.item.meta<int>('commits') ?? 0;

    // Show immediately from metadata if we already have commits info
    if (initialCommits > 0 || initialFiles > 0) {
      setState(() {
        _details = (
          commits: initialCommits,
          changedFiles: initialFiles,
          body: initialBody,
        );
      });
    }

    setState(() => _loading = true);
    try {
      final EngiTrackController controller = EngiTrackScope.of(context);
      final result = await controller.fetchPrDetails(widget.item);
      if (mounted) {
        setState(() {
          _details = result;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String body =
        _details?.body ?? widget.item.meta<String>('body') ?? '';
    final int commits = _details?.commits ?? 0;
    final int changedFiles = _details?.changedFiles ?? 0;
    final String filesLabel = changedFiles == 1
        ? '$changedFiles file changed'
        : '$changedFiles files changed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Stats row: commits + files changed
        if (commits > 0 || changedFiles > 0 || _loading)
          AppSurface(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: _loading && commits == 0 && changedFiles == 0
                ? Row(
                    children: <Widget>[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading PR stats...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.tertiaryInk,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      if (commits > 0) ...<Widget>[
                        const Icon(
                          Icons.commit_rounded,
                          size: 14,
                          color: AppColors.secondaryInk,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$commits commit${commits == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (changedFiles > 0) ...<Widget>[
                          const SizedBox(width: 16),
                        ],
                      ],
                      if (changedFiles > 0) ...<Widget>[
                        const Icon(
                          Icons.description_outlined,
                          size: 14,
                          color: AppColors.secondaryInk,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          filesLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_loading) ...<Widget>[
                        const Spacer(),
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      ],
                    ],
                  ),
          ),
        // PR description
        if (body.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          _DescriptionCard(label: 'PR Description', text: body),
        ],
      ],
    );
  }
}

class _SlackDeepLinkButton extends StatelessWidget {
  const _SlackDeepLinkButton({required this.item});
  final IntegrationItem item;

  @override
  Widget build(BuildContext context) {
    final String deepLink = item.meta<String>('slackDeepLink') ?? '';
    final String webLink = item.meta<String>('slackWebLink') ?? '';
    if (deepLink.isEmpty && webLink.isEmpty) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: () async {
        if (deepLink.isNotEmpty) {
          final Uri? uri = Uri.tryParse(deepLink);
          if (uri != null) {
            final bool launched = await launchUrl(uri);
            if (launched) return;
          }
        }
        if (webLink.isNotEmpty && context.mounted) {
          openExternalUrl(context, webLink);
        }
      },
      icon: const Icon(Icons.open_in_new_rounded, size: 14),
      label: const Text('Open in Slack'),
    );
  }
}

class _AiReviewButton extends StatelessWidget {
  const _AiReviewButton({required this.item});
  final IntegrationItem item;

  Future<void> _runReview(BuildContext context, String providerId) async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    try {
      await controller.reviewPullRequest(item, providerId: providerId);
    } catch (error) {
      if (!context.mounted) return;
      showInfoSnackBar(context, 'AI review failed: $error');
    }
  }

  Future<void> _onPressed(BuildContext context) async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final List<AiProvider> providers = controller.configuredAiProviders;

    if (providers.length == 1) {
      await _runReview(context, providers.first.id);
      return;
    }

    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return _AiProviderPicker(
          providers: providers,
          config: controller.config,
        );
      },
    );

    if (chosen == null || !context.mounted) return;
    await _runReview(context, chosen);
  }

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final bool isReviewing = controller.activeReviewPrId == item.id;

    return FilledButton.icon(
      onPressed: !controller.canRunAiReview || isReviewing
          ? null
          : () => _onPressed(context),
      icon: isReviewing
          ? const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.auto_awesome_rounded, size: 14),
      label: Text(isReviewing ? 'Reviewing...' : 'AI Review'),
    );
  }
}

class _AiProviderPicker extends StatelessWidget {
  const _AiProviderPicker({required this.providers, required this.config});
  final List<AiProvider> providers;
  final ConnectorConfig config;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentSuperLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'AI Review',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Choose a provider to review this PR',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...providers.map((AiProvider p) {
                final String modelName = p.model(config);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context, p.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.divider,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: p.brandColorLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                p.icon,
                                color: p.brandColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    p.displayName,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    modelName,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.tertiaryInk,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppColors.tertiaryInk,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiReviewSection extends StatefulWidget {
  const _AiReviewSection({required this.item});
  final IntegrationItem item;

  @override
  State<_AiReviewSection> createState() => _AiReviewSectionState();
}

class _AiReviewSectionState extends State<_AiReviewSection> {
  bool _chatExpanded = false;
  List<AiChatMessage> _chatHistory = <AiChatMessage>[];
  final TextEditingController _chatController = TextEditingController();
  bool _chatLoading = false;
  bool _didLoadChat = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadChat) {
      _didLoadChat = true;
      _loadChatHistory();
    }
  }

  Future<void> _loadChatHistory() async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    _chatHistory = await controller.loadAiChat(widget.item.id);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final AiReviewResult? review = controller.reviewFor(widget.item.id);
    final ThemeData theme = Theme.of(context);

    if (review == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accentSuperLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AI Review',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatCompactTimestamp(review.generatedAt),
                    style: theme.textTheme.labelMedium?.copyWith(fontSize: 10),
                  ),
                ],
              ),
              if (review.verdict.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'Verdict',
                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(review.verdict, style: theme.textTheme.bodyMedium),
              ],
              if (review.concerns.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Concerns',
                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 6),
                ...review.concerns.map(
                  (AiReviewConcern c) =>
                      _ConcernCard(item: widget.item, concern: c),
                ),
              ],
              if (review.mergeConfidence.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                SoftTag(
                  label: 'Merge: ${review.mergeConfidence}',
                  icon: Icons.merge_rounded,
                  dense: true,
                ),
              ],
              if (review.executiveSummary.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  review.executiveSummary,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (review.concerns.isEmpty &&
                  review.rawReview.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  review.rawReview.length <= 600
                      ? review.rawReview
                      : '${review.rawReview.substring(0, 597)}...',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildChatSection(context, review, theme),
      ],
    );
  }

  Widget _buildChatSection(
    BuildContext context,
    AiReviewResult review,
    ThemeData theme,
  ) {
    return AppSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _chatExpanded = !_chatExpanded),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.chat_rounded,
                  size: 15,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  'Chat about this review',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.accent,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Icon(
                  _chatExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppColors.tertiaryInk,
                ),
              ],
            ),
          ),
          if (_chatExpanded) ...<Widget>[
            const SizedBox(height: 10),
            if (_chatHistory.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _chatHistory.length,
                  itemBuilder: (BuildContext context, int index) {
                    final AiChatMessage msg = _chatHistory[index];
                    final bool isUser = msg.role == 'user';
                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? AppColors.accentLight
                              : AppColors.softSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          msg.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Ask about this review...',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(review),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _chatLoading ? null : () => _sendMessage(review),
                  icon: _chatLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
            if (_chatHistory.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _clearChat,
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: const Text(
                    'Clear conversation',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendMessage(AiReviewResult review) async {
    final String text = _chatController.text.trim();
    if (text.isEmpty) return;

    final EngiTrackController controller = EngiTrackScope.of(context);
    final AiChatMessage userMsg = AiChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _chatHistory = <AiChatMessage>[..._chatHistory, userMsg];
      _chatLoading = true;
      _chatController.clear();
    });

    try {
      final AiChatMessage response = await controller.chatAboutReview(
        item: widget.item,
        review: review,
        history: _chatHistory,
        userMessage: text,
      );
      _chatHistory = <AiChatMessage>[..._chatHistory, response];
      await controller.saveAiChat(widget.item.id, _chatHistory);
    } catch (error) {
      if (mounted) showInfoSnackBar(context, 'Chat failed: $error');
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  Future<void> _clearChat() async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    _chatHistory = <AiChatMessage>[];
    await controller.saveAiChat(widget.item.id, _chatHistory);
    if (mounted) setState(() {});
  }
}

class _ConcernCard extends StatelessWidget {
  const _ConcernCard({required this.item, required this.concern});
  final IntegrationItem item;
  final AiReviewConcern concern;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final EngiTrackController controller = EngiTrackScope.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SoftTag(
                label: concern.severity,
                foregroundColor: _severityColor(concern.severity),
                backgroundColor: _severityColor(
                  concern.severity,
                ).withValues(alpha: 0.1),
                dense: true,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  concern.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            concern.description,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
          if (concern.filePath != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '${concern.filePath}${concern.lineNumber != null ? ':${concern.lineNumber}' : ''}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: OutlinedButton.icon(
              onPressed: () => _addComment(context, controller),
              icon: const Icon(Icons.comment_outlined, size: 12),
              label: const Text('Add comment', style: TextStyle(fontSize: 10)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addComment(
    BuildContext context,
    EngiTrackController controller,
  ) async {
    final TextEditingController textController = TextEditingController(
      text:
          '**[${concern.severity}] ${concern.title}**\n\n${concern.description}'
          '${concern.filePath != null ? '\n\nFile: `${concern.filePath}${concern.lineNumber != null ? ':${concern.lineNumber}' : ''}`' : ''}',
    );

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Add PR Comment'),
          content: SizedBox(
            width: 500,
            child: TextField(
              controller: textController,
              maxLines: 8,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Edit your comment...',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, textController.text),
              child: const Text('Post comment'),
            ),
          ],
        );
      },
    );

    textController.dispose();

    if (result != null && result.trim().isNotEmpty && context.mounted) {
      try {
        final String url = await controller.postPrComment(item, result);
        if (!context.mounted) return;
        showInfoSnackBar(
          context,
          url.isNotEmpty ? 'Comment posted!' : 'Comment posted.',
        );
      } catch (error) {
        if (!context.mounted) return;
        showInfoSnackBar(context, 'Failed to post: $error');
      }
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppColors.danger;
      case 'suggestion':
        return AppColors.info;
      case 'nitpick':
        return AppColors.tertiaryInk;
      default:
        return AppColors.warning;
    }
  }
}
