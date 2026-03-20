import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      case 0: return const DashboardScreen(key: ValueKey<int>(0));
      case 1: return const WorkspaceScreen(key: ValueKey<int>(1));
      case 2: return const IntegrationsScreen(key: ValueKey<int>(2));
      default: return const DashboardScreen(key: ValueKey<int>(0));
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
            top: BorderSide(color: AppColors.divider.withOpacity(0.5), width: 0.5),
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

  Widget _buildSidebar(ThemeData theme, EngiTrackController controller) {
    return Container(
      width: 250,
      margin: const EdgeInsets.fromLTRB(16, 0, 12, 16),
      child: AppSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: <Widget>[
                  _BrandMark(size: 34),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'EngiTrack',
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 15),
                      ),
                      Text(
                        'v1.0',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.tertiaryInk,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ...List<Widget>.generate(_destinations.length, (int index) {
              final _ShellDestination dest = _destinations[index];
              final bool selected = _currentIndex == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _currentIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accentSuperLight : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(color: AppColors.accent.withOpacity(0.15), width: 0.5)
                            : null,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            dest.icon,
                            size: 18,
                            color: selected ? AppColors.accent : AppColors.tertiaryInk,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            dest.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? AppColors.accent : AppColors.secondaryInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            _DisabledNavItem(label: 'Notes', icon: Icons.sticky_note_2_outlined),
            const Spacer(),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.softSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: AppColors.tertiaryInk,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Engineer',
                          style: theme.textTheme.titleMedium?.copyWith(fontSize: 12),
                        ),
                        Text(
                          'Live mode',
                          style: theme.textTheme.labelMedium?.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisabledNavItem extends StatelessWidget {
  const _DisabledNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Opacity(
        opacity: 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.tertiaryInk),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryInk,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Upcoming',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0B1220).withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SvgPicture.asset(
        'assets/branding/engitrack_logomark.svg',
        fit: BoxFit.cover,
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}
