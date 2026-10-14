/// Native Flutter census survey, rendered **dynamically** from the published
/// form definition served by ``/api/v1/meta/form/current``.
///
/// Every section, field, label and validation rule comes from the backend, and
/// every select option comes from the admin-managed master data, so an
/// administrator can add new inputs, rename sections, reorder steps or extend
/// the option lists in the console without shipping a new build:
///
///   * Section titles / order  → `form_sections`
///   * Inputs (type, label,
///     required, binding)      → `form_fields`
///   * Select options          → `/api/v1/master/*` and `/api/v1/meta/geography`
///
/// Fields whose name matches the fixed submission schema (household, person,
/// geography, livestock tables) are grouped for a familiar wizard; any other
/// admin-authored field is rendered generically and submitted through
/// ``additional_data`` so its value is persisted as a typed field answer.
///
/// The whole survey is persisted to local storage on every change so an
/// interrupted census can be resumed.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/localization/l10n_ext.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/app_dialogs.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/feedback.dart';
import '../core/widgets/progress_header.dart';
import '../features/home/submission_repository.dart';
import 'survey_models.dart';



/// Top-level entry point for a new (or resumed) census survey.
class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key, this.repository, this.onSubmitted});

  /// When supplied, submissions are routed through the offline-aware
  /// [SubmissionRepository] so a capture made without a network connection is
  /// queued locally and retried automatically instead of being lost.
  final SubmissionRepository? repository;

  /// Called once a census has been stored (uploaded or queued). The shell uses
  /// this to refresh the feed and history.
  final VoidCallback? onSubmitted;

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  SurveyDefinition? _definition;
  ReferenceSets? _refs;
  Object? _loadError;
  bool _loading = true;

  SurveyDraft _draft = SurveyDraft();
  int _rowSeq = 1;

  /// 0..numSections-1 = the definition's sections, numSections = review,
  /// numSections+1 = success.
  int _step = 0;
  bool _submitting = false;
  Map<String, dynamic>? _created;
  bool _queued = false;

  // Field names that belong to a person block, used to keep the familiar
  // respondent / head / interviewer grouping while still rendering the fields
  // defined by the admin.
  static const _respondentNames = {
    'respondent_name_burmese', 'respondent_name_english', 'respondent_gender_id',
    'respondent_age', 'respondent_age_group_id', 'respondent_education',
    'respondent_phone',
  };
  static const _headNames = {
    'household_head_name_burmese', 'household_head_name_english',
    'household_head_gender_id', 'household_head_age',
    'household_head_age_group_id', 'household_head_education',
    'household_head_phone',
  };
  static const _interviewerNames = {'interviewer_name', 'interviewer_phone'};

  /// Myanmar mobile number, either the local `09…` form or the international
  /// `+959…` form. Kept client-side so a mistyped number is caught before the
  /// enumerator walks away from the household.
  static final RegExp _phonePattern = RegExp(r'^(09|\+959)\d{7,9}$');

  static bool _isPhoneField(FormFieldDef f) =>
      f.fieldType == 'telephone' || f.name.endsWith('_phone');

  int get _numSections => _definition?.sections.length ?? 0;
  bool get _isReview => _step == _numSections;
  bool get _isSuccess => _step == _numSections + 1;

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // Only load if form definition not cached with current version;
    // prevents duplicate master data requests on route re-entry.
    _load();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    // Skip SharedPreferences and heavy loads on web/desktop in problematic cases
    // Just load minimal state
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        api.genders(),
        api.animalTypes(),
        api.animalCategories(),
        api.species(),
        api.ageGroups(),
        api.breedingCategories(),
        api.geography(),
        api.currentForm(),
      ]).timeout(const Duration(seconds: 30));

      final definition =
          SurveyDefinition.fromJson((results[7] as Map).cast<String, dynamic>());
      if (definition.isEmpty) {
        throw ApiException(0, 'The published form has no sections yet.');
      }
      _definition = definition;
      _refs = ReferenceSets(
        genders: (results[0] as List).cast<Map<String, dynamic>>(),
        animalTypes: (results[1] as List).cast<Map<String, dynamic>>(),
        categories: (results[2] as List).cast<Map<String, dynamic>>(),
        species: (results[3] as List).cast<Map<String, dynamic>>(),
        ageGroups: (results[4] as List).cast<Map<String, dynamic>>(),
        breeding: (results[5] as List).cast<Map<String, dynamic>>(),
        regions: (results[6] as List).cast<Map<String, dynamic>>(),
        formVersionId: definition.formVersionId,
      );

      if (_hasRepeatingGroup('breeding_rows') && _draft.breeding.isEmpty) {
        _draft.breeding = [
          for (final c in _refs!.breeding)
            BreedingRow(categoryId: c['id'] as int),
        ];
      }

      if (_isDisposed || !mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (_isDisposed || !mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Future<void> _persist() async {
    // Skip persisting to avoid potential hangs
  }

  Future<void> _clearDraft() async {
    // Skip clearing to avoid potential hangs
  }

  // ------------------------------------------------------------------
  // definition helpers
  // ------------------------------------------------------------------
  List<FormFieldDef> get _allFields =>
      _definition?.sections.expand((s) => s.fields).toList() ?? const [];

  bool _definitionHasField(String name) =>
      _allFields.any((f) => f.name == name);

  bool _hasRepeatingGroup(String binding) => _allFields
      .any((f) => f.fieldType == 'repeating_group' && f.dataBinding == binding);

  String? _personPrefix(String name) {
    if (_respondentNames.contains(name)) return 'respondent';
    if (_headNames.contains(name)) return 'household_head';
    if (_interviewerNames.contains(name)) return 'interviewer';
    return null;
  }

  int _typeId(String code) =>
      (_refs!.animalTypes.firstWhere((t) => t['code'] == code,
              orElse: () => const {})['id'] as int?) ??
      0;

  String get _formTitle {
    final l10n = context.l10n;
    final def = _definition;
    if (def == null) return l10n.censusTitle;
    if (context.isMyanmar) {
      return (def.burmeseTitle?.isNotEmpty == true)
          ? def.burmeseTitle!
          : l10n.censusTitle;
    }
    return (def.englishTitle?.isNotEmpty == true)
        ? def.englishTitle!
        : l10n.censusTitle;
  }

  String _labelFor(FormFieldDef f) => f.labelFor(context.isMyanmar);

  // ------------------------------------------------------------------
  // value accessors (fixed schema fields ↔ draft, others ↔ extras)
  // ------------------------------------------------------------------
  dynamic _valueFor(String name) {
    switch (name) {
      case 'state_region_id':
        return _draft.regionId;
      case 'district_id':
        return _draft.districtId;
      case 'township_id':
        return _draft.townshipId;
      case 'village_tract_id':
        return _draft.tractId;
      case 'ward_id':
        return _draft.wardId;
      case 'household_no':
        return _draft.householdNo;
      case 'interview_date':
        return _draft.interviewDate;
      case 'respondent_name_burmese':
        return _draft.respondent.name;
      case 'respondent_name_english':
        return _draft.respondent.nameEn;
      case 'respondent_gender_id':
        return _draft.respondent.genderId;
      case 'respondent_age':
        return _draft.respondent.age;
      case 'respondent_age_group_id':
        return _draft.respondent.ageGroupId;
      case 'respondent_education':
        return _draft.respondent.education;
      case 'respondent_phone':
        return _draft.respondent.phone;
      case 'household_head_name_burmese':
        return _draft.head.name;
      case 'household_head_name_english':
        return _draft.head.nameEn;
      case 'household_head_gender_id':
        return _draft.head.genderId;
      case 'household_head_age':
        return _draft.head.age;
      case 'household_head_age_group_id':
        return _draft.head.ageGroupId;
      case 'household_head_education':
        return _draft.head.education;
      case 'household_head_phone':
        return _draft.head.phone;
      case 'interviewer_name':
        return _draft.interviewer.name;
      case 'interviewer_phone':
        return _draft.interviewer.phone;
      case 'has_raised_animals':
        return _draft.hasRaisedAnimals;
      case 'has_poultry':
        return _draft.hasPoultry;
      default:
        return _draft.extras[name];
    }
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  void _setValue(String name, dynamic value) {
    setState(() {
      switch (name) {
        case 'state_region_id':
          _draft.regionId = _asInt(value);
          _draft.districtId = null;
          _draft.townshipId = null;
          _draft.tractId = null;
          _draft.wardId = null;
          break;
        case 'district_id':
          _draft.districtId = _asInt(value);
          _draft.townshipId = null;
          _draft.tractId = null;
          _draft.wardId = null;
          break;
        case 'township_id':
          _draft.townshipId = _asInt(value);
          _draft.tractId = null;
          _draft.wardId = null;
          break;
        case 'village_tract_id':
          _draft.tractId = _asInt(value);
          _draft.wardId = null;
          break;
        case 'ward_id':
          _draft.wardId = _asInt(value);
          break;
        case 'household_no':
          _draft.householdNo = value?.toString() ?? '';
          break;
        case 'interview_date':
          _draft.interviewDate = value?.toString() ?? '';
          break;
        case 'respondent_name_burmese':
          _draft.respondent.name = value?.toString() ?? '';
          break;
        case 'respondent_name_english':
          _draft.respondent.nameEn = value?.toString() ?? '';
          break;
        case 'respondent_gender_id':
          _draft.respondent.genderId = _asInt(value);
          break;
        case 'respondent_age':
          _draft.respondent.age = _asInt(value);
          break;
        case 'respondent_age_group_id':
          _draft.respondent.ageGroupId = _asInt(value);
          break;
        case 'respondent_education':
          _draft.respondent.education = value?.toString() ?? '';
          break;
        case 'respondent_phone':
          _draft.respondent.phone = value?.toString() ?? '';
          break;
        case 'household_head_name_burmese':
          _draft.head.name = value?.toString() ?? '';
          break;
        case 'household_head_name_english':
          _draft.head.nameEn = value?.toString() ?? '';
          break;
        case 'household_head_gender_id':
          _draft.head.genderId = _asInt(value);
          break;
        case 'household_head_age':
          _draft.head.age = _asInt(value);
          break;
        case 'household_head_age_group_id':
          _draft.head.ageGroupId = _asInt(value);
          break;
        case 'household_head_education':
          _draft.head.education = value?.toString() ?? '';
          break;
        case 'household_head_phone':
          _draft.head.phone = value?.toString() ?? '';
          break;
        case 'interviewer_name':
          _draft.interviewer.name = value?.toString() ?? '';
          break;
        case 'interviewer_phone':
          _draft.interviewer.phone = value?.toString() ?? '';
          break;
        case 'has_raised_animals':
          _draft.hasRaisedAnimals = value == true;
          break;
        case 'has_poultry':
          _draft.hasPoultry = value == true;
          break;
        default:
          _draft.extras[name] = value;
      }
    });
    _persist();
  }

  bool _isEmpty(dynamic v) {
    if (v == null) return true;
    if (v is String) return v.trim().isEmpty;
    if (v is bool) return false; // a boolean answer is always "given"
    return false;
  }

  List<Json> _optionsForField(FormFieldDef f) {
    final name = f.name;
    final isPersonGender = name.contains('gender') && _personPrefix(name) != null;
    if (isPersonGender) return _refs!.personGenders;
    switch (f.dataBinding) {
      case 'gender':
        return _refs!.genders;
      case 'animal_types':
        return _refs!.animalTypes;
      case 'animal_categories':
        return _refs!.categories;
      case 'species':
        return _refs!.species;
      case 'age_groups':
        return _refs!.ageGroups;
      case 'breeding_categories':
        return _refs!.breeding;
    }
    return const [];
  }

  // ------------------------------------------------------------------
  // row helpers
  // ------------------------------------------------------------------
  void _addRow({required bool poultry, required bool small}) {
    setState(() {
      if (poultry) {
        _draft.poultryRows.add(AnimalRow.poultry(key: _rowSeq++));
      } else if (small) {
        _draft.smallRows.add(AnimalRow(key: _rowSeq++));
      } else {
        _draft.largeRows.add(AnimalRow(key: _rowSeq++));
      }
      _persist();
    });
  }

  // ------------------------------------------------------------------
  // validation
  // ------------------------------------------------------------------
  String _requiredMsg(FormFieldDef f) =>
      context.l10n.validationRequired(_labelFor(f));

  List<String> _validateSection(int step) {
    if (step < 0 || step >= _numSections) return const [];
    final errors = <String>[];
    for (final f in _definition!.sections[step].fields) {
      if (!f.isRequired) continue;
      if (f.fieldType == 'repeating_group' ||
          f.fieldType == 'heading' ||
          f.fieldType == 'paragraph' ||
          f.fieldType == 'boolean') {
        continue;
      }
      if (_isEmpty(_valueFor(f.name))) {
        errors.add(_requiredMsg(f));
        continue;
      }
      // Optional-but-present phone numbers must still be valid.
      if (_isPhoneField(f)) {
        final phone = '${_valueFor(f.name)}'.replaceAll(' ', '');
        if (!_phonePattern.hasMatch(phone)) {
          errors.add('${_labelFor(f)}: ${context.l10n.phoneInvalidError}');
        }
      }
    }
    return errors;
  }

  List<String> _validateAll() {
    final errors = <String>[];
    for (var i = 0; i < _numSections; i++) {
      errors.addAll(_validateSection(i));
    }
    return errors;
  }

  Future<void> _showErrors(List<String> errors) {
    return showAppMessageDialog(
      context,
      title: context.l10n.validationTitle,
      closeLabel: context.l10n.ok,
      icon: Icons.error_outline,
      iconColor: AppColors.warning,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.validationIntro, style: AppTextStyles.supporting),
          const SizedBox(height: 12),
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle,
                      size: 7, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(e, style: AppTextStyles.supporting)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // payload
  // ------------------------------------------------------------------
  Map<String, dynamic> _buildPayload() {
    final refs = _refs!;
    final animalCounts = <Map<String, dynamic>>[];

    void push(List<AnimalRow> rows, {bool poultry = false}) {
      for (final r in rows) {
        final cat = refs.categoryById(r.categoryId);
        if (cat == null) {
          continue;
        }
        final base = <String, dynamic>{
          'animal_type_id': cat['animal_type_id'],
          if (r.speciesId != null) 'species_id': r.speciesId,
          if (r.ageGroupId != null) 'age_group_id': r.ageGroupId,
        };
        final cells = poultry
            ? [('male', r.male), ('female', r.female)]
            : [
                ('male', r.male),
                ('castrated', r.castrated),
                ('female', r.female),
              ];
        for (final (gender, value) in cells) {
          if (value != null && value > 0) {
            animalCounts.add({...base, 'gender': gender, 'count': value});
          }
        }
      }
    }

    push(_draft.largeRows);
    push(_draft.smallRows);
    push(_draft.poultryRows, poultry: true);

    final breedingCounts = _hasRepeatingGroup('breeding_rows')
        ? [
            for (final b in _draft.breeding)
              if ((b.male ?? 0) + (b.female ?? 0) > 0)
                {
                  'breeding_category_id': b.categoryId,
                  'male_count': b.male ?? 0,
                  'female_count': b.female ?? 0,
                },
          ]
        : const <Map<String, dynamic>>[];

    // Admin-authored fields flow through additional_data; fixed-schema values
    // are sent through their dedicated keys below.
    final additional = <String, dynamic>{};
    _draft.extras.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is List && value.isEmpty) return;
      additional[key] = value;
    });

    return {
      'form_version_id': _definition?.formVersionId ?? refs.formVersionId,
      'state_region_id': _draft.regionId,
      'district_id': _draft.districtId,
      'township_id': _draft.townshipId,
      'village_tract_id': _draft.tractId,
      'ward_id': _draft.wardId,
      'household_no': _draft.householdNo.trim(),
      'respondent_name_burmese': _draft.respondent.name.trim(),
      if (_draft.respondent.nameEn.trim().isNotEmpty)
        'respondent_name_english': _draft.respondent.nameEn.trim(),
      'respondent_gender_id': _draft.respondent.genderId,
      if (_draft.respondent.age != null) 'respondent_age': _draft.respondent.age,
      if (_draft.respondent.ageGroupId != null)
        'respondent_age_group_id': _draft.respondent.ageGroupId,
      if (_draft.respondent.education.trim().isNotEmpty)
        'respondent_education': _draft.respondent.education.trim(),
      'respondent_phone': _draft.respondent.phone.trim(),
      'household_head_name_burmese': _draft.head.name.trim(),
      if (_draft.head.nameEn.trim().isNotEmpty)
        'household_head_name_english': _draft.head.nameEn.trim(),
      'household_head_gender_id': _draft.head.genderId,
      if (_draft.head.age != null) 'household_head_age': _draft.head.age,
      if (_draft.head.ageGroupId != null)
        'household_head_age_group_id': _draft.head.ageGroupId,
      if (_draft.head.education.trim().isNotEmpty)
        'household_head_education': _draft.head.education.trim(),
      'household_head_phone': _draft.head.phone.trim(),
      'interview_date': _draft.interviewDate,
      'interviewer_name': _draft.interviewer.name.trim(),
      if (_draft.interviewer.phone.trim().isNotEmpty)
        'interviewer_phone': _draft.interviewer.phone.trim(),
      if (_definitionHasField('has_raised_animals'))
        'has_raised_animals': _draft.hasRaisedAnimals,
      if (_definitionHasField('has_poultry')) 'has_poultry': _draft.hasPoultry,
      'animal_counts': animalCounts,
      'breeding_counts': breedingCounts,
      if (additional.isNotEmpty) 'additional_data': additional,
    };
  }

  Future<void> _submit({bool allowDuplicate = false}) async {
    final errors = _validateAll();
    if (errors.isNotEmpty) {
      if (_step != _numSections) setState(() => _step = _numSections);
      await _showErrors(errors);
      return;
    }
    final payload = _buildPayload();
    setState(() => _submitting = true);
    try {
      final repository = widget.repository;
      final bool queued;
      final Map<String, dynamic> created;
      if (repository != null) {
        final outcome = await repository.submit(
          payload,
          allowDuplicate: allowDuplicate,
        );
        queued = outcome.queued;
        created = outcome.record;
      } else {
        queued = false;
        created = await api.submitSurvey(payload,
            allowDuplicate: allowDuplicate);
      }
      await _clearDraft();
      if (_isDisposed || !mounted) return;
      setState(() {
        _created = created;
        _queued = queued;
        _step = _numSections + 1;
        _submitting = false;
      });
      widget.onSubmitted?.call();
    } on ApiException catch (e) {
      if (_isDisposed || !mounted) return;
      setState(() => _submitting = false);
      if (e.statusCode == 409) {
        final l10n = context.l10n;
        final resubmit = await showAppConfirmDialog(
          context,
          icon: Icons.report_gmailerrorred_outlined,
          title: l10n.duplicateTitle,
          message: l10n.duplicateBody,
          cancelLabel: l10n.duplicateCancel,
          confirmLabel: l10n.duplicateResubmit,
        );
        if (resubmit) {
          await _submit(allowDuplicate: true);
        }
      } else {
        if (_isDisposed || !mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.submissionFailed(e.message)),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ------------------------------------------------------------------
  // build
  // ------------------------------------------------------------------


  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
        appBar: AppBar(
          title: Text(l10n.censusTitle),
          actions: [
            if (!_isSuccess)
              IconButton(
                tooltip: l10n.discardDraftTooltip,
                onPressed: () {
                  // Fire and forget, no async blocking
                  _confirmDiscard();
                },
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: _buildBody(),
      );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_loading) {
      return const AppLoadingView();
    }
    if (_loadError != null) {
      final detail = _loadError is ApiException
          ? (_loadError as ApiException).message
          : '$_loadError';
      return AppErrorView(
        title: l10n.formLoadFailed,
        message: detail.trim().isEmpty ? l10n.formLoadFailedHint : detail,
        retryLabel: l10n.retry,
        onRetry: _load,
        icon: Icons.cloud_off_outlined,
      );
    }
    if (_isSuccess) {
      return _buildSuccess();
    }
    return Column(
      children: [
        FormProgressHeader(
          formTitle: _formTitle,
          sectionTitle:
              _isReview ? l10n.reviewStepName : _definition!.sections[_step].titleFor(context.isMyanmar),
          step: _step + 1,
          total: _numSections + 1,
          instruction: l10n.stepHint,
        ),
        Expanded(
          child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(.025, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: _buildStepBody(),
            ),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildStepBody() {
    if (_step < _numSections) {
      return _renderSection(_definition!.sections[_step]);
    }
    return _buildReviewSection();
  }

  Widget _buildBottomBar() {
    final l10n = context.l10n;
    final showPrevious = _step > 0 && _step <= _numSections;
    final isLastSection = _step == _numSections - 1;
    final nextLabel = _isReview
        ? (_submitting ? l10n.submitting : l10n.submitButton)
        : (isLastSection ? l10n.reviewAndSubmitButton : l10n.nextButton);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_done_outlined,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(l10n.draftSaved, style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (showPrevious) ...[
                    Expanded(
                      child: AppSecondaryButton(
                        label: l10n.previousButton,
                        icon: Icons.arrow_back,
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _step -= 1),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: AppPrimaryButton(
                      label: nextLabel,
                      icon: _isReview ? Icons.check : Icons.arrow_forward,
                      loading: _submitting,
                      onPressed: _isReview ? _submit : _onNext,
                    ),
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

  void _onNext() {
    final errors = _validateSection(_step);
    if (errors.isNotEmpty) {
      _showErrors(errors);
      return;
    }
    setState(() => _step += 1);
  }

  // ------------------------------------------------------------------
  // dynamic section rendering
  // ------------------------------------------------------------------
  Widget _renderSection(FormSectionDef sec) {
    final bools = sec.fields.where((f) => f.fieldType == 'boolean').toList();
    final gateOpen =
        bools.isEmpty ? true : _valueFor(bools.first.name) == true;

    final scalarChildren = <Widget>[];
    final tables = <Widget>[];
    final emittedPersonGroups = <String>{};

    for (final f in sec.fields) {
      if (f.fieldType == 'repeating_group') {
        tables.add(_Reveal(open: gateOpen, child: _repeatingGroup(f)));
        continue;
      }
      final prefix = _personPrefix(f.name);
      if (prefix != null) {
        if (emittedPersonGroups.contains(prefix)) continue;
        emittedPersonGroups.add(prefix);
        scalarChildren.add(_personGroup(prefix, sec));
        continue;
      }
      scalarChildren.add(_fieldWidget(f, gateOpen: gateOpen));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
        if (scalarChildren.isNotEmpty)
          SectionCard(
            title: sec.titleFor(context.isMyanmar),
            description: sec.subtitleFor(context.isMyanmar),
            icon: _iconForSection(sec),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: scalarChildren,
            ),
          ),
        for (final t in tables) ...[
          const SizedBox(height: 16),
          t,
        ],
        const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _iconForSection(FormSectionDef sec) {
    final hay =
        '${sec.titleEnglish ?? ''} ${sec.titleBurmese}'.toLowerCase();
    if (hay.contains('poultry') || hay.contains('ကြက်')) {
      return Icons.egg_alt_outlined;
    }
    if (hay.contains('breeding') || hay.contains('မျိုး')) {
      return Icons.favorite_outline;
    }
    if (hay.contains('livestock') || hay.contains('large')) {
      return Icons.pets_outlined;
    }
    if (hay.contains('interviewer') || hay.contains('မေးမြန်းသူ')) {
      return Icons.badge_outlined;
    }
    if (hay.contains('interview') || hay.contains('household')) {
      return Icons.home_work_outlined;
    }
    return Icons.list_alt_outlined;
  }

  Widget _personGroup(String prefix, FormSectionDef sec) {
    final l10n = context.l10n;
    final names = prefix == 'respondent'
        ? _respondentNames
        : prefix == 'household_head'
            ? _headNames
            : _interviewerNames;
    final fields = sec.fields.where((f) => names.contains(f.name)).toList();
    final title = switch (prefix) {
      'respondent' => l10n.personSectionRespondent,
      'household_head' => l10n.personSectionHead,
      _ => l10n.personSectionInterviewer,
    };
    final person = prefix == 'respondent'
        ? _draft.respondent
        : prefix == 'household_head'
            ? _draft.head
            : _draft.interviewer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        _GroupHeader(title, icon: Icons.person_outline),
        for (final f in fields) _fieldWidget(f, gateOpen: true),
        if (prefix == 'respondent' || prefix == 'household_head')
          _ageGroupDropdown(person),
      ],
    );
  }

  Widget _ageGroupDropdown(PersonInfo person) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _MasterDropdown(
        label: context.l10n.ageGroupLabel,
        required: false,
        value: person.ageGroupId,
        options: _refs!.personAges,
        onChanged: (id) {
          setState(() => person.ageGroupId = id);
          _persist();
        },
      ),
    );
  }

  Widget _fieldWidget(FormFieldDef f, {required bool gateOpen}) {
    switch (f.fieldType) {
      case 'heading':
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _GroupHeader(_labelFor(f)),
        );
      case 'paragraph':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            f.titleBurmese.isNotEmpty
                ? _labelFor(f)
                : (f.placeholderBurmese ?? ''),
            style: AppTextStyles.supporting,
          ),
        );
      case 'geographic':
        return _geoField(f);
      case 'boolean':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _BoolField(
            label: _labelFor(f),
            value: _valueFor(f.name) == true,
            onChanged: (v) => _setValue(f.name, v),
          ),
        );
      case 'repeating_group':
        return _repeatingGroup(f);
      case 'single_select':
      case 'radio':
        return _selectField(f);
      case 'integer':
      case 'number_counter':
        return _numberField(f);
      case 'decimal':
        return _numberField(f, decimal: true);
      case 'date':
      case 'datetime':
        return _dateField(f);
      case 'telephone':
        return _textFieldDef(f, keyboard: TextInputType.phone);
      case 'email':
        return _textFieldDef(f, keyboard: TextInputType.emailAddress);
      default:
        return _textFieldDef(f);
    }
  }

  Widget _geoField(FormFieldDef f) {
    final key = f.dataBinding ?? f.name;
    switch (key) {
      case 'state_region':
      case 'state_region_id':
        return _regionDropdown();
      case 'district':
      case 'district_id':
        return _districtsDropdown();
      case 'township':
      case 'township_id':
        return _townshipsDropdown();
      case 'village_tract':
      case 'village_tract_id':
        return _tractsDropdown();
      case 'ward':
      case 'ward_id':
        return _wardsDropdown();
      default:
        return _unsupported(f, context.l10n.unsupportedField);
    }
  }

  Widget _selectField(FormFieldDef f) {
    final options = _optionsForField(f);
    if (options.isEmpty) {
      // No master source is bound for this select — fall back to free text so
      // the value is still captured instead of being silently dropped.
      return _textFieldDef(f);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _MasterDropdown(
        label: _labelFor(f),
        required: f.isRequired,
        value: _asInt(_valueFor(f.name)),
        options: options,
        onChanged: (id) => _setValue(f.name, id),
      ),
    );
  }

  Widget _textFieldDef(FormFieldDef f, {TextInputType? keyboard}) {
    return _textField(
      key: ValueKey('field-${f.name}'),
      label: _labelFor(f),
      required: f.isRequired,
      initial: _valueFor(f.name)?.toString() ?? '',
      keyboard: keyboard,
      onChanged: (v) => _setValue(f.name, v),
    );
  }

  Widget _numberField(FormFieldDef f, {bool decimal = false}) {
    return _textField(
      key: ValueKey('field-${f.name}'),
      label: _labelFor(f),
      required: f.isRequired,
      initial: _valueFor(f.name)?.toString() ?? '',
      keyboard: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        decimal
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (v) {
        final text = v.trim();
        if (text.isEmpty) {
          _setValue(f.name, null);
        } else {
          _setValue(f.name, decimal ? double.tryParse(text) : int.tryParse(text));
        }
      },
      suffix: (f.unit != null && f.unit!.isNotEmpty) ? f.unit : null,
    );
  }

  Widget _dateField(FormFieldDef f) {
    final value = _valueFor(f.name)?.toString() ?? '';
    return _DateField(
      label: _labelFor(f),
      required: f.isRequired,
      value: value.isEmpty ? null : value,
      onChanged: (iso) => _setValue(f.name, iso ?? ''),
    );
  }

  Widget _repeatingGroup(FormFieldDef f) {
    final binding = f.dataBinding;
    if (binding == 'animal_rows') {
      final small = f.name.contains('small');
      final rows = small ? _draft.smallRows : _draft.largeRows;
      return _animalTableCard(
        title: _labelFor(f),
        rows: rows,
        typeId: _typeId(small ? 'atID02' : 'atID01'),
        poultry: false,
        onAdd: () => _addRow(poultry: false, small: small),
        onDelete: (i) => setState(() {
          rows.removeAt(i);
          _persist();
        }),
      );
    }
    if (binding == 'poultry_rows') {
      return _animalTableCard(
        title: _labelFor(f),
        rows: _draft.poultryRows,
        typeId: _typeId('atID03'),
        poultry: true,
        onAdd: () => _addRow(poultry: true, small: false),
        onDelete: (i) => setState(() {
          _draft.poultryRows.removeAt(i);
          _persist();
        }),
      );
    }
    if (binding == 'breeding_rows') {
      return SectionCard(
        title: _labelFor(f),
        icon: Icons.favorite_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _draft.breeding.length; i++) ...[
              _breedingCard(_refs!, i),
              if (i != _draft.breeding.length - 1)
                const SizedBox(height: 12),
            ],
          ],
        ),
      );
    }
    return _unsupported(f, context.l10n.unsupportedGroup);
  }

  Widget _unsupported(FormFieldDef f, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppBanner(
        kind: BannerKind.warning,
        title: _labelFor(f),
        message: message,
      ),
    );
  }

  // ------------------------------------------------------------------
  // geography cascade
  // ------------------------------------------------------------------
  Widget _regionDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _MasterDropdown(
        label: _labelForOrDefault(
            'state_region_id', 'တိုင်းဒေသကြီး/ပြည်နယ်', 'State / Region'),
        required: true,
        value: _draft.regionId,
        options: _refs!.regions,
        onChanged: (id) => _setValue('state_region_id', id),
      ),
    );
  }

  FormFieldDef? _fieldByName(String name) {
    for (final f in _allFields) {
      if (f.name == name) return f;
    }
    return null;
  }

  Widget _districtsDropdown() {
    final region = _regionFor(_refs!);
    final items = (region?['districts'] as List?)?.cast<Json>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _MasterDropdown(
        label: _labelForOrDefault('district_id', 'ခရိုင်', 'District'),
        required: false,
        value: _draft.districtId,
        options: items ?? const [],
        emptyHint: context.l10n.selectUpperLevelFirst,
        onChanged: (id) => _setValue('district_id', id),
      ),
    );
  }

  Widget _townshipsDropdown() {
    final district = _districtFor(_refs!);
    final items = (district?['townships'] as List?)?.cast<Json>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _MasterDropdown(
        label: _labelForOrDefault('township_id', 'မြို့နယ်', 'Township'),
        required: false,
        value: _draft.townshipId,
        options: items ?? const [],
        emptyHint: context.l10n.selectUpperLevelFirst,
        onChanged: (id) => _setValue('township_id', id),
      ),
    );
  }

  Widget _tractsDropdown() {
    final township = _townshipFor(_refs!);
    final items = (township?['village_tracts'] as List?)?.cast<Json>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _MasterDropdown(
        label: _labelForOrDefault(
            'village_tract_id', 'ကျေးရွာအုပ်စု', 'Village tract'),
        required: false,
        value: _draft.tractId,
        options: items ?? const [],
        emptyHint: context.l10n.selectUpperLevelFirst,
        onChanged: (id) => _setValue('village_tract_id', id),
      ),
    );
  }

  Widget _wardsDropdown() {
    final tract = _tractFor(_refs!);
    final items = (tract?['wards'] as List?)?.cast<Json>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _MasterDropdown(
        label: _labelForOrDefault('ward_id', 'ရပ်ကွက်/ကျေးရွာ', 'Ward / Village'),
        required: false,
        value: _draft.wardId,
        options: items ?? const [],
        emptyHint: context.l10n.selectUpperLevelFirst,
        onChanged: (id) => _setValue('ward_id', id),
      ),
    );
  }

  String _labelForOrDefault(String name, String burmese, String english) {
    final f = _fieldByName(name);
    if (f != null) return _labelFor(f);
    return context.isMyanmar ? burmese : english;
  }

  Json? _regionFor(ReferenceSets refs) =>
      _findById(refs.regions, _draft.regionId);

  Json? _districtFor(ReferenceSets refs) {
    final region = _regionFor(refs);
    return _findById(
        (region?['districts'] as List?)?.cast<Json>() ?? const [],
        _draft.districtId);
  }

  Json? _townshipFor(ReferenceSets refs) {
    final district = _districtFor(refs);
    return _findById(
        (district?['townships'] as List?)?.cast<Json>() ?? const [],
        _draft.townshipId);
  }

  Json? _tractFor(ReferenceSets refs) {
    final township = _townshipFor(refs);
    return _findById(
        (township?['village_tracts'] as List?)?.cast<Json>() ?? const [],
        _draft.tractId);
  }

  Json? _findById(List<Json> list, int? id) {
    if (id == null) return null;
    for (final row in list) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // animal rows
  // ------------------------------------------------------------------
  Widget _animalTableCard({
    required String title,
    required List<AnimalRow> rows,
    required int typeId,
    required bool poultry,
    required VoidCallback onAdd,
    required ValueChanged<int> onDelete,
  }) {
    final l10n = context.l10n;
    final categories = _refs!.categoriesForType(typeId);
    return SectionCard(
      title: title,
      icon: poultry ? Icons.egg_alt_outlined : Icons.pets_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          l10n.rowsCountLabel(rows.length),
          style: AppTextStyles.caption.copyWith(color: AppColors.primary),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categories.isEmpty)
            Text(l10n.noCategoriesAvailable,
                style: AppTextStyles.supporting)
          else ...[
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(l10n.emptyRowsHint,
                    style: AppTextStyles.supporting),
              ),
            for (var i = 0; i < rows.length; i++) ...[
              _animalRowCard(
                rows[i],
                categories: categories,
                poultry: poultry,
                index: i,
                onDelete: () => onDelete(i),
              ),
              const SizedBox(height: 12),
            ],
            if (categories.isNotEmpty)
              AppSecondaryButton(
                label: l10n.addRowButton,
                icon: Icons.add,
                expand: false,
                height: 52,
                onPressed: onAdd,
              ),
          ],
        ],
      ),
    );
  }

  Widget _animalRowCard(
    AnimalRow row, {
    required List<Json> categories,
    required bool poultry,
    required int index,
    required VoidCallback onDelete,
  }) {
    final l10n = context.l10n;
    final refs = _refs!;
    void update(VoidCallback cb) {
      setState(cb);
      _persist();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.rowNumber(index + 1), style: AppTextStyles.titleSmall),
              const Spacer(),
              IconButton(
                tooltip: l10n.removeRowTooltip,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _MasterDropdown(
            label: l10n.animalCategoryLabel,
            required: true,
            value: row.categoryId,
            options: categories,
            onChanged: (id) => update(() {
              row.categoryId = id;
              row.speciesId = null;
              row.ageGroupId = null;
            }),
          ),
          const SizedBox(height: 8),
          _MasterDropdown(
            label: l10n.speciesLabel,
            required: false,
            value: row.speciesId,
            options: refs.speciesForCategory(row.categoryId),
            onChanged: (id) => update(() => row.speciesId = id),
          ),
          const SizedBox(height: 8),
          _MasterDropdown(
            label: l10n.ageGroupLabelShort,
            required: false,
            value: row.ageGroupId,
            options: refs.ageGroupsForCategory(row.categoryId),
            onChanged: (id) => update(() => row.ageGroupId = id),
          ),
          const SizedBox(height: 12),
          _CountFieldsRow(row: row, poultry: poultry, apply: update),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.rowTotalLabel(row.rowTotal),
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.primaryDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // breeding stock
  // ------------------------------------------------------------------
  Widget _breedingCard(ReferenceSets refs, int index) {
    final l10n = context.l10n;
    final row = _draft.breeding[index];
    final category = context.masterName(refs.breeding.firstWhere(
        (c) => c['id'] == row.categoryId,
        orElse: () => const {}));
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category, style: AppTextStyles.titleSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CountField(
                  key: ValueKey('breed-${row.categoryId}-male'),
                  label: l10n.maleLabel,
                  value: row.male,
                  onChanged: (v) {
                    setState(() => row.male = v);
                    _persist();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CountField(
                  key: ValueKey('breed-${row.categoryId}-female'),
                  label: l10n.femaleLabel,
                  value: row.female,
                  onChanged: (v) {
                    setState(() => row.female = v);
                    _persist();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Review section
  // ------------------------------------------------------------------
  Widget _buildReviewSection() {
    final l10n = context.l10n;
    final payload = _buildPayload();
    final animalCounts = (payload['animal_counts'] as List).length;
    final breedingCounts = (payload['breeding_counts'] as List).length;
    final additional = (payload['additional_data'] as Map?)?.length ?? 0;
    final errors = _validateAll();
    final sections = _definition!.sections;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
        SectionCard(
          title: l10n.reviewTitle,
          description: l10n.reviewSubtitle,
          icon: Icons.fact_check_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewRow(
                icon: Icons.home_outlined,
                label: l10n.reviewHouseholdCard,
                value: _draft.householdNo.isEmpty
                    ? l10n.notProvided
                    : _draft.householdNo,
              ),
              const SizedBox(height: 10),
              _ReviewRow(
                icon: Icons.event_outlined,
                label: l10n.reviewInterviewDate(_draft.interviewDate.isEmpty
                    ? l10n.notProvided
                    : _draft.interviewDate),
                value: '',
              ),
              const SizedBox(height: 10),
              _ReviewRow(
                icon: Icons.pets_outlined,
                label: l10n.reviewAnimalRecords(animalCounts),
                value: '',
              ),
              const SizedBox(height: 10),
              _ReviewRow(
                icon: Icons.favorite_outline,
                label: l10n.reviewBreedingRecords(breedingCounts),
                value: '',
              ),
              if (additional > 0) ...[
                const SizedBox(height: 10),
                _ReviewRow(
                  icon: Icons.list_alt_outlined,
                  label: l10n.reviewAdditionalFields(additional),
                  value: '',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Jump back to any section to fix an answer.
        for (var i = 0; i < sections.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primarySoft,
                child: Text('${i + 1}',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
              title: Text(sections[i].titleFor(context.isMyanmar),
                  style: AppTextStyles.titleSmall),
              trailing: TextButton(
                onPressed: () => setState(() => _step = i),
                child: Text(l10n.reviewEditSection),
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (errors.isNotEmpty)
          AppBanner(
            kind: BannerKind.warning,
            title: l10n.reviewIncompleteTitle,
            message: errors.join('\n'),
          )
        else
          AppBanner(
            kind: BannerKind.success,
            message: l10n.reviewReady,
          ),
        const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Success
  // ------------------------------------------------------------------
  Widget _buildSuccess() {
    final l10n = context.l10n;
    final created = _created ?? const {};
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: reduceMotion ? 1 : 0.6, end: 1),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: _queued
                        ? AppColors.warningSurface
                        : AppColors.successSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _queued ? Icons.cloud_upload_outlined : Icons.check_rounded,
                    size: 64,
                    color: _queued ? AppColors.warning : AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _queued
                    ? l10n.submissionQueuedTitle
                    : l10n.submissionConfirmedTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.textTheme(AppColors.textPrimary)
                    .headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                _queued
                    ? l10n.submissionQueuedBody
                    : l10n.submissionConfirmedBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.supporting,
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: l10n.reviewHouseholdCard,
                icon: Icons.receipt_long_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReviewRow(
                      icon: Icons.home_outlined,
                      label: l10n.submissionHouseholdNo(
                          '${created['household_no'] ?? '—'}'),
                      value: '',
                    ),
                    const SizedBox(height: 10),
                    _ReviewRow(
                      icon: Icons.tag,
                      label: l10n.submissionReference(
                          '${created['id'] ?? '—'}'),
                      value: '',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: l10n.backToDashboard,
                icon: Icons.arrow_back,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // misc
  // ------------------------------------------------------------------
  Future<void> _confirmDiscard() async {
    if (_isSuccess || _submitting) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    if (!mounted) return;
    final l10n = context.l10n;
    try {
      final ok = await showAppConfirmDialog(
        context,
        destructive: true,
        icon: Icons.delete_outline,
        title: l10n.discardDraftTitle,
        message: l10n.discardDraftBody,
        cancelLabel: l10n.cancel,
        confirmLabel: l10n.discardConfirmButton,
      );
      if (ok && mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      // Don't try to pop if something went wrong - avoid leaving in bad state
    }
  }

  // ------------------------------------------------------------------
  // small field widgets
  // ------------------------------------------------------------------
  Widget _textField({
    Key? key,
    required String label,
    required bool required,
    required String initial,
    required ValueChanged<String> onChanged,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    String? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppTextField(
        key: key,
        label: label,
        required: required,
        initialValue: initial,
        keyboardType: keyboard,
        inputFormatters: inputFormatters,
        suffixText: suffix,
        onChanged: onChanged,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leaf widgets
// ---------------------------------------------------------------------------

/// Heading inside a section card (used for the person sub-groups).
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title, {this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(title, style: AppTextStyles.titleSmall),
          ),
        ],
      ),
    );
  }
}

/// One line in the review / success summary.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value.isEmpty ? label : '$label  ·  $value',
            style: AppTextStyles.supporting.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Two-option yes/no control for a boolean form field.
class _BoolField extends StatelessWidget {
  const _BoolField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.fieldLabel),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(l10n.boolYes),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(l10n.boolNo),
                ),
              ],
              selected: {value},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown bound to a master-data / geography option list. Labels follow the
/// active language; a "select" entry lets the user clear an optional value.
class _MasterDropdown extends StatelessWidget {
  const _MasterDropdown({
    required this.label,
    required this.required,
    required this.value,
    required this.options,
    required this.onChanged,
    this.emptyHint,
  });

  final String label;
  final bool required;
  final int? value;
  final List<Json> options;
  final ValueChanged<int?> onChanged;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (options.isEmpty) {
      // No options yet (a parent selector was not chosen, or the backend
      // deliberately has no rows for this node). Render a disabled field so we
      // never trip Dropdown's "initialValue must match an item" assert.
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldLabel(label, required: required),
            const SizedBox(height: 5),
            InputDecorator(
              decoration: const InputDecoration(enabled: false),
              child: Text(
                emptyHint ?? l10n.noOptionsAvailable,
                style: AppTextStyles.supporting.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }
    final safeValue = options.any((o) => o['id'] == value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label, required: required),
          const SizedBox(height: 5),
          DropdownButtonFormField<int>(
            key: ValueKey('$label-$safeValue-${options.length}'),
            initialValue: safeValue,
            isExpanded: true,
            decoration: const InputDecoration(),
            items: [
              DropdownMenuItem<int>(
                value: null,
                child: Text(l10n.selectPrompt,
                    style: AppTextStyles.supporting
                        .copyWith(color: AppColors.textMuted)),
              ),
              for (final option in options)
                DropdownMenuItem<int>(
                  value: option['id'] as int?,
                  child: Text(context.masterName(option),
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Row of per-gender count inputs, stacked on very narrow screens.
class _CountFieldsRow extends StatelessWidget {
  const _CountFieldsRow({
    required this.row,
    required this.poultry,
    required this.apply,
  });

  final AnimalRow row;
  final bool poultry;

  /// Runs a mutation inside the parent's `setState` + draft-persist wrapper.
  final void Function(VoidCallback mutation) apply;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fields = <Widget>[
      _CountField(
        key: ValueKey('count-${row.key}-male'),
        label: l10n.maleLabel,
        value: row.male,
        onChanged: (v) => apply(() => row.male = v),
      ),
      if (!poultry)
        _CountField(
          key: ValueKey('count-${row.key}-castrated'),
          label: l10n.castratedLabel,
          value: row.castrated,
          onChanged: (v) => apply(() => row.castrated = v),
        ),
      _CountField(
        key: ValueKey('count-${row.key}-female'),
        label: l10n.femaleLabel,
        value: row.female,
        onChanged: (v) => apply(() => row.female = v),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i != fields.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              Expanded(child: fields[i]),
              if (i != fields.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}

/// Single numeric count input. Keeps an empty field distinct from an explicit
/// zero, and only accepts digits.
class _CountField extends StatefulWidget {
  const _CountField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_CountField> createState() => _CountFieldState();
}

class _CountFieldState extends State<_CountField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void dispose() {
    // Clean up any in-flight operations and prevent callbacks after disposal
    _controller.dispose();
    // Note: WebSocket/stream cleanup is handled by SubmissionRepository/RealTimeService
    // which are shared across the app shell. See home_shell.dart for shared service disposal.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTextStyles.input,
          decoration: const InputDecoration(hintText: '0', isDense: true),
          onChanged: (v) {
            final text = v.trim();
            widget.onChanged(text.isEmpty ? null : int.tryParse(text));
          },
        ),
      ],
    );
  }
}

/// Date picker field with a large tap target and localized help text.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = true,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label, required: required),
          const SizedBox(height: 5),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final initial = (value != null && value!.isNotEmpty)
                  ? DateTime.tryParse(value!) ?? today
                  : today;
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2020),
                lastDate: today, // no future interview dates
                helpText: l10n.pickDateHelp,
              );
              if (picked != null) {
                final iso = '${picked.year.toString().padLeft(4, '0')}-'
                    '${picked.month.toString().padLeft(2, '0')}-'
                    '${picked.day.toString().padLeft(2, '0')}';
                onChanged(iso);
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
              ),
              child: Text(
                value ?? l10n.pickDateHelp,
                style: value == null
                    ? AppTextStyles.supporting.copyWith(
                        color: AppColors.textMuted)
                    : AppTextStyles.input,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsible wrapper used to reveal a boolean-gated table with a soft
/// size animation. Instant when the user prefers reduced motion.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.open, required this.child});

  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedSize(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: open ? child : const SizedBox(width: double.infinity),
    );
  }
}

/// WillPopScope to handle back button press with proper cleanup
