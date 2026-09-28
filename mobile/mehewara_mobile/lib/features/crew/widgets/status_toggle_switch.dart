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
    final isAvailable = crew.isAvailable;
    final isBusy = crew.isBusy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Squad Availability Toggle',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBusy
                          ? 'Locked: Deployed on active mission'
                          : (isAvailable ? 'Standby (Ready for AI assignment)' : 'Off-duty / Depot maintenance'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isBusy ? AppColors.statusBusyText : AppColors.textSecondary,
                        fontWeight: isBusy ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                if (isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryForest),
                  )
                else
                  Switch(
                    value: isAvailable,
                    activeThumbColor: AppColors.primaryForest,
                    activeTrackColor: AppColors.softSage,
                    inactiveThumbColor: AppColors.textMuted,
                    inactiveTrackColor: AppColors.borderSubtle,
                    onChanged: isBusy ? null : onToggle,
                  ),
              ],
            ),
            if (isBusy) ...[
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
                        'Availability is locked while active work order is underway. Completing the work order restores standby readiness.',
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
