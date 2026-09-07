import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PixelPatternMode  –  Selectable Ambient Background Patterns
// ─────────────────────────────────────────────────────────────────────────────

enum PixelPatternMode {
  /// Night Sky & Passing Comets: Realistic multi-magnitude starfield with
  /// atmospheric twinkling and periodic comets/shooting stars sweeping across.
  nightSky,

  /// Constellation: Shimmering celestial nodes and geometric constellation links.
  constellation,

  /// Flowing Waves: Sinusoidal light waves drifting across the grid.
  flowingWaves,

  /// Matrix Trail: Gentle streaming vertical pulses and decaying trails.
  matrixTrail,

  /// Geometric Grid: Symmetrical diamond and cross geometric light pulses.
  geometricGrid,

  /// Interactive Only: Minimalist dark grid that only lights up on touch/hover.
  interactiveOnly,
}

// ─────────────────────────────────────────────────────────────────────────────
//  AppBackground  –  Silky Smooth Monochrome Night Sky Pixel Background
// ─────────────────────────────────────────────────────────────────────────────

class AppBackground extends StatefulWidget {
  final Widget child;

  /// Ambient pattern mode for lighting background pixels.
  final PixelPatternMode patternMode;

  /// Size of each pixel square (dp).
  final double pixelSize;

  /// Gap between pixels (dp).
  final double pixelGap;

  /// Radius (dp) around each interaction point that lights up.
  final double glowRadius;

  /// Primary glow colour (Pure White).
  final Color glowColor;

  /// Base dim colour for unlit pixels.
  final Color baseColor;

  /// Ambient animation speed multiplier.
  final double animationSpeed;

  /// Star density factor (0.5 to 2.0).
  final double starDensity;

  /// Average interval in seconds between passing comets (e.g. 4.0 to 10.0).
  final double cometIntervalSeconds;

