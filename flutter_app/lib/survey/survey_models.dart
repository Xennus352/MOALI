/// Survey domain models for the MOALI livestock census.
///
/// The structure mirrors the backend `SubmissionCreate`/`AnimalCountIn`
/// schemas and the reference tables served by `/api/v1/master/*` and
/// `/api/v1/meta/*`. The `SurveyDraft` object is what gets persisted to local
/// storage so an unfinished survey can be resumed.
library;

typedef Json = Map<String, dynamic>;

/// One field of the published census form, as served by
/// ``/api/v1/meta/form/current``. The app renders its input from this contract
/// so an administrator can add/rename/retype fields without shipping a new
/// build.
class FormFieldDef {
  FormFieldDef({
    required this.id,
    required this.name,
    required this.titleBurmese,
    this.titleEnglish,
    required this.fieldType,
    this.isRequired = false,
    this.displayOrder = 0,
    this.sectionId,
    this.optionSource,
    this.dataBinding,
    this.placeholderBurmese,
    this.unit,
    this.minValue,
    this.maxValue,
    this.defaultValue,
  });

  final int id;
  final String name;
  final String titleBurmese;
  final String? titleEnglish;
  final String fieldType;
  final bool isRequired;
  final int displayOrder;
  final int? sectionId;
  final String? optionSource;
  final String? dataBinding;
  final String? placeholderBurmese;
  final String? unit;
  final int? minValue;
  final int? maxValue;
  final String? defaultValue;

  /// Bilingual label combining both official titles (used where a single line
  /// of context is helpful regardless of the active language).
  String get label => titleBurmese.isNotEmpty
      ? (titleEnglish == null || titleEnglish!.isEmpty
          ? titleBurmese
          : '$titleBurmese · $titleEnglish')
      : name;

  /// The official title for the active language, falling back to the other
  /// language (or the field key) so a label is never empty.
  String labelFor(bool myanmar) {
    if (myanmar) {
      if (titleBurmese.isNotEmpty) return titleBurmese;
      if (titleEnglish?.isNotEmpty == true) return titleEnglish!;
    } else {
      if (titleEnglish?.isNotEmpty == true) return titleEnglish!;
      if (titleBurmese.isNotEmpty) return titleBurmese;
    }
    return name;
  }

  factory FormFieldDef.fromJson(Json j) => FormFieldDef(
        id: (j['id'] as int?) ?? 0,
        name: (j['name'] as String?) ?? '',
        titleBurmese: (j['title_burmese'] as String?) ?? '',
        titleEnglish: j['title_english'] as String?,
        fieldType: (j['field_type'] as String?) ?? 'short_text',
        isRequired: (j['is_required'] as bool?) ?? false,
        displayOrder: (j['display_order'] as int?) ?? 0,
        sectionId: j['associated_section_id'] as int?,
        optionSource: j['option_source'] as String?,
        dataBinding: j['data_binding'] as String?,
        placeholderBurmese: j['placeholder_burmese'] as String?,
        unit: j['unit'] as String?,
        minValue: j['min_value'] as int?,
        maxValue: j['max_value'] as int?,
        defaultValue: j['default_value'] as String?,
      );
}

/// A section (wizard step) of the published form.
class FormSectionDef {
  FormSectionDef({
    required this.id,
    required this.titleBurmese,
    this.titleEnglish,
    this.displayOrder = 0,
    required this.fields,
  });

  final int id;
  final String titleBurmese;
  final String? titleEnglish;
  final int displayOrder;
  final List<FormFieldDef> fields;

  String get title => titleBurmese.isNotEmpty ? titleBurmese : 'Section $id';

  /// The official section title for the active language.
  String titleFor(bool myanmar) {
    if (myanmar) {
      if (titleBurmese.isNotEmpty) return titleBurmese;
      if (titleEnglish?.isNotEmpty == true) return titleEnglish!;
    } else {
      if (titleEnglish?.isNotEmpty == true) return titleEnglish!;
      if (titleBurmese.isNotEmpty) return titleBurmese;
    }
    return 'Section $id';
  }

  /// The secondary (other-language) title, shown as a subtitle for context.
  String subtitleFor(bool myanmar) {
    if (myanmar) {
      return (titleEnglish?.isNotEmpty == true) ? titleEnglish! : '';
    }
    return titleBurmese.isNotEmpty ? titleBurmese : '';
  }

