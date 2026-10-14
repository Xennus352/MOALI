// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appShortName => 'Livestock Census';

  @override
  String get appTitle => 'MOALI Livestock Census';

  @override
  String get appOrganisation =>
      'Ministry of Agriculture, Livestock and Irrigation';

  @override
  String get language => 'Language';

  @override
  String get languageMyanmar => 'မြန်မာ (Myanmar)';

  @override
  String get languageEnglish => 'English';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Try again';

  @override
  String get close => 'Close';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get edit => 'Edit';

  @override
  String get back => 'Back';

  @override
  String get save => 'Save';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Sign in to collect household livestock data.';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubtitle => 'Register to start collecting census data.';

  @override
  String get emailLabel => 'Email address';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHintLogin => 'Enter your password';

  @override
  String get passwordHintRegister => 'At least 8 characters';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get fullNameHint => 'Optional';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get loginButton => 'Sign in';

  @override
  String get registerButton => 'Create account';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get creatingAccount => 'Creating account…';

  @override
  String get switchToRegister => 'I don\'t have an account';

  @override
  String get switchToLogin => 'I already have an account — sign in';

  @override
  String get termsNotice =>
      'By continuing you agree to the terms of use of this government service.';

  @override
  String get secureNotice => 'Official government application';

  @override
  String get emailRequiredError => 'Please enter your email address.';

  @override
  String get emailInvalidError => 'Please enter a valid email address.';

  @override
  String get passwordRequiredError => 'Please enter your password.';

  @override
  String get passwordTooShortError => 'Password must be at least 8 characters.';

  @override
  String get nameRequiredError => 'Please enter your name.';

  @override
  String welcomeUser(String name) {
    return 'Welcome, $name';
  }

  @override
  String get sessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorIncorrectCredentials => 'Incorrect email or password.';

  @override
  String get errorAccountDisabled =>
      'This account is disabled. Please contact an administrator.';

  @override
  String get errorEmailRegistered =>
      'This email is already registered. Try signing in instead.';

  @override
  String get errorTooManyAttempts =>
      'Too many failed attempts. Please wait a moment and try again.';

  @override
  String get errorNetwork =>
      'Cannot reach the server. Check your connection and try again.';

  @override
  String get errorServer =>
      'Something went wrong on the server. Please try again.';

  @override
  String get errorUnexpected =>
      'An unexpected error occurred. Please try again.';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get overview => 'Overview';

  @override
  String get statTotalSubmissions => 'Total submissions';

  @override
  String get statToday => 'Today';

  @override
  String get statPendingReview => 'Pending review';

  @override
  String get statApproved => 'Approved';

  @override
  String get statAnimalsRecorded => 'Animals recorded';

  @override
  String get statHouseholds => 'Households';

  @override
  String get recentSubmissions => 'Recent submissions';

  @override
  String get noSubmissionsYet =>
      'No submissions yet. Tap “Collect census” to begin.';

  @override
  String get newSurvey => 'Collect census';

  @override
  String get historyTitle => 'Submission history';

  @override
  String get logOut => 'Sign out';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get liveConnected => 'Live updates connected';

  @override
  String get liveConnecting => 'Connecting to live updates…';

  @override
  String get liveOffline => 'Live updates offline';

  @override
  String get unableToLoad => 'Could not load data';

  @override
  String get noSubmissionsFound => 'No submissions found.';

  @override
  String householdLabel(String number) {
    return 'Household $number';
  }

  @override
  String dateLabel(String date) {
    return 'Date: $date';
  }

  @override
  String roleLabel(String role) {
    return 'Role: $role';
  }

  @override
  String get censusTitle => 'Census collection';

  @override
  String stepOfTotal(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get reviewStepName => 'Review';

  @override
  String get stepHint =>
      'Fill in the fields below. Fields marked * are required.';

  @override
  String get previousButton => 'Previous';

  @override
  String get nextButton => 'Next step';

  @override
  String get reviewAndSubmitButton => 'Review & submit';

  @override
  String get draftSaved => 'Draft saved automatically';

  @override
  String get discardDraftTooltip => 'Discard draft';

  @override
  String get discardDraftTitle => 'Discard this draft?';

  @override
  String get discardDraftBody =>
      'Unsaved data for this census will be permanently deleted.';

  @override
  String get discardConfirmButton => 'Discard';

  @override
  String get submitButton => 'Submit census';

  @override
  String get submitting => 'Submitting…';

  @override
  String get submissionConfirmedTitle => 'Census submitted successfully';

  @override
  String get submissionConfirmedBody =>
      'The census has been sent to the official management system.';

  @override
  String get submissionQueuedTitle =>
      'Saved offline — will upload automatically';

  @override
  String get submissionQueuedBody =>
      'You are offline, so this census has been stored on your device. It will upload by itself as soon as the connection returns.';

  @override
  String submissionHouseholdNo(String number) {
    return 'Household number: $number';
  }

  @override
  String submissionReference(String id) {
    return 'Submission reference: $id';
  }

  @override
  String get backToDashboard => 'Back to dashboard';

  @override
  String submissionFailed(String message) {
    return 'Submission failed: $message';
  }

  @override
  String get validationTitle => 'Please complete these fields';

  @override
  String validationRequired(String field) {
    return '$field is required';
  }

  @override
  String get validationIntro =>
      'Please correct the highlighted items before continuing.';

  @override
  String get formLoadFailed => 'Could not load the census form';

  @override
  String get formLoadFailedHint => 'Check your connection and try again.';

  @override
  String get connectionErrorTitle => 'Cannot reach the server';

  @override
  String get connectionErrorHint => 'Please check the network and try again.';

  @override
  String apiEndpoint(String url) {
    return 'Server: $url';
  }

  @override
  String get duplicateTitle => 'Household already recorded';

  @override
  String get duplicateBody =>
      'A submission for this household, township and interview date already exists.\n\nIf you intentionally want to record it again, tap “Submit anyway”.';

  @override
  String get duplicateCancel => 'Do not submit';

  @override
  String get duplicateResubmit => 'Submit anyway';

  @override
  String get personSectionRespondent => 'Respondent';

  @override
  String get personSectionHead => 'Household head';

  @override
  String get personSectionInterviewer => 'Interviewer';

  @override
  String get ageGroupLabel => 'Age group';

  @override
  String get unsupportedField => 'This field is not supported in the app yet';

  @override
  String get unsupportedGroup =>
      'This table type is not supported in the app yet';

  @override
  String get animalCategoryLabel => 'Category / breed';

  @override
  String get speciesLabel => 'Species';

  @override
  String get ageGroupLabelShort => 'Age group';

  @override
  String get maleLabel => 'Male';

  @override
  String get castratedLabel => 'Castrated';

  @override
  String get femaleLabel => 'Female';

  @override
  String rowTotalLabel(int total) {
    return 'Total: $total';
  }

  @override
  String get addRowButton => 'Add row';

  @override
  String get removeRowTooltip => 'Remove this row';

  @override
  String get emptyRowsHint => 'Tap “Add row” to enter the animal counts.';

  @override
  String get noCategoriesAvailable =>
      'No categories are available for this table yet.';

  @override
  String get selectPrompt => '— Select —';

  @override
  String rowNumber(int number) {
    return 'Row $number';
  }

  @override
  String get boolYes => 'Yes';

  @override
  String get boolNo => 'No';

  @override
  String get pickDateHelp => 'Select a date';

  @override
  String get reviewTitle => 'Review answers';

  @override
  String get reviewSubtitle => 'Check the answers below before submitting.';

  @override
  String get reviewHouseholdCard => 'Household & interview';

  @override
  String reviewInterviewDate(String date) {
    return 'Interview date: $date';
  }

  @override
  String reviewAnimalRecords(int count) {
    return 'Animal counts recorded: $count';
  }

  @override
  String reviewBreedingRecords(int count) {
    return 'Breeding records: $count';
  }

  @override
  String reviewAdditionalFields(int count) {
    return 'Additional fields: $count';
  }

  @override
  String get reviewReady =>
      'Everything looks complete. You can submit the census.';

  @override
  String get reviewIncompleteTitle => 'Some required answers are missing';

  @override
  String get reviewEditSection => 'Go to section';

  @override
  String get statusUnknown => 'unknown';

  @override
  String get statusApproved => 'approved';

  @override
  String get statusRejected => 'rejected';

  @override
  String get statusReturned => 'returned';

  @override
  String get statusUnderReview => 'under review';

  @override
  String get statusSubmitted => 'submitted';

  @override
  String get statusPending => 'pending';

  @override
  String get statusReopened => 'reopened';

  @override
  String get selectUpperLevelFirst => 'Select the level above first';

  @override
  String get noOptionsAvailable => 'No options available yet';

  @override
  String get fieldOptional => 'Optional';

  @override
  String get notProvided => 'Not provided';

  @override
  String get draftRestored => 'Your previous draft was restored.';

  @override
  String sectionLabel(int number) {
    return 'Section $number';
  }

  @override
  String rowsCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows added',
      one: '1 row added',
      zero: 'No rows added',
    );
    return '$_temp0';
  }

  @override
  String get navHome => 'Home';

  @override
  String get navCollect => 'Collect';

  @override
  String get navHistory => 'History';

  @override
  String get personalSummary => 'Your summary';

  @override
  String get liveFeedTitle => 'Live activity';

  @override
  String get noActivityYet =>
      'No activity yet. Captured census records will appear here.';

  @override
  String get offlineCachedHint => 'Showing saved data — you are offline.';

  @override
  String get tagPending => 'Pending';

  @override
  String get tagSynced => 'Synced';

  @override
  String get tagLive => 'Live';

  @override
  String get waitingToUpload => 'Waiting to upload';

  @override
  String get submissionDetailTitle => 'Submission details';

  @override
  String get labelInterviewDate => 'Interview date';

  @override
  String get labelLocation => 'Location';

  @override
  String get collectHint =>
      'Capture the census for one household at a time. Your answers are saved automatically and can be submitted even when the network is weak or missing.';

  @override
  String get accountSection => 'Account';

  @override
  String get uploadQueueTitle => 'Offline uploads';

  @override
  String get uploadQueueEmpty =>
      'All your captured surveys have been uploaded.';

  @override
  String queuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count surveys waiting to upload',
      one: '1 survey waiting to upload',
    );
    return '$_temp0';
  }

  @override
  String get syncingNow => 'Syncing…';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncCompleted => 'All queued surveys have been uploaded.';

  @override
  String get syncPartial =>
      'Some surveys could not be uploaded yet. They will retry automatically.';

  @override
  String get signInWithGoogle => 'Continue with Google';

  @override
  String get orDivider => 'or';

  @override
  String get googleUnavailable =>
      'Google sign-in is not enabled on this server. Please sign in with your email and password.';

  @override
  String get googleSignInFailed =>
      'Google sign-in could not be completed. Please try again.';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get navSettings => 'Settings';

  @override
  String get syncingSchema => 'Syncing live schema…';

  @override
  String get statusTagActive => 'Active';

  @override
  String get personalHistorySection => 'Personal survey history';

  @override
  String get personalHistorySubtitle =>
      'Only census records captured by your own account are shown here.';

  @override
  String get systemConfig => 'System configuration';

  @override
  String get connectionStatusLabel => 'Live connection';

  @override
  String get autoSyncTitle => 'Auto-sync when online';

  @override
  String get autoSyncSubtitle =>
      'Queued surveys upload by themselves once the connection returns.';

  @override
  String get uploadAllOffline => 'Upload all offline drafts';

  @override
  String uploadProgress(int done, int total) {
    return 'Uploading $done of $total…';
  }

  @override
  String get apiEndpointLabel => 'Server address';

  @override
  String get phoneInvalidError =>
      'Enter a valid Myanmar phone number, e.g. 09xxxxxxxxx.';
}
