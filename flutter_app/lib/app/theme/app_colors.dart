import 'package:flutter/material.dart';

/// Central colour palette for the MOALI / LBVD census app.
///
/// Government-standard identity: emerald / forest green (`#047857` / `#065F46`
/// / `#10B981`) as the single accent family, sitting on light grey and mint
/// soft-UI canvases (`#F3F4F6` / `#E8F5F1`). Depth comes from layered
/// light/shadow gradients rather than hard borders, so the app still reads as
/// soft UI while the institutional green stays unmistakable.
///
/// The token names are stable across the codebase; only the values changed when
/// the app moved from navy/slate to emerald, so every existing widget restyles
/// for free.
abstract final class AppColors {
  // Accent (emerald / forest green)
  static const Color primary = Color(0xFF0F766E); // teal 700
  static const Color primaryDark = Color(0xFF0D6847); // MOALI forest green
  static const Color primaryLight = Color(0xFF14B8A6); // teal 500

  // Tinted mint surfaces for selected / supporting states
  static const Color primaryContainer = Color(0xFFCCFBF1); // teal 100
  static const Color primarySoft = Color(0xFFF0FDFA); // soft teal canvas

  // Base neutrals (light grey / mint — "soft UI" canvas)
  static const Color background = Color(0xFFF8FAFC); // slate 50
  static const Color surface = Color(0xFFFFFFFF); // raised cards
  static const Color surfaceAlt = Color(0xFFF1F5F9); // slate 100

  // Ink (deep forest / neutral slate)
  static const Color navy = Color(0xFF064E3B); // forest 900 (app bar / hero)
  static const Color slate = Color(0xFF065F46); // forest 800
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF64748B); // slate 500
  static const Color textMuted = Color(0xFF94A3B8); // slate 400
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Borders / dividers (kept very light — soft UI prefers shadow to stroke)
  static const Color border = Color(0xFFE2E8F0); // slate 200
  static const Color borderStrong = Color(0xFFCBD5E1); // slate 300

  // Soft-UI elevation. Layered dual-tone shadows: a light highlight and a cool
  // shade give the "extruded" neumorphic depth without any visible border.
  static const Color shadowDark = Color(0x24173128);
  static const Color shadowLight = Color(0xCCFFFFFF);
  static const Color glassTint = Color(0x22FFFFFF);
  static const Color glow = Color(0x55047857);

  // Feedback
  static const Color success = Color(0xFF047857);
  static const Color successSurface = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorSurface = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSurface = Color(0xFFDBEAFE);

  // Status chips
  static const Color statusApproved = Color(0xFF047857);
  static const Color statusRejected = Color(0xFFDC2626);
  static const Color statusReturned = Color(0xFFB45309);
  static const Color statusUnderReview = Color(0xFF2563EB);
  static const Color statusNeutral = Color(0xFF6B7280);

  /// Colour used to tag a submission in the user-facing history.
  ///
  /// * live    — approved/published data
  /// * synced  — safely stored on the server, awaiting review
  /// * pending — queued locally, not yet uploaded
  static const Color statusLive = statusApproved;
  static const Color statusSynced = statusUnderReview;
  static const Color statusPending = statusReturned;

  static Color statusColor(String status) {
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      case 'approved':
        return statusApproved;
      case 'rejected':
        return statusRejected;
      case 'returned':
        return statusReturned;
      case 'under_review':
      case 'reopened':
        return statusUnderReview;
      case 'submitted':
      case 'pending':
      default:
        return statusNeutral;
    }
  }

  /// Soft-UI raised panel: long, blurred, dual-tone shadows.
  static List<BoxShadow> raised({double blur = 22, double y = 10}) => [
        BoxShadow(
          color: shadowDark,
          blurRadius: blur,
          offset: Offset(0, y),
          spreadRadius: -4,
        ),
        const BoxShadow(
          color: shadowLight,
          blurRadius: 12,
          offset: Offset(-6, -6),
        ),
      ];

  /// Soft-UI inset/concave well used for inputs and pressed surfaces.
  static List<BoxShadow> inset({double blur = 12}) => const [
        BoxShadow(
          color: shadowDark,
          blurRadius: 12,
          offset: Offset(2, 3),
          spreadRadius: -3,
        ),
      ];

  /// Soft outer glow, tinted with [color], used behind accent controls.
  static List<BoxShadow> glowOf(Color color, {double blur = 24, double a = 0.45}) => [
        BoxShadow(
          color: color.withValues(alpha: a),
          blurRadius: blur,
          spreadRadius: 1,
        ),
      ];
}
