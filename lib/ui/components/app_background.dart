import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PixelPatternMode  –  Selectable Ambient Background Patterns (Kept for compatibility)
// ─────────────────────────────────────────────────────────────────────────────

enum PixelPatternMode {
  nightSky,
  constellation,
  flowingWaves,
  matrixTrail,
  geometricGrid,
  interactiveOnly,
}

// ─────────────────────────────────────────────────────────────────────────────
//  AppBackground  –  Dynamic Ambient Dark Gradient Background
// ─────────────────────────────────────────────────────────────────────────────

class AppBackground extends StatefulWidget {
  final Widget child;

  /// Whether to enable subtle ambient motion. Defaults to true.
  final bool animate;

  /// Ambient pattern mode (retained for backward compatibility).
  final PixelPatternMode patternMode;

  /// Size of each pixel square (dp).
  final double pixelSize;

  /// Gap between pixels (dp).
  final double pixelGap;

  /// Radius (dp) around each interaction point that lights up.
  final double glowRadius;

  /// Primary glow colour.
  final Color glowColor;

  /// Base dim colour for unlit pixels.
  final Color baseColor;

  /// Ambient animation speed multiplier. Defaults to 1.0 (slow, calming drift).
  final double animationSpeed;

  /// Star density factor.
  final double starDensity;

  /// Average interval in seconds between passing comets.
  final double cometIntervalSeconds;

  /// Global notifier to pause background animation during active scroll flings for 120 FPS smoothness.
  static final ValueNotifier<bool> isScrollingNotifier = ValueNotifier<bool>(false);

  const AppBackground({
    super.key,
    required this.child,
    this.animate = true,
    this.patternMode = PixelPatternMode.nightSky,
    this.pixelSize = 3.5,
    this.pixelGap = 6.5,
    this.glowRadius = 140.0,
    this.glowColor = const Color(0xFFFFFFFF),
    this.baseColor = const Color(0xFF2A2A2A),
    this.animationSpeed = 1.0,
    this.starDensity = 1.0,
    this.cometIntervalSeconds = 6.0,
  });

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration _calculateDuration() {
    final speed = widget.animationSpeed <= 0 ? 1.0 : widget.animationSpeed;
    final seconds = (12.0 / speed).clamp(4.0, 45.0).round();
    return Duration(seconds: seconds);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _calculateDuration(),
    );

    if (widget.animate && !AppBackground.isScrollingNotifier.value) {
      _controller.repeat();
    }

    AppBackground.isScrollingNotifier.addListener(_onScrollingChanged);
  }

  void _onScrollingChanged() {
    if (!mounted || !widget.animate) return;
    if (AppBackground.isScrollingNotifier.value) {
      if (_controller.isAnimating) {
        _controller.stop(canceled: false);
      }
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void didUpdateWidget(AppBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationSpeed != oldWidget.animationSpeed) {
      _controller.duration = _calculateDuration();
    }
    if (widget.animate != oldWidget.animate) {
      if (widget.animate && !AppBackground.isScrollingNotifier.value) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    AppBackground.isScrollingNotifier.removeListener(_onScrollingChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion && _controller.isAnimating) {
      _controller.stop();
    } else if (!reduceMotion &&
        widget.animate &&
        !_controller.isAnimating &&
        !AppBackground.isScrollingNotifier.value) {
      _controller.repeat();
    }

    return ColoredBox(
      color: const Color(0xFF0C1214),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Isolated Animated Background Canvas ───────────────────────────
          // RepaintBoundary isolates texture repaints from the app UI.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              child: const _StaticAtmosphereStack(),
              builder: (context, child) {
                final t = _controller.value;
                final theta = t * 2 * math.pi;

                // Closed-loop Figure-8 orbital drift (C1 smooth, zero jump at loop point)
                final dx = math.sin(theta) * 36.0;
                final dy = math.sin(2 * theta) * 24.0;
                final scale = 1.24 + (0.04 * math.cos(theta));

                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
            ),
          ),

          // ── App UI (Child) ────────────────────────────────────────────────
          // Never rebuilt by background animation ticker!
          widget.child,
        ],
      ),
    );
  }
}

/// Static pre-built atmospheric layers.
/// Completely decoupled from animation ticks so Skia / Impeller can cache the texture
/// and only perform a fast GPU matrix transform on every frame.
class _StaticAtmosphereStack extends StatelessWidget {
  const _StaticAtmosphereStack();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base Layer: Dark petrol teal texture
        const Image(
          image: AssetImage('assets/dark_teal_bg.jpg'),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),

        // Atmospheric Layer 1: Muted Petrol Teal glow (#174044)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.35, 0.78),
                radius: 1.25,
                colors: [
                  const Color(0xFF174044).withValues(alpha: 0.24),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.75],
              ),
            ),
          ),
        ),

        // Atmospheric Layer 2: Soft Turquoise glow (#24615F)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.70, 0.82),
                radius: 1.05,
                colors: [
                  const Color(0xFF24615F).withValues(alpha: 0.22),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.70],
              ),
            ),
          ),
        ),

        // Atmospheric Layer 3: Deep Blue-Green Top Haze (#102326)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.15, -0.85),
                radius: 0.90,
                colors: [
                  const Color(0xFF102326).withValues(alpha: 0.19),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.75],
              ),
            ),
          ),
        ),

        // Subtle Darkening Vignette: Preserves high contrast in center & top
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.2),
                radius: 0.85,
                colors: [
                  const Color(0xFF0C1214).withValues(alpha: 0.38),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
