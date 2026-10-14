// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Burmese (`my`).
class AppLocalizationsMy extends AppLocalizations {
  AppLocalizationsMy([String locale = 'my']) : super(locale);

  @override
  String get appShortName => 'တိရစ္ဆာန်ကောင်ရေစာရင်း';

  @override
  String get appTitle => 'တိရစ္ဆာန်ကောင်ရေစာရင်း ကောက်ယူခြင်း';

  @override
  String get appOrganisation =>
      'စိုက်ပျိုးရေး၊ မွေးမြူရေးနှင့် ဆည်မြောင်းဝန်ကြီးဌာန';

  @override
  String get language => 'ဘာသာစကား';

  @override
  String get languageMyanmar => 'မြန်မာ';

  @override
  String get languageEnglish => 'English';

  @override
  String get ok => 'အိုကေ';

  @override
  String get cancel => 'မလုပ်တော့ပါ';

  @override
  String get retry => 'ပြန်ကြိုးစားမည်';

  @override
  String get close => 'ပိတ်မည်';

  @override
  String get yes => 'မှန်သည်';

  @override
  String get no => 'မဟုတ်ပါ';

  @override
  String get edit => 'ပြင်ဆင်ရန်';

  @override
  String get back => 'နောက်သို့';

  @override
  String get save => 'သိမ်းမည်';

  @override
  String get loginTitle => 'အကောင့်ဝင်ရန်';

  @override
  String get loginSubtitle =>
      'အိမ်ထောင်စု တိရစ္ဆာန်ကောင်ရေ စာရင်းကောက်ယူရန် ဝင်ရောက်ပါ။';

  @override
  String get registerTitle => 'အကောင့်အသစ်ဖွင့်ရန်';

  @override
  String get registerSubtitle => 'စာရင်းကောက်ယူရန် အကောင့်အသစ် ဖွင့်ပါ။';

  @override
  String get emailLabel => 'အီးမေးလ်';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get passwordLabel => 'စကားဝှက်';

  @override
  String get passwordHintLogin => 'သင့်စကားဝှက် ထည့်ပါ';

  @override
  String get passwordHintRegister => 'အနည်းဆုံး (၈) လုံး';

  @override
  String get fullNameLabel => 'အမည် အပြည့်အစုံ';

  @override
  String get fullNameHint => 'မဖြစ်မနေ မဟုတ်ပါ';

  @override
  String get showPassword => 'စကားဝှက် ပြရန်';

  @override
  String get hidePassword => 'စကားဝှက် ဖျောက်ရန်';

  @override
  String get loginButton => 'ဝင်မည်';

  @override
  String get registerButton => 'အကောင့်ဖွင့်မည်';

  @override
  String get signingIn => 'ဝင်ရောက်နေသည်…';

  @override
  String get creatingAccount => 'အကောင့် ဖွင့်နေသည်…';

  @override
  String get switchToRegister => 'အကောင့် မရှိသေးပါ';

  @override
  String get switchToLogin => 'အကောင့် ရှိပြီးသားဖြစ်ပါက ဝင်မည်';

  @override
  String get termsNotice =>
      'ဆက်လက်ဆောင်ရွက်ခြင်းဖြင့် ဤအစိုးရဝန်ဆောင်မှု၏ အသုံးပြုစည်းကမ်းချက်များကို လက်ခံသည်ဟု မှတ်ယူပါသည်။';

  @override
  String get secureNotice => 'တရားဝင် အစိုးရအက်ပလီကေးရှင်း';

  @override
  String get emailRequiredError => 'အီးမေးလ် ထည့်သွင်းပါ။';

  @override
  String get emailInvalidError => 'မှန်ကန်သော အီးမေးလ် ထည့်သွင်းပါ။';

  @override
  String get passwordRequiredError => 'စကားဝှက် ထည့်သွင်းပါ။';

