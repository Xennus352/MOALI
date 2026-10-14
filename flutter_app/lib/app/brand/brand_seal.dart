import 'package:flutter/material.dart';

/// MOALI / LBVD emblem drawn with [CustomPainter] so the app renders branding
/// without an SVG decoder. `assets/moali_seal.svg` ships in the bundle for
/// replacement with the official logo files when they are available.
class BrandSeal extends StatelessWidget {
  const BrandSeal({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MOALI LBVD',
      child: CustomPaint(size: Size.square(size), painter: const _SealPainter()),
    );
  }
}

class _SealPainter extends CustomPainter {
  const _SealPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final ringPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF16694A), Color(0xFF3E8E64)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      radius - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.12
        ..shader = ringPaint.shader,
    );

    canvas.drawCircle(
      center,
      radius * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF0c2218).withValues(alpha: 0.3),
    );

    final arch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6;
    arch.color = const Color(0xFFC9891B);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height * 0.68),
        radius: size.width * 0.3,
      ),
      3.4,
      3.4 - 2,
      false,
      arch,
    );

    final head = Paint()..color = const Color(0xFF1b4d3e);
    final ear = Path()
      ..moveTo(size.width * 0.42, size.height * 0.42)
      ..lineTo(size.width * 0.44, size.height * 0.34)
      ..lineTo(size.width * 0.47, size.height * 0.40)
      ..close();
    canvas.drawPath(ear, head);
    final ear2 = Path()
      ..moveTo(size.width * 0.58, size.height * 0.42)
      ..lineTo(size.width * 0.56, size.height * 0.34)
      ..lineTo(size.width * 0.53, size.height * 0.40)
      ..close();
    canvas.drawPath(ear2, head);

    final faceRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.5),
      width: size.width * 0.34,
      height: size.height * 0.26,
    );
    final face = Path()
      ..addRRect(RRect.fromRectAndCorners(
        faceRect,
        topLeft: Radius.circular(size.width * 0.06),
        topRight: Radius.circular(size.width * 0.06),
      ));
    canvas.drawPath(face, Paint()..color = const Color(0xFF16694A));

    final eye = Paint()..color = const Color(0xFF0c2218);
    canvas.drawCircle(
        Offset(size.width * 0.46, size.height * 0.47), size.width * 0.016, eye);
    canvas.drawCircle(
        Offset(size.width * 0.54, size.height * 0.47), size.width * 0.016, eye);

    final snout = Path()
      ..moveTo(size.width * 0.46, size.height * 0.53)
      ..quadraticBezierTo(
          size.width * 0.5, size.height * 0.62, size.width * 0.54, size.height * 0.53);
    canvas.drawPath(
      snout,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF0c2218),
    );

    final moali = TextPainter(
      text: TextSpan(
        text: 'MOALI',
        style: TextStyle(
          color: const Color(0xFF0a1f17),
          fontSize: size.height * 0.15,
          fontWeight: FontWeight.w900,
          letterSpacing: size.width * 0.02,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    moali.paint(
        canvas, Offset(size.width / 2 - moali.width / 2, size.height * 0.74));

    final lbvd = TextPainter(
      text: TextSpan(
        text: 'LBVD · LIVESTOCK CENSUS',
        style: TextStyle(
          color: const Color(0xFF0a6b57),
          fontSize: size.height * 0.075,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lbvd.paint(
        canvas, Offset(size.width / 2 - lbvd.width / 2, size.height * 0.88));
  }

  @override
  bool shouldRepaint(covariant _SealPainter oldDelegate) => false;
}
