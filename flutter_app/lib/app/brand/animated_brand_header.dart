import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'brand_seal.dart';
import 'department_titles.dart';

/// Glassmorphic departmental letterhead: the two official emblems (MOALI on the
/// left, LBVD on the right) above the bilingual ministry / department / survey
/// title block.
///
/// Both languages are shown at once (Burmese first, English beneath) regardless
/// of the active UI locale, exactly as the printed government form does. Behind
/// the panel a soft emerald glow breathes slowly; the animation is disabled when
/// the platform reports reduced motion, so it never becomes a distraction for
/// the enumerators using the app in the field.
///
/// If a logo asset is missing or fails to decode, the tile falls back to the
/// painted [BrandSeal] so the header always renders.
class AnimatedBrandHeader extends StatefulWidget {
  const AnimatedBrandHeader({
    super.key,
    this.compact = false,
    this.animate = true,
    this.welcome,
  });

  /// Tighter paddings and smaller emblems, for use inside a scroll view.
  final bool compact;

  /// When false the glow animation is skipped entirely (e.g. inline headers).
  final bool animate;

  /// Optional greeting (e.g. "ပြန်လည် ကြိုဆိုပါသည်") shown under the titles.
  final String? welcome;

  @override
  State<AnimatedBrandHeader> createState() => _AnimatedBrandHeaderState();
}

class _AnimatedBrandHeaderState extends State<AnimatedBrandHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start/stop the breathing glow according to reduced-motion, so the header
    // is still when the user prefers (and so widget tests can settle).
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate = widget.animate && !reduceMotion;
    if (shouldAnimate && !_glow.isAnimating) {
      _glow.repeat(reverse: true);
    } else if (!shouldAnimate && _glow.isAnimating) {
      _glow.stop();
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate = widget.animate && !reduceMotion;

    // Respect reduced motion: freeze the glow instead of pulsing.
    if (!shouldAnimate && _glow.isAnimating) _glow.stop();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, child) {
          final t = shouldAnimate ? _glow.value : 0.5;
          final glowAlpha = 0.16 + 0.20 * t;
          final glowBlur = 20.0 + 16.0 * t;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: glowAlpha),
                  blurRadius: glowBlur,
                  spreadRadius: 0.5,
                ),
                ...AppColors.raised(blur: 26, y: 12),
              ],
            ),
            child: child,
          );
        },
        child: _glassPanel(context),
      ),
    );
  }

  Widget _glassPanel(BuildContext context) {
    final compact = widget.compact;
    final pad = compact ? 14.0 : 18.0;
    final emblemSize = compact ? 46.0 : 58.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.92),
                AppColors.primarySoft.withValues(alpha: 0.72),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _EmblemTile(
                    asset: 'assets/logos/moali.png',
                    size: emblemSize,
                    semanticLabel: DepartmentTitles.ministryEnglish,
                  ),
                  const Spacer(),
                  _LogoDivider(compact: compact),
                  const Spacer(),
                  _EmblemTile(
                    asset: 'assets/logos/lbvd.png',
                    size: emblemSize,
                    semanticLabel: DepartmentTitles.departmentEnglish,
                  ),
                ],
              ),
              SizedBox(height: compact ? 12 : 14),
              const _BilingualTitles(),
              if (widget.welcome != null) ...[
                SizedBox(height: compact ? 10 : 12),
                Text(
                  widget.welcome!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The bilingual ministry → department → survey title block, Burmese then
/// English, always shown together.
class _BilingualTitles extends StatelessWidget {
  const _BilingualTitles();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _TitleLine(DepartmentTitles.ministryBurmese, _TitleWeight.strong),
        _TitleLine(DepartmentTitles.ministryEnglish, _TitleWeight.soft),
        SizedBox(height: 6),
        _TitleLine(DepartmentTitles.departmentBurmese, _TitleWeight.strong),
        _TitleLine(DepartmentTitles.departmentEnglish, _TitleWeight.soft),
        SizedBox(height: 8),
        _TitleLine(DepartmentTitles.surveyBurmese, _TitleWeight.accent),
        _TitleLine(DepartmentTitles.surveyEnglish, _TitleWeight.accentSoft),
      ],
    );
  }
}

enum _TitleWeight { strong, soft, accent, accentSoft }

class _TitleLine extends StatelessWidget {
  const _TitleLine(this.text, this.weight);

  final String text;
  final _TitleWeight weight;

  @override
  Widget build(BuildContext context) {
    final (style, color) = switch (weight) {
      _TitleWeight.strong => (
          const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.5),
          AppColors.textPrimary,
        ),
      _TitleWeight.soft => (
          const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.4),
          AppColors.textSecondary,
        ),
      _TitleWeight.accent => (
          const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.5),
          AppColors.primaryDark,
        ),
      _TitleWeight.accentSoft => (
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
          AppColors.primary,
        ),
    };
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

class _LogoDivider extends StatelessWidget {
  const _LogoDivider({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.eco_rounded,
            size: 18, color: AppColors.primary.withValues(alpha: 0.8)),
        const SizedBox(height: 6),
        Container(
          width: 1.5,
          height: compact ? 22 : 30,
          color: AppColors.border,
        ),
      ],
    );
  }
}

class _EmblemTile extends StatelessWidget {
  const _EmblemTile({
    required this.asset,
    required this.size,
    required this.semanticLabel,
  });

  final String asset;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.raised(blur: 14, y: 6),
        ),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) =>
              Center(child: BrandSeal(size: size - 12)),
        ),
      ),
    );
  }
}

/// Headline text block that sits under the emblem header on the auth screens
/// and the dashboard, kept here so the branding stays consistent.
class BrandHeadline extends StatelessWidget {
  const BrandHeadline({
    super.key,
    required this.title,
    required this.subtitle,
    this.textAlign = TextAlign.center,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final String title;
  final String subtitle;
  final TextAlign textAlign;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: AppTextStyles.textTheme(AppColors.textPrimary).headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: textAlign,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