  @override
  String get passwordTooShortError => 'စကားဝှက်သည် အနည်းဆုံး (၈) လုံး ရှိရမည်။';

  @override
  String get nameRequiredError => 'အမည် ထည့်သွင်းပါ။';

  @override
  String welcomeUser(String name) {
    return 'ကြိုဆိုပါသည်၊ $name';
  }

  @override
  String get sessionExpired =>
      'သင်၏ အကောင့်ဝင်ရောက်မှု သက်တမ်းကုန်ဆုံးပါပြီ။ ပြန်လည်ဝင်ရောက်ပါ။';

  @override
  String get errorIncorrectCredentials =>
      'အီးမေးလ် သို့မဟုတ် စကားဝှက် မှားနေပါသည်။';

  @override
  String get errorAccountDisabled =>
      'ဤအကောင့်ကို ပိတ်ထားပါသည်။ စီမံခန့်ခွဲသူကို ဆက်သွယ်ပါ။';

  @override
  String get errorEmailRegistered =>
      'ဤအီးမေးလ်ဖြင့် အကောင့်ဖွင့်ပြီးသားဖြစ်သည်။ ဝင်ရောက်ကြည့်ပါ။';

  @override
  String get errorTooManyAttempts =>
      'မအောင်မြင်သော ကြိုးစားမှု များလွန်းသည်။ ခဏနေမှ ပြန်ကြိုးစားပါ။';

  @override
  String get errorNetwork =>
      'ဆာဗာသို့ ချိတ်ဆက်၍မရပါ။ ချိတ်ဆက်မှုကို စစ်ဆေး၍ ပြန်ကြိုးစားပါ။';

  @override
  String get errorServer => 'ဆာဗာတွင် အမှားဖြစ်ပွားသည်။ ပြန်ကြိုးစားပါ။';

  @override
  String get errorUnexpected =>
      'မမျှော်လင့်သော အမှားဖြစ်ပွားသည်။ ပြန်ကြိုးစားပါ။';

  @override
  String get dashboardTitle => 'ပင်မစာမျက်နှာ';

  @override
  String get overview => 'ခြုံငုံသုံးသပ်ချက်';

  @override
  String get statTotalSubmissions => 'စုစုပေါင်း တင်သွင်းမှု';

  @override
  String get statToday => 'ယနေ့';

  @override
  String get statPendingReview => 'စစ်ဆေးရန် ကျန်ရှိ';

  @override
  String get statApproved => 'အတည်ပြုပြီး';

  @override
  String get statAnimalsRecorded => 'မှတ်တမ်းတင်ပြီး တိရစ္ဆာန်';

  @override
  String get statHouseholds => 'အိမ်ထောင်စု';

  @override
  String get recentSubmissions => 'မကြာသေးမီ တင်သွင်းမှုများ';

  @override
  String get noSubmissionsYet =>
      'တင်သွင်းမှု မရှိသေးပါ။ “စာရင်းကောက်ယူမည်” ကို နှိပ်ပါ။';

  @override
  String get newSurvey => 'စာရင်းကောက်ယူမည်';

  @override
  String get historyTitle => 'တင်သွင်းမှု မှတ်တမ်း';

  @override
  String get logOut => 'အကောင့်မှ ထွက်မည်';

  @override
  String get refreshTooltip => 'ပြန်လည်ရယူမည်';

  @override
  String get liveConnected => 'အချိန်နှင့်တပြေးညီ ချိတ်ဆက်ပြီး';

  @override
  String get liveConnecting => 'အချိန်နှင့်တပြေးညီ ချိတ်ဆက်နေသည်…';

  @override
  String get liveOffline => 'အချိန်နှင့်တပြေးညီ ချိတ်ဆက်မှု မရှိ';

  @override
  String get unableToLoad => 'ဒေတာ မရယူနိုင်ပါ';

  @override
  String get noSubmissionsFound => 'တင်သွင်းမှု ရှာမတွေ့ပါ။';

