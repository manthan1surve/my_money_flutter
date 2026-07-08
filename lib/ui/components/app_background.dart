import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  AppBackground
//  Ultra-smooth dynamic monochrome background
//  flowing liquid gradients (black, charcoal, silver, white)
// ─────────────────────────────────────────────
class AppBackground extends StatefulWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // 40 second loop for ultra-slow, ambient cinematic motion
    // This creates a silky, relaxing, and premium feel.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Animated monochrome background
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return CustomPaint(
              painter: _LiquidMonochromePainter(_ctrl.value * math.pi * 2),
            );
          },
        ),
        // Screen content sits gracefully on top
        widget.child,
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  _LiquidMonochromePainter
// ─────────────────────────────────────────────
class _LiquidMonochromePainter extends CustomPainter {
  final double t; // current angle in radians, 0 → 2π

  const _LiquidMonochromePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── 1. Pure OLED Black base ──────────────────────────────────────────
    // Ensures OLED friendliness and provides deep, infinite contrast.
    final bgPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // ── 2. Flowing Monochrome Gradients (Blobs with extreme blur) ────────
    // We use very large radii and massive blur to create a seamless "liquid" gradient field
    // without visible shapes, objects, or patterns.
    
    // Single bottom mass (Pure White) moving slowly up and down
    _drawBlob(
      canvas: canvas,
      cx: w * 0.5 + math.cos(t * 1.0) * w * 0.3,
      cy: h * 0.7 + math.sin(t * 1.0) * h * 0.3, // Larger vertical movement
      r: w * 0.65,
      color: const Color(0xFFFFFFFF).withValues(alpha: 0.95),
      blurSigma: 80,
    );
  }

  void _drawBlob({
    required Canvas canvas,
    required double cx,
    required double cy,
    required double r,
    required Color color,
    required double blurSigma,
  }) {
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(_LiquidMonochromePainter old) => old.t != t;
}
