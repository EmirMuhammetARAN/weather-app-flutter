// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'dart:math';

class RainEffect extends StatefulWidget {
  const RainEffect({super.key});

  @override
  State<RainEffect> createState() => _RainEffectState();
}

class _RainEffectState extends State<RainEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final int dropCount = 60;
  final List<_Drop> drops = [];

  @override
  void initState() {
    super.initState();
    final random = Random();
    for (int i = 0; i < dropCount; i++) {
      drops.add(
        _Drop(
          x: random.nextDouble(),
          y: random.nextDouble(),
          length: 10 + random.nextDouble() * 10,
          speed: 0.01 + random.nextDouble() * 0.02,
        ),
      );
    }
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() {
            setState(() {
              for (var drop in drops) {
                drop.y += drop.speed;
                if (drop.y > 1.0) {
                  drop.y = 0;
                  drop.x = random.nextDouble();
                }
              }
            });
          })
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: RainPainter(drops), size: Size.infinite);
  }
}

class _Drop {
  double x;
  double y;
  double length;
  double speed;
  _Drop({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
  });
}

class RainPainter extends CustomPainter {
  final List<_Drop> drops;
  RainPainter(this.drops);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var drop in drops) {
      final dx = drop.x * size.width;
      final dy = drop.y * size.height;
      canvas.drawLine(Offset(dx, dy), Offset(dx, dy + drop.length), paint);
    }
  }

  @override
  bool shouldRepaint(covariant RainPainter oldDelegate) => true;
}