  /// Compact label for the step indicator.
  String get shortLabel {
    final base = titleBurmese.isNotEmpty
        ? titleBurmese
        : (titleEnglish ?? 'Section $id');
    return base.length <= 9 ? base : '${base.substring(0, 8)}…';
  }

  String shortLabelFor(bool myanmar) {
    final base = titleFor(myanmar);
    return base.length <= 10 ? base : '${base.substring(0, 9)}…';
  }
}

/// The published census form: an ordered list of sections, each holding the
/// fields that belong to it. Everything the survey screen renders comes from
/// here, so the admin console is the single source of truth for the form.
class SurveyDefinition {
  SurveyDefinition({
    this.formId,
    this.burmeseTitle,
    this.englishTitle,
    this.versionNumber,
    this.formVersionId,
    required this.sections,
  });

  final String? formId;
  final String? burmeseTitle;
  final String? englishTitle;
  final int? versionNumber;
  final int? formVersionId;
  final List<FormSectionDef> sections;

  bool get isEmpty => sections.isEmpty;

  factory SurveyDefinition.fromJson(Json json) {
    final fieldsRaw = (json['fields'] as List?) ?? const [];
    final fields = fieldsRaw
        .whereType<Json>()
        .map(FormFieldDef.fromJson)
        .toList();

    final sectionsRaw = (json['sections'] as List?) ?? const [];
    final sectionIds = sectionsRaw
        .whereType<Json>()
        .map((s) => s['id'] as int?)
        .whereType<int>()
        .toSet();
    final sections = sectionsRaw.whereType<Json>().map((s) {
      final sid = s['id'] as int?;
      final own = fields.where((f) => f.sectionId == sid).toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return FormSectionDef(
        id: sid ?? 0,
        titleBurmese: (s['title_burmese'] as String?) ?? '',
        titleEnglish: s['title_english'] as String?,
        displayOrder: (s['display_order'] as int?) ?? 0,
        fields: own,
      );
    }).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    // Never drop a field: if its section was deleted or never assigned, render
    // it in a trailing "Other" step instead of silently losing the input.
    final orphans = fields
        .where((f) => f.sectionId == null || !sectionIds.contains(f.sectionId))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    if (orphans.isNotEmpty) {
      sections.add(FormSectionDef(
        id: -1,
        titleBurmese: 'အခြား အချက်အလက်များ',
        titleEnglish: 'Other information',
        displayOrder: 9000,
        fields: orphans,
      ));
    }

    return SurveyDefinition(
      formId: json['form_id'] as String?,
      burmeseTitle: json['burmese_title'] as String?,
      englishTitle: json['english_title'] as String?,
      versionNumber: json['version_number'] as int?,
      formVersionId: json['form_version_id'] as int?,
      sections: sections,
    );
  }
}

/// Reference data needed to render the five survey sections.
class ReferenceSets {
  ReferenceSets({
    required this.genders,
    required this.animalTypes,
    required this.categories,
    required this.species,
    required this.ageGroups,
    required this.breeding,
    required this.regions,
    required this.formVersionId,
  });

  final List<Json> genders;
  final List<Json> animalTypes;
  final List<Json> categories;
  final List<Json> species;
  final List<Json> ageGroups;
  final List<Json> breeding;
  final List<Json> regions;

  /// ``/api/v1/meta/form/current`` → ``form_version_id``.
  final int? formVersionId;

  /// Age groups for respondent / household head (all groups).
  List<Json> get personAges => ageGroups;

  /// Person gender options: the original form has no "castrated" gender for
  /// people, so `g02` is excluded (same as the admin survey form).
  List<Json> get personGenders =>
      genders.where((g) => g['code'] != 'g02').toList();

  /// Livestock / poultry gender options for animal-count rows.
  List<Json> get animalGenders => genders;

