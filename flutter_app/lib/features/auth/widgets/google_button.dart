import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../google_auth.dart';

/// "Continue with Google" button with an animated, softly pulsing gradient rim
/// and light haptic feedback.
///
/// The Google "G" is drawn from text with the four brand colours applied as a
/// shader, so no third-party logo asset or dependency is required. The pulse is
/// disabled under reduced-motion settings.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  static const _googleColors = [
    Color(0xFF4285F4),
    Color(0xFFEA4335),
    Color(0xFFFBBC05),
    Color(0xFF34A853),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only run the pulse when motion is allowed; this also lets widget tests
    // settle.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (reduceMotion && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled || widget.loading) return;
    HapticFeedback.selectionClick();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final active = widget.enabled && !widget.loading;
    final disabled = !active;

    return Semantics(
      button: true,
      enabled: active,
      label: widget.label,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = reduceMotion ? 0.5 : Curves.easeInOut.transform(_pulse.value);
          return Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: SweepGradient(
                startAngle: t * 6.28318,
                endAngle: t * 6.28318 + 6.28318,
                colors: [
                  ..._googleColors,
                  _googleColors.first,
                ],
              ),
              boxShadow: AppColors.glowOf(
                AppColors.primary,
                blur: disabled ? 10 : 18 + 10 * t,
                a: disabled ? 0.12 : 0.22 + 0.16 * t,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: active ? _handleTap : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.loading)
                          const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        else
                          const _GoogleGlyph(),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.button.copyWith(
                              color: disabled
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4285F4),
              Color(0xFFEA4335),
              Color(0xFFFBBC05),
              Color(0xFF34A853),
            ],
          ).createShader(bounds),
          child: Text(
            'G',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin "or" divider used between the Google button and the email form.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: AppTextStyles.caption),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

/// Maps a [GoogleSignInError] to a localizable sentence key the UI can resolve.
String googleErrorKey(GoogleSignInError error) => switch (error.code) {
      'not_configured' => 'not_configured',
      'launch_failed' => 'launch_failed',
      'timeout' => 'timeout',
      _ => 'unexpected',
    };
