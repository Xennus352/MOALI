import '../../api/api_client.dart';
import '../../l10n/generated/app_localizations.dart';

/// Turn an [ApiException] into a friendly, localized message.
///
/// The backend returns English `detail` strings; we intercept the common
/// status codes with curated wording in the user's language and fall back to the
/// server message for anything we do not specifically recognise.
String localizeApiError(
  AppLocalizations l10n,
  ApiException error, {
  bool registering = false,
}) {
  if (error.statusCode == 0) return l10n.errorNetwork;
  final detail = error.message.trim();
  switch (error.statusCode) {
    case 401:
      return l10n.errorIncorrectCredentials;
    case 403:
      return detail.isNotEmpty ? detail : l10n.errorAccountDisabled;
    case 409:
      if (registering) return l10n.errorEmailRegistered;
      return detail.isNotEmpty ? detail : l10n.errorServer;
    case 429:
      return l10n.errorTooManyAttempts;
    case 422:
      return detail.isNotEmpty ? detail : l10n.errorServer;
    default:
      if (error.statusCode >= 500) return l10n.errorServer;
      return detail.isNotEmpty ? detail : l10n.errorServer;
  }
}