  @override
  String householdLabel(String number) {
    return 'အိမ်ထောင်စု $number';
  }

  @override
  String dateLabel(String date) {
    return 'ရက်စွဲ: $date';
  }

  @override
  String roleLabel(String role) {
    return 'အခန်းကဏ္ဍ: $role';
  }

  @override
  String get censusTitle => 'စာရင်းကောက်ယူမှု';

  @override
  String stepOfTotal(int step, int total) {
    return 'အဆင့် $step / $total';
  }

  @override
  String get reviewStepName => 'စစ်ဆေးရန်';

  @override
  String get stepHint =>
      'အောက်ပါ အချက်အလက်များကို ဖြည့်ပါ။ * ပါသော အချက်များ မဖြစ်မနေ ဖြည့်ရမည်။';

  @override
  String get previousButton => 'နောက်သို့';

  @override
  String get nextButton => 'ရှေ့သို့';

  @override
  String get reviewAndSubmitButton => 'စစ်ဆေး၍ တင်သွင်းမည်';

  @override
  String get draftSaved => 'ပုံကြမ်း အလိုအလျောက် သိမ်းဆည်းပြီး';

  @override
  String get discardDraftTooltip => 'ပုံကြမ်း ဖျက်မည်';

  @override
  String get discardDraftTitle => 'ဤပုံကြမ်းကို ဖျက်မည်လား?';

  @override
  String get discardDraftBody =>
      'ဤစာရင်း၏ မသိမ်းဆည်းရသေးသော ဒေတာများ အပြီးအပိုင် ဆုံးရှုံးမည်။';

  @override
  String get discardConfirmButton => 'ဖျက်မည်';

  @override
  String get submitButton => 'စာရင်း တင်သွင်းမည်';

  @override
  String get submitting => 'တင်သွင်းနေသည်…';

  @override
  String get submissionConfirmedTitle => 'စာရင်းတင်သွင်း အောင်မြင်ပါသည်!';

  @override
  String get submissionConfirmedBody =>
      'စာရင်းကို တရားဝင် စီမံခန့်ခွဲမှုစနစ်သို့ ပို့ဆောင်ပြီးပါပြီ။';

  @override
  String get submissionQueuedTitle =>
      'အော့ဖ်လိုင်း သိမ်းဆည်းပြီး — အလိုအလျောက် တင်သွင်းပါမည်';

  @override
  String get submissionQueuedBody =>
      'သင်သည် အော့ဖ်လိုင်း ဖြစ်နေသောကြောင့် ဤစာရင်းကို သင့်စက်ပစ္စည်းတွင် သိမ်းဆည်းထားပါသည်။ ကွန်ရက် ပြန်လည်ရရှိသည်နှင့် အလိုအလျောက် တင်သွင်းပါမည်။';

  @override
  String submissionHouseholdNo(String number) {
    return 'အိမ်ထောင်စုနံပါတ်: $number';
  }

  @override
  String submissionReference(String id) {
    return 'တင်သွင်းမှု အမှတ်: $id';
  }

  @override
  String get backToDashboard => 'ပင်မစာမျက်နှာသို့ ပြန်သွားမည်';

  @override
  String submissionFailed(String message) {
    return 'တင်သွင်းမှု မအောင်မြင်ပါ: $message';
  }

  @override
  String get validationTitle => 'လိုအပ်ချက်များ';

  @override
  String validationRequired(String field) {
    return '$field ထည့်သွင်းရန် လိုအပ်သည်';
  }

  @override
  String get validationIntro =>
      'ဆက်လက်မဆောင်ရွက်မီ အမှတ်ပြထားသော အချက်များကို ပြင်ဆင်ပါ။';

  @override
  String get formLoadFailed => 'စာရင်းပုံစံကို မရယူနိုင်ပါ';

