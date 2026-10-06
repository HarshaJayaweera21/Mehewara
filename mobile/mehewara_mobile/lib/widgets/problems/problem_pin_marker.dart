import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/problem.dart';

class ProblemPinMarker extends StatelessWidget {
  final Problem problem;
  final bool isSelected;
  final VoidCallback onTap;

  const ProblemPinMarker({
    super.key,
    required this.problem,
    required this.isSelected,
    required this.onTap,
  });

  Color _getPinColor() {
    if (isSelected) return CivicColors.forest;

    switch (problem.category) {
      case 'DRAINAGE':
        return CivicColors.pinDrainage;
      case 'ROAD':
        return CivicColors.pinRoad;
      case 'ELECTRICAL':
        return CivicColors.pinElectrical;
      case 'WASTE':
        return CivicColors.pinWaste;
      case 'ENVIRONMENT':
        return CivicColors.pinEnvironment;
      default:
        return CivicColors.forest;
    }
  }

  IconData _getCategoryIcon() {
    switch (problem.category) {
      case 'DRAINAGE':
        return Icons.water_drop_rounded;
      case 'ROAD':
        return Icons.construction_rounded;
      case 'ELECTRICAL':
        return Icons.bolt_rounded;
      case 'WASTE':
        return Icons.delete_outline_rounded;
      case 'ENVIRONMENT':
        return Icons.eco_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinColor = _getPinColor();
    final pinWidth = isSelected ? 42.0 : 34.0;
    final pinHeight = isSelected ? 52.0 : 42.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 54,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
        children: [
          // Ground shadow
          Positioned(
            bottom: 0,
            child: Container(
              width: isSelected ? 22 : 16,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Selection radar halo ring (when selected)
          if (isSelected)
            Positioned(
              top: 0,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CivicColors.forest.withValues(alpha: 0.18),
                ),
              ),
            ),

          // Teardrop Pin Body
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: SizedBox(
              width: pinWidth,
              height: pinHeight,
              child: CustomPaint(
                painter: TeardropPinPainter(
                  fillColor: pinColor,
                  strokeColor: Colors.white,
                  strokeWidth: isSelected ? 2.5 : 2.0,
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: isSelected ? 7.0 : 6.0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Icon(
                      _getCategoryIcon(),
                      size: isSelected ? 20 : 16,
                      color: isSelected ? CivicColors.mintPip : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top-right notification count badge (consolidated reports count)
          Positioned(
            top: isSelected ? -4 : -2,
            right: isSelected ? -2 : 0,
            child: Container(
              width: isSelected ? 20 : 16,
              height: isSelected ? 20 : 16,
              decoration: BoxDecoration(
                color: isSelected ? CivicColors.mintPip : Colors.black87,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${problem.reportCount}',
                  style: TextStyle(
                    fontSize: isSelected ? 10 : 8.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? CivicColors.forest : Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}

class TeardropPinPainter extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  TeardropPinPainter({
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;

    final path = Path()
      ..moveTo(w / 2, h)
      ..cubicTo(0, h * 0.65, 0, r, 0, r)
      ..arcToPoint(
        Offset(w, r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..cubicTo(w, h * 0.65, w / 2, h, w / 2, h)
      ..close();

    final paint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawPath(path, paint);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant TeardropPinPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
