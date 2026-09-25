import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CrewStatusBadge extends StatelessWidget {
  final String status;
  final bool showDot;

  const CrewStatusBadge({
    super.key,
    required this.status,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;
    Color border;

    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        bg = AppColors.statusAvailableBg;
        textColor = AppColors.statusAvailableText;
        border = AppColors.statusAvailableBorder;
        break;
      case 'BUSY':
        bg = AppColors.statusBusyBg;
        textColor = AppColors.statusBusyText;
        border = AppColors.statusBusyBorder;
        break;
      default:
        bg = AppColors.statusUnavailableBg;
        textColor = AppColors.statusUnavailableText;
        border = AppColors.statusUnavailableBorder;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
