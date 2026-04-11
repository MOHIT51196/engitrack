import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

String formatTimestamp(DateTime value) {
  return DateFormat('MMM d, y • h:mm a').format(value);
}

String formatCompactTimestamp(DateTime value) {
  return DateFormat('MMM d • h:mm a').format(value);
}

String formatRelativeTime(DateTime value) {
  final Duration diff = DateTime.now().difference(value);
  if (diff.inSeconds < 60) {
    return 'just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  }
  return DateFormat('MMM d').format(value);
}

Future<void> openExternalUrl(BuildContext context, String rawUrl) async {
  if (rawUrl.trim().isEmpty) {
    showInfoSnackBar(context, 'No link available for this item.');
    return;
  }

  final Uri? uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) {
    showInfoSnackBar(context, 'Could not open the link.');
    return;
  }

  final bool launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
  if (!launched && context.mounted) {
    showInfoSnackBar(context, 'Could not open the link.');
  }
}

void showInfoSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: <Widget>[
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
    ),
  );
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 14,
    this.borderColor,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: elevated ? AppColors.surfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppColors.outline.withValues(alpha: 0.6),
          width: 0.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: elevated ? 0.06 : 0.03),
            blurRadius: elevated ? 20 : 8,
            offset: Offset(0, elevated ? 6 : 2),
          ),
          if (!elevated)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 3),
                Text(subtitle!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class SoftTag extends StatelessWidget {
  const SoftTag({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.dense = false,
    this.shrinkable = false,
  });

  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool dense;
  final bool shrinkable;

  @override
  Widget build(BuildContext context) {
    final Color bg = backgroundColor ?? AppColors.softSurface;
    final Color fg = foregroundColor ?? AppColors.secondaryInk;
    final Widget content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 11 : 12, color: fg),
            SizedBox(width: dense ? 3 : 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: fg,
                letterSpacing: 0.1,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
    if (shrinkable) {
      return Flexible(child: content);
    }
    return content;
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = accentColor ?? AppColors.accent;
    return AppSurface(
      radius: 12,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
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
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.3),
          width: 0.5,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.tertiaryInk, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.secondaryInk,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.tertiaryInk,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class IntegrationIcon extends StatelessWidget {
  const IntegrationIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 34,
    this.lightColor,
  });

  final IconData icon;
  final Color color;
  final double size;
  final Color? lightColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: lightColor ?? color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Icon(icon, color: color, size: size * 0.47),
    );
  }
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    required this.assetPath,
    this.size = 30,
    this.backgroundColor,
    this.padding = 5,
  });

  final String assetPath;
  final double size;
  final Color? backgroundColor;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.softSurface,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: SvgPicture.asset(assetPath, fit: BoxFit.contain),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.isConfigured});

  final bool isConfigured;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConfigured ? AppColors.successLight : AppColors.softSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConfigured
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.outline.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isConfigured ? AppColors.success : AppColors.tertiaryInk,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isConfigured ? 'Connected' : 'Not set up',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isConfigured ? AppColors.success : AppColors.tertiaryInk,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
