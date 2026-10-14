import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';

/// Shared frame for the sign-in / create-account screens.
///
/// Keeps the branding, the language switch and the centred card identical
/// between both modes so switching between them feels like one screen. The
/// layout is scrollable (so the soft keyboard never covers a field) and stays
/// centred while there is room.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5F1),
              Color(0xFFF8FAF9),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final form = ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 480 : 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!wide) ...[
                      _BurmeseHeader(title: title, subtitle: subtitle),
                      const SizedBox(height: 14),
                    ],
                    _Entrance(
                      reduceMotion: reduceMotion,
                      child: SectionCard(
                        title: title,
                        description: subtitle,
                        icon: Icons.verified_user_outlined,
                        padding: EdgeInsets.all(wide ? 28 : 20),
                        child: child,
                      ),
                    ),
                    if (footer != null) ...[
                      const SizedBox(height: 16),
                      footer!,
                    ],
                  ],
                ),
              );

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 40 : 20,
                  vertical: wide ? 32 : 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (wide ? 64 : 48),
                  ),
                  child: Center(
                    child: wide
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1120),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _WelcomePanel(
                                    title: title,
                                    subtitle: subtitle,
                                  ),
                                ),
                                const SizedBox(width: 64),
                                form,
                              ],
                            ),
                          )
                        : form,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DepartmentLogos(),
        const SizedBox(height: 30),
        Text(
          title,
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

/// One-shot fade + slide used for the auth card. Honours the reduced-motion
/// accessibility setting by rendering immediately.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child, required this.reduceMotion});

  final Widget child;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: c),
      ),
      child: child,
    );
  }
}

/// Burmese-only departmental header: emblems + three Burmese title lines
/// (ministry, department, survey) as they appear on the official letterhead.
class _BurmeseHeader extends StatelessWidget {
  const _BurmeseHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DepartmentLogos(),
          const SizedBox(height: 18),
          // Ministry title (Burmese)
          _BurmeseTitleLine(
            text: title,
            style: AppTextStyles.titleMedium,
            color: AppColors.textPrimary,
          ),
          const SizedBox(height: 6),
          // Department title (Burmese)
          _BurmeseTitleLine(
            text: subtitle,
            style: AppTextStyles.caption,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

/// Official ministry and department emblems shared by both auth screens.
class _DepartmentLogos extends StatelessWidget {
  const _DepartmentLogos();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        child: Image.asset(
          'assets/logos/moali.png',
          width: 88,
          height: 88,
          fit: BoxFit.contain,
          semanticLabel: 'MOALI',
        ),
      ),
      const SizedBox(width: 24),
      Flexible(
        child: Image.asset(
          'assets/logos/lbvd.png',
          width: 88,
          height: 88,
          fit: BoxFit.contain,
          semanticLabel: 'LBVD',
        ),
      ),
    ],
  );
}

class _BurmeseTitleLine extends StatelessWidget {
  const _BurmeseTitleLine({
    required this.text,
    required this.style,
    required this.color,
  });

  final String text;
  final TextStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: style.copyWith(
          fontFamily: AppTextStyles.fontFamily,
          color: color,
        ),
      ),
    );
  }
}
