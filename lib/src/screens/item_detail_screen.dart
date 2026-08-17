import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ai/ai_provider.dart';
import '../ai/ai_provider_registry.dart';
import '../ai/ai_review_helpers.dart';
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
          content.add(const SizedBox(height: 12));
        }
        content.add(_JiraAssistSection(item: item));
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

    // A Cursor cloud agent is already running (or finished) for this PR --
    // re-attach to it instead of asking for a provider again.
    if (controller.hasPendingCursorRun(item.id)) {
      await _runReview(context, 'cursor');
      return;
    }

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
    final bool hasPendingRun = controller.hasPendingCursorRun(item.id);

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
          : Icon(
              hasPendingRun
                  ? Icons.restart_alt_rounded
                  : Icons.auto_awesome_rounded,
              size: 14,
            ),
      label: Text(
        isReviewing
            ? 'Reviewing...'
            : hasPendingRun
                ? 'Resume review'
                : 'AI Review',
      ),
    );
  }
}

class _AiProviderPicker extends StatelessWidget {
  const _AiProviderPicker({
    required this.providers,
    required this.config,
    this.title = 'AI Review',
    this.subtitle = 'Choose a provider to review this PR',
  });
  final List<AiProvider> providers;
  final ConnectorConfig config;
  final String title;
  final String subtitle;

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
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          subtitle,
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

/// Chat-based AI discovery on a Jira item. Built purely from the ticket
/// content -- it never fetches anything from GitHub (the Cursor cloud-agent
/// provider is excluded for that reason).
class _JiraAssistSection extends StatefulWidget {
  const _JiraAssistSection({required this.item});
  final IntegrationItem item;

  @override
  State<_JiraAssistSection> createState() => _JiraAssistSectionState();
}

class _JiraAssistSectionState extends State<_JiraAssistSection> {
  final TextEditingController _inputController = TextEditingController();
  List<AiChatMessage> _history = <AiChatMessage>[];
  bool _loading = false;
  bool _didLoad = false;

  /// Storage key is prefixed so an assist thread can never collide with a
  /// PR review chat thread.
  String get _chatKey => 'assist-${widget.item.id}';

  bool get _isSpike =>
      isSpikeIssueType(widget.item.meta<String>('issueType') ?? '');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    _history = await controller.loadAiChat(_chatKey);
    if (mounted) setState(() {});
  }

