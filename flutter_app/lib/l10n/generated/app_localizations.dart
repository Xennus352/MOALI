import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_my.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('my'),
  ];

  /// No description provided for @appShortName.
  ///
  /// In en, this message translates to:
  /// **'Livestock Census'**
  String get appShortName;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MOALI Livestock Census'**
  String get appTitle;

  /// No description provided for @appOrganisation.
  ///
  /// In en, this message translates to:
  /// **'Ministry of Agriculture, Livestock and Irrigation'**
  String get appOrganisation;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageMyanmar.
  ///
  /// In en, this message translates to:
  /// **'မြန်မာ (Myanmar)'**
  String get languageMyanmar;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to collect household livestock data.'**
  String get loginSubtitle;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Register to start collecting census data.'**
  String get registerSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHintLogin.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHintLogin;

  /// No description provided for @passwordHintRegister.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHintRegister;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameLabel;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get fullNameHint;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginButton;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerButton;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account…'**
  String get creatingAccount;

  /// No description provided for @switchToRegister.
  ///
  /// In en, this message translates to:
  /// **'I don\'t have an account'**
  String get switchToRegister;

  /// No description provided for @switchToLogin.
  ///
  /// In en, this message translates to:
  /// **'I already have an account — sign in'**
  String get switchToLogin;

  /// No description provided for @termsNotice.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to the terms of use of this government service.'**
  String get termsNotice;

  /// No description provided for @secureNotice.
  ///
  /// In en, this message translates to:
  /// **'Official government application'**
  String get secureNotice;

  /// No description provided for @emailRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get emailRequiredError;

  /// No description provided for @emailInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get emailInvalidError;

  /// No description provided for @passwordRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get passwordRequiredError;

  /// No description provided for @passwordTooShortError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get passwordTooShortError;

  /// No description provided for @nameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get nameRequiredError;

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcomeUser(String name);

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get sessionExpired;

  /// No description provided for @errorIncorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get errorIncorrectCredentials;

  /// No description provided for @errorAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account is disabled. Please contact an administrator.'**
  String get errorAccountDisabled;

  /// No description provided for @errorEmailRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Try signing in instead.'**
  String get errorEmailRegistered;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please wait a moment and try again.'**
  String get errorTooManyAttempts;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on the server. Please try again.'**
  String get errorServer;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errorUnexpected;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @statTotalSubmissions.
  ///
  /// In en, this message translates to:
  /// **'Total submissions'**
  String get statTotalSubmissions;

  /// No description provided for @statToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statToday;

  /// No description provided for @statPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get statPendingReview;

  /// No description provided for @statApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get statApproved;

  /// No description provided for @statAnimalsRecorded.
  ///
  /// In en, this message translates to:
  /// **'Animals recorded'**
  String get statAnimalsRecorded;

  /// No description provided for @statHouseholds.
  ///
  /// In en, this message translates to:
  /// **'Households'**
  String get statHouseholds;

  /// No description provided for @recentSubmissions.
  ///
  /// In en, this message translates to:
  /// **'Recent submissions'**
  String get recentSubmissions;

  /// No description provided for @noSubmissionsYet.
  ///
  /// In en, this message translates to:
  /// **'No submissions yet. Tap “Collect census” to begin.'**
  String get noSubmissionsYet;

  /// No description provided for @newSurvey.
  ///
  /// In en, this message translates to:
  /// **'Collect census'**
  String get newSurvey;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Submission history'**
  String get historyTitle;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logOut;

  /// No description provided for @refreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// No description provided for @liveConnected.
  ///
  /// In en, this message translates to:
  /// **'Live updates connected'**
  String get liveConnected;

  /// No description provided for @liveConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to live updates…'**
  String get liveConnecting;

  /// No description provided for @liveOffline.
  ///
  /// In en, this message translates to:
  /// **'Live updates offline'**
  String get liveOffline;

  /// No description provided for @unableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load data'**
  String get unableToLoad;

  /// No description provided for @noSubmissionsFound.
  ///
  /// In en, this message translates to:
  /// **'No submissions found.'**
  String get noSubmissionsFound;

  /// No description provided for @householdLabel.
  ///
  /// In en, this message translates to:
  /// **'Household {number}'**
  String householdLabel(String number);

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String dateLabel(String date);

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}'**
  String roleLabel(String role);

  /// No description provided for @censusTitle.
  ///
  /// In en, this message translates to:
  /// **'Census collection'**
  String get censusTitle;

  /// No description provided for @stepOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepOfTotal(int step, int total);

  /// No description provided for @reviewStepName.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewStepName;

  /// No description provided for @stepHint.
  ///
  /// In en, this message translates to:
  /// **'Fill in the fields below. Fields marked * are required.'**
  String get stepHint;

  /// No description provided for @previousButton.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousButton;

  /// No description provided for @nextButton.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get nextButton;

  /// No description provided for @reviewAndSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Review & submit'**
  String get reviewAndSubmitButton;

  /// No description provided for @draftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved automatically'**
  String get draftSaved;

  /// No description provided for @discardDraftTooltip.
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get discardDraftTooltip;

  /// No description provided for @discardDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this draft?'**
  String get discardDraftTitle;

  /// No description provided for @discardDraftBody.
  ///
  /// In en, this message translates to:
  /// **'Unsaved data for this census will be permanently deleted.'**
  String get discardDraftBody;

  /// No description provided for @discardConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardConfirmButton;

  /// No description provided for @submitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit census'**
  String get submitButton;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get submitting;

  /// No description provided for @submissionConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Census submitted successfully'**
  String get submissionConfirmedTitle;

  /// No description provided for @submissionConfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'The census has been sent to the official management system.'**
  String get submissionConfirmedBody;

  /// No description provided for @submissionQueuedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved offline — will upload automatically'**
  String get submissionQueuedTitle;

  /// No description provided for @submissionQueuedBody.
  ///
  /// In en, this message translates to:
  /// **'You are offline, so this census has been stored on your device. It will upload by itself as soon as the connection returns.'**
  String get submissionQueuedBody;

  /// No description provided for @submissionHouseholdNo.
  ///
  /// In en, this message translates to:
  /// **'Household number: {number}'**
  String submissionHouseholdNo(String number);

  /// No description provided for @submissionReference.
  ///
  /// In en, this message translates to:
  /// **'Submission reference: {id}'**
  String submissionReference(String id);

  /// No description provided for @backToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to dashboard'**
  String get backToDashboard;

  /// No description provided for @submissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Submission failed: {message}'**
  String submissionFailed(String message);

  /// No description provided for @validationTitle.
  ///
  /// In en, this message translates to:
  /// **'Please complete these fields'**
  String get validationTitle;

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'{field} is required'**
  String validationRequired(String field);

  /// No description provided for @validationIntro.
  ///
  /// In en, this message translates to:
  /// **'Please correct the highlighted items before continuing.'**
  String get validationIntro;

  /// No description provided for @formLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the census form'**
  String get formLoadFailed;

  /// No description provided for @formLoadFailedHint.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get formLoadFailedHint;

  /// No description provided for @connectionErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server'**
  String get connectionErrorTitle;

  /// No description provided for @connectionErrorHint.
  ///
  /// In en, this message translates to:
  /// **'Please check the network and try again.'**
  String get connectionErrorHint;

  /// No description provided for @apiEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Server: {url}'**
  String apiEndpoint(String url);

  /// No description provided for @duplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Household already recorded'**
  String get duplicateTitle;

  /// No description provided for @duplicateBody.
  ///
  /// In en, this message translates to:
  /// **'A submission for this household, township and interview date already exists.\n\nIf you intentionally want to record it again, tap “Submit anyway”.'**
  String get duplicateBody;

  /// No description provided for @duplicateCancel.
  ///
  /// In en, this message translates to:
  /// **'Do not submit'**
  String get duplicateCancel;

  /// No description provided for @duplicateResubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit anyway'**
  String get duplicateResubmit;

  /// No description provided for @personSectionRespondent.
  ///
  /// In en, this message translates to:
  /// **'Respondent'**
  String get personSectionRespondent;

  /// No description provided for @personSectionHead.
  ///
  /// In en, this message translates to:
  /// **'Household head'**
  String get personSectionHead;

  /// No description provided for @personSectionInterviewer.
  ///
  /// In en, this message translates to:
  /// **'Interviewer'**
  String get personSectionInterviewer;

  /// No description provided for @ageGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Age group'**
  String get ageGroupLabel;

  /// No description provided for @unsupportedField.
  ///
  /// In en, this message translates to:
  /// **'This field is not supported in the app yet'**
  String get unsupportedField;

  /// No description provided for @unsupportedGroup.
  ///
  /// In en, this message translates to:
  /// **'This table type is not supported in the app yet'**
  String get unsupportedGroup;

  /// No description provided for @animalCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category / breed'**
  String get animalCategoryLabel;

  /// No description provided for @speciesLabel.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get speciesLabel;

  /// No description provided for @ageGroupLabelShort.
  ///
  /// In en, this message translates to:
  /// **'Age group'**
  String get ageGroupLabelShort;

  /// No description provided for @maleLabel.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get maleLabel;

  /// No description provided for @castratedLabel.
  ///
  /// In en, this message translates to:
  /// **'Castrated'**
  String get castratedLabel;

  /// No description provided for @femaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get femaleLabel;

  /// No description provided for @rowTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total: {total}'**
  String rowTotalLabel(int total);

  /// No description provided for @addRowButton.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get addRowButton;

  /// No description provided for @removeRowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove this row'**
  String get removeRowTooltip;

  /// No description provided for @emptyRowsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap “Add row” to enter the animal counts.'**
  String get emptyRowsHint;

  /// No description provided for @noCategoriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No categories are available for this table yet.'**
  String get noCategoriesAvailable;

  /// No description provided for @selectPrompt.
  ///
  /// In en, this message translates to:
  /// **'— Select —'**
  String get selectPrompt;

  /// No description provided for @rowNumber.
  ///
  /// In en, this message translates to:
  /// **'Row {number}'**
  String rowNumber(int number);

  /// No description provided for @boolYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get boolYes;

  /// No description provided for @boolNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get boolNo;

  /// No description provided for @pickDateHelp.
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get pickDateHelp;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review answers'**
  String get reviewTitle;

  /// No description provided for @reviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check the answers below before submitting.'**
  String get reviewSubtitle;

  /// No description provided for @reviewHouseholdCard.
  ///
  /// In en, this message translates to:
  /// **'Household & interview'**
  String get reviewHouseholdCard;

  /// No description provided for @reviewInterviewDate.
  ///
  /// In en, this message translates to:
  /// **'Interview date: {date}'**
  String reviewInterviewDate(String date);

  /// No description provided for @reviewAnimalRecords.
  ///
  /// In en, this message translates to:
  /// **'Animal counts recorded: {count}'**
  String reviewAnimalRecords(int count);

  /// No description provided for @reviewBreedingRecords.
  ///
  /// In en, this message translates to:
  /// **'Breeding records: {count}'**
  String reviewBreedingRecords(int count);

  /// No description provided for @reviewAdditionalFields.
  ///
  /// In en, this message translates to:
  /// **'Additional fields: {count}'**
  String reviewAdditionalFields(int count);

  /// No description provided for @reviewReady.
  ///
  /// In en, this message translates to:
  /// **'Everything looks complete. You can submit the census.'**
  String get reviewReady;

  /// No description provided for @reviewIncompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Some required answers are missing'**
  String get reviewIncompleteTitle;

  /// No description provided for @reviewEditSection.
  ///
  /// In en, this message translates to:
  /// **'Go to section'**
  String get reviewEditSection;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get statusUnknown;

  /// No description provided for @statusApproved.
  ///
  /// In en, this message translates to:
  /// **'approved'**
  String get statusApproved;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'rejected'**
  String get statusRejected;

  /// No description provided for @statusReturned.
  ///
  /// In en, this message translates to:
  /// **'returned'**
  String get statusReturned;

  /// No description provided for @statusUnderReview.
  ///
  /// In en, this message translates to:
  /// **'under review'**
  String get statusUnderReview;

  /// No description provided for @statusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'submitted'**
  String get statusSubmitted;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get statusPending;

  /// No description provided for @statusReopened.
  ///
  /// In en, this message translates to:
  /// **'reopened'**
  String get statusReopened;

  /// No description provided for @selectUpperLevelFirst.
  ///
  /// In en, this message translates to:
  /// **'Select the level above first'**
  String get selectUpperLevelFirst;

  /// No description provided for @noOptionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No options available yet'**
  String get noOptionsAvailable;

  /// No description provided for @fieldOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get fieldOptional;

  /// No description provided for @notProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notProvided;

  /// No description provided for @draftRestored.
  ///
  /// In en, this message translates to:
  /// **'Your previous draft was restored.'**
  String get draftRestored;

  /// No description provided for @sectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Section {number}'**
  String sectionLabel(int number);

  /// No description provided for @rowsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No rows added} =1{1 row added} other{{count} rows added}}'**
  String rowsCountLabel(int count);

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get navCollect;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @personalSummary.
  ///
  /// In en, this message translates to:
  /// **'Your summary'**
  String get personalSummary;

  /// No description provided for @liveFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Live activity'**
  String get liveFeedTitle;

  /// No description provided for @noActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No activity yet. Captured census records will appear here.'**
  String get noActivityYet;

  /// No description provided for @offlineCachedHint.
  ///
  /// In en, this message translates to:
  /// **'Showing saved data — you are offline.'**
  String get offlineCachedHint;

  /// No description provided for @tagPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get tagPending;

  /// No description provided for @tagSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get tagSynced;

  /// No description provided for @tagLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get tagLive;

  /// No description provided for @waitingToUpload.
  ///
  /// In en, this message translates to:
  /// **'Waiting to upload'**
  String get waitingToUpload;

  /// No description provided for @submissionDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Submission details'**
  String get submissionDetailTitle;

  /// No description provided for @labelInterviewDate.
  ///
  /// In en, this message translates to:
  /// **'Interview date'**
  String get labelInterviewDate;

  /// No description provided for @labelLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get labelLocation;

  /// No description provided for @collectHint.
  ///
  /// In en, this message translates to:
  /// **'Capture the census for one household at a time. Your answers are saved automatically and can be submitted even when the network is weak or missing.'**
  String get collectHint;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// No description provided for @uploadQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline uploads'**
  String get uploadQueueTitle;

  /// No description provided for @uploadQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'All your captured surveys have been uploaded.'**
  String get uploadQueueEmpty;

  /// No description provided for @queuedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 survey waiting to upload} other{{count} surveys waiting to upload}}'**
  String queuedCount(int count);

  /// No description provided for @syncingNow.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncingNow;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncCompleted.
  ///
  /// In en, this message translates to:
  /// **'All queued surveys have been uploaded.'**
  String get syncCompleted;

  /// No description provided for @syncPartial.
  ///
  /// In en, this message translates to:
  /// **'Some surveys could not be uploaded yet. They will retry automatically.'**
  String get syncPartial;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInWithGoogle;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @googleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not enabled on this server. Please sign in with your email and password.'**
  String get googleUnavailable;

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in could not be completed. Please try again.'**
  String get googleSignInFailed;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @syncingSchema.
  ///
  /// In en, this message translates to:
  /// **'Syncing live schema…'**
  String get syncingSchema;

  /// No description provided for @statusTagActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusTagActive;

  /// No description provided for @personalHistorySection.
  ///
  /// In en, this message translates to:
  /// **'Personal survey history'**
  String get personalHistorySection;

  /// No description provided for @personalHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only census records captured by your own account are shown here.'**
  String get personalHistorySubtitle;

  /// No description provided for @systemConfig.
  ///
  /// In en, this message translates to:
  /// **'System configuration'**
  String get systemConfig;

  /// No description provided for @connectionStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Live connection'**
  String get connectionStatusLabel;

  /// No description provided for @autoSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync when online'**
  String get autoSyncTitle;

  /// No description provided for @autoSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Queued surveys upload by themselves once the connection returns.'**
  String get autoSyncSubtitle;

  /// No description provided for @uploadAllOffline.
  ///
  /// In en, this message translates to:
  /// **'Upload all offline drafts'**
  String get uploadAllOffline;

  /// No description provided for @uploadProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading {done} of {total}…'**
  String uploadProgress(int done, int total);

  /// No description provided for @apiEndpointLabel.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get apiEndpointLabel;

  /// No description provided for @phoneInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Myanmar phone number, e.g. 09xxxxxxxxx.'**
  String get phoneInvalidError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'my'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'my':
      return AppLocalizationsMy();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
