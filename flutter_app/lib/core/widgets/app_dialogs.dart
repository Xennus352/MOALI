import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// Confirmation dialog used before destructive actions (discard draft) and
/// before intentional duplicate submissions. Deliberately roomy so it stays
/// readable on small screens and with large system text.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon == null
          ? null
          : Icon(icon, color: destructive ? AppColors.error : AppColors.primary, size: 32),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, style: AppTextStyles.supporting),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Simple acknowledgement dialog (used for validation summaries).
Future<void> showAppMessageDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  required String closeLabel,
  IconData? icon,
  Color? iconColor,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon == null ? null : Icon(icon, color: iconColor, size: 32),
      title: Text(title, textAlign: TextAlign.center),
      content: SingleChildScrollView(child: content),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(closeLabel),
          ),
        ),
      ],
    ),
  );
}
