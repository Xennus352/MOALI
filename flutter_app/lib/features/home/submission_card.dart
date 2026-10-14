import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/widgets/feedback.dart';
import 'submission_repository.dart';

/// Group digits with thousands separators (locale-independent so the figures
/// stay legible in both Myanmar and English).
String formatInt(Object? value) {
  final n = value is int ? value : int.tryParse('$value') ?? 0;
  final digits = n.abs().toString();
  final buffer = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Colours for the three user-facing states.
({Color color, IconData icon}) _tagStyle(String tag) => switch (tag) {
      'live' => (color: AppColors.statusLive, icon: Icons.podcasts_rounded),
      'pending' => (color: AppColors.statusPending, icon: Icons.schedule_rounded),
      _ => (color: AppColors.statusSynced, icon: Icons.cloud_done_rounded),
    };

String _tagLabel(BuildContext context, String tag) => switch (tag) {
      'live' => context.l10n.tagLive,
      'pending' => context.l10n.tagPending,
      _ => context.l10n.tagSynced,
    };

/// Compact status pill used in the feed and history.
class StatusTag extends StatelessWidget {
  const StatusTag({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tag = SubmissionRepository.statusTag(status);
    final style = _tagStyle(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 5),
          Text(
            _tagLabel(context, tag),
            style: AppTextStyles.caption
                .copyWith(color: style.color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Soft-UI card representing one submission in the feed or history.
class SubmissionCard extends StatelessWidget {
  const SubmissionCard({
    super.key,
    required this.submission,
    this.onTap,
    this.heroTag,
  });

  final Map<String, dynamic> submission;
  final VoidCallback? onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = '${submission['collection_status'] ?? ''}';
    final tag = SubmissionRepository.statusTag(status);
    final color = _tagStyle(tag).color;
    final isLocal = submission['_local'] == true;
    final subtitle = [
      submission['respondent_name_burmese'],
      submission['township'],
      submission['state_region'],
    ].where((e) => e != null && '$e'.isNotEmpty).join(' · ');

    final icon = Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isLocal ? Icons.cloud_upload_outlined : Icons.description_outlined,
        color: color,
        size: 22,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        onTap: onTap,
        semanticLabel: l10n.householdLabel('${submission['household_no'] ?? ''}'),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.raised(blur: 18, y: 8),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heroTag != null
                  ? Hero(tag: heroTag!, child: icon)
                  : icon,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.householdLabel(
                          '${submission['household_no'] ?? '—'}'),
                      style: AppTextStyles.titleSmall,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: AppTextStyles.bodySmall),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.event_outlined,
                            size: 15, color: AppColors.textMuted),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${submission['interview_date'] ?? '—'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ),
                        if (isLocal) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              l10n.waitingToUpload,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.statusPending),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusTag(status: status),
            ],
          ),
        ),
      ),
    );
  }
}
