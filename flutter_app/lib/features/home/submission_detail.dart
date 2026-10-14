import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/widgets/app_card.dart';
import 'submission_card.dart';

/// Read-only detail for a submission the enumerator created. The leading icon
/// is shared with the list via a [Hero], giving the tap a smooth transition.
class SubmissionDetailScreen extends StatelessWidget {
  const SubmissionDetailScreen({super.key, required this.submission});

  final Map<String, dynamic> submission;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = '${submission['collection_status'] ?? ''}';
    final rows = <(IconData, String, String)>[
      (Icons.home_outlined, l10n.statHouseholds,
          '${submission['household_no'] ?? '—'}'),
      (Icons.person_outline, l10n.personSectionRespondent,
          '${submission['respondent_name_burmese'] ?? l10n.notProvided}'),
      (Icons.event_outlined, l10n.labelInterviewDate,
          '${submission['interview_date'] ?? '—'}'),
      (Icons.map_outlined, l10n.labelLocation,
          [
            submission['township'],
            submission['state_region'],
          ].where((e) => e != null && '$e'.isNotEmpty).join(', ')),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.submissionDetailTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          Center(
            child: Hero(
              tag: 'sub-${submission['id']}',
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.raised(blur: 22, y: 10),
                ),
                child: Icon(Icons.description_outlined,
                    size: 44, color: AppColors.statusColor(status)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(child: StatusTag(status: status)),
          const SizedBox(height: 22),
          SectionCard(
            title: l10n.householdLabel('${submission['household_no'] ?? '—'}'),
            icon: Icons.receipt_long_outlined,
            child: Column(
              children: [
                for (final (icon, label, value) in rows)
                  if (value.trim().isNotEmpty && value != '—')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 20, color: AppColors.textMuted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: AppTextStyles.caption),
                                const SizedBox(height: 2),
                                Text(value, style: AppTextStyles.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                if (submission['_local'] == true)
                  InfoCard(
                    icon: Icons.cloud_upload_outlined,
                    color: AppColors.warningSurface,
                    child: Text(l10n.waitingToUpload,
                        style: AppTextStyles.supporting),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
