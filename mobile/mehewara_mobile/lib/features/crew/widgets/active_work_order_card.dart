import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/work_order_model.dart';

class ActiveWorkOrderCard extends StatelessWidget {
  final WorkOrderModel workOrder;
  final VoidCallback onViewDetails;

  const ActiveWorkOrderCard({
    super.key,
    required this.workOrder,
    required this.onViewDetails,
  });

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return AppColors.priorityCritical;
      case 'HIGH':
        return AppColors.priorityHigh;
      case 'MEDIUM':
        return AppColors.priorityMedium;
      default:
        return AppColors.priorityLow;
    }
  }

  Color _getPriorityBg(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return AppColors.priorityCriticalBg;
      case 'HIGH':
        return AppColors.priorityHighBg;
      case 'MEDIUM':
        return AppColors.priorityMediumBg;
      default:
        return AppColors.priorityLowBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor(workOrder.priority);
    final priorityBg = _getPriorityBg(workOrder.priority);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (workOrder.problemCategory != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.softSage,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      workOrder.problemCategory!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryForest,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: priorityColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    workOrder.priority,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              workOrder.problemTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
            if (workOrder.problemAddress != null && workOrder.problemAddress!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      workOrder.problemAddress!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
            if (workOrder.instructions != null && workOrder.instructions!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.canvasBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COORDINATOR INSTRUCTIONS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      workOrder.instructions!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View Work Order & Site Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryForest,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
