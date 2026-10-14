import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/api_error_messages.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/feedback.dart';
import '../widgets/auth_scaffold.dart';

/// Create-account screen. Registers against the backend, then signs the new
/// account in so the enumerator goes straight to the dashboard.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.onSignedIn,
    required this.onSwitchToLogin,
  });

  final ValueChanged<SessionUser> onSignedIn;
  final VoidCallback onSwitchToLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _emailError;
  String? _passwordError;
  String? _formError;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _minPasswordLength = 8;

  @override
  void dispose() {
    _nameController.dispose();
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
      _passwordError = password.isEmpty
          ? l10n.passwordRequiredError
          : (password.length < _minPasswordLength
                ? l10n.passwordTooShortError
                : null);
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
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    try {
      await api.register(
        email: email,
        password: password,
        name: _nameController.text.trim(),
      );
      // Registration succeeded; sign the new account straight in.
      final user = await api.login(email: email, password: password);
      if (!mounted) return;
      widget.onSignedIn(user);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _formError = localizeApiError(context.l10n, e, registering: true),
      );
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
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
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
              label: l10n.fullNameLabel,
              hint: l10n.fullNameHint,
              icon: Icons.person_outline,
              controller: _nameController,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              enabled: !busy,
              onChanged: (_) {
                if (_formError != null) setState(() => _formError = null);
              },
            ),
            AppTextField(
              label: l10n.emailLabel,
              hint: l10n.emailHint,
              icon: Icons.mail_outline,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
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
              hint: l10n.passwordHintRegister,
              controller: _passwordController,
              errorText: _passwordError,
              required: true,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 4),
            AppPrimaryButton(
              label: _loading ? l10n.creatingAccount : l10n.registerButton,
              icon: Icons.person_add_alt_1,
              loading: _loading,
              onPressed: busy ? null : _submit,
            ),
            const SizedBox(height: 12),
            AppTextAction(
              label: l10n.switchToLogin,
              icon: Icons.login,
              onPressed: busy ? null : widget.onSwitchToLogin,
            ),
          ],
        ),
      ),
    );
  }
}
