// Regression tests for the redesigned Home and Settings tabs.
//
// These render the two tabs at a deliberately narrow phone width (360 dp) — the
// surface on which the old home screen produced
// `BOTTOM OVERFLOWED BY 1.00 PIXELS` — so a layout regression fails the build
// instead of shipping. The backend is replaced by a fake client, so no network
// is touched.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moali.itlens/api/api_client.dart';
import 'package:moali.itlens/app/theme/app_theme.dart';
import 'package:moali.itlens/core/localization/locale_controller.dart';
import 'package:moali.itlens/core/storage/local_store.dart';
import 'package:moali.itlens/features/home/home_tab.dart';
import 'package:moali.itlens/features/home/submission_repository.dart';
import 'package:moali.itlens/features/settings/settings_tab.dart';
import 'package:moali.itlens/l10n/generated/app_localizations.dart';
import 'package:moali.itlens/realtime/realtime_service.dart';

/// An [ApiClient] that never leaves the process.
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.invalid');

  @override
  Future<Map<String, dynamic>> listSubmissions({
    int page = 1,
    int pageSize = 25,
    String? search,
    int? stateRegionId,
    bool mine = false,
  }) async {
    return {
      'items': [
        {
          'id': 'srv-1',
          'household_no': 'HH-001',
          'collection_status': 'approved',
          'interview_date': '2026-10-14',
          'respondent_name_burmese': 'ဦးမောင်',
          'township': 'တာမွေ',
          'state_region': 'ရန်ကုန်',
        },
        {
          'id': 'srv-2',
          'household_no': 'HH-002',
          'collection_status': 'submitted',
          'interview_date': '2026-10-14',
          'respondent_name_burmese': 'ဒေါ်ခင်',
          'township': 'တာမွေ',
          'state_region': 'ရန်ကုန်',
        },
      ],
      'total': 2,
    };
  }
}

const _user = SessionUser(
  id: 'u1',
  name: 'Aung Aung',
  email: 'aung@moali.example.com',
  role: 'enumerator',
);

Future<SubmissionRepository> _seededRepository() async {
  final repo = SubmissionRepository(
    client: _FakeApi(),
    store: LocalStore(opener: SharedPreferences.getInstance),
  );
  await repo.init(_user.id);
  return repo;
}

Future<Widget> _host(Widget child) async {
  final controller = await LocaleController.load();
  return LocaleScope(
    controller: controller,
    child: ValueListenableBuilder<Locale>(
      valueListenable: controller,
      builder: (context, locale, _) => MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  testWidgets('Home tab renders its summary without overflowing at 360 dp',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = await _seededRepository();
    final status = ValueNotifier(RealtimeStatus.disconnected);

    await tester.pumpWidget(await _host(HomeTab(
      user: _user,
      repository: repo,
      status: status,
      onOpenSurvey: () async {},
      onOpenHistory: () {},
    )));
    await tester.pumpAndSettle();

    // A layout overflow would be thrown as a test failure above; assert the
    // tiles and the captured row rendered.
    expect(find.byType(HomeTab), findsOneWidget);
    expect(find.textContaining('HH-001'), findsWidgets);
  });

  testWidgets('Settings tab renders account, offline manager and history',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = await _seededRepository();
    final status = ValueNotifier(RealtimeStatus.connected);

    await tester.pumpWidget(await _host(SettingsTab(
      user: _user,
      repository: repo,
      status: status,
      onOpenSurvey: () async {},
      onSignedOut: () async {},
    )));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsTab), findsOneWidget);
    // Account details are visible at the top of the settings list.
    expect(find.text('aung@moali.example.com'), findsWidgets);

    // The auto-sync toggle sits in the offline manager, further down.
    await tester.scrollUntilVisible(find.byType(Switch), 240);
    expect(find.byType(Switch), findsOneWidget);

    // The scoped history is listed below that.
    await tester.scrollUntilVisible(find.textContaining('HH-001'), 240);
    expect(find.textContaining('HH-001'), findsWidgets);
  });
}
