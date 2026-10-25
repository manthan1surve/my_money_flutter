import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/currency_format.dart';
class AnimatedConcentricRingsChart extends StatefulWidget {
  final List<Map<String, dynamic>> rings;
  final double size;
  final int? selectedIndex;
  final ValueChanged<int?>? onRingTap;
  final bool isActive;

  const AnimatedConcentricRingsChart({
    super.key,
    required this.rings,
    this.size = 140.0,
    this.selectedIndex,
    this.onRingTap,
    this.isActive = true,
  });

  @override
  State<AnimatedConcentricRingsChart> createState() => _AnimatedConcentricRingsChartState();
}

class _AnimatedConcentricRingsChartState extends State<AnimatedConcentricRingsChart>
    with TickerProviderStateMixin {
  late AnimationController _sweepController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  late AnimationController _selectionController;
  int? _activeSelectedIndex;
  int? _prevSelectedIndex;

  @override
  void initState() {
    super.initState();
    _activeSelectedIndex = widget.selectedIndex;
    _prevSelectedIndex = widget.selectedIndex;

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sweepController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _sweepController,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.selectedIndex != null ? 1.0 : 0.0,
    );

    if (widget.isActive) {
      _sweepController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedConcentricRingsChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _prevSelectedIndex = _activeSelectedIndex;
      _activeSelectedIndex = widget.selectedIndex;
      _selectionController.forward(from: 0.0);
    }

    if (!oldWidget.isActive && widget.isActive) {
      _sweepController.forward(from: 0.0);
      return;
    } else if (oldWidget.isActive && !widget.isActive) {
      _sweepController.reset();
      return;
    }

    bool ringsChanged = oldWidget.rings.length != widget.rings.length;
    if (!ringsChanged) {
      for (int i = 0; i < widget.rings.length; i++) {
        if (widget.rings[i]['id'] != oldWidget.rings[i]['id'] ||
            widget.rings[i]['percentage'] != oldWidget.rings[i]['percentage'] ||
            widget.rings[i]['color'] != oldWidget.rings[i]['color']) {
          ringsChanged = true;
          break;
        }
      }
    }

    if (ringsChanged) {
      _sweepController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.rings.isEmpty) return;
    final double center = widget.size / 2;
    final dx = details.localPosition.dx - center;
    final dy = details.localPosition.dy - center;
    final double distance = sqrt(dx * dx + dy * dy);

    const double maxStroke = 10.0;
    const double gapRatio = 0.5;
    final int count = widget.rings.length;
    final double divisor = (count + (count - 1) * gapRatio);
    final double requiredStroke = divisor > 0 ? (center - 10) / divisor : maxStroke;
    final double strokeWidth = min(maxStroke, requiredStroke);
    final double gap = strokeWidth * gapRatio;

    int tappedIndex = -1;
    for (int i = 0; i < widget.rings.length; i++) {
      final double radius = center - 5 - (strokeWidth / 2) - (i * (strokeWidth + gap));
      if (radius <= 0) break;
      if ((distance - radius).abs() <= strokeWidth * 0.95) {
        tappedIndex = i;
        break;
      }
    }

    setState(() {
      _prevSelectedIndex = _activeSelectedIndex;
      if (tappedIndex != -1) {
        _activeSelectedIndex = (_activeSelectedIndex == tappedIndex) ? null : tappedIndex;
      } else {
        _activeSelectedIndex = null;
      }
    });
    _selectionController.forward(from: 0.0);
    widget.onRingTap?.call(_activeSelectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTapUp,
      child: AnimatedBuilder(
        animation: Listenable.merge([_sweepController, _selectionController]),
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: AnimatedConcentricRingsPainter(
                      rings: widget.rings,
                      progress: _sweepController.value,
                      selectedIndex: _activeSelectedIndex,
                      prevSelectedIndex: _prevSelectedIndex,
                      selectionProgress: _selectionController.value,
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

class AnimatedConcentricRingsPainter extends CustomPainter {
  final List<Map<String, dynamic>> rings;
  final double progress;
  final int? selectedIndex;
  final int? prevSelectedIndex;
  final double selectionProgress;

  static final Paint _bgPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  static final Paint _solidPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  AnimatedConcentricRingsPainter({
    required this.rings,
    required this.progress,
    this.selectedIndex,
    this.prevSelectedIndex,
    this.selectionProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rings.isEmpty) return;
    final double center = size.width / 2;
    final Offset centerOffset = Offset(center, center);

    const double maxStroke = 10.0;
    const double gapRatio = 0.5;
    final int count = rings.length;
    final double divisor = (count + (count - 1) * gapRatio);
    final double requiredStroke = divisor > 0 ? (center - 10) / divisor : maxStroke;
    final double strokeWidth = min(maxStroke, requiredStroke);
    final double gap = strokeWidth * gapRatio;

    // Smooth selection interpolation
    final bool hasSelection = selectedIndex != null;
    final double selectFactor = Curves.easeInOutCubic.transform(selectionProgress.clamp(0.0, 1.0));

    for (int i = 0; i < rings.length; i++) {
      final ring = rings[i];
      final double radius = center - 5 - (strokeWidth / 2) - (i * (strokeWidth + gap));
      if (radius <= 0) break;
      final Rect rect = Rect.fromCircle(center: centerOffset, radius: radius);

      // Compute smoothly interpolated highlight
      final bool isCurrentSelected = selectedIndex == i;
      final bool wasPrevSelected = prevSelectedIndex == i;
      double highlightWeight;
      if (isCurrentSelected && wasPrevSelected) {
        highlightWeight = 1.0;
      } else if (isCurrentSelected) {
        highlightWeight = selectFactor;
      } else if (wasPrevSelected) {
        highlightWeight = 1.0 - selectFactor;
      } else {
        highlightWeight = 0.0;
      }

      final double currentStroke = strokeWidth + (highlightWeight * 2.0);

      // Background track
      final double bgAlpha = hasSelection
          ? ui.lerpDouble(0.05, 0.02, selectFactor)!
          : 0.05;
      _bgPaint
        ..color = Colors.white.withValues(alpha: bgAlpha)
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(centerOffset, radius, _bgPaint);

      if (progress <= 0) continue;

      final double percentage = ((ring['percentage'] as num?)?.toDouble() ?? 0.0) / 100.0;
      final double targetSweepAngle = min(percentage * 360, 360) * pi / 180;
      if (targetSweepAngle <= 0) continue;

      // Ultra-smooth cascading ease-in-out curve
      final double delay = count > 1 ? (i / (count - 1)) * 0.28 : 0.0;
      const double ringDuration = 0.72;
      final double localProgress = ((progress - delay) / ringDuration).clamp(0.0, 1.0);
      final double ringEase = Curves.easeInOutCubic.transform(localProgress);
      final double sweepAngle = targetSweepAngle * ringEase;

      if (sweepAngle <= 0.001) continue;

      // Smooth fade-in during the initial ~50ms of each ring's movement to prevent cap pop
      final double startFeather = (localProgress / 0.08).clamp(0.0, 1.0);

      final Color baseColor = ring['color'] as Color? ?? Colors.white;
      final double targetDim = hasSelection ? 0.35 : 1.0;
      final double colorDim = ui.lerpDouble(1.0, isCurrentSelected ? 1.0 : targetDim, selectFactor)!;
      final double finalAlpha = (colorDim * startFeather).clamp(0.0, 1.0);

      final Color color = baseColor.withValues(alpha: finalAlpha);

      final double glowAlpha = ui.lerpDouble(0.6, 0.85, highlightWeight)! * startFeather;
      _glowPaint
        ..strokeWidth = currentStroke
        ..color = baseColor.withValues(alpha: glowAlpha);
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, _glowPaint);

      _solidPaint
        ..strokeWidth = currentStroke
        ..color = color;
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, _solidPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedConcentricRingsPainter oldDelegate) {
    if (progress != oldDelegate.progress ||
        selectedIndex != oldDelegate.selectedIndex ||
        prevSelectedIndex != oldDelegate.prevSelectedIndex ||
        selectionProgress != oldDelegate.selectionProgress ||
        rings.length != oldDelegate.rings.length) {
      return true;
    }
    for (int i = 0; i < rings.length; i++) {
      if (rings[i]['id'] != oldDelegate.rings[i]['id'] ||
          rings[i]['percentage'] != oldDelegate.rings[i]['percentage'] ||
          rings[i]['color'] != oldDelegate.rings[i]['color']) {
        return true;
      }
    }
    return false;
  }
}

class AnimatedPieChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final double totalAmount;
  final String currencySymbol;
  final String analysisType;
  final double size;
  final int? selectedIndex;
  final ValueChanged<int?>? onSliceTap;

  const AnimatedPieChart({
    super.key,
    required this.data,
    required this.totalAmount,
    required this.currencySymbol,
    this.analysisType = 'expense',
    this.size = 160.0,
    this.selectedIndex,
    this.onSliceTap,
  });

  @override
  State<AnimatedPieChart> createState() => _AnimatedPieChartState();
}

class _AnimatedPieChartState extends State<AnimatedPieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sweepAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _sweepAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _selectedIndex = widget.selectedIndex;
    }

    bool shouldReplay = oldWidget.analysisType != widget.analysisType ||
        oldWidget.totalAmount != widget.totalAmount ||
        oldWidget.data.length != widget.data.length;

    if (!shouldReplay && oldWidget.data.length == widget.data.length) {
      for (int i = 0; i < widget.data.length; i++) {
        if (widget.data[i]['id'] != oldWidget.data[i]['id'] ||
            widget.data[i]['amount'] != oldWidget.data[i]['amount']) {
          shouldReplay = true;
          break;
        }
      }
    }

    if (shouldReplay) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapUp(TapUpDetails details) {
    final double halfSize = widget.size / 2;
    final Offset center = Offset(halfSize, halfSize);
    final dx = details.localPosition.dx - center.dx;
    final dy = details.localPosition.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    const double strokeWidth = 20.0;
    final double radius = halfSize - 10.0;
    final double midRadius = radius - strokeWidth / 2;
    final double innerRadius = midRadius - strokeWidth / 2 - 6;
    final double outerRadius = midRadius + strokeWidth / 2 + 10;

    if (distance < innerRadius) {
      // Tap center hole -> deselect
      if (_selectedIndex != null) {
        setState(() => _selectedIndex = null);
        widget.onSliceTap?.call(null);
      }
      return;
    }

    if (distance >= innerRadius && distance <= outerRadius && widget.data.isNotEmpty) {
      // Tap ring -> find slice
      double touchAngle = atan2(dy, dx);
      double normalizedAngle = touchAngle - (-pi / 2);
      if (normalizedAngle < 0) normalizedAngle += 2 * pi;

      double totalPercentage = 0.0;
      for (final d in widget.data) {
        totalPercentage += (d['percentage'] as num?)?.toDouble() ?? 0.0;
      }
      if (totalPercentage <= 0) totalPercentage = 100.0;

      double accumulated = 0.0;
      int tappedIndex = -1;
      for (int i = 0; i < widget.data.length; i++) {
        final frac = ((widget.data[i]['percentage'] as num?)?.toDouble() ?? 0.0) / totalPercentage;
        final sweep = frac * 2 * pi;
        if (normalizedAngle >= accumulated && normalizedAngle < accumulated + sweep) {
          tappedIndex = i;
          break;
        }
        accumulated += sweep;
      }

      if (tappedIndex != -1) {
        setState(() {
          if (_selectedIndex == tappedIndex) {
            _selectedIndex = null;
          } else {
            _selectedIndex = tappedIndex;
          }
        });
        widget.onSliceTap?.call(_selectedIndex);
      }
    }
  }

  Widget _buildCenterContent() {
    if (_selectedIndex != null && _selectedIndex! < widget.data.length) {
      final item = widget.data[_selectedIndex!];
      final icon = item['icon'] as String? ?? '📊';
      final name = item['name'] as String? ?? '';
      final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
      final percentage = (item['percentage'] as num?)?.toDouble() ?? 0.0;
      final color = item['color'] as Color? ?? Colors.white;

      return Column(
        key: ValueKey('slice_center_$_selectedIndex'),
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            "${percentage.toStringAsFixed(1)}%",
            style: GoogleFonts.inter(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                "${widget.currencySymbol}${amount.formatIndianCurrency()}",
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final isExpense = widget.analysisType == 'expense';
    final typeLabel = isExpense ? "EXPENSE" : "INCOME";
    final typeColor = isExpense ? const Color(0xFFFE0000) : const Color(0xFF00FE06);

    return Column(
      key: const ValueKey('total_center_display'),
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          typeLabel,
          style: TextStyle(
            color: typeColor,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              "${widget.currencySymbol}${widget.totalAmount.formatIndianCurrency()}",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "${widget.data.length} ${widget.data.length == 1 ? 'Category' : 'Categories'}",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTapUp,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _PieChartPainter(
                          data: widget.data,
                          progress: _sweepAnimation.value,
                          selectedIndex: _selectedIndex,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: widget.size * 0.62,
                      height: widget.size * 0.62,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.92, end: 1.0).animate(animation),
                            child: child,
                          ),
                        ),
                        child: _buildCenterContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double progress;
  final int? selectedIndex;

  _PieChartPainter({
    required this.data,
    required this.progress,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerVal = size.width / 2;
    final Offset center = Offset(centerVal, centerVal);
    const double strokeWidth = 20.0;
    final double radius = centerVal - 10.0;
    final double midRadius = radius - strokeWidth / 2;

    // 1. Draw subtle background track
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(center, midRadius, bgPaint);

    if (data.isEmpty || progress <= 0) return;

    double totalPercentage = 0.0;
    for (final d in data) {
      totalPercentage += (d['percentage'] as num?)?.toDouble() ?? 0.0;
    }
    if (totalPercentage <= 0) totalPercentage = 100.0;

    const double gapAngle = 0.045; // ~2.5 degrees gap between slices
    final double maxSweep = 2 * pi * progress;
    double currentStart = -pi / 2;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final frac = ((item['percentage'] as num?)?.toDouble() ?? 0.0) / totalPercentage;
      final sliceFullSweep = 2 * pi * frac;
      final isSelected = selectedIndex == i;
      final hasSelection = selectedIndex != null;

      if (currentStart >= -pi / 2 + maxSweep) {
        break;
      }

      final availableSweep = (-pi / 2 + maxSweep) - currentStart;
      final actualSweep = min(sliceFullSweep, availableSweep);

      if (actualSweep > 0) {
        final double drawStart;
        final double drawSweep;

        if (data.length > 1) {
          final effectiveGap = min(gapAngle, sliceFullSweep * 0.35);
          if (actualSweep > effectiveGap) {
            drawStart = currentStart + (effectiveGap / 2);
            drawSweep = actualSweep - effectiveGap;
          } else {
            drawStart = currentStart;
            drawSweep = actualSweep;
          }
        } else {
          drawStart = currentStart;
          drawSweep = actualSweep;
        }

        final double sliceStroke = isSelected ? strokeWidth + 4.0 : strokeWidth;
        final double sliceRadius = midRadius + (isSelected ? 2.0 : 0.0);
        final Rect sliceRect = Rect.fromCircle(center: center, radius: sliceRadius);

        Color sliceColor = item['color'] as Color? ?? Colors.white;
        if (hasSelection && !isSelected) {
          sliceColor = sliceColor.withValues(alpha: 0.35);
        }

        // Draw ambient glow
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sliceStroke
          ..strokeCap = StrokeCap.butt
          ..color = sliceColor.withValues(alpha: isSelected ? 0.5 : 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawArc(sliceRect, drawStart, drawSweep, false, glowPaint);

        // Draw solid sector
        final solidPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sliceStroke
          ..strokeCap = StrokeCap.butt
          ..color = sliceColor;
        canvas.drawArc(sliceRect, drawStart, drawSweep, false, solidPaint);
      }

      currentStart += sliceFullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        selectedIndex != oldDelegate.selectedIndex ||
        data != oldDelegate.data;
  }
}

class CustomLineChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final double maxAmount;
  final Color color;
  final String currencySymbol;
  final bool showAllLabels;
  final bool isExpense;
  final int? defaultIndex;
  final ValueChanged<Map<String, dynamic>>? onActiveItemChanged;
  final double labelWidth;

  const CustomLineChart({
    super.key,
    required this.data,
    required this.maxAmount,
    required this.color,
    required this.currencySymbol,
    required this.showAllLabels,
    required this.isExpense,
    this.defaultIndex,
    this.onActiveItemChanged,
    this.labelWidth = 36,
  });

  @override
  State<CustomLineChart> createState() => _CustomLineChartState();
}

class _CustomLineChartState extends State<CustomLineChart> {
  late ValueNotifier<int> _activeIndexNotifier;

  @override
  void initState() {
    super.initState();
    _activeIndexNotifier = ValueNotifier<int>(widget.defaultIndex ?? -1);
  }

  @override
  void didUpdateWidget(CustomLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.defaultIndex != oldWidget.defaultIndex || widget.data != oldWidget.data) {
      _activeIndexNotifier.value = widget.defaultIndex ?? -1;
    }
  }

  @override
  void dispose() {
    _activeIndexNotifier.dispose();
    super.dispose();
  }

  final double _padL = 16;
  final double _padR = 16;
  final double _padTop = 20;
  final double _padBottom = 34;

  int _getDisplayIndex(int index) => index < 0 ? widget.data.length - 1 : index;

  double _getNiceMax() {
    if (widget.maxAmount <= 0) return 100;
    double step = widget.maxAmount / 4;
    double magnitude = pow(10, (log(step) / ln10).floor()).toDouble();
    if (widget.maxAmount >= 1000 && magnitude < 1000) magnitude = 1000;
    double residual = step / magnitude;
    if (residual <= 1.2) { step = 1.0 * magnitude; }
    else if (residual <= 2.2) { step = 2.0 * magnitude; }
    else if (residual <= 3.0) { step = 2.5 * magnitude; }
    else if (residual <= 6.0) { step = 5.0 * magnitude; }
    else { step = 10.0 * magnitude; }
    return (widget.maxAmount / step).ceil() * step;
  }

  Offset _pointAt(int index, Size size, double niceMax) {
    final graphW = size.width - _padL - _padR;
    final graphH = size.height - _padTop - _padBottom;
    double x = widget.data.length > 1
        ? _padL + (index / (widget.data.length - 1)) * graphW
        : _padL + graphW / 2;
    double yRatio = niceMax > 0 ? (widget.data[index]['total'] as num).toDouble() / niceMax : 0;
    double y = _padTop + graphH - (yRatio.clamp(0.0, 1.0) * graphH);
    return Offset(x, y);
  }

  void _selectIndex(int index) {
    final idx = index.clamp(0, widget.data.length - 1);
    if (_activeIndexNotifier.value != idx) {
      _activeIndexNotifier.value = idx;
      widget.onActiveItemChanged?.call(widget.data[_getDisplayIndex(idx)]);
    }
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final graphW = size.width - _padL - _padR;
    if (graphW <= 0 || widget.data.isEmpty) return;
    final relX = (d.localPosition.dx - _padL).clamp(0.0, graphW);
    final frac = relX / graphW;
    final idx = (frac * (widget.data.length - 1)).round().clamp(0, widget.data.length - 1);
    _selectIndex(idx);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox();
    final niceMax = _getNiceMax();

    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _onPanUpdate(DragUpdateDetails(
          globalPosition: d.globalPosition,
          localPosition: d.localPosition,
          delta: Offset.zero,
          primaryDelta: 0,
        ), size),
        onPanUpdate: (d) => _onPanUpdate(d, size),
        onTapDown: (d) => _onPanUpdate(DragUpdateDetails(
          globalPosition: d.globalPosition,
          localPosition: d.localPosition,
          delta: Offset.zero,
          primaryDelta: 0,
        ), size),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Static Chart Painter (always rendered, cached by RepaintBoundary)
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _StaticLineChartPainter(
                    data: widget.data,
                    niceMax: niceMax,
                    color: widget.color,
                    padL: _padL,
                    padR: _padR,
                    padTop: _padTop,
                    padBottom: _padBottom,
                  ),
                ),
              ),
            ),

            // Dynamic Active Dot and Tooltip
            ValueListenableBuilder<int>(
              valueListenable: _activeIndexNotifier,
              builder: (context, activeIndex, _) {
                final displayIdx = _getDisplayIndex(activeIndex);
                final activePt = _pointAt(displayIdx, size, niceMax);
                final activeData = widget.data[displayIdx];

                final rawTotal = (activeData['total'] as num?)?.toDouble() ?? 0.0;
                final formattedAmount = rawTotal >= 1000
                    ? NumberFormat.decimalPattern('en_IN').format(rawTotal.round())
                    : rawTotal.round().toString();

                final graphW = size.width - _padL - _padR;
                final double alignX = graphW > 0
                    ? (((activePt.dx - _padL) / graphW) * 2 - 1.0).clamp(-1.0, 1.0)
                    : 0.0;

                final bool isNearTop = activePt.dy < 58;
                final double tooltipTop = isNearTop
                    ? (activePt.dy + 14).clamp(4.0, size.height - 60)
                    : (activePt.dy - 56).clamp(4.0, size.height - 60);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Active Dot Painter
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ActiveDotPainter(
                          data: widget.data,
                          niceMax: niceMax,
                          color: widget.color,
                          activeIndex: displayIdx,
                          padL: _padL,
                          padR: _padR,
                          padTop: _padTop,
                          padBottom: _padBottom,
                        ),
                      ),
                    ),

                    // Floating date & amount label above active point
                    Positioned(
                      top: tooltipTop,
                      left: _padL,
                      right: _padR,
                      child: Align(
                        alignment: Alignment(alignX, 0.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      activeData['label']?.toString() ?? '',
                                      style: GoogleFonts.fraunces(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                      softWrap: false,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${widget.currencySymbol}$formattedAmount',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                      softWrap: false,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // X-axis: labels
            Positioned(
              left: _padL,
              right: _padR,
              bottom: 6,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: 18,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _activeIndexNotifier,
                      builder: (context, activeIndex, _) {
                        final displayIdx = _getDisplayIndex(activeIndex);
                        final totalItems = widget.data.length;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: widget.data.asMap().entries.map((entry) {
                            final i = entry.key;
                            final item = entry.value;

                            bool showLabel = true;
                            String displayText = item['axisLabel']?.toString() ?? item['label']?.toString() ?? '';

                            if (totalItems > 14) {
                              // Monthly view (~28-31 days)
                              final int day = (item['dayNumber'] as int?) ?? (i + 1);
                              final int totalDays = (item['daysInMonth'] as int?) ?? totalItems;

                              // Show Day 1, multiples of 5 (5, 10, 15, 20, 25), and last day of the month
                              showLabel = (day == 1) || (day % 5 == 0) || (day == totalDays);
                              // Avoid crowding 30 and 31 together on 31-day months
                              if (day == 30 && totalDays == 31) {
                                showLabel = false;
                              }
                              displayText = day.toString();
                            } else if (totalItems > 8) {
                              // Yearly view (12 months)
                              if (!widget.showAllLabels) {
                                showLabel = (i % 2 == 0) || (i == totalItems - 1);
                              }
                            }

                            if (!showLabel) return const SizedBox.shrink();

                            final double leftPct = totalItems > 1 ? (i / (totalItems - 1)) : 0.5;
                            final double leftPos = leftPct * constraints.maxWidth;
                            const double labelW = 40.0;
                            final bool isActive = (i == displayIdx);

                            return Positioned(
                              left: leftPos - (labelW / 2),
                              width: labelW,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _selectIndex(i),
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 150),
                                  style: GoogleFonts.fraunces(
                                    color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                  child: Text(
                                    displayText,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _StaticLineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double niceMax;
  final Color color;
  final double padL, padR, padTop, padBottom;

  _StaticLineChartPainter({
    required this.data,
    required this.niceMax,
    required this.color,
    required this.padL,
    required this.padR,
    required this.padTop,
    required this.padBottom,
  });

  List<Offset> _buildPoints(Size size) {
    final graphW = size.width - padL - padR;
    final graphH = size.height - padTop - padBottom;
    return List.generate(data.length, (i) {
      double x = data.length > 1 ? padL + (i / (data.length - 1)) * graphW : padL + graphW / 2;
      double yRatio = niceMax > 0 ? (data[i]['total'] as num).toDouble() / niceMax : 0;
      return Offset(x, padTop + graphH - (yRatio.clamp(0.0, 1.0) * graphH));
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final points = _buildPoints(size);
    final graphBottom = size.height - padBottom;
    final graphLeft = padL;
    final graphRight = size.width - padR;

    // Draw background grid lines (subtle white grid)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    const double gridSpacing = 24.0;

    // Horizontal grid lines
    double y = graphBottom;
    while (y >= padTop) {
      canvas.drawLine(Offset(graphLeft, y), Offset(graphRight, y), gridPaint);
      y -= gridSpacing;
    }

    // Vertical grid lines
    double x = graphLeft;
    while (x <= graphRight) {
      canvas.drawLine(Offset(x, padTop), Offset(x, graphBottom), gridPaint);
      x += gridSpacing;
    }

    // Build smooth bezier path
    final path = Path();
    final fillPath = Path();

    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, graphBottom);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final cur = points[i];
      final nxt = points[i + 1];
      final midX = (cur.dx + nxt.dx) / 2;
      path.cubicTo(midX, cur.dy, midX, nxt.dy, nxt.dx, nxt.dy);
      fillPath.cubicTo(midX, cur.dy, midX, nxt.dy, nxt.dx, nxt.dy);
    }
    fillPath.lineTo(points.last.dx, graphBottom);
    fillPath.close();

    // Deep warm gradient fill (matches reference)
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, padTop),
        Offset(0, graphBottom),
        [color.withValues(alpha: 0.45), color.withValues(alpha: 0.12), color.withValues(alpha: 0.0)],
        [0.0, 0.6, 1.0],
      );
    canvas.drawPath(fillPath, fillPaint);

    // Glow
    canvas.drawPath(path, Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // Line
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _StaticLineChartPainter old) =>
      old.data != data || old.niceMax != niceMax || old.color != color;
}

class _ActiveDotPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double niceMax;
  final Color color;
  final int activeIndex;
  final double padL, padR, padTop, padBottom;

  _ActiveDotPainter({
    required this.data,
    required this.niceMax,
    required this.color,
    required this.activeIndex,
    required this.padL,
    required this.padR,
    required this.padTop,
    required this.padBottom,
  });

  List<Offset> _buildPoints(Size size) {
    final graphW = size.width - padL - padR;
    final graphH = size.height - padTop - padBottom;
    return List.generate(data.length, (i) {
      double x = data.length > 1 ? padL + (i / (data.length - 1)) * graphW : padL + graphW / 2;
      double yRatio = niceMax > 0 ? (data[i]['total'] as num).toDouble() / niceMax : 0;
      return Offset(x, padTop + graphH - (yRatio.clamp(0.0, 1.0) * graphH));
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || activeIndex < 0 || activeIndex >= data.length) return;
    final points = _buildPoints(size);
    final graphBottom = size.height - padBottom;

    final pt = points[activeIndex];

    // Vertical dashed line
    const dashH = 4.0;
    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.2;
    double dy = pt.dy;
    while (dy < graphBottom) {
      canvas.drawLine(Offset(pt.dx, dy), Offset(pt.dx, min(dy + dashH, graphBottom)), dashPaint);
      dy += dashH * 2;
    }

    // Outer glow ring
    canvas.drawCircle(pt, 12, Paint()..color = color.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    // Colored ring
    canvas.drawCircle(pt, 6, Paint()..color = color);
    // White inner dot
    canvas.drawCircle(pt, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ActiveDotPainter old) =>
      old.activeIndex != activeIndex || old.data != data || old.niceMax != niceMax || old.color != color;
}


class CustomGroupedBarChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final double maxAmount;
  final String currencySymbol;

  const CustomGroupedBarChart({
    super.key,
    required this.data,
    required this.maxAmount,
    this.currencySymbol = '\$',
  });

  @override
  State<CustomGroupedBarChart> createState() => _CustomGroupedBarChartState();
}

class _CustomGroupedBarChartState extends State<CustomGroupedBarChart> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    if (widget.data.isNotEmpty) {
      _selectedIndex = widget.data.length - 1;
    }
  }

  @override
  void didUpdateWidget(CustomGroupedBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data && widget.data.isNotEmpty) {
      _selectedIndex = widget.data.length - 1;
    }
  }

  List<double> _getNiceTicks() {
    double niceMax = widget.maxAmount;
    if (niceMax <= 0) return [100, 75, 50, 25, 0];
    
    double step = niceMax / 4;
    double magnitude = pow(10, (log(step) / ln10).floor()).toDouble();
    if (niceMax >= 1000 && magnitude < 1000) magnitude = 1000;
    
    double residual = step / magnitude;
    if (residual <= 1.2) { step = 1.0 * magnitude; }
    else if (residual <= 2.2) { step = 2.0 * magnitude; }
    else if (residual <= 3.0) { step = 2.5 * magnitude; }
    else if (residual <= 6.0) { step = 5.0 * magnitude; }
    else { step = 10.0 * magnitude; }

    niceMax = (widget.maxAmount / step).ceil() * step;
    List<double> ticks = [];
    for (double v = niceMax; v >= 0; v -= step) {
      ticks.add(v);
    }
    if (ticks.isEmpty || ticks.last != 0) ticks.add(0);
    return ticks;
  }

  String _formatY(double val) {
    if (val >= 1000) {
      double kVal = val / 1000;
      return kVal % 1 == 0 ? "${kVal.toInt()}k" : "${kVal.toStringAsFixed(1)}k";
    }
    return val.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final ticks = _getNiceTicks();
    final niceMax = ticks.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        
        final barAreaW = w - 45 - 20; // left: 45, right: 20
        final barAreaH = h - 30 - 30; // top: 30, bottom: 30
        
        double tooltipTop = 5;
        double tooltipAlignX = 0.0;
        
        if (_selectedIndex != null) {
          final item = widget.data[_selectedIndex!];
          final incPct = niceMax > 0 ? (item['income'] / niceMax) : 0.0;
          final expPct = niceMax > 0 ? (item['expense'] / niceMax) : 0.0;
          final maxPct = max(incPct, expPct).clamp(0.0, 1.0);
          
          final peakY = 30 + barAreaH - (maxPct * barAreaH);
          tooltipTop = peakY - 38; // 38px above the peak
          
          final colWidth = barAreaW / widget.data.length;
          final colCenterX = 45 + (colWidth * _selectedIndex!) + (colWidth / 2);
          
          tooltipAlignX = ((colCenterX / w) * 2 - 1.0).clamp(-1.0, 1.0);
        }

        return GestureDetector(
          onTapDown: (_) => setState(() => _selectedIndex = null),
          child: RepaintBoundary(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
            Positioned(
              top: 15,
              right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _selectedIndex == null ? 1.0 : 0.0,
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF00FE06), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 5),
                    Text("Income", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
                    const SizedBox(width: 15),
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFFE0000), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 5),
                    Text("Expense", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 5,
              top: 23,
              bottom: 23,
              width: 35,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: ticks.map((t) => Text(_formatY(t), style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w600))).toList(),
              ),
            ),

            Positioned(
              left: 45,
              right: 20,
              top: 30,
              bottom: 30,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ticks.map((t) => Container(height: 1, color: Colors.white.withValues(alpha: 0.05))).toList(), 
              ),
            ),

            Positioned(
              left: 45,
              right: 20,
              top: 30,
              bottom: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: widget.data.asMap().entries.map((entry) {
                  final int index = entry.key;
                  final item = entry.value;
                  final incPct = niceMax > 0 ? (item['income'] / niceMax) : 0.0;
                  final expPct = niceMax > 0 ? (item['expense'] / niceMax) : 0.0;
                  return Expanded(
                    child: GestureDetector(
                      onTapDown: (_) {
                        setState(() {
                          if (_selectedIndex == index) {
                            _selectedIndex = null;
                          } else {
                            _selectedIndex = index;
                          }
                        });
                      },
                      child: Container(
                        color: Colors.transparent, // Needed to catch taps
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            incPct > 0
                                ? FractionallySizedBox(
                                    heightFactor: incPct,
                                    child: Container(
                                      width: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00FE06),
                                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(3)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF00FE06).withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                            offset: const Offset(0, -2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : const SizedBox(width: 10),
                            const SizedBox(width: 4),
                            expPct > 0
                                ? FractionallySizedBox(
                                    heightFactor: expPct,
                                    child: Container(
                                      width: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFE0000),
                                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(3)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFE0000).withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                            offset: const Offset(0, -2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : const SizedBox(width: 10),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            Positioned(
              left: 45,
              right: 20,
              bottom: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: widget.data.map((item) => Expanded(
                  child: Text(
                    item['label'],
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                )).toList(),
              ),
            ),

            if (_selectedIndex != null)
              Positioned(
                top: tooltipTop,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment(tooltipAlignX, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${widget.data[_selectedIndex!]['label']}: ",
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 8),
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF00FE06), borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 4),
                              Text(
                                "${widget.currencySymbol}${widget.data[_selectedIndex!]['income'].round()}",
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 12),
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFFFE0000), borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 4),
                              Text(
                                "${widget.currencySymbol}${widget.data[_selectedIndex!]['expense'].round()}",
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
          ),
        );
  },
);
}
}

class BreathingText extends StatefulWidget {
  final String text;
  final Color color;
  final double fontSize;
  
  const BreathingText({super.key, required this.text, required this.color, required this.fontSize});
  
  @override
  State<BreathingText> createState() => _BreathingTextState();
}

class _BreathingTextState extends State<BreathingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          widget.text,
          style: GoogleFonts.inter(
            color: widget.color,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w600,
            shadows: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animation.value * 0.8),
                blurRadius: _animation.value * 15,
                spreadRadius: _animation.value * 3,
              )
            ]
          ),
        );
      },
    );
  }
}