  Json? categoryById(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c['id'] == id) return c;
    }
    return null;
  }

  /// The species rows applicable to a category (same filtering as the admin
  /// survey form: same animal type and, when present, same category code).
  List<Json> speciesForCategory(int? categoryId) {
    final cat = categoryById(categoryId);
    if (cat == null) return const [];
    final typeId = cat['animal_type_id'];
    final catCode = cat['code'];
    return species
        .where((s) =>
            s['animal_type_id'] == typeId &&
            (s['animal_category_code'] == null ||
                s['animal_category_code'] == catCode))
        .toList();
  }

  List<Json> categoriesForType(int? typeId) => categories
      .where((c) => c['animal_type_id'] == typeId)
      .toList();

  /// Age groups that apply to a category — mirrors the admin form's mappings
  /// derived from the workbook ``ageType`` sheet.
  List<Json> ageGroupsForCategory(int? categoryId) {
    final cat = categoryById(categoryId);
    if (cat == null) return const [];
    final typeId = cat['animal_type_id'];
    final type =
        animalTypes.where((t) => t['id'] == typeId).toList().firstOrNull;
    if (type == null) return ageGroups;

    const largeCodes = ['ageID01', 'ageID02', 'ageID03'];
    const poultryCodes = <String, List<String>>{
      'lsID01': ['ageID07', 'ageID08', 'ageID09'],
      'lsID03': ['ageID10', 'ageID11'],
      'lsID04': ['ageID12', 'ageID13', 'ageID14'],
      'lsID07': ['ageID07', 'ageID15', 'ageID16'],
    };

    final codes = type['code'] == 'atID03'
        ? (poultryCodes[cat['code']] ?? poultryCodes['lsID01']!)
        : largeCodes;
    return codes
        .map((c) => ageGroups.where((a) => a['code'] == c).toList().firstOrNull)
        .whereType<Json>()
        .toList();
  }
}

class PersonInfo {
  PersonInfo({
    this.name = '',
    this.nameEn = '',
    this.genderId,
    this.age,
    this.ageGroupId,
    this.education = '',
    this.phone = '',
  });

  String name;
  String nameEn;
  int? genderId;
  int? age;
  int? ageGroupId;
  String education;
  String phone;

  Json toJson() => {
        'name': name,
        'name_en': nameEn,
        'gender_id': genderId,
        'age': age,
        'age_group_id': ageGroupId,
        'education': education,
        'phone': phone,
      };