  Future<String?> _pickProvider() async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final List<AiProvider> providers = controller.jiraAssistProviders;
    if (providers.isEmpty) return null;
    if (providers.length == 1) return providers.first.id;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _AiProviderPicker(
        providers: providers,
        config: controller.config,
        title: 'AI Assist',
        subtitle: 'Choose a provider to analyze this ticket',
      ),
    );
  }

  Future<void> _startAnalysis() async {
    final String? providerId = await _pickProvider();
    if (providerId == null || !mounted) return;
    await _send(jiraAssistKickoffMessage, providerId: providerId);
  }

  Future<void> _send(String text, {String? providerId}) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final EngiTrackController controller = EngiTrackScope.of(context);
    final List<AiChatMessage> prior = List<AiChatMessage>.from(_history);
    final AiChatMessage userMsg = AiChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      role: 'user',
      content: trimmed,
      timestamp: DateTime.now(),
    );

    setState(() {
      _history = <AiChatMessage>[..._history, userMsg];
      _loading = true;
      _inputController.clear();
    });

    try {
      final AiChatMessage response = await controller.chatAboutJiraItem(
        item: widget.item,
        history: prior,
        userMessage: trimmed,
        providerId: providerId,
      );
      _history = <AiChatMessage>[..._history, response];
      await controller.saveAiChat(_chatKey, _history);
    } catch (error) {
      // Roll back the optimistic user message so a failed kickoff returns
      // to the "Analyze" card instead of a dangling one-sided chat.
      _history = prior;
      if (mounted) showInfoSnackBar(context, 'AI assist failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearChat() async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    _history = <AiChatMessage>[];
    await controller.saveAiChat(_chatKey, _history);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final ThemeData theme = Theme.of(context);
    final bool available = controller.jiraAssistProviders.isNotEmpty;

    if (_history.isEmpty && !available) return const SizedBox.shrink();
    if (_history.isEmpty) return _buildKickoffCard(theme, available);
    return _buildChat(controller, theme);
  }

  Widget _buildKickoffCard(ThemeData theme, bool available) {
    return AppSurface(
      padding: const EdgeInsets.all(14),
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
                'AI Assist',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isSpike
                ? 'Get a structured spike breakdown: questions to answer, '
                    'investigation plan, timebox, and deliverables.'
                : 'Get a discovery summary of the code change this ticket '
                    'needs: approach, affected areas, edge cases, and a test '
                    'checklist.',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chat only -- nothing is fetched from GitHub.',
            style: TextStyle(fontSize: 10, color: AppColors.tertiaryInk),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading || !available ? null : _startAnalysis,
              icon: _loading
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 14),
              label: Text(
                _loading
                    ? 'Analyzing...'
                    : _isSpike
                        ? 'Analyze spike'
                        : 'Explain code change',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat(EngiTrackController controller, ThemeData theme) {
    final String? providerId = controller.assistProviderFor(widget.item.id);
    final AiProvider? provider =
        providerId == null ? null : AiProviderRegistry.byId(providerId);

    return AppSurface(
      padding: const EdgeInsets.all(14),
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
                'AI Assist',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.accent,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (provider != null)
                SoftTag(
                  label: provider.displayName,
                  icon: provider.icon,
                  backgroundColor: provider.brandColorLight,
                  foregroundColor: provider.brandColor,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _history.length,
              itemBuilder: (BuildContext context, int index) {
                final AiChatMessage msg = _history[index];
                final bool isUser = msg.role == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width *
                          (isUser ? 0.7 : 0.85),
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.accentLight
                          : AppColors.softSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      msg.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.45,
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
                  controller: _inputController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Ask a follow-up about this ticket...',
                    isDense: true,
                  ),
                  onSubmitted: _loading ? null : (String v) => _send(v),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _loading ? null : () => _send(_inputController.text),
                icon: _loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
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
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Copy full review',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: review.review),
                        );
                        if (!context.mounted) return;
                        showInfoSnackBar(context, 'Review copied.');
                      },
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              if (_reviewedByLabel(review) case final String reviewedBy
                  when reviewedBy.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: <Widget>[
                    SoftTag(
                      label: reviewedBy,
                      icon: AiProviderRegistry.byId(review.providerId)?.icon ??
                          Icons.psychology_outlined,
                      backgroundColor:
                          AiProviderRegistry.byId(review.providerId)
                                  ?.brandColorLight ??
                              AppColors.softSurface,
                      foregroundColor: AiProviderRegistry.byId(
                            review.providerId,
                          )?.brandColor ??
                          AppColors.secondaryInk,
                      dense: true,
                      shrinkable: false,
                    ),
                    if (controller.postedReviewDecisionFor(widget.item.id)
                        case final PrReviewDecision posted?)
                      SoftTag(
                        label: 'Posted: ${posted.label}',
                        icon: _decisionIcon(posted),
                        foregroundColor: _decisionColor(posted),
                        backgroundColor:
                            _decisionColor(posted).withValues(alpha: 0.1),
                        dense: true,
                      ),
                  ],
                ),
              ],
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
                  'Concerns (${review.concerns.length})',
                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 6),
                _SeveritySummary(concerns: review.concerns),
                const SizedBox(height: 8),
                ...sortConcernsBySeverity(review.concerns).map(
                  (AiReviewConcern c) => _ConcernCard(
                    concern: c,
                    initiallyExpanded: c.severity.toLowerCase() == 'critical' ||
                        review.concerns.length <= 3,
                    onPost: () =>
                        _openPostReviewFlow(context, review, preselected: c),
                  ),
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
                _ExpandableReviewText(text: review.rawReview),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openPostReviewFlow(context, review),
                  icon: const Icon(Icons.rate_review_outlined, size: 14),
                  label: const Text('Post review to GitHub'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildChatSection(context, review, theme),
      ],
    );
  }

  /// e.g. "Cursor · claude-fable-5" or "OpenAI · gpt-4o".
  String _reviewedByLabel(AiReviewResult review) {
    final String providerName =
        AiProviderRegistry.byId(review.providerId)?.displayName ??
            review.providerId;
    return <String>[
      if (providerName.isNotEmpty) providerName,
      if (review.model.isNotEmpty) review.model,
    ].join(' · ');
  }

  IconData _decisionIcon(PrReviewDecision decision) {
    switch (decision) {
      case PrReviewDecision.comment:
        return Icons.chat_bubble_outline_rounded;
      case PrReviewDecision.requestChanges:
        return Icons.published_with_changes_rounded;
      case PrReviewDecision.approve:
        return Icons.check_circle_outline_rounded;
    }
  }

  Color _decisionColor(PrReviewDecision decision) {
    switch (decision) {
      case PrReviewDecision.comment:
        return AppColors.info;
      case PrReviewDecision.requestChanges:
        return AppColors.warning;
      case PrReviewDecision.approve:
        return AppColors.success;
    }
  }

  /// Opens the post-review sheet: pick the review state, select which
  /// concerns to include (all by default, or a single preselected one), and
  /// edit the consolidated comment before it is posted as one GitHub review.
  Future<void> _openPostReviewFlow(
    BuildContext context,
    AiReviewResult review, {
    AiReviewConcern? preselected,
  }) async {
    final ({PrReviewDecision decision, String body})? result =
        await showModalBottomSheet<({PrReviewDecision decision, String body})>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _PostReviewSheet(
        review: review,
        subtitle: widget.item.subtitle,
        preselected: preselected,
      ),
    );
    if (result == null || !context.mounted) return;

    final EngiTrackController controller = EngiTrackScope.of(context);
    try {
      await controller.submitPrReview(
        widget.item,
        body: result.body,
        decision: result.decision,
      );
      if (!context.mounted) return;
      showInfoSnackBar(context, 'Review posted (${result.decision.label}).');
    } catch (error) {
      if (!context.mounted) return;
      showInfoSnackBar(context, 'Failed to post review: $error');
    }
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

/// Severity counts shown above a long concern list so the scale of the
/// feedback is clear at a glance.
class _SeveritySummary extends StatelessWidget {
  const _SeveritySummary({required this.concerns});
  final List<AiReviewConcern> concerns;

  @override
  Widget build(BuildContext context) {
    final Map<String, int> counts = <String, int>{};
    for (final AiReviewConcern concern in concerns) {
      final String key = concern.severity.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final List<Widget> tags = <Widget>[];
    void addTag(String severity, String label, Color color) {
      final int count = counts.remove(severity) ?? 0;
      if (count == 0) return;
      tags.add(
        SoftTag(
          label: '$count $label',
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: 0.1),
          dense: true,
        ),
      );
    }

    addTag('critical', 'critical', AppColors.danger);
    addTag('suggestion', 'suggestions', AppColors.info);
    addTag('nitpick', 'nitpicks', AppColors.tertiaryInk);
    for (final MapEntry<String, int> entry in counts.entries) {
      tags.add(
        SoftTag(
          label: '${entry.value} ${entry.key}',
          foregroundColor: AppColors.warning,
          backgroundColor: AppColors.warningLight,
          dense: true,
        ),
      );
    }

    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 4, runSpacing: 4, children: tags);
  }
}

