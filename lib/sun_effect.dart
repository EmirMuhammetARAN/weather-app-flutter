import 'package:flutter/material.dart';

class SunEffect extends StatelessWidget {
  const SunEffect({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SoftSunPainter(), size: const Size(320, 320));
  }
}

class _SoftSunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.yellow.withOpacity(0.13), Colors.transparent],
        stops: [0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));
    canvas.drawCircle(center, size.width / 2, haloPaint);

    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.yellow.shade200.withOpacity(0.5),
          Colors.orange.shade300.withOpacity(0.3),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 70));
    canvas.drawCircle(center, 70, sunPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
