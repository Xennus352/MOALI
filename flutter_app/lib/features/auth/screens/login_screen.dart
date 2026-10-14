import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/api_error_messages.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/feedback.dart';
import '../widgets/auth_scaffold.dart';

/// Sign-in screen. Authenticates against the backend and hands the resulting
/// [SessionUser] back to the auth gate.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onSignedIn,
    required this.onSwitchToRegister,
  });

  final ValueChanged<SessionUser> onSignedIn;
  final VoidCallback onSwitchToRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _emailError;
  String? _passwordError;
  String? _formError;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    final l10n = context.l10n;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _emailError = email.isEmpty
          ? l10n.emailRequiredError
          : (_emailPattern.hasMatch(email) ? null : l10n.emailInvalidError);
      _passwordError = password.isEmpty ? l10n.passwordRequiredError : null;
      _formError = null;
    });
    return _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _formError = null;
    });
    try {
      final user = await api.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      widget.onSignedIn(user);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _formError = localizeApiError(context.l10n, e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _formError = context.l10n.errorUnexpected);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy = _loading;
    return AuthScaffold(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      footer: Text(
        l10n.termsNotice,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: AppColors.textMuted,
        ),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_formError != null) ...[
              AppBanner(message: _formError!),
              const SizedBox(height: 16),
            ],
            AppTextField(
              label: l10n.emailLabel,
              hint: l10n.emailHint,
              icon: Icons.mail_outline,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              errorText: _emailError,
              required: true,
              enabled: !busy,
              onChanged: (_) {
                if (_emailError != null || _formError != null) {
                  setState(() {
                    _emailError = null;
                    _formError = null;
                  });
                }
              },
            ),
            AppPasswordField(
              label: l10n.passwordLabel,
              hint: l10n.passwordHintLogin,
              controller: _passwordController,
              errorText: _passwordError,
              required: true,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 4),
            AppPrimaryButton(
              label: _loading ? l10n.signingIn : l10n.loginButton,
              icon: Icons.login,
              loading: _loading,
              onPressed: busy ? null : _submit,
            ),
            const SizedBox(height: 12),
            AppTextAction(
              label: l10n.switchToRegister,
              icon: Icons.person_add_alt,
              onPressed: busy ? null : widget.onSwitchToRegister,
            ),
          ],
        ),
      ),
    );
  }
}
