import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../l10n/generated/app_localizations.dart';

/// Labelled text input with a persistent label above the field (clearer for
/// older users than a floating label), large touch area, optional leading icon
/// and inline validation error.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.icon,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.errorText,
    this.required = false,
    this.enabled = true,
    this.focusNode,
    this.suffixText,
    this.suffix,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.onSubmitted,
    this.semanticLabel,
    this.autofillHints,
  });

  final String label;
  final String? hint;
  final IconData? icon;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final bool required;
  final bool enabled;
  final FocusNode? focusNode;
  final String? suffixText;
  final Widget? suffix;
  final bool autofocus;
  final int? maxLines;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  final String? semanticLabel;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      maxLines: maxLines,
      maxLength: maxLength,
      autofillHints: autofillHints,
      style: AppTextStyles.input,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        prefixIcon: icon == null ? null : Icon(icon, size: 22),
        suffixText: suffixText,
        suffix: suffix,
        counterText: '',
      ),
    );

    return Semantics(
      textField: true,
      label: semanticLabel ?? label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label, required: required),
          const SizedBox(height: 5),
          field,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Password input with a large, clearly-labelled show/hide control.
///
/// The [controller] is reused across rebuilds, so toggling visibility never
/// clears what the user has typed.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.required = false,
    this.enabled = true,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final bool required;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label, required: widget.required),
        const SizedBox(height: 5),
        TextFormField(
          controller: widget.controller,
          obscureText: _hidden,
          enabled: widget.enabled,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHints,
          style: AppTextStyles.input,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            prefixIcon: const Icon(Icons.lock_outline, size: 22),
            suffixIcon: IconButton(
              iconSize: 24,
              tooltip: _hidden ? l10n.showPassword : l10n.hidePassword,
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: Icon(
                _hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Label shown above a form field. Kept in one place so spacing and the
/// required marker stay consistent across the whole app.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.fieldLabel,
          ),
        ),
        if (required)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              '*',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.55,
              ),
            ),
          ),
      ],
    );
  }
}