  const AppBackground({
    super.key,
    required this.child,
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
  final List<_TouchPoint> _touches = [];
  Ticker? _ticker;
  final _repaint = ValueNotifier<int>(0);
  double _elapsedSeconds = 0.0;
  Duration _lastDuration = Duration.zero;
  Duration _lastAmbientTick = Duration.zero;
  DateTime _lastInteraction = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ensureTickerRunning();
  }

  void _ensureTickerRunning() {
    _lastInteraction = DateTime.now();
    if (_ticker != null && !_ticker!.isActive) {
      _ticker!.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastDuration != Duration.zero) {
      final dt = (elapsed - _lastDuration).inMicroseconds / 1000000.0;
      // Clamp dt to avoid huge jumps on frame drops or tab unfocus
      _elapsedSeconds += (dt.clamp(0.0, 0.05)) * widget.animationSpeed;
    }
    _lastDuration = elapsed;

    final hasTouches = _touches.isNotEmpty;
    if (hasTouches) {
      _lastInteraction = DateTime.now();
    } else {
      // Suspend ticker after 8 seconds of idle without touches to eliminate battery & GPU drain
      if (DateTime.now().difference(_lastInteraction).inSeconds > 8) {
        _ticker?.stop();
        return;
      }
      // When idle (no touches), throttle ambient twinkle to ~25-30 FPS to save CPU and battery.
      if ((elapsed - _lastAmbientTick).inMilliseconds < 33) {
        return;
      }
      _lastAmbientTick = elapsed;
    }

    bool isStillAnimating = widget.patternMode != PixelPatternMode.interactiveOnly;

    for (final t in _touches) {
      // Smooth position interpolation (Spring-like fluid inertia)
      final delta = t.targetPosition - t.position;
      if (delta.distance > 0.05) {
        t.position += delta * 0.22; // Smooth 22% lerp per frame
        isStillAnimating = true;
      } else {
        t.position = t.targetPosition;
      }

      // Smooth alpha fade transitions
      final targetAlpha = t.active ? 1.0 : 0.0;
      final alphaDiff = targetAlpha - t.currentAlpha;
      if (alphaDiff.abs() > 0.005) {
        t.currentAlpha += alphaDiff * (t.active ? 0.25 : 0.08); // Fast fade in, silky fade out
        isStillAnimating = true;
      } else {
        t.currentAlpha = targetAlpha;
      }
    }

    // Clean up fully faded points
    _touches.removeWhere((t) => !t.active && t.currentAlpha < 0.005);

    if (_touches.isEmpty && !isStillAnimating) {
      _ticker?.stop();
    }
    _repaint.value++;
  }

  @override
  void didUpdateWidget(covariant AppBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.patternMode != PixelPatternMode.interactiveOnly) {
      _ensureTickerRunning();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _upsert(int id, Offset pos) {
    final idx = _touches.indexWhere((t) => t.id == id);
    if (idx == -1) {
      _touches.add(_TouchPoint(id: id, position: pos, targetPosition: pos));
    } else {
      _touches[idx]
        ..targetPosition = pos
        ..active = true;
    }
    _ensureTickerRunning();
    _repaint.value++;
  }

  void _release(int id) {
    final idx = _touches.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _touches[idx].active = false;
    }
    _ensureTickerRunning();
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (e) => _upsert(e.pointer, e.localPosition),
      onPointerMove: (e) => _upsert(e.pointer, e.localPosition),
      onPointerDown: (e) => _upsert(e.pointer, e.localPosition),
      onPointerUp: (e) => _release(e.pointer),
      onPointerCancel: (e) => _release(e.pointer),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Pure OLED Black base ──────────────────────────────────────
          const ColoredBox(color: Color(0xFF000000)),

          // ── 2. Hardware-accelerated pixel canvas (Isolated Render Layer) ─
          ValueListenableBuilder<int>(
            valueListenable: _repaint,
            builder: (context, value, child) => RepaintBoundary(
              child: CustomPaint(
                painter: _PixelGridPainter(
                  touches: List.of(_touches),
                  time: _elapsedSeconds,
                  patternMode: widget.patternMode,
                  pixelSize: widget.pixelSize,
                  pixelGap: widget.pixelGap,
                  glowRadius: widget.glowRadius,
                  glowColor: widget.glowColor,
                  baseColor: widget.baseColor,
                  starDensity: widget.starDensity,
                  cometInterval: widget.cometIntervalSeconds,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),

          // ── 3. Foreground screen content (Isolated from Background Repaints) ──
          RepaintBoundary(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data model for a single interaction point with smooth lerp state
// ─────────────────────────────────────────────────────────────────────────────
class _TouchPoint {
  final int id;
  Offset position;
  Offset targetPosition;
  double currentAlpha;
  bool active;

  _TouchPoint({
    required this.id,
    required this.position,
    required this.targetPosition,
  })  : currentAlpha = 0.0,
        active = true;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Night Sky Starfield & Comet Models
// ─────────────────────────────────────────────────────────────────────────────

enum _StarTier {
  faintStardust, // Faint distant micro-stars with subtle gentle breathing
  midMagnitude,  // Mid-sky stars with atmospheric multi-wave twinkle
  brightBeacon,  // Prominent luminous anchor stars with 4-point cross diffraction halos
}

class _NightStar {
  final int col;
  final int row;
  final _StarTier tier;
  final double baseBrightness;
  final double pulseSpeed1;
  final double pulseSpeed2;
  final double phase1;
  final double phase2;
  final double twinkleExponent;
  final bool canFlare;
  final double flarePeriod;
  final double flareOffset;
  final double flareDuration;

  const _NightStar({
    required this.col,
    required this.row,
    required this.tier,
    required this.baseBrightness,
    required this.pulseSpeed1,
    required this.pulseSpeed2,
    required this.phase1,
    required this.phase2,
    required this.twinkleExponent,
    required this.canFlare,
    required this.flarePeriod,
    required this.flareOffset,
    required this.flareDuration,
  });
}

class _ConstellationLink {
  final int starA;
  final int starB;
  final List<int> pixelIndices;
  final double linkWeight;

  const _ConstellationLink({
    required this.starA,
    required this.starB,
    required this.pixelIndices,
    required this.linkWeight,
  });
}

class _NightSkyField {
  final int cols;
  final int rows;
  final List<_NightStar> stars;
  final List<_ConstellationLink> links;

  _NightSkyField({
    required this.cols,
    required this.rows,
    required this.stars,
    required this.links,
  });

  factory _NightSkyField.build(int cols, int rows, double density) {
    final stars = <_NightStar>[];
    final links = <_ConstellationLink>[];

    const sectorSize = 6;
    final sectorsX = (cols / sectorSize).ceil();
    final sectorsY = (rows / sectorSize).ceil();

    int pseudoRand(int x, int y, int seed) {
      int h = (x * 374761393 + y * 668265263 + seed * 961748941);
      h = (h ^ (h >> 13)) * 1274126177;
      return (h ^ (h >> 16)) & 0x7FFFFFFF;
    }

    double randUnit(int x, int y, int seed) {
      return (pseudoRand(x, y, seed) % 10000) / 10000.0;
    }

    final starGrid = List.generate(sectorsY, (_) => List<int?>.filled(sectorsX, null));

    for (int sy = 0; sy < sectorsY; sy++) {
      for (int sx = 0; sx < sectorsX; sx++) {
        final spawnChance = randUnit(sx, sy, 101);
        if (spawnChance > (0.75 * density.clamp(0.4, 2.0))) {
          continue;
        }

        final offsetX = (randUnit(sx, sy, 202) * (sectorSize - 1)).floor();
        final offsetY = (randUnit(sx, sy, 303) * (sectorSize - 1)).floor();

        final col = (sx * sectorSize + offsetX).clamp(0, cols - 1);
        final row = (sy * sectorSize + offsetY).clamp(0, rows - 1);

        final tierRand = randUnit(sx, sy, 404);
        _StarTier tier;
        double baseBrightness;
        double twinkleExponent;

        if (tierRand < 0.16) {
          // Bright Beacon Sirius/Vega star
          tier = _StarTier.brightBeacon;
          baseBrightness = 0.75 + randUnit(sx, sy, 505) * 0.25;
          twinkleExponent = 3.0;
        } else if (tierRand < 0.60) {
          // Mid-magnitude atmospheric twinkling star
          tier = _StarTier.midMagnitude;
          baseBrightness = 0.38 + randUnit(sx, sy, 505) * 0.36;
          twinkleExponent = 5.0;
        } else {
          // Faint distant micro stardust
          tier = _StarTier.faintStardust;
          baseBrightness = 0.18 + randUnit(sx, sy, 505) * 0.20;
          twinkleExponent = 2.0;
        }

        final pulseSpeed1 = 0.6 + randUnit(sx, sy, 606) * 1.8;
        final pulseSpeed2 = 1.4 + randUnit(sx, sy, 707) * 3.2;
        final phase1 = randUnit(sx, sy, 808) * math.pi * 2.0;
        final phase2 = randUnit(sx, sy, 909) * math.pi * 2.0;

        // Flare properties for 1-2 second max-brightness stellar flare
        final canFlare = tier == _StarTier.brightBeacon || randUnit(sx, sy, 111) < 0.45;
        final flarePeriod = 3.5 + randUnit(sx, sy, 222) * 6.0; // Every 3.5 to 9.5 seconds
        final flareOffset = randUnit(sx, sy, 333) * flarePeriod;
        final flareDuration = 1.0 + randUnit(sx, sy, 444) * 1.0; // 1.0 to 2.0 seconds duration

        final starIdx = stars.length;
        stars.add(_NightStar(
          col: col,
          row: row,
          tier: tier,
          baseBrightness: baseBrightness,
          pulseSpeed1: pulseSpeed1,
          pulseSpeed2: pulseSpeed2,
          phase1: phase1,
          phase2: phase2,
          twinkleExponent: twinkleExponent,
          canFlare: canFlare,
          flarePeriod: flarePeriod,
          flareOffset: flareOffset,
          flareDuration: flareDuration,
        ));
        starGrid[sy][sx] = starIdx;
      }
    }

    // Constellation lines for constellation mode
    final offsets = [
      [1, 0], [0, 1], [1, 1], [1, -1],
      [2, 0], [0, 2], [2, 1], [1, 2],
    ];

    for (int sy = 0; sy < sectorsY; sy++) {
      for (int sx = 0; sx < sectorsX; sx++) {
        final starAIdx = starGrid[sy][sx];
        if (starAIdx == null) continue;
        final starA = stars[starAIdx];

        for (final off in offsets) {
          final nsy = sy + off[1];
          final nsx = sx + off[0];
          if (nsx < 0 || nsx >= sectorsX || nsy < 0 || nsy >= sectorsY) continue;

          final starBIdx = starGrid[nsy][nsx];
          if (starBIdx == null) continue;
          final starB = stars[starBIdx];

          final dx = starB.col - starA.col;
          final dy = starB.row - starA.row;
          final dist = math.sqrt(dx * dx + dy * dy);

          if (dist >= 3 && dist <= 12) {
            final connectRand = randUnit(starAIdx, starBIdx, 909);
            if (connectRand < 0.60) {
              final linePixels = _rasterizeLine(
                starA.col,
                starA.row,
                starB.col,
                starB.row,
                cols,
                rows,
              );
              if (linePixels.isNotEmpty) {
                links.add(_ConstellationLink(
                  starA: starAIdx,
                  starB: starBIdx,
                  pixelIndices: linePixels,
                  linkWeight: 0.18 + randUnit(starAIdx, starBIdx, 111) * 0.15,
                ));
              }
            }
          }
        }
      }
    }

    return _NightSkyField(
      cols: cols,
      rows: rows,
      stars: stars,
      links: links,
    );
  }

  static List<int> _rasterizeLine(
    int x0,
    int y0,
    int x1,
    int y1,
    int cols,
    int rows,
  ) {
    final indices = <int>[];
    int dx = (x1 - x0).abs();
    int dy = (y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;

    int curX = x0;
    int curY = y0;

    while (true) {
      if ((curX != x0 || curY != y0) && (curX != x1 || curY != y1)) {
        if (curX >= 0 && curX < cols && curY >= 0 && curY < rows) {
          indices.add(curY * cols + curX);
        }
      }

      if (curX == x1 && curY == y1) break;
      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        curX += sx;
      }
      if (e2 < dx) {
        err += dx;
        curY += sy;
      }
    }

    return indices;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  High-Performance CustomPainter with Night Sky & Comet Physics
// ─────────────────────────────────────────────────────────────────────────────

class _PixelGridPainter extends CustomPainter {
  final List<_TouchPoint> touches;
  final double time;
  final PixelPatternMode patternMode;
  final double pixelSize;
  final double pixelGap;
  final double glowRadius;
  final Color glowColor;
  final Color baseColor;
  final double starDensity;
  final double cometInterval;

  static _NightSkyField? _cachedField;
  static Float32List _baseBuffer = Float32List(16384);
  static Float32List _litPixelsBuffer = Float32List(16384);
  static final List<Float32List> _bucketBuffers = List.generate(8, (_) => Float32List(8192));
  static final List<int> _bucketCounts = List.filled(8, 0);
  static final List<Paint> _cachedBucketPaints = List.generate(8, (_) => Paint());
  static final Paint _cachedBasePaint = Paint();
  static Color? _lastBaseColor;
  static Color? _lastGlowColor;
  static double? _lastPixelSize;

  const _PixelGridPainter({
    required this.touches,
    required this.time,
    required this.patternMode,
    required this.pixelSize,
    required this.pixelGap,
    required this.glowRadius,
    required this.glowColor,
    required this.baseColor,
    required this.starDensity,
    required this.cometInterval,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final step = pixelSize + pixelGap;
    final cols = (size.width / step).ceil() + 1;
    final rows = (size.height / step).ceil() + 1;
    final totalDots = cols * rows;

    // ── Ensure buffer sizes ──────────────────────────────────────────────
    if (_baseBuffer.length < totalDots * 2) {
      _baseBuffer = Float32List(totalDots * 2 + 1024);
    }
    if (_litPixelsBuffer.length < totalDots) {
      _litPixelsBuffer = Float32List(totalDots + 1024);
    }
    _litPixelsBuffer.fillRange(0, totalDots, 0.0);
    final litPixels = _litPixelsBuffer;

    // ── Build or update cached Night Sky field if dimensions change ──
    if (patternMode == PixelPatternMode.nightSky ||
        patternMode == PixelPatternMode.constellation) {
      if (_cachedField == null ||
          _cachedField!.cols != cols ||
          _cachedField!.rows != rows) {
        _cachedField = _NightSkyField.build(cols, rows, starDensity);
      }
    }

    // Active touch points with non-zero alpha
    final activePts = touches
        .where((t) => t.currentAlpha > 0.005)
        .map((t) => (x: t.position.dx, y: t.position.dy, alpha: t.currentAlpha))
        .toList();

    // ── 1. Calculate Ambient Pattern & Stars ─────────────────────────────
    switch (patternMode) {
      case PixelPatternMode.nightSky:
        _computeNightSkyPattern(litPixels, cols, rows, size, step);
        break;
      case PixelPatternMode.constellation:
        _computeConstellationMode(litPixels, cols, rows, size, step);
        break;
      case PixelPatternMode.flowingWaves:
        _computeWavesPattern(litPixels, cols, rows);
        break;
      case PixelPatternMode.matrixTrail:
        _computeMatrixPattern(litPixels, cols, rows);
        break;
      case PixelPatternMode.geometricGrid:
        _computeGeometricPattern(litPixels, cols, rows);
        break;
      case PixelPatternMode.interactiveOnly:
        break;
    }

    // ── 2. Calculate Touch / Pointer Glowing Pixels ──────────────────────
    if (activePts.isNotEmpty) {
      final glowRadiusSq = glowRadius * glowRadius;
      for (final p in activePts) {
        final minCol = ((p.x - glowRadius) / step).floor().clamp(0, cols - 1);
        final maxCol = ((p.x + glowRadius) / step).ceil().clamp(0, cols - 1);
        final minRow = ((p.y - glowRadius) / step).floor().clamp(0, rows - 1);
        final maxRow = ((p.y + glowRadius) / step).ceil().clamp(0, rows - 1);

        for (int r = minRow; r <= maxRow; r++) {
          final cy = r * step + pixelSize / 2;
          final dy = cy - p.y;
          final dySq = dy * dy;

          for (int c = minCol; c <= maxCol; c++) {
            final cx = c * step + pixelSize / 2;
            final dx = cx - p.x;
            final distSq = dx * dx + dySq;

            if (distSq < glowRadiusSq) {
              final dist = math.sqrt(distSq);
              final normDist = dist / glowRadius; // 0.0 (center) to 1.0 (edge)
              final falloff = math.pow((1.0 - normDist).clamp(0.0, 1.0), 0.7).toDouble();
              final touchBrightness = (falloff * 1.45).clamp(0.0, 1.0) * p.alpha;

              final idx = r * cols + c;
              if (touchBrightness > litPixels[idx]) {
                litPixels[idx] = touchBrightness.clamp(0.0, 1.0);
              }
            }
          }
        }
      }
    }

    // ── 3. Group Lit Pixels into Brightness Buckets for Batch Draw Calls ──
    const numBuckets = 8;
    for (int i = 0; i < numBuckets; i++) {
      _bucketCounts[i] = 0;
    }
    int basePtr = 0;

    for (int r = 0; r < rows; r++) {
      final cy = r * step + pixelSize / 2;
      for (int c = 0; c < cols; c++) {
        final cx = c * step + pixelSize / 2;
        final idx = r * cols + c;
        final brightness = litPixels[idx];

        if (brightness < 0.02) {
          _baseBuffer[basePtr++] = cx;
          _baseBuffer[basePtr++] = cy;
        } else {
          final bIdx = ((brightness.clamp(0.0, 1.0)) * (numBuckets - 1))
              .floor()
              .clamp(0, numBuckets - 1);
          var bBuf = _bucketBuffers[bIdx];
          var count = _bucketCounts[bIdx];
          if (count + 2 >= bBuf.length) {
            bBuf = Float32List(bBuf.length * 2);
            _bucketBuffers[bIdx] = bBuf;
          }
          bBuf[count] = cx;
          bBuf[count + 1] = cy;
          _bucketCounts[bIdx] = count + 2;
        }
      }
    }

    // ── 4. Render All Base Unlit Pixels (1 Fast Draw Call) ───────────────
    if (_lastBaseColor != baseColor || _lastPixelSize != pixelSize) {
      _cachedBasePaint
        ..strokeWidth = pixelSize
        ..strokeCap = StrokeCap.square
        ..style = PaintingStyle.stroke
        ..color = baseColor.withValues(alpha: 0.28);
    }

    if (basePtr > 0) {
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.sublistView(_baseBuffer, 0, basePtr),
        _cachedBasePaint,
      );
    }

    // ── 5. Render Brightness Buckets with Cached Luminous Paints ─────────
    if (_lastGlowColor != glowColor || _lastBaseColor != baseColor || _lastPixelSize != pixelSize) {
      for (int i = 0; i < numBuckets; i++) {
        final t = (i + 1) / numBuckets;
        final color = Color.lerp(
          baseColor.withValues(alpha: 0.35),
          glowColor,
          t,
        )!;
        _cachedBucketPaints[i]
          ..strokeWidth = pixelSize
          ..strokeCap = StrokeCap.square
          ..style = PaintingStyle.stroke
          ..color = color;
      }
      _lastBaseColor = baseColor;
      _lastGlowColor = glowColor;
      _lastPixelSize = pixelSize;
    }

    for (int i = 0; i < numBuckets; i++) {
      final count = _bucketCounts[i];
      if (count == 0) continue;

      canvas.drawRawPoints(
        PointMode.points,
        Float32List.sublistView(_bucketBuffers[i], 0, count),
        _cachedBucketPaints[i],
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Night Sky Engine: Deep Stars + Passing Comets & Shooting Stars
  // ───────────────────────────────────────────────────────────────────────────
  void _computeNightSkyPattern(
    Float32List litPixels,
    int cols,
    int rows,
    Size size,
    double step,
  ) {
    final field = _cachedField;
    if (field == null) return;

    // 1. Render Realistic Twinkling Night Stars
    _renderNightStars(litPixels, field, cols, rows);

    // 2. Render Passing Comets & Shooting Stars at dynamic intervals
    _renderComets(litPixels, cols, rows, size, step);
  }

  void _computeConstellationMode(
    Float32List litPixels,
    int cols,
    int rows,
    Size size,
    double step,
  ) {
    final field = _cachedField;
    if (field == null) return;

    _renderNightStars(litPixels, field, cols, rows);

    // Delicate Constellation Lines
    for (final link in field.links) {
      const lineBrightness = 0.22;
      for (final pIdx in link.pixelIndices) {
        if (lineBrightness > litPixels[pIdx]) {
          litPixels[pIdx] = lineBrightness;
        }
      }
    }

    _renderComets(litPixels, cols, rows, size, step);
  }

  void _renderNightStars(
    Float32List litPixels,
    _NightSkyField field,
    int cols,
    int rows,
  ) {
    for (int i = 0; i < field.stars.length; i++) {
      final star = field.stars[i];

      // Compound atmospheric wave
      final w1 = (math.sin(time * star.pulseSpeed1 + star.phase1) + 1.0) * 0.5;
      final w2 = (math.sin(time * star.pulseSpeed2 + star.phase2) + 1.0) * 0.5;
      final combinedWave = (w1 * 0.65 + w2 * 0.35);
      final twinkleGlint = math.pow(combinedWave, star.twinkleExponent).toDouble();

      double brightness = star.baseBrightness * (0.65 + combinedWave * 0.35) + twinkleGlint * 0.30;

      switch (star.tier) {
        case _StarTier.brightBeacon:
          brightness = brightness.clamp(0.60, 1.0);
          break;
        case _StarTier.midMagnitude:
          brightness = brightness.clamp(0.25, 0.85);
          break;
        case _StarTier.faintStardust:
          brightness = brightness.clamp(0.12, 0.40);
          break;
      }

      // ── 1-2 Second Stellar Flare (swell to max 1.0, sustain, and fade) ──
      double flareBoost = 0.0;
      if (star.canFlare) {
        final tInFlare = (time + star.flareOffset) % star.flarePeriod;
        if (tInFlare < star.flareDuration) {
          final p = tInFlare / star.flareDuration; // 0.0 to 1.0
          // Smooth sine swell (first 25%), sustained peak (25%-60%), graceful decay (60%-100%)
          if (p < 0.25) {
            flareBoost = math.sin((p / 0.25) * math.pi * 0.5);
          } else if (p < 0.60) {
            flareBoost = 1.0;
          } else {
            final decayP = (p - 0.60) / 0.40;
            flareBoost = math.pow(1.0 - decayP, 1.8).toDouble();
          }
          // Spike brightness straight to maximum pure white 1.0
          brightness = math.max(brightness, flareBoost);
        }
      }

      final idx = star.row * cols + star.col;
      litPixels[idx] = brightness;

      // Bright beacon stars & flaring stars emit soft 4-way cross diffraction spikes
      if (flareBoost > 0.30 || (star.tier == _StarTier.brightBeacon && brightness > 0.72)) {
        final spikeB = math.max(
          (brightness - 0.72).clamp(0.0, 0.28) / 0.28 * 0.32,
          flareBoost * 0.42,
        );
        if (star.row > 0) {
          final pIdx = (star.row - 1) * cols + star.col;
          if (spikeB > litPixels[pIdx]) litPixels[pIdx] = spikeB;
        }
        if (star.row < rows - 1) {
          final pIdx = (star.row + 1) * cols + star.col;
          if (spikeB > litPixels[pIdx]) litPixels[pIdx] = spikeB;
        }
        if (star.col > 0) {
          final pIdx = star.row * cols + (star.col - 1);
          if (spikeB > litPixels[pIdx]) litPixels[pIdx] = spikeB;
        }
        if (star.col < cols - 1) {
          final pIdx = star.row * cols + (star.col + 1);
          if (spikeB > litPixels[pIdx]) litPixels[pIdx] = spikeB;
        }
      }
    }
  }

  void _renderComets(
    Float32List litPixels,
    int cols,
    int rows,
    Size size,
    double step,
  ) {
    // We simulate passing comets using scheduled cyclical epochs
    // Each comet epoch lasts `interval` seconds (default ~6.0s)
    final interval = cometInterval.clamp(3.0, 20.0);
    final currentEpoch = (time / interval).floor();

    // Render current comet and previous comet (if still in flight / tail dissipating)
    for (int epoch = currentEpoch - 1; epoch <= currentEpoch + 1; epoch++) {
      if (epoch < 0) continue;

      // Deterministic pseudo-random parameters for this comet epoch
      int seed(int k) {
        int h = epoch * 73856093 + k * 19349663;
        h = (h ^ (h >> 13)) * 1274126177;
        return (h ^ (h >> 16)) & 0x7FFFFFFF;
      }

      double randVal(int k) => (seed(k) % 10000) / 10000.0;

      final cometStartTime = epoch * interval + randVal(1) * (interval * 0.35);
      final duration = 1.6 + randVal(2) * 1.6; // 1.6s to 3.2s flight time
      final progress = (time - cometStartTime) / duration;

      if (progress < 0.0 || progress > 1.25) {
        // Not active or fully dissipated
        continue;
      }

      // Comet trajectory generation across screen
      final angleChoice = randVal(3);
      double startX, startY, endX, endY;

      if (angleChoice < 0.45) {
        // Trajectory 1: Sweeping from Top-Right down towards Bottom-Left (Classic meteor path)
        startX = cols * (0.60 + randVal(4) * 0.45);
        startY = -rows * 0.15 + randVal(5) * rows * 0.30;
        endX = cols * (-0.20 + randVal(6) * 0.40);
        endY = rows * (0.70 + randVal(7) * 0.45);
      } else if (angleChoice < 0.80) {
        // Trajectory 2: Sweeping from Top-Left down towards Bottom-Right
        startX = cols * (-0.15 + randVal(4) * 0.35);
        startY = -rows * 0.15 + randVal(5) * rows * 0.25;
        endX = cols * (0.75 + randVal(6) * 0.40);
        endY = rows * (0.65 + randVal(7) * 0.45);
      } else {
        // Trajectory 3: Majestic high-altitude sweep across upper sky
        startX = cols * (0.85 + randVal(4) * 0.30);
        startY = rows * (0.05 + randVal(5) * 0.20);
        endX = -cols * 0.20;
        endY = rows * (0.25 + randVal(7) * 0.35);
      }

      final isGrandComet = randVal(8) < 0.30; // 30% chance for extra long majestic comet
      final tailLength = isGrandComet ? (30.0 + randVal(9) * 20.0) : (16.0 + randVal(9) * 14.0);
      final headBrightness = 1.0;

      // Current head position along trajectory
      final currentProgress = progress.clamp(0.0, 1.0);
      final headCol = startX + (endX - startX) * currentProgress;
      final headRow = startY + (endY - startY) * currentProgress;

      // Trajectory direction vector
      final dx = endX - startX;
      final dy = endY - startY;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len <= 0) continue;

      final dirX = dx / len;
      final dirY = dy / len;

      // Dissipation fade out when comet completes flight
      final flightFade = progress > 1.0 ? (1.0 - (progress - 1.0) / 0.25) : 1.0;

      // ── 1. Draw Glowing Comet Nucleus & Coma Halo ────────────────────
      final intHeadCol = headCol.round();
      final intHeadRow = headRow.round();

      for (int dr = -2; dr <= 2; dr++) {
        for (int dc = -2; dc <= 2; dc++) {
          final r = intHeadRow + dr;
          final c = intHeadCol + dc;
          if (c >= 0 && c < cols && r >= 0 && r < rows) {
            final distSq = dc * dc + dr * dr;
            if (distSq <= 4) {
              final comaGlow = (1.0 - math.sqrt(distSq) / 2.2) * headBrightness * flightFade;
              if (comaGlow > 0.05) {
                final pIdx = r * cols + c;
                if (comaGlow > litPixels[pIdx]) litPixels[pIdx] = comaGlow;
              }
            }
          }
        }
      }

      // ── 2. Draw Tapered Luminous Ion & Dust Tail ──────────────────────
      final samples = tailLength.toInt();
      for (int s = 1; s <= samples; s++) {
        final tDist = s.toDouble();
        final tailProgress = tDist / tailLength; // 0.0 (near head) to 1.0 (tail tip)

        // Tail center coordinate
        final tailCol = headCol - dirX * tDist;
        final tailRow = headRow - dirY * tDist;

        // Exponential luminous decay along tail
        final decay = math.pow(1.0 - tailProgress, 1.6).toDouble() * flightFade;
        if (decay < 0.02) continue;

        // Particle scintillation in tail
        final shimmer = 0.85 + 0.15 * math.sin(s * 1.3 + time * 8.0);
        final baseTailBrightness = decay * shimmer * (isGrandComet ? 0.95 : 0.80);

        // Tail lateral width (tapered)
        final maxLateral = isGrandComet ? (1.8 * (1.0 - tailProgress * 0.6)) : (1.2 * (1.0 - tailProgress * 0.7));

        final normX = -dirY; // Perpendicular normal
        final normY = dirX;

        for (int w = -2; w <= 2; w++) {
          final c = (tailCol + normX * w).round();
          final r = (tailRow + normY * w).round();

          if (c >= 0 && c < cols && r >= 0 && r < rows) {
            final lateralDist = w.abs().toDouble();
            if (lateralDist <= maxLateral) {
              final lateralFalloff = 1.0 - (lateralDist / (maxLateral + 0.5));
              final tailB = baseTailBrightness * lateralFalloff;

              if (tailB > 0.03) {
                final pIdx = r * cols + c;
                if (tailB > litPixels[pIdx]) litPixels[pIdx] = tailB;
              }
            }
          }
        }
      }
    }
  }

  void _computeWavesPattern(
    Float32List litPixels,
    int cols,
    int rows,
  ) {
    for (int r = 0; r < rows; r += 2) {
      for (int c = 0; c < cols; c += 2) {
        final w1 = math.sin(c * 0.12 + r * 0.08 + time * 1.5);
        final w2 = math.cos(c * 0.07 - r * 0.14 - time * 1.1);
        final val = ((w1 + w2) * 0.5 + 1.0) * 0.5;

        if (val > 0.65) {
          final b = math.pow((val - 0.65) / 0.35, 1.8).toDouble() * 0.65;
          litPixels[r * cols + c] = b;
        }
      }
    }
  }

  void _computeMatrixPattern(
    Float32List litPixels,
    int cols,
    int rows,
  ) {
    const streamSpacing = 6;
    for (int c = 2; c < cols; c += streamSpacing) {
      final speed = 8.0 + ((c * 17) % 7);
      final offset = (c * 23) % rows;
      final headY = ((time * speed + offset) % (rows + 15)).toInt();

      for (int tail = 0; tail < 12; tail++) {
        final r = headY - tail;
        if (r >= 0 && r < rows) {
          final b = (1.0 - (tail / 12.0)) * 0.60;
          litPixels[r * cols + c] = b;
        }
      }
    }
  }

  void _computeGeometricPattern(
    Float32List litPixels,
    int cols,
    int rows,
  ) {
    final centerX = cols / 2.0;
    final centerY = rows / 2.0;

    for (int r = 0; r < rows; r += 3) {
      for (int c = 0; c < cols; c += 3) {
        final dx = (c - centerX).abs();
        final dy = (r - centerY).abs();
        final diamondDist = dx + dy;

        final wave = (math.sin(diamondDist * 0.25 - time * 2.0) + 1.0) * 0.5;
        if (wave > 0.70) {
          final b = math.pow((wave - 0.70) / 0.30, 2).toDouble() * 0.60;
          litPixels[r * cols + c] = b;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PixelGridPainter old) => true;
}