  @override
  String get formLoadFailedHint => 'ချိတ်ဆက်မှုကို စစ်ဆေး၍ ပြန်ကြိုးစားပါ။';

  @override
  String get connectionErrorTitle => 'ဆာဗာသို့ ချိတ်ဆက်၍ မရပါ';

  @override
  String get connectionErrorHint => 'ကွန်ရက်ကို စစ်ဆေး၍ ပြန်ကြိုးစားပါ။';

  @override
  String apiEndpoint(String url) {
    return 'ဆာဗာ: $url';
  }

  @override
  String get duplicateTitle => 'ထပ်နေသော အိမ်ထောင်စု';

  @override
  String get duplicateBody =>
      'ဤအိမ်ထောင်စုအတွက် ဤမြို့နယ်နှင့် တူညီသော အင်တာဗျူးရက်စွဲဖြင့် စာရင်းသွင်းပြီးသားဖြစ်သည်။\n\nသိသိချင်း ထပ်မံတင်သွင်းလိုပါက “ထပ်မံတင်သွင်းမည်” ကို နှိပ်ပါ။';

  @override
  String get duplicateCancel => 'မလုပ်တော့ပါ';

  @override
  String get duplicateResubmit => 'ထပ်မံတင်သွင်းမည်';

  @override
  String get personSectionRespondent => 'ဖြေဆိုသူ';

  @override
  String get personSectionHead => 'အိမ်ထောင်ဦးစီး';

  @override
  String get personSectionInterviewer => 'မေးမြန်းသူ';

  @override
  String get ageGroupLabel => 'အသက်အပိုင်းအခြား';

  @override
  String get unsupportedField => 'ဤအကွက်ကို ဤအက်ပ်၌ မပံ့ပိုးရသေးပါ';

  @override
  String get unsupportedGroup => 'ဤဇယားအမျိုးအစားကို ဤအက်ပ်၌ မပံ့ပိုးရသေးပါ';

  @override
  String get animalCategoryLabel => 'မျိုးအမျိုးအစား';

  @override
  String get speciesLabel => 'မျိုး';

  @override
  String get ageGroupLabelShort => 'အသက်အပိုင်းအခြား';

  @override
  String get maleLabel => 'အထီး';

  @override
  String get castratedLabel => 'သင်းကွပ်အထီး';

  @override
  String get femaleLabel => 'အမ';

  @override
  String rowTotalLabel(int total) {
    return 'စုစုပေါင်း: $total';
  }

  @override
  String get addRowButton => 'ထည့်မည်';

  @override
  String get removeRowTooltip => 'ဤအတန်းကို ဖယ်ရှားမည်';

  @override
  String get emptyRowsHint => 'ကောင်ရေတွက်ရန် “ထည့်မည်” ကို နှိပ်ပါ။';

  @override
  String get noCategoriesAvailable => 'ဤဇယားအတွက် အမျိုးအစားများ မရရှိနိုင်ပါ';

  @override
  String get selectPrompt => '— ရွေးရန် —';

  @override
  String rowNumber(int number) {
    return 'အတန်း $number';
  }

  @override
  String get boolYes => 'မှန်သည်';

  @override
  String get boolNo => 'မဟုတ်ပါ';

  @override
  String get pickDateHelp => 'ရက် ရွေးပါ';

  @override
  String get reviewTitle => 'အဖြေများ ပြန်လည်စစ်ဆေးခြင်း';

  @override
  String get reviewSubtitle => 'တင်သွင်းမီ အောက်ပါ အဖြေများကို စစ်ဆေးပါ။';

  @override
  String get reviewHouseholdCard => 'အိမ်ထောင်စုနှင့် အင်တာဗျူး';

  @override
  String reviewInterviewDate(String date) {
    return 'အင်တာဗျူးရက်စွဲ: $date';
  }

  @override
  String reviewAnimalRecords(int count) {
    return 'မှတ်တမ်းတင်ထားသော တိရစ္ဆာန်ကောင်ရေ: $count';
  }

