import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Axis labels and their display names for the skill radar chart.
const kRadarAxes = [
  'Arrays & Strings',
  'Trees & Graphs',
  'Dynamic Programming',
  'Sorting & Searching',
  'Data Structures',
  'Math & Bit Manipulation',
];

/// Animated hexagonal radar chart.
/// [scores] must have exactly 6 values in [0.0, 1.0] order matching [kRadarAxes].
class RadarChart extends StatefulWidget {
  final List<double> scores;
  final Color color;
  final double size;
  final bool animate;

  const RadarChart({
    super.key,
    required this.scores,
    this.color = AppColors.primary,
    this.size = 260,
    this.animate = true,
  }) : assert(scores.length == 6);

  @override
  State<RadarChart> createState() => _RadarChartState();
}

class _RadarChartState extends State<RadarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (_, __) => CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _RadarPainter(
            scores: widget.scores,
            progress: _progress.value.clamp(0.0, 1.0),
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<double> scores;
  final double progress;
  final Color color;

  _RadarPainter({
    required this.scores,
    required this.progress,
    required this.color,
  });

  static const int _rings = 5;
  static const int _axes = 6;

  Offset _vertex(Offset center, double r, int i) {
    // Start at top (-π/2), go clockwise
    final angle = -pi / 2 + (2 * pi / _axes) * i;
    return Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Leave margin for axis labels
    final maxR = size.width / 2 - 40;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    // Draw grid rings
    for (int ring = 1; ring <= _rings; ring++) {
      final r = maxR * ring / _rings;
      final path = Path();
      for (int i = 0; i < _axes; i++) {
        final v = _vertex(center, r, i);
        i == 0 ? path.moveTo(v.dx, v.dy) : path.lineTo(v.dx, v.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw axis lines
    for (int i = 0; i < _axes; i++) {
      final v = _vertex(center, maxR, i);
      canvas.drawLine(center, v, axisPaint);
    }

    // Draw score polygon
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.3 * progress)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withValues(alpha: progress.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    for (int i = 0; i < _axes; i++) {
      final r = maxR * scores[i] * progress;
      final v = _vertex(center, r, i);
      i == 0 ? path.moveTo(v.dx, v.dy) : path.lineTo(v.dx, v.dy);
    }
    path.close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Draw dots at vertices
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < _axes; i++) {
      final r = maxR * scores[i] * progress;
      canvas.drawCircle(_vertex(center, r, i), 4, dotPaint);
    }

    // Axis labels (drawn via TextPainter outside canvas transform)
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < _axes; i++) {
      final v = _vertex(center, maxR + 16, i);
      final short = kRadarAxes[i].split(' ').first;
      labelPainter.text = TextSpan(
        text: short,
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(
          v.dx - labelPainter.width / 2,
          v.dy - labelPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.progress != progress || old.scores != scores;
}
