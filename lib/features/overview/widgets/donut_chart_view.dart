import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class DonutSlice {
  final String label;
  final int count;
  final Color color;

  const DonutSlice({
    required this.label,
    required this.count,
    required this.color,
  });
}

class DonutChartView extends StatelessWidget {
  final List<DonutSlice> slices;
  final String primaryText;
  final String secondaryText;
  final double height;
  final double strokeWidth;

  const DonutChartView({
    super.key,
    required this.slices,
    this.primaryText = '',
    this.secondaryText = '',
    this.height = 120,
    this.strokeWidth = 14,
  });

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (sum, item) => sum + item.count);
    final pText = primaryText.isNotEmpty ? primaryText : total.toString();

    return SizedBox(
      height: height,
      width: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(height, height),
            painter: _DonutChartPainter(
              slices: slices,
              strokeWidth: strokeWidth,
            ),
          ),
          // Center Text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pText,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              if (secondaryText.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  secondaryText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double strokeWidth;

  _DonutChartPainter({
    required this.slices,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = slices.fold<int>(0, (sum, item) => sum + item.count);

    if (total <= 0) {
      // Empty Ring
      final emptyPaint = Paint()
        ..color = const Color(0xFF203653)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, 0, 2 * math.pi, false, emptyPaint);
      return;
    }

    final validSlices = slices.where((s) => s.count > 0).toList();

    if (validSlices.length == 1) {
      final paint = Paint()
        ..color = validSlices.first.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
      return;
    }

    const gapDegrees = 3.5;
    final gapRadians = gapDegrees * (math.pi / 180.0);
    final totalGaps = gapRadians * validSlices.length;
    final availableSweep = (2 * math.pi) - totalGaps;

    double startAngle = -math.pi / 2; // Start from top 12 o'clock

    for (final slice in validSlices) {
      final sweep = (slice.count / total) * availableSweep;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep + gapRadians;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.strokeWidth != strokeWidth;
  }
}

class DonutLegendItem extends StatelessWidget {
  final DonutSlice slice;
  final int total;
  final VoidCallback? onTap;

  const DonutLegendItem({
    super.key,
    required this.slice,
    required this.total,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total > 0 ? (slice.count * 100 / total).round() : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
          child: Row(
            children: [
              // Dot Indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: slice.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: slice.color.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Label
              Expanded(
                child: Text(
                  slice.label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              // Count & Percent
              Text(
                '${slice.count} ($percent%)',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
