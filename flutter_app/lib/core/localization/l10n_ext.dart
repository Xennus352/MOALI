import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

/// Convenience accessors so widgets can read localized strings, the active
/// language, and the language-appropriate name of a master-data row without
/// importing the generated class everywhere.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  bool get isMyanmar => Localizations.localeOf(this).languageCode == 'my';

  /// Pick the Burmese or English name from a master-data / geography row
  /// according to the active language, falling back to whichever value exists,
  /// then to the code, then to an em dash.
  String masterName(Map<String, dynamic> row) {
    final burmese = (row['burmese_name'] as String?)?.trim();
    final english = (row['english_name'] as String?)?.trim();
    final code = (row['code'] as String?)?.trim();
    final hasBurmese = burmese != null && burmese.isNotEmpty;
    final hasEnglish = english != null && english.isNotEmpty;
    if (isMyanmar) {
      if (hasBurmese) return burmese;
      if (hasEnglish) return english;
    } else {
      if (hasEnglish) return english;
      if (hasBurmese) return burmese;
    }
    return (code != null && code.isNotEmpty) ? code : '—';
  }

  /// Human-readable label for a submission `collection_status` value.
  String statusLabel(String status) {
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      case 'approved':
        return l10n.statusApproved;
      case 'rejected':
        return l10n.statusRejected;
      case 'returned':
        return l10n.statusReturned;
      case 'under_review':
      case 'in_review':
        return l10n.statusUnderReview;
      case 'reopened':
        return l10n.statusReopened;
      case 'submitted':
        return l10n.statusSubmitted;
      case 'pending':
        return l10n.statusPending;
      default:
        return status.isEmpty ? l10n.statusUnknown : status;
    }
  }
}
