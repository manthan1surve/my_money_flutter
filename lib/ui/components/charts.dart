import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ConcentricRingsPainter extends CustomPainter {
  final List<Map<String, dynamic>> rings;

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

    for (int i = 0; i < rings.length; i++) {
      final ring = rings[i];
      final double radius = center - 5 - (strokeWidth / 2) - (i * (strokeWidth + gap));
      if (radius <= 0) break;
      final Rect rect = Rect.fromCircle(center: Offset(center, center), radius: radius);
      final double percentage = ring['percentage'] / 100.0;
      final double sweepAngle = min(percentage * 360, 360) * pi / 180;
      
      final Color color = ring['color'];

      final Paint bgPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(Offset(center, center), radius, bgPaint);

      final Paint glowPaint = Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, glowPaint);

      final Paint solidPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, solidPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ConcentricRingsPainter oldDelegate) => true;
}

class CustomLineChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final double maxAmount;
  final Color color;
  final String currencySymbol;
  final bool showAllLabels;
  final bool isExpense;

  const CustomLineChart({
    super.key,
    required this.data,
    required this.maxAmount,
    required this.color,
    required this.currencySymbol,
    required this.showAllLabels,
    required this.isExpense,
  });

  @override
  State<CustomLineChart> createState() => _CustomLineChartState();
}

class _CustomLineChartState extends State<CustomLineChart> {
  int _activeIndex = -1; // -1 = show last point as default
  final double _padL = 0;
  final double _padR = 0;
  final double _padTop = 70;
  final double _padBottom = 28;

  int get _displayIndex => _activeIndex < 0 ? widget.data.length - 1 : _activeIndex;

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

  Offset _pointAt(int index, Size size) {
    final graphW = size.width - _padL - _padR;
    final graphH = size.height - _padTop - _padBottom;
    final niceMax = _getNiceMax();
    double x = widget.data.length > 1
        ? _padL + (index / (widget.data.length - 1)) * graphW
        : _padL + graphW / 2;
    double yRatio = niceMax > 0 ? widget.data[index]['total'] / niceMax : 0;
    double y = _padTop + graphH - (yRatio.clamp(0.0, 1.0) * graphH);
    return Offset(x, y);
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final graphW = size.width - _padL - _padR;
    final relX = (d.localPosition.dx - _padL).clamp(0.0, graphW);
    final frac = relX / graphW;
    final idx = (frac * (widget.data.length - 1)).round().clamp(0, widget.data.length - 1);
    if (idx != _activeIndex) setState(() => _activeIndex = idx);
  }

  String _pctChange() {
    if (widget.data.length < 2) return '';
    final first = (widget.data.first['total'] as num).toDouble();
    final last = (widget.data.last['total'] as num).toDouble();
    if (first == 0) return '';
    final pct = ((last - first) / first * 100);
    return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox();
    final niceMax = _getNiceMax();
    final activeData = widget.data[_displayIndex];
    final pct = _pctChange();
    final isUp = !pct.startsWith('-');

    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final activePt = _pointAt(_displayIndex, size);

      return GestureDetector(
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
            // Chart painter
            Positioned.fill(
              child: CustomPaint(
                painter: _LineChartPainter(
                  data: widget.data,
                  niceMax: niceMax,
                  color: widget.color,
                  activeIndex: _displayIndex,
                  padL: _padL,
                  padR: _padR,
                  padTop: _padTop,
                  padBottom: _padBottom,
                ),
              ),
            ),

            // Summary top-left
            Positioned(
              left: 16,
              top: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isExpense ? 'Total Expense' : 'Money Received',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.currencySymbol}${activeData['total'].round()}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),

            // Percentage change top-right
            if (pct.isNotEmpty)
              Positioned(
                right: 16,
                top: 20,
                child: Row(
                  children: [
                    Text(
                      pct,
                      style: TextStyle(
                        color: isUp ? const Color(0xFF00FE06) : const Color(0xFFFE0000),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: isUp ? const Color(0xFF00FE06) : const Color(0xFFFE0000),
                      size: 14,
                    ),
                  ],
                ),
              ),

            // Floating date & amount label above active point
            Positioned(
              left: (activePt.dx - 45).clamp(4.0, size.width - 90),
              top: (activePt.dy - 54).clamp(68.0, size.height - 40),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      activeData['label'],
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.currencySymbol}${activeData['total'].round()}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // X-axis: labels
            Positioned(
              left: 12,
              right: 12,
              bottom: 6,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: 15,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: widget.data.asMap().entries.map((entry) {
                        final i = entry.key;
                        final label = entry.value['label'].toString();
                        String displayText = label;
                        bool showLabel = true;

                        if (!widget.showAllLabels && widget.data.length > 12) {
                          final parts = label.split(' ');
                          if (parts.length > 1) {
                            final day = int.tryParse(parts.last) ?? 1;
                            showLabel = day % 2 == 0;
                            // Only show the day number to prevent overlap
                            displayText = day.toString();
                          } else {
                            showLabel = (i + 1) % 2 == 0;
                          }
                        }

                        if (!showLabel) return const SizedBox.shrink();

                        final double leftPct = widget.data.length > 1 ? (i / (widget.data.length - 1)) : 0.5;
                        final double leftPos = leftPct * constraints.maxWidth;

                        return Positioned(
                          left: leftPos - 15,
                          width: 30,
                          child: Text(
                            displayText,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        );
                      }).toList(),
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

class _LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double niceMax;
  final Color color;
  final int activeIndex;
  final double padL, padR, padTop, padBottom;

  _LineChartPainter({
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
    if (data.isEmpty) return;
    final points = _buildPoints(size);
    final graphBottom = size.height - padBottom;

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
        [color.withValues(alpha: 0.55), color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
        [0.0, 0.55, 1.0],
      );
    canvas.drawPath(fillPath, fillPaint);

    // Glow
    canvas.drawPath(path, Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // Line
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);

    // Active dot
    final pt = points[activeIndex];

    // Vertical dashed line
    const dashH = 5.0;
    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    double dy = pt.dy;
    while (dy < graphBottom) {
      canvas.drawLine(Offset(pt.dx, dy), Offset(pt.dx, dy + dashH), dashPaint);
      dy += dashH * 2;
    }

    // Outer glow ring
    canvas.drawCircle(pt, 14, Paint()..color = color.withValues(alpha: 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // White-filled inner circle (like reference)
    canvas.drawCircle(pt, 7, Paint()..color = color);
    canvas.drawCircle(pt, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.activeIndex != activeIndex || old.data != data;
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
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
        ],
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
