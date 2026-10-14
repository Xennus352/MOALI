import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../localization/locale_controller.dart';
import '../../l10n/generated/app_localizations.dart';

/// Compact, accessible language switch showing the two actual language names
/// (Myanmar / English) rather than flags. Changing it applies immediately and is
/// persisted by [LocaleController].
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key, this.compact = false});

  /// When [compact] the control is a small popup button (used in app bars);
  /// otherwise it is a full-width segmented control (used on the login screen).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = LocaleScope.of(context);
    final l10n = AppLocalizations.of(context);
    final code = controller.value.languageCode;

    if (compact) {
      return PopupMenuButton<String>(
        tooltip: l10n.language,
        initialValue: code,
        onSelected: controller.setLanguageCode,
        itemBuilder: (context) => [
          _menuItem(LocaleController.languageCodeMyanmar, l10n.languageMyanmar),
          _menuItem(LocaleController.languageCodeEnglish, l10n.languageEnglish),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, size: 22),
              const SizedBox(width: 6),
              Text(
                code == LocaleController.languageCodeMyanmar ? 'မြန်မာ' : 'EN',
                style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.language, color: AppColors.textSecondary),
          ),
          Expanded(
            child: SegmentedButton<String>(
              showSelectedIcon: true,
              segments: [
                ButtonSegment(
                  value: LocaleController.languageCodeMyanmar,
                  label: Text(l10n.languageMyanmar),
                ),
                ButtonSegment(
                  value: LocaleController.languageCodeEnglish,
                  label: Text(l10n.languageEnglish),
                ),
              ],
              selected: {code},
              onSelectionChanged: (selection) =>
                  controller.setLanguageCode(selection.first),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label) => PopupMenuItem(
        value: value,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(label, style: AppTextStyles.input),
        ),
      );
}
