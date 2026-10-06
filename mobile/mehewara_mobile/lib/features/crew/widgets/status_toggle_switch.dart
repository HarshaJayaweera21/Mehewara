import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/crew_model.dart';

class StatusToggleSwitch extends StatelessWidget {
  final CrewModel crew;
  final bool isLoading;
  final ValueChanged<bool> onToggle;

  const StatusToggleSwitch({
    super.key,
    required this.crew,
    required this.isLoading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isBusy = crew.isBusy;
    final isUnavailable = crew.isUnavailable;
    final isOnDuty = crew.isOnDuty;

    return Container(
      decoration: BoxDecoration(
        color: CivicColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
        boxShadow: const [CivicShadows.subtle],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Squad Duty & Availability',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CivicColors.charcoal,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isUnavailable
                          ? 'Off-duty / On Break (Lunch, Tea, Standby)'
                          : (isBusy
                              ? 'Active Mission Underway (Toggle off to pause)'
                              : 'Ready & Available on Standby'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isUnavailable
                            ? CivicColors.subdued
                            : (isBusy ? const Color(0xFFD97706) : CivicColors.slateGreen),
                        fontWeight: isBusy ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: CivicColors.forest),
                )
              else
                Switch(
                  value: isOnDuty,
                  activeThumbColor: CivicColors.forest,
                  activeTrackColor: CivicColors.mintTint,
                  inactiveThumbColor: CivicColors.subdued,
                  inactiveTrackColor: CivicColors.segmentBg,
                  trackOutlineColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? CivicColors.mintPip.withValues(alpha: 0.4)
                        : const Color(0xFFDCE5DF),
                  ),
                  onChanged: onToggle,
                ),
            ],
          ),
          if (isUnavailable) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.coffee_rounded, size: 16, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Squad is currently inactive. Dispatch Coordinator & AI will not assign new jobs until you toggle back on duty.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF991B1B),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isBusy) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Active remediation mission in progress. You can toggle off duty at any time for breaks or vehicle maintenance.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
