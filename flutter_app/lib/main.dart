import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'app/theme/app_text_styles.dart';
import 'app/theme/app_theme.dart';
import 'core/localization/l10n_ext.dart';
import 'core/localization/locale_controller.dart';
import 'core/widgets/feedback.dart';
import 'features/auth/auth_flow.dart';
import 'features/shell/home_shell.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore any saved session before the auth gate runs so a returning user
  // lands straight in the app instead of on the sign-in screen.
  await api.restoreSession();
  final localeController = await LocaleController.load();
  runApp(MOALIApp(localeController: localeController));
}

/// Application root. Hosts the [MaterialApp] with the MOALI soft-UI theme, the
/// two supported locales (Myanmar / English) and the persisted language choice.
class MOALIApp extends StatelessWidget {
  const MOALIApp({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      controller: localeController,
      child: ValueListenableBuilder<Locale>(
        valueListenable: localeController,
        builder: (context, locale, _) {
          return MaterialApp(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------
// Auth gate: decides between sign-in, the signed-in shell and a connection
// error.
// ---------------------------------------------------------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  SessionUser? _user;
  bool _checking = true;
  ApiException? _connectionError;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    setState(() {
      _checking = true;
      _connectionError = null;
    });
    try {
      final user = await api.me();
      if (!mounted) return;
      setState(() {
        _user = user;
        _checking = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _connectionError = e;
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectionError = ApiException(0, '$e');
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: AppLoadingView());
    }
    if (_connectionError != null) {
      return _ConnectionErrorScreen(
        error: _connectionError!,
        onRetry: _restoreSession,
      );
    }
    if (_user == null) {
      return AuthFlow(
        onSignedIn: (user) => setState(() => _user = user),
      );
    }
    return HomeShell(
      user: _user!,
      onSignedOut: () => setState(() => _user = null),
    );
  }
}

// ---------------------------------------------------------------
// Connection error
// ---------------------------------------------------------------
class _ConnectionErrorScreen extends StatelessWidget {
  const _ConnectionErrorScreen({required this.error, required this.onRetry});

  final ApiException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: AppErrorView(
          title: l10n.connectionErrorTitle,
          message: error.statusCode == 0
              ? l10n.connectionErrorHint
              : error.message,
          retryLabel: l10n.retry,
          onRetry: onRetry,
          icon: Icons.wifi_off_rounded,
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          l10n.apiEndpoint(api.baseUrl),
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ),
    );
  }
}