/// Full model output with expand/collapse -- never truncates the content, so
/// long free-form reviews stay readable and scrollable.
class _ExpandableReviewText extends StatefulWidget {
  const _ExpandableReviewText({required this.text});
  final String text;

  @override
  State<_ExpandableReviewText> createState() => _ExpandableReviewTextState();
}

class _ExpandableReviewTextState extends State<_ExpandableReviewText> {
  static const int _collapsedMaxLines = 12;

  bool _expanded = false;

  bool get _isLong =>
      widget.text.length > 700 ||
      '\n'.allMatches(widget.text).length >= _collapsedMaxLines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style =
        theme.textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.outline.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: _expanded || !_isLong
              ? SelectableText(widget.text.trim(), style: style)
              : Text(
                  widget.text.trim(),
                  style: style,
                  maxLines: _collapsedMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        if (_isLong)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
              size: 14,
            ),
            label: Text(
              _expanded ? 'Show less' : 'Show full review',
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _ConcernCard extends StatefulWidget {
  const _ConcernCard({
    required this.concern,
    required this.onPost,
    this.initiallyExpanded = true,
  });
  final AiReviewConcern concern;
  final VoidCallback onPost;
  final bool initiallyExpanded;

  @override
  State<_ConcernCard> createState() => _ConcernCardState();
}

class _ConcernCardState extends State<_ConcernCard> {
  late bool _expanded = widget.initiallyExpanded;

  AiReviewConcern get concern => widget.concern;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
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
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(
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
                      style:
                          theme.textTheme.titleMedium?.copyWith(fontSize: 12),
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: AppColors.tertiaryInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SelectableText(
                    concern.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      height: 1.45,
                    ),
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
                      onPressed: widget.onPost,
                      icon: const Icon(Icons.rate_review_outlined, size: 12),
                      label: const Text(
                        'Post to GitHub',
                        style: TextStyle(fontSize: 10),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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

/// Bottom sheet for posting the AI review to GitHub as a single pull request
/// review: pick the review state, choose which concerns to include, and edit
/// the consolidated comment before posting.
class _PostReviewSheet extends StatefulWidget {
  const _PostReviewSheet({
    required this.review,
    required this.subtitle,
    this.preselected,
  });

  final AiReviewResult review;
  final String subtitle;
  final AiReviewConcern? preselected;

  @override
  State<_PostReviewSheet> createState() => _PostReviewSheetState();
}

class _PostReviewSheetState extends State<_PostReviewSheet> {
  PrReviewDecision _decision = PrReviewDecision.comment;
  late final Set<int> _selectedIndexes = widget.preselected == null
      ? <int>{for (int i = 0; i < widget.review.concerns.length; i++) i}
      : <int>{
          widget.review.concerns.indexOf(widget.preselected!),
        }.where((int i) => i >= 0).toSet();
  late final TextEditingController _bodyController =
      TextEditingController(text: _generatedBody());
  bool _userEdited = false;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  String _generatedBody() {
    return buildConsolidatedReviewComment(
      review: widget.review,
      concerns: <AiReviewConcern>[
        for (int i = 0; i < widget.review.concerns.length; i++)
          if (_selectedIndexes.contains(i)) widget.review.concerns[i],
      ],
    );
  }

  void _toggleConcern(int index, bool selected) {
    setState(() {
      if (selected) {
        _selectedIndexes.add(index);
      } else {
        _selectedIndexes.remove(index);
      }
      // Keep the body in sync with the selection until the user starts
      // editing it manually.
      if (!_userEdited) {
        _bodyController.text = _generatedBody();
      }
    });
  }

  bool get _canPost =>
      _decision == PrReviewDecision.approve ||
      _bodyController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AiReviewConcern> concerns = widget.review.concerns;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Post review to GitHub',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryInk,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Review state',
                style: theme.textTheme.labelLarge?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 6),
              SegmentedButton<PrReviewDecision>(
                segments: const <ButtonSegment<PrReviewDecision>>[
                  ButtonSegment<PrReviewDecision>(
                    value: PrReviewDecision.comment,
                    label: Text('Comment'),
                    icon: Icon(Icons.chat_bubble_outline_rounded, size: 13),
                  ),
                  ButtonSegment<PrReviewDecision>(
                    value: PrReviewDecision.requestChanges,
                    label: Text('Request changes'),
                    icon: Icon(Icons.published_with_changes_rounded, size: 13),
                  ),
                  ButtonSegment<PrReviewDecision>(
                    value: PrReviewDecision.approve,
                    label: Text('Approve'),
                    icon: Icon(Icons.check_circle_outline_rounded, size: 13),
                  ),
                ],
                selected: <PrReviewDecision>{_decision},
                onSelectionChanged: (Set<PrReviewDecision> selection) {
                  setState(() => _decision = selection.first);
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (concerns.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  'Include concerns (${_selectedIndexes.length}/${concerns.length})',
                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < concerns.length; i++)
                          CheckboxListTile(
                            value: _selectedIndexes.contains(i),
                            onChanged: (bool? v) =>
                                _toggleConcern(i, v ?? false),
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              '[${concerns[i].severity}] ${concerns[i].title}',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Comment',
                style: theme.textTheme.labelLarge?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _bodyController,
                minLines: 4,
                maxLines: 10,
                style: const TextStyle(fontSize: 12, height: 1.4),
                decoration: InputDecoration(
                  hintText: _decision == PrReviewDecision.approve
                      ? 'Optional comment (approvals can be empty)...'
                      : 'Review comment (posted as one message)...',
                ),
                onChanged: (String _) {
                  _userEdited = true;
                  setState(() {});
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _canPost
                          ? () => Navigator.pop(
                                context,
                                (
                                  decision: _decision,
                                  body: _bodyController.text,
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: Text('Post (${_decision.label})'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
