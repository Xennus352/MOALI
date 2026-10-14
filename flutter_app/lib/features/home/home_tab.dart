import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app/brand/animated_brand_header.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/skeletons.dart';
import '../../core/widgets/summary_tile.dart';
import '../../realtime/realtime_service.dart';
import 'submission_card.dart';
import 'submission_detail.dart';
import 'submission_repository.dart';

/// Home destination: a warm welcome, a personal at-a-glance summary and the
/// live activity feed driven by WebSocket events.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.user,
    required this.repository,
    required this.status,
    required this.onOpenSurvey,
    required this.onOpenHistory,
  });

  final SessionUser user;
  final SubmissionRepository repository;
  final ValueListenable<RealtimeStatus> status;
  final Future<void> Function() onOpenSurvey;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final items = repository.items;
        final feed = items.take(6).toList();
        final summary = repository.summary;
        final syncing = repository.loading;

        return RefreshIndicator(
          onRefresh: () => repository.refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SyncBanner(visible: syncing, label: l10n.syncingSchema),
                      const AnimatedBrandHeader(compact: true, animate: false),
                      const SizedBox(height: 16),
                      _WelcomeCard(user: user),
                      const SizedBox(height: 20),
                      Text(l10n.personalSummary, style: AppTextStyles.titleSmall),
                      const SizedBox(height: 12),
                      _SummaryGrid(
                        tiles: [
                          SummaryTile(
                            icon: Icons.assignment_outlined,
                            label: l10n.statTotalSubmissions,
                            value: formatInt(summary['total']),
                          ),
                          SummaryTile(
                            icon: Icons.today_outlined,
                            label: l10n.statToday,
                            value: formatInt(summary['today']),
                            color: AppColors.info,
                          ),
                          SummaryTile(
                            icon: Icons.cloud_upload_outlined,
                            label: l10n.tagPending,
                            value: formatInt(summary['pending']),
                            color: AppColors.statusPending,
                          ),
                          SummaryTile(
                            icon: Icons.podcasts_rounded,
                            label: l10n.tagLive,
                            value: formatInt(summary['live']),
                            color: AppColors.statusLive,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AppPrimaryButton(
                        label: l10n.newSurvey,
                        icon: Icons.edit_document,
                        onPressed: onOpenSurvey,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Text(l10n.liveFeedTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleSmall),
                          ),
                          Flexible(
                            child: TextButton(
                              onPressed: onOpenHistory,
                              child: Text(l10n.historyTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (repository.loading && items.isEmpty)
                        const SubmissionSkeletonList(count: 3)
                      else if (feed.isEmpty)
                        InfoCard(
                          icon: Icons.inbox_outlined,
                          child: Text(l10n.noActivityYet,
                              style: AppTextStyles.supporting),
                        )
                      else
                        for (final sub in feed)
                          RepaintBoundary(
                            child: SubmissionCard(
                              submission: sub,
                              heroTag: 'sub-${sub['id']}',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SubmissionDetailScreen(submission: sub),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Thin animated strip shown while a foreground refresh is in flight, so the
/// enumerator can see *what* the app is doing ("Syncing live schema…") rather
/// than staring at a silent screen.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.visible, required this.label});

  final bool visible;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: visible
            ? Padding(
                key: const ValueKey('syncing'),
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const _SpinningSync(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(label,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.primaryDark)),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('idle')),
      ),
    );
  }
}

class _SpinningSync extends StatefulWidget {
  const _SpinningSync();

  @override
  State<_SpinningSync> createState() => _SpinningSyncState();
}

class _SpinningSyncState extends State<_SpinningSync>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion && !_spin.isAnimating) {
      _spin.repeat();
    } else if (reduceMotion && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final icon = Icon(Icons.sync_rounded, size: 18, color: AppColors.primary);
    if (reduceMotion) return icon;
    return RotationTransition(turns: _spin, child: icon);
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.slate],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.raised(blur: 22, y: 10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.30),
            child: const Icon(Icons.person_outline,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.welcomeUser(user.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.titleMedium.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.email} · ${l10n.roleLabel(user.role)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive summary grid.
///
/// Uses [IntrinsicHeight] rows rather than a fixed-extent [GridView] so a tile
/// is exactly as tall as its tallest neighbour. That removes the
/// `BOTTOM OVERFLOWED BY 1.00 PIXELS` class of bug entirely, even when the user
/// turns the system text size up.
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += columns) {
          final rowTiles = <Widget>[];
          for (var c = 0; c < columns; c++) {
            final index = i + c;
            if (index >= tiles.length) {
              rowTiles.add(const Expanded(child: SizedBox.shrink()));
            } else {
              rowTiles.add(Expanded(child: tiles[index]));
            }
            if (c != columns - 1) rowTiles.add(const SizedBox(width: 12));
          }
          if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
          rows.add(IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rowTiles,
            ),
          ));
        }
        return Column(children: rows);
      },
    );
  }
}
