import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'integration_detail_screen.dart';

/// Integrations hub: one compact row per integration (logo, status chip,
/// enable switch). All configuration lives in [IntegrationDetailScreen],
/// which opens when a row is tapped.
class IntegrationsScreen extends StatelessWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
            child: _ExportImportButtons(
              onExport: () => _exportConfig(context),
              onImport: () => _importConfig(context),
            ),
          ),
          const _CategoryHeader(icon: Icons.code_rounded, label: 'Git'),
          const SizedBox(height: 8),
          _IntegrationRow(spec: IntegrationSpec.byId('github')),
          const SizedBox(height: 16),
          const _CategoryHeader(
            icon: Icons.assignment_rounded,
            label: 'Management',
          ),
          const SizedBox(height: 8),
          _IntegrationRow(spec: IntegrationSpec.byId('jira')),
          const SizedBox(height: 16),
          const _CategoryHeader(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messaging',
          ),
          const SizedBox(height: 8),
          _IntegrationRow(spec: IntegrationSpec.byId('slack')),
          const SizedBox(height: 16),
          const _CategoryHeader(
            icon: Icons.auto_awesome_rounded,
            label: 'AI Services',
          ),
          const SizedBox(height: 8),
          _IntegrationRow(spec: IntegrationSpec.byId('openai')),
          const SizedBox(height: 8),
          _IntegrationRow(spec: IntegrationSpec.byId('gemini')),
          const SizedBox(height: 8),
          _IntegrationRow(spec: IntegrationSpec.byId('claude')),
          const SizedBox(height: 8),
          _IntegrationRow(spec: IntegrationSpec.byId('grok')),
          const SizedBox(height: 8),
          _IntegrationRow(spec: IntegrationSpec.byId('cursor')),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _exportConfig(BuildContext context) async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    try {
      final String? path = await controller.exportConfig();
      if (!context.mounted || path == null) return;
      showInfoSnackBar(context, 'Config exported successfully.');
    } catch (error) {
      if (!context.mounted) return;
      showInfoSnackBar(context, 'Export failed: $error');
    }
  }

  Future<void> _importConfig(BuildContext context) async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    try {
      final ConnectorConfig? imported = await controller.importConfig();
      if (!context.mounted || imported == null) return;
      showInfoSnackBar(context, 'Config imported and applied.');
    } on FormatException catch (error) {
      if (!context.mounted) return;
      showInfoSnackBar(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      showInfoSnackBar(context, 'Import failed: $error');
    }
  }
}

// ---------------------------------------------------------------------------
// Integration row
// ---------------------------------------------------------------------------

class _IntegrationRow extends StatelessWidget {
  const _IntegrationRow({required this.spec});

  final IntegrationSpec spec;

  Future<void> _setEnabled(BuildContext context, bool value) async {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final bool ok = await controller.setIntegrationEnabled(spec.id, value);
    if (!value || ok || !context.mounted) return;
    final String message = controller.healthFor(spec.id).message;
    showInfoSnackBar(
      context,
      message.isEmpty ? '${spec.name} connection failed.' : message,
    );
  }

  Color _borderColor(
    bool enabled,
    bool isConfigured,
    IntegrationHealth health,
  ) {
    if (!enabled) return AppColors.outline.withValues(alpha: 0.4);
    if (isConfigured && health.isConnected) {
      return AppColors.success.withValues(alpha: 0.25);
    }
    if (health.isError) return AppColors.danger.withValues(alpha: 0.3);
    return spec.color.withValues(alpha: 0.15);
  }

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final ConnectorConfig config = controller.config;
    final ThemeData theme = Theme.of(context);

    final bool enabled = integrationEnabled(config, spec.id);
    final bool canEnable = integrationCanEnable(config, spec.id);
    final bool isConfigured = integrationIsConfigured(config, spec.id);
    final IntegrationHealth health = controller.healthFor(spec.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _borderColor(enabled, isConfigured, health),
          width: 0.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: enabled ? 0.04 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => IntegrationDetailScreen(integrationId: spec.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: <Widget>[
              IntegrationAvatar(spec: spec, enabled: enabled),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            spec.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 14,
                              color: enabled
                                  ? AppColors.ink
                                  : AppColors.tertiaryInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IntegrationStatusChip(
                          enabled: enabled,
                          isConfigured: isConfigured,
                          health: health,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: enabled
                            ? AppColors.secondaryInk
                            : AppColors.tertiaryInk,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 28,
                child: FittedBox(
                  child: Switch.adaptive(
                    value: enabled,
                    onChanged: (enabled || canEnable)
                        ? (bool value) => _setEnabled(context, value)
                        : null,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: enabled ? AppColors.secondaryInk : AppColors.tertiaryInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category header separator
// ---------------------------------------------------------------------------

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: AppColors.secondaryInk),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryInk,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Export / Import buttons
// ---------------------------------------------------------------------------

class _ExportImportButtons extends StatelessWidget {
  const _ExportImportButtons({required this.onExport, required this.onImport});

  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = OutlinedButton.styleFrom(
      foregroundColor: AppColors.secondaryInk,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
    );

    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.upload_rounded, size: 16),
            label: const Text('Export'),
            style: style,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Import'),
            style: style,
          ),
        ),
      ],
    );
  }
}
