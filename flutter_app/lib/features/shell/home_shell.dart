import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/widgets/language_selector.dart';
import '../../realtime/realtime_service.dart';
import '../home/home_tab.dart';
import '../home/submission_repository.dart';
import '../settings/settings_tab.dart';
import '../../survey/survey_screen.dart';
import 'floating_nav_bar.dart';

/// The signed-in experience: a soft-UI shell hosting the real-time home
/// dashboard and the user's settings / history, with the "Collect census" FAB
/// docked into the curved floating navigation bar.
///
/// A single [SubmissionRepository] and [RealTimeService] live here so both
/// destinations share one source of truth: a WebSocket event or an offline sync
/// updates every tab at once, without refetching.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user, required this.onSignedOut});

  final SessionUser user;
  final VoidCallback onSignedOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final RealTimeService _realtime;
  late final SubmissionRepository _repo;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  @override
  void initState() {
    super.initState();
    _repo = SubmissionRepository();
    _realtime = RealTimeService(api: api);
    _eventsSub = _realtime.events.listen(_repo.handleEvent);
    _realtime.status.addListener(_onConnectionChanged);
    _realtime.start();
    _repo.init(widget.user.id);
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _realtime.status.removeListener(_onConnectionChanged);
    _realtime.dispose();
    _repo.dispose();
    super.dispose();
  }

  // Reconnecting is the moment to push anything captured offline and pull the
  // freshest rows (respecting the user's auto-sync preference).
  void _onConnectionChanged() {
    if (_realtime.status.value == RealtimeStatus.connected) {
      if (_repo.autoSync) _repo.flushPending();
      _repo.refresh(silent: true);
    }
  }

  Future<void> _openSurvey() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SurveyScreen(repository: _repo)),
    );
    if (mounted) _repo.refresh(silent: true);
  }

  Future<void> _logout() async {
    try {
      await api.logout();
    } finally {
      widget.onSignedOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titles = [l10n.navHome, l10n.navSettings];
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        // Tabs do not create routes, so Flutter cannot infer a back button when
        // the user opens Settings from Home. Give that destination an explicit
        // way back while keeping pushed pages (survey/details) on their own
        // normal route back buttons.
        leading: _index == 1
            ? IconButton(
                tooltip: l10n.navHome,
                onPressed: () => setState(() => _index = 0),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: Text(titles[_index]),
        actions: [
          ConnectionBadge(status: _realtime.status),
          const LanguageSelector(compact: true),
          IconButton(
            tooltip: l10n.refreshTooltip,
            onPressed: _repo.loading ? null : () => _repo.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide) ...[
            _DesktopSidebar(
              selectedIndex: _index,
              onSelect: (i) => setState(() => _index = i),
              homeLabel: l10n.navHome,
              settingsLabel: l10n.navSettings,
            ),
          ],
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 1320 : double.infinity),
                child: IndexedStack(
                  index: _index,
                  children: [
                    HomeTab(
                      user: widget.user,
                      repository: _repo,
                      status: _realtime.status,
                      onOpenSurvey: _openSurvey,
                      onOpenHistory: () => setState(() => _index = 1),
                    ),
                    SettingsTab(
                      user: widget.user,
                      repository: _repo,
                      status: _realtime.status,
                      onOpenSurvey: _openSurvey,
                      onSignedOut: _logout,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: CollectFab(
        onPressed: _openSurvey,
        tooltip: l10n.newSurvey,
      ),
      floatingActionButtonLocation: wide
          ? FloatingActionButtonLocation.endFloat
          : FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: wide ? null : FloatingNavBar(
        selectedIndex: _index,
        onSelect: (i) => setState(() => _index = i),
        items: [
          FloatingNavItem(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: l10n.navHome,
          ),
          FloatingNavItem(
            icon: Icons.tune_outlined,
            selectedIcon: Icons.tune_rounded,
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}

/// Stable desktop navigation that keeps destination widgets mounted while
/// changing selection, without NavigationRail's hover/selection animation path.
class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.homeLabel,
    required this.settingsLabel,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String homeLabel;
  final String settingsLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 28),
            child: CircleAvatar(
              radius: 23,
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.agriculture_rounded, color: AppColors.primaryDark),
            ),
          ),
          _SidebarDestination(
            label: homeLabel,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          const SizedBox(height: 8),
          _SidebarDestination(
            label: settingsLabel,
            icon: Icons.tune_outlined,
            selectedIcon: Icons.tune_rounded,
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
        ],
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final color = selected ? AppColors.primaryDark : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: color, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live-connection pill for the app bar.
class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({super.key, required this.status});

  final ValueListenable<RealtimeStatus> status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<RealtimeStatus>(
      valueListenable: status,
      builder: (context, value, _) {
        final (color, icon, label) = switch (value) {
          RealtimeStatus.connected => (
              AppColors.primaryContainer,
              Icons.wifi_rounded,
              l10n.liveConnected
            ),
          RealtimeStatus.connecting => (
              const Color(0xFFFDE68A),
              Icons.wifi_tethering_rounded,
              l10n.liveConnecting
            ),
          RealtimeStatus.disconnected => (
              Colors.white70,
              Icons.wifi_off_rounded,
              l10n.liveOffline
            ),
        };
        return Tooltip(
          message: label,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(icon, size: 20, color: color),
          ),
        );
      },
    );
  }
}
