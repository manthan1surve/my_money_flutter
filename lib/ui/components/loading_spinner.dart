import 'dart:math' as math;
import 'package:flutter/material.dart';

class LoadingSpinner extends StatefulWidget {
  final double size;
  final double strokeWidth;

  const LoadingSpinner({
    super.key,
    this.size = 22,
    this.strokeWidth = 3.5,
  });

  @override
  State<LoadingSpinner> createState() => _LoadingSpinnerState();
}

class _LoadingSpinnerState extends State<LoadingSpinner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 2.0 * math.pi,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _SpinnerPainter(
                  strokeWidth: widget.strokeWidth,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final double strokeWidth;

  _SpinnerPainter({required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // The radius where the dots will be placed
    final orbitRadius = size.width / 2 - strokeWidth;

    // Define 3 dots at -90, 30, 150 degrees
    final angles = [ -math.pi / 2, math.pi / 6, 5 * math.pi / 6 ];
    final colors = [
      Colors.white,
      Colors.white.withValues(alpha: 0.5),
      Colors.white.withValues(alpha: 0.15),
    ];

    for (int i = 0; i < 3; i++) {
      final dotCenter = Offset(
        center.dx + orbitRadius * math.cos(angles[i]),
        center.dy + orbitRadius * math.sin(angles[i]),
      );
      
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      // Draw a subtle glow for the brightest dot
      if (i == 0) {
        canvas.drawCircle(
          dotCenter, 
          strokeWidth * 1.5, 
          Paint()..color = Colors.white.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        );
      }
      
      canvas.drawCircle(dotCenter, strokeWidth, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth;
  }
}
