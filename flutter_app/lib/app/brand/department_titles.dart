/// Official departmental identity for the MOALI / LBVD livestock census app.
///
/// These are fixed institution names rather than translatable UI copy, so they
/// live as constants and the branding header always shows **both** languages at
/// once (Burmese first, English beneath) regardless of the active UI locale —
/// exactly as a government letterhead would.
abstract final class DepartmentTitles {
  static const String ministryBurmese =
      'စိုက်ပျိုးရေး၊ မွေးမြူရေးနှင့် ဆည်မြောင်းဝန်ကြီးဌာန';
  static const String ministryEnglish =
      'Ministry of Agriculture, Livestock and Irrigation';

  static const String departmentBurmese = 'မွေးမြူရေးနှင့် ကုသရေးဦးစီးဌာန';
  static const String departmentEnglish =
      'Livestock Breeding and Veterinary Department';

  static const String surveyBurmese = 'တိရစ္ဆာန်ကောင်ရေစာရင်း ကောက်ယူခြင်း';
  static const String surveyEnglish = 'Livestock Census Survey';
}