  factory PersonInfo.fromJson(Json json) => PersonInfo(
        name: (json['name'] as String?) ?? '',
        nameEn: (json['name_en'] as String?) ?? '',
        genderId: json['gender_id'] as int?,
        age: json['age'] as int?,
        ageGroupId: json['age_group_id'] as int?,
        education: (json['education'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
      );

  PersonInfo copyWith({
    String? name,
    String? nameEn,
    int? Function()? genderId,
    int? Function()? age,
    int? Function()? ageGroupId,
    String? education,
    String? phone,
  }) =>
      PersonInfo(
        name: name ?? this.name,
        nameEn: nameEn ?? this.nameEn,
        genderId: genderId != null ? genderId() : this.genderId,
        age: age != null ? age() : this.age,
        ageGroupId: ageGroupId != null ? ageGroupId() : this.ageGroupId,
        education: education ?? this.education,
        phone: phone ?? this.phone,
      );
}

class AnimalRow {
  AnimalRow({
    required this.key,
    this.categoryId,
    this.speciesId,
    this.ageGroupId,
    this.male,
    this.castrated,
    this.female,
  }) : isPoultry = false;

  AnimalRow.poultry({
    required this.key,
    this.categoryId,
    this.speciesId,
    this.ageGroupId,
    this.male,
    this.female,
  })  : castrated = null,
        isPoultry = true;

  final int key;
  final bool isPoultry;
  int? categoryId;
  int? speciesId;
  int? ageGroupId;
  int? male;
  int? castrated;
  int? female;

  int get rowTotal {
    int total = 0;
    if (male != null) total += male!;
    if (castrated != null) total += castrated!;
    if (female != null) total += female!;
    return total;
  }

  Json toJson() => {
        'key': key,
        'is_poultry': isPoultry,
        'category_id': categoryId,
        'species_id': speciesId,
        'age_group_id': ageGroupId,
        'male': male,
        'castrated': castrated,
        'female': female,
      };

  factory AnimalRow.fromJson(Json json) {
    final poultry = (json['is_poultry'] as bool?) ?? false;
    if (poultry) {
      return AnimalRow.poultry(
        key: json['key'] as int,
        categoryId: json['category_id'] as int?,
        speciesId: json['species_id'] as int?,
        ageGroupId: json['age_group_id'] as int?,
        male: json['male'] as int?,
        female: json['female'] as int?,
      );
    }
    return AnimalRow(
      key: json['key'] as int,
      categoryId: json['category_id'] as int?,
      speciesId: json['species_id'] as int?,
      ageGroupId: json['age_group_id'] as int?,
      male: json['male'] as int?,
      castrated: json['castrated'] as int?,
      female: json['female'] as int?,
    );
  }
}

class BreedingRow {
  BreedingRow({required this.categoryId, this.male, this.female});

  final int categoryId;
  int? male;
  int? female;

  Json toJson() =>
      {'category_id': categoryId, 'male': male, 'female': female};

  factory BreedingRow.fromJson(Json json) => BreedingRow(
        categoryId: json['category_id'] as int,
        male: json['male'] as int?,
        female: json['female'] as int?,
      );
}

class SurveyDraft {
  SurveyDraft({
    this.regionId,
    this.districtId,
    this.townshipId,
    this.tractId,
    this.wardId,
    this.householdNo = '',
    this.interviewDate = '',
    PersonInfo? respondent,
    PersonInfo? head,
    this.hasRaisedAnimals = true,
    this.hasPoultry = true,
    List<AnimalRow>? largeRows,
    List<AnimalRow>? smallRows,
    List<AnimalRow>? poultryRows,
    List<BreedingRow>? breeding,
    PersonInfo? interviewer,
    Map<String, dynamic>? extras,
  })  : respondent = respondent ?? PersonInfo(),
        head = head ?? PersonInfo(),
        interviewer = interviewer ?? PersonInfo(),
        largeRows = largeRows ?? [],
        smallRows = smallRows ?? [],
        poultryRows = poultryRows ?? [],
        breeding = breeding ?? [],
        extras = extras ?? {};

  int? regionId;
  int? districtId;
  int? townshipId;
  int? tractId;
  int? wardId;
  String householdNo;
  String interviewDate; // ISO-8601 (YYYY-MM-DD)
  PersonInfo respondent;
  PersonInfo head;
  bool hasRaisedAnimals;
  bool hasPoultry;
  List<AnimalRow> largeRows;
  List<AnimalRow> smallRows;
  List<AnimalRow> poultryRows;
  List<BreedingRow> breeding;
  PersonInfo interviewer;

  /// Values for admin-authored fields that are not part of the fixed
  /// submission schema. Serialised to ``additional_data`` on submit.
  Map<String, dynamic> extras;

  Json toJson() => {
        'region_id': regionId,
        'district_id': districtId,
        'township_id': townshipId,
        'tract_id': tractId,
        'ward_id': wardId,
        'household_no': householdNo,
        'interview_date': interviewDate,
        'respondent': respondent.toJson(),
        'head': head.toJson(),
        'has_raised_animals': hasRaisedAnimals,
        'has_poultry': hasPoultry,
        'large_rows': largeRows.map((r) => r.toJson()).toList(),
        'small_rows': smallRows.map((r) => r.toJson()).toList(),
        'poultry_rows': poultryRows.map((r) => r.toJson()).toList(),
        'breeding': breeding.map((b) => b.toJson()).toList(),
        'interviewer': interviewer.toJson(),
        'extras': extras,
      };

  factory SurveyDraft.fromJson(Json json) => SurveyDraft(
        regionId: json['region_id'] as int?,
        districtId: json['district_id'] as int?,
        townshipId: json['township_id'] as int?,
        tractId: json['tract_id'] as int?,
        wardId: json['ward_id'] as int?,
        householdNo: (json['household_no'] as String?) ?? '',
        interviewDate: (json['interview_date'] as String?) ?? '',
        respondent: PersonInfo.fromJson(
            (json['respondent'] as Json?) ?? const {}),
        head: PersonInfo.fromJson((json['head'] as Json?) ?? const {}),
        hasRaisedAnimals: (json['has_raised_animals'] as bool?) ?? true,
        hasPoultry: (json['has_poultry'] as bool?) ?? true,
        largeRows: ((json['large_rows'] as List?) ?? const [])
            .whereType<Json>()
            .map(AnimalRow.fromJson)
            .toList(),
        smallRows: ((json['small_rows'] as List?) ?? const [])
            .whereType<Json>()
            .map(AnimalRow.fromJson)
            .toList(),
        poultryRows: ((json['poultry_rows'] as List?) ?? const [])
            .whereType<Json>()
            .map(AnimalRow.fromJson)
            .toList(),
        breeding: ((json['breeding'] as List?) ?? const [])
            .whereType<Json>()
            .map(BreedingRow.fromJson)
            .toList(),
        interviewer:
            PersonInfo.fromJson((json['interviewer'] as Json?) ?? const {}),
        extras: Map<String, dynamic>.from(
            (json['extras'] as Map?) ?? const <String, dynamic>{}),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final e in this) {
      return e;
    }
    return null;
  }
}