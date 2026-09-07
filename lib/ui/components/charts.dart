import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ConcentricRingsPainter extends CustomPainter {
  final List<Map<String, dynamic>> rings;

  static final Paint _bgPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  static final Paint _solidPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  ConcentricRingsPainter({
    required this.rings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rings.isEmpty) return;
    final double center = size.width / 2;
    
    double maxStroke = 10.0;
    double gapRatio = 0.5;
    int count = rings.length;
    // ensure we don't divide by zero
    double divisor = (count + (count - 1) * gapRatio);
    double requiredStroke = divisor > 0 ? (center - 10) / divisor : maxStroke;
    double strokeWidth = min(maxStroke, requiredStroke);
    double gap = strokeWidth * gapRatio;

    _bgPaint
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = strokeWidth;
    _glowPaint.strokeWidth = strokeWidth;
    _solidPaint.strokeWidth = strokeWidth;

    for (int i = 0; i < rings.length; i++) {
      final ring = rings[i];
      final double radius = center - 5 - (strokeWidth / 2) - (i * (strokeWidth + gap));
      if (radius <= 0) break;
      final Rect rect = Rect.fromCircle(center: Offset(center, center), radius: radius);
      final double percentage = ring['percentage'] / 100.0;
      final double sweepAngle = min(percentage * 360, 360) * pi / 180;
      
      final Color color = ring['color'];

      canvas.drawCircle(Offset(center, center), radius, _bgPaint);

      _glowPaint.color = color.withValues(alpha: 0.6);
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, _glowPaint);

      _solidPaint.color = color;
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, _solidPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ConcentricRingsPainter oldDelegate) {
    if (rings.length != oldDelegate.rings.length) return true;
    for (int i = 0; i < rings.length; i++) {
      if (rings[i]['id'] != oldDelegate.rings[i]['id'] ||
          rings[i]['amount'] != oldDelegate.rings[i]['amount'] ||
          rings[i]['percentage'] != oldDelegate.rings[i]['percentage'] ||
          rings[i]['color'] != oldDelegate.rings[i]['color']) {
        return true;
      }
    }
    return false;
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
                                      style: GoogleFonts.fraunces(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
                children: ticks.map((t) => Text(_formatY(t), style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12))).toList(),
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
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 12),
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFFFE0000), borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 4),
                              Text(
                                "${widget.currencySymbol}${widget.data[_selectedIndex!]['expense'].round()}",
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
          style: TextStyle(
            color: widget.color,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
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
