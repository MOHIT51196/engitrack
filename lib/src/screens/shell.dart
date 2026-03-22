import 'package:flutter/material.dart';

import '../controller.dart';
import '../theme.dart';
import '../widgets.dart';
import 'dashboard_screen.dart';
import 'integrations_screen.dart';
import 'workspace_screen.dart';

class EngiTrackShell extends StatefulWidget {
  const EngiTrackShell({super.key});

  @override
  State<EngiTrackShell> createState() => _EngiTrackShellState();
}

class _EngiTrackShellState extends State<EngiTrackShell> {
  int _currentIndex = 0;

  static const List<_ShellDestination> _destinations = <_ShellDestination>[
    _ShellDestination('Dashboard', Icons.grid_view_rounded),
    _ShellDestination('ToDos', Icons.checklist_rounded),
    _ShellDestination('Integrations', Icons.settings_input_component_rounded),
  ];

  Widget _buildPage() {
    switch (_currentIndex) {
      case 0:
        return const DashboardScreen(key: ValueKey<int>(0));
      case 1:
        return const WorkspaceScreen(key: ValueKey<int>(1));
      case 2:
        return const IntegrationsScreen(key: ValueKey<int>(2));
      default:
        return const DashboardScreen(key: ValueKey<int>(0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final EngiTrackController controller = EngiTrackScope.of(context);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: _buildAppBar(controller, theme),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _buildPage(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.5), width: 0.5),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (int index) {
            setState(() => _currentIndex = index);
          },
          destinations: _destinations
              .map(
                (_ShellDestination destination) => NavigationDestination(
                  icon: Icon(destination.icon),
                  label: destination.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    EngiTrackController controller,
    ThemeData theme,
  ) {
    final String syncLabel = controller.lastSyncedAt == null
        ? 'Not synced yet'
        : 'Synced ${formatRelativeTime(controller.lastSyncedAt!)}';

    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _destinations[_currentIndex].label,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(syncLabel, style: theme.textTheme.labelMedium),
            ],
          ),
        ],
      ),
      actions: const <Widget>[SizedBox(width: 6)],
    );
  }
}

class _ShellDestination {
  const _ShellDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}