  @override
  String reviewBreedingRecords(int count) {
    return 'မျိုးပွားမှတ်တမ်း: $count';
  }

  @override
  String reviewAdditionalFields(int count) {
    return 'ထပ်ဆောင်းအကွက်: $count';
  }

  @override
  String get reviewReady =>
      'အားလုံး ပြည့်စုံပါသည်။ စာရင်းကို တင်သွင်းနိုင်ပါပြီ။';

  @override
  String get reviewIncompleteTitle =>
      'မဖြည့်ရသေးသော မဖြစ်မနေအချက်များ ရှိပါသည်';

  @override
  String get reviewEditSection => 'အပိုင်းသို့ သွားမည်';

  @override
  String get statusUnknown => 'မသိ';

  @override
  String get statusApproved => 'အတည်ပြုပြီး';

  @override
  String get statusRejected => 'ပယ်ချပြီး';

  @override
  String get statusReturned => 'ပြန်လည်ပေးပို့ပြီး';

  @override
  String get statusUnderReview => 'စစ်ဆေးနေဆဲ';

  @override
  String get statusSubmitted => 'တင်သွင်းပြီး';

  @override
  String get statusPending => 'စောင့်ဆိုင်းဆဲ';

  @override
  String get statusReopened => 'ပြန်ဖွင့်ပြီး';

  @override
  String get selectUpperLevelFirst => 'အပေါ်အဆင့်ကို အရင်ရွေးပါ';

  @override
  String get noOptionsAvailable => 'ရွေးချယ်စရာ မရှိသေးပါ';

  @override
  String get fieldOptional => 'မဖြစ်မနေ မဟုတ်ပါ';

  @override
  String get notProvided => 'မဖြည့်ထားပါ';

  @override
  String get draftRestored => 'ယခင် ပုံကြမ်းကို ပြန်လည်ရယူပြီးပါပြီ။';

  @override
  String sectionLabel(int number) {
    return 'အပိုင်း $number';
  }

