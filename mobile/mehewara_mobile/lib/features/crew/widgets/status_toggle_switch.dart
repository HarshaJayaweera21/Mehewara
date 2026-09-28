import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
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

    return Card(
      child: Padding(
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isUnavailable
                            ? 'Off-duty / On Break (Lunch, Tea, Emergency)'
                            : (isBusy
                                ? 'Active Mission Underway (Toggle off to take break)'
                                : 'Standby (Ready for AI assignment)'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isUnavailable
                              ? AppColors.textMuted
                              : (isBusy ? AppColors.statusBusyText : AppColors.textSecondary),
                          fontWeight: isBusy ? FontWeight.w600 : FontWeight.w400,
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryForest),
                  )
                else
                  Switch(
                    value: isOnDuty,
                    activeThumbColor: AppColors.primaryForest,
                    activeTrackColor: AppColors.softSage,
                    inactiveThumbColor: AppColors.textMuted,
                    inactiveTrackColor: AppColors.borderSubtle,
                    onChanged: onToggle,
                  ),
              ],
            ),
            if (isUnavailable) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.statusUnavailableBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.statusUnavailableBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.coffee_outlined, size: 16, color: AppColors.statusUnavailableText),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Squad is currently inactive. Dispatch Coordinator & AI will not assign new jobs until you toggle back on duty.',
                        style: TextStyle(fontSize: 11, color: AppColors.statusUnavailableText, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isBusy) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.statusBusyBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.statusBusyBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.statusBusyText),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active mission in progress. You can toggle off at any time for lunch, tea breaks, rest, vehicle maintenance, or incident reporting.',
                        style: TextStyle(fontSize: 11, color: AppColors.statusBusyText, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
