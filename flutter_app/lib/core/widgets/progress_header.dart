import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// Sticky header at the top of the census form. Shows the form title, the
/// current section, "Step X of Y", a smooth progress bar and a short instruction
/// so an older user always knows where they are and what to do next.
class FormProgressHeader extends StatelessWidget {
  const FormProgressHeader({
    super.key,
    required this.formTitle,
    required this.sectionTitle,
    required this.step,
    required this.total,
    required this.instruction,
  });

  final String formTitle;
  final String sectionTitle;
  final int step;
  final int total;
  final String instruction;

  @override
  Widget build(BuildContext context) {
    final clamped = step.clamp(1, total);
    final value = total == 0 ? 0.0 : clamped / total;
    final l10nStep = '$clamped / $total';
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10nStep,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                child: Text(
                  sectionTitle,
                  key: ValueKey(sectionTitle),
                  style: AppTextStyles.headlineSmall,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 4,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(instruction, style: AppTextStyles.supporting),
                  ),
                ],
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}