  @override
  String rowsCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'အတန်း $count ခု ထည့်ပြီး',
      zero: 'အတန်း မထည့်ရသေးပါ',
    );
    return '$_temp0';
  }

  @override
  String get navHome => 'ပင်မ';

  @override
  String get navCollect => 'ကောက်ယူရန်';

  @override
  String get navHistory => 'မှတ်တမ်း';

  @override
  String get personalSummary => 'သင့်အနှစ်ချုပ်';

  @override
  String get liveFeedTitle => 'အချိန်နှင့်တပြေးညီ လှုပ်ရှားမှု';

  @override
  String get noActivityYet =>
      'လှုပ်ရှားမှု မရှိသေးပါ။ ကောက်ယူထားသော စာရင်းများ ဤနေရာတွင် ပေါ်လာပါမည်။';

  @override
  String get offlineCachedHint =>
      'သိမ်းဆည်းထားသော အချက်အလက်ကို ပြသနေသည် — အော်ဖ်လိုင်း ဖြစ်နေသည်။';

  @override
  String get tagPending => 'စောင့်ဆိုင်းဆဲ';

  @override
  String get tagSynced => 'ဆာဗာရောက်ပြီး';

  @override
  String get tagLive => 'အသက်ဝင်ပြီး';

  @override
  String get waitingToUpload => 'တင်ရန် စောင့်ဆိုင်းနေသည်';

  @override
  String get submissionDetailTitle => 'တင်သွင်းမှု အသေးစိတ်';

  @override
  String get labelInterviewDate => 'အင်တာဗျူးရက်စွဲ';

  @override
  String get labelLocation => 'တည်နေရာ';

  @override
  String get collectHint =>
      'အိမ်ထောင်စု တစ်ခုချင်းအတွက် စာရင်းကောက်ယူပါ။ ဖြေကြားချက်များကို အလိုအလျောက် သိမ်းဆည်းထားပြီး ကွန်ရက်အားနည်းချိန်တွင်လည်း တင်သွင်းနိုင်ပါသည်။';

  @override
  String get accountSection => 'အကောင့်';

  @override
  String get uploadQueueTitle => 'အော့ဖ်လိုင်း တင်သွင်းမှုများ';

  @override
  String get uploadQueueEmpty =>
      'ကောက်ယူထားသော စာရင်းအားလုံး တင်သွင်းပြီးပါပြီ။';

  @override
  String queuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'တင်ရန် စာရင်း $count ခု ကျန်ရှိနေသည်',
      one: 'တင်ရန် စာရင်း ၁ ခု ကျန်ရှိနေသည်',
    );
    return '$_temp0';
  }

  @override
  String get syncingNow => 'ပို့နေသည်…';

  @override
  String get syncNow => 'ယခု ပို့မည်';

  @override
  String get syncCompleted =>
      'စောင့်ဆိုင်းနေသော စာရင်းအားလုံး တင်သွင်းပြီးပါပြီ။';

  @override
  String get syncPartial =>
      'အချို့စာရင်းများ တင်သွင်း၍ မရသေးပါ။ အလိုအလျောက် ထပ်မံကြိုးစားပါမည်။';

  @override
  String get signInWithGoogle => 'Google ဖြင့် ဆက်လက်ဆောင်ရွက်မည်';

  @override
  String get orDivider => 'သို့မဟုတ်';

  @override
  String get googleUnavailable =>
      'ဤဆာဗာတွင် Google အကောင့်ဝင်ခြင်း မဖွင့်ထားပါ။ အီးမေးလ်နှင့် စကားဝှက်ဖြင့် ဝင်ပါ။';

  @override
  String get googleSignInFailed =>
      'Google အကောင့်ဝင်ခြင်း မပြီးမြောက်ပါ။ ထပ်မံကြိုးစားပါ။';

  @override
  String get welcomeBack => 'ပြန်လည် ကြိုဆိုပါသည်';

  @override
  String get navSettings => 'ဆက်တင်';

  @override
  String get syncingSchema => 'အချက်အလက် ပြန်လည်ရယူနေသည်…';

  @override
  String get statusTagActive => 'အသုံးပြုနေဆဲ';

  @override
  String get personalHistorySection => 'ကိုယ်ပိုင် စာရင်းမှတ်တမ်း';

  @override
  String get personalHistorySubtitle =>
      'သင့်အကောင့်ဖြင့် ကောက်ယူထားသော စာရင်းများကိုသာ ဤနေရာတွင် ပြသပါသည်။';

  @override
  String get systemConfig => 'စနစ် ဖွဲ့စည်းမှု';

  @override
  String get connectionStatusLabel => 'အချိန်နှင့်တပြေးညီ ချိတ်ဆက်မှု';

  @override
  String get autoSyncTitle => 'အွန်လိုင်းရှိချိန် အလိုအလျောက် တင်သွင်းမည်';

  @override
  String get autoSyncSubtitle =>
      'ကွန်ရက် ပြန်လည်ရရှိသည်နှင့် စောင့်ဆိုင်းနေသော စာရင်းများ အလိုအလျောက် တင်သွင်းပါမည်။';

  @override
  String get uploadAllOffline => 'အော့ဖ်လိုင်း ပုံကြမ်းအားလုံး တင်သွင်းမည်';

  @override
  String uploadProgress(int done, int total) {
    return 'တင်သွင်းနေသည် $done / $total…';
  }

  @override
  String get apiEndpointLabel => 'ဆာဗာ လိပ်စာ';

  @override
  String get phoneInvalidError =>
      'မှန်ကန်သော မြန်မာဖုန်းနံပါတ် ထည့်ပါ (ဥပမာ 09xxxxxxxxx)။';
}
