import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted application language.
///
/// Exactly two languages are supported: English (`en`) and Myanmar (`my`).
/// The selection is written to [SharedPreferences] so it survives an app
/// restart, and exposed through a [ValueNotifier] so switching updates the whole
/// UI immediately without restarting or rebuilding form state.
class LocaleController extends ValueNotifier<Locale> {
  LocaleController._(super.value);

  static const String _prefsKey = 'moali_locale';
  static const String languageCodeEnglish = 'en';
  static const String languageCodeMyanmar = 'my';

  static const List<Locale> supportedLocales = [Locale('en'), Locale('my')];

  /// Myanmar is the default: the enumerators this app is built for read it.
  static const Locale defaultLocale = Locale(languageCodeMyanmar);

  static Future<LocaleController> load() async {
    Locale initial = defaultLocale;
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      final code = prefs.getString(_prefsKey);
      if (code != null &&
          supportedLocales.any((l) => l.languageCode == code)) {
        initial = Locale(code);
      }
    } catch (_) {
      // Fall back to the default when preferences are unavailable.
    }
    return LocaleController._(initial);
  }

  bool get isMyanmar => value.languageCode == languageCodeMyanmar;

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == value.languageCode) return;
    value = locale;
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      await prefs.setString(_prefsKey, locale.languageCode);
    } catch (_) {
      // Non-fatal: the in-memory selection still applies for this session.
    }
  }

  Future<void> setLanguageCode(String code) =>
      setLocale(Locale(supportedLocales.any((l) => l.languageCode == code)
          ? code
          : defaultLocale.languageCode));

  Future<void> toggle() => setLocale(
        isMyanmar
            ? const Locale(languageCodeEnglish)
            : defaultLocale,
      );

  /// Reads the controller from the tree (see [LocaleScope]).
  static LocaleController of(BuildContext context) => LocaleScope.of(context);
}

/// InheritedNotifier that carries the [LocaleController] down the tree, so
/// `LocaleController.of(context)` rebuilds dependents when the language changes.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'LocaleScope not found in the widget tree');
    return scope!.notifier!;
  }
}
