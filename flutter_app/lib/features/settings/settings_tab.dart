import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app/brand/animated_brand_header.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/language_selector.dart';
import '../../core/widgets/skeletons.dart';
import '../../realtime/realtime_service.dart';
import '../home/submission_card.dart';
import '../home/submission_detail.dart';
import '../home/submission_repository.dart';

/// Settings destination: the signed-in user's account, their **own** survey
/// history, the offline upload queue, the language switch and system details.
///
/// Everything that used to be spread across a separate "Collect" and "History"
/// tab now lives here, so the floating bar can stay a clean two-stop navigation
/// with the "Collect census" FAB in the middle.
///
/// All history data comes from [SubmissionRepository], which queries the backend
/// with `mine=true`: a standard enumerator can never see another user's rows.
class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.user,
    required this.repository,
    required this.status,
    required this.onOpenSurvey,
    required this.onSignedOut,
  });

  final SessionUser user;
  final SubmissionRepository repository;
  final ValueListenable<RealtimeStatus> status;
  final Future<void> Function() onOpenSurvey;
  final Future<void> Function() onSignedOut;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _uploading = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;

  Future<void> _uploadAll() async {
    final repo = widget.repository;
    if (_uploading || repo.pendingCount == 0) return;
    setState(() {
      _uploading = true;
      _uploadDone = 0;
      _uploadTotal = repo.pendingCount;
    });
    final uploaded = await repo.flushPending(onProgress: (done, total) {
      if (mounted) setState(() => _uploadDone = done);
    });
    if (!mounted) return;
    setState(() => _uploading = false);
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(uploaded == 0 ? l10n.syncPartial : l10n.syncCompleted),
        backgroundColor: uploaded == 0 ? AppColors.warning : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final items = widget.repository.items;
        return RefreshIndicator(
          onRefresh: () => widget.repository.refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              const AnimatedBrandHeader(compact: true, animate: false),
              const SizedBox(height: 16),
              _AccountCard(user: widget.user),
              const SizedBox(height: 16),
              const _LanguageCard(),
              const SizedBox(height: 16),
              _OfflineManagerCard(
                repository: widget.repository,
                uploading: _uploading,
                done: _uploadDone,
                total: _uploadTotal,
                onUploadAll: _uploadAll,
              ),
              const SizedBox(height: 26),
              _SectionHeading(
                icon: Icons.history_rounded,
                title: l10n.personalHistorySection,
                subtitle: l10n.personalHistorySubtitle,
                trailing: items.isEmpty ? null : '${items.length}',
              ),
              const SizedBox(height: 12),
              if (widget.repository.showingCachedData) ...[
                InfoCard(
                  icon: Icons.cloud_off_outlined,
                  color: AppColors.warningSurface,
                  child: Text(l10n.offlineCachedHint,
                      style: AppTextStyles.supporting),
                ),
                const SizedBox(height: 14),
              ],
              if (widget.repository.loading && items.isEmpty)
                const SubmissionSkeletonList(count: 4)
              else if (items.isEmpty)
                _EmptyHistory(onOpenSurvey: widget.onOpenSurvey)
              else
                for (final sub in items)
                  RepaintBoundary(
                    child: SubmissionCard(
                      submission: sub,
                      heroTag: 'settings-sub-${sub['id']}',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SubmissionDetailScreen(submission: sub),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
              _SystemCard(status: widget.status, user: widget.user),
              const SizedBox(height: 16),
              AppSecondaryButton(
                label: l10n.logOut,
                icon: Icons.logout,
                onPressed: widget.onSignedOut,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final SessionUser user;

  String get _initials {
    final source = user.name.trim().isNotEmpty ? user.name : user.email;
    final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String s) => s.isEmpty ? '' : s.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first(parts.first);
    return first(parts.first) + first(parts.last);
  }

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
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.raised(blur: 22, y: 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                child: Text(
                  _initials,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: Colors.white, fontSize: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium
                          .copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                label: l10n.roleLabel(user.role),
                icon: Icons.badge_outlined,
              ),
              _Pill(
                label: l10n.statusTagActive,
                icon: Icons.verified_rounded,
                color: AppColors.primaryLight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, this.color = Colors.white});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption
                .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SectionCard(
      title: l10n.language,
      icon: Icons.translate_rounded,
      child: LanguageSelector(),
    );
  }
}

class _OfflineManagerCard extends StatelessWidget {
  const _OfflineManagerCard({
    required this.repository,
    required this.uploading,
    required this.done,
    required this.total,
    required this.onUploadAll,
  });

  final SubmissionRepository repository;
  final bool uploading;
  final int done;
  final int total;
  final Future<void> Function() onUploadAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pending = repository.pendingCount;
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return SectionCard(
      title: l10n.uploadQueueTitle,
      icon: pending > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
      accent: pending > 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.autoSyncTitle, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 2),
                    Text(l10n.autoSyncSubtitle,
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: repository.autoSync,
                onChanged: (v) => repository.setAutoSync(v),
              ),
            ],
          ),
          const Divider(height: 28),
          Text(
            pending == 0 ? l10n.uploadQueueEmpty : l10n.queuedCount(pending),
            style: AppTextStyles.supporting,
          ),
          if (uploading) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.uploadProgress(done, total),
                style: AppTextStyles.caption),
          ],
          const SizedBox(height: 14),
          AppSecondaryButton(
            label: l10n.uploadAllOffline,
            icon: Icons.cloud_sync_outlined,
            height: 52,
            onPressed: pending == 0 || uploading ? null : onUploadAll,
          ),
        ],
      ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({required this.status, required this.user});

  final ValueListenable<RealtimeStatus> status;
  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SectionCard(
      title: l10n.systemConfig,
      icon: Icons.settings_suggest_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<RealtimeStatus>(
            valueListenable: status,
            builder: (context, value, _) {
              final (color, label) = switch (value) {
                RealtimeStatus.connected => (AppColors.success, l10n.liveConnected),
                RealtimeStatus.connecting => (AppColors.warning, l10n.liveConnecting),
                RealtimeStatus.disconnected => (AppColors.textMuted, l10n.liveOffline),
              };
              return _InfoRow(
                icon: Icons.wifi_rounded,
                iconColor: color,
                label: l10n.connectionStatusLabel,
                value: label,
                valueColor: color,
              );
            },
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.dns_outlined,
            iconColor: AppColors.textMuted,
            label: l10n.apiEndpointLabel,
            value: api.baseUrl,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.person_outline,
            iconColor: AppColors.textMuted,
            label: l10n.fullNameLabel,
            value: user.email,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: valueColor ?? AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.titleSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTextStyles.caption),
              ],
            ],
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(trailing!,
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.primaryDark)),
          ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onOpenSurvey});

  final Future<void> Function() onOpenSurvey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: AppColors.raised(blur: 20, y: 10),
            ),
            child: const Icon(Icons.inbox_outlined,
                size: 40, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          Text(l10n.noActivityYet,
              textAlign: TextAlign.center,
              style: AppTextStyles.supporting),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: l10n.newSurvey,
            icon: Icons.edit_document,
            onPressed: onOpenSurvey,
          ),
        ],
      ),
    );
  }
}
