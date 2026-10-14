// Widget tests for the MOALI app.
//
// With no session cookie present the app should render the sign-in screen. The
// backend is never contacted in these tests because `ApiClient.me()`
// short-circuits when it holds no cookie, and `LocaleController.load()`
// silently falls back to the default (Myanmar) locale when preferences are
// unavailable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moali.itlens/core/localization/locale_controller.dart';
import 'package:moali.itlens/core/widgets/app_button.dart';
import 'package:moali.itlens/core/widgets/app_text_field.dart';
import 'package:moali.itlens/features/auth/screens/login_screen.dart';
import 'package:moali.itlens/features/auth/screens/register_screen.dart';
import 'package:moali.itlens/main.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  final controller = await LocaleController.load();
  await tester.pumpWidget(MOALIApp(localeController: controller));
  await tester.pumpAndSettle();
}

void main() {
  // Register an in-memory preference store. Without this the shared_preferences
  // platform channel never answers in a unit-test environment and the awaited
  // `getInstance()` call would hang indefinitely.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // The app has subtle, continuous "breathing" animations (the Google button
    // rim, skeletons, brand glow). Ask for reduced motion so pumpAndSettle can
    // reach a steady state instead of waiting on an endless repeating frame.
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  testWidgets('Shows the sign-in screen when there is no session',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing);

    // Email + password inputs.
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.byType(AppPasswordField), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('Can switch between sign-in and create-account',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    // Tap the "I don't have an account" action. It sits below the fold on the
    // small default test surface, so scroll it into view first.
    await tester.ensureVisible(find.byType(AppTextAction));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppTextAction));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);

    // Name, email + password inputs on the register form.
    expect(find.byType(AppTextField), findsNWidgets(2));
    expect(find.byType(AppPasswordField), findsOneWidget);
  });

  testWidgets('Switching language keeps the auth screen in place',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    final context = tester.element(find.byType(LoginScreen));
    expect(Localizations.localeOf(context).languageCode, 'my');

    final controller = LocaleController.of(context);
    await controller.setLanguageCode('en');
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(Localizations.localeOf(tester.element(find.byType(LoginScreen)))
        .languageCode, 'en');
  });
}
