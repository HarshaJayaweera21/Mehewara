import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/work_order_model.dart';

class ActiveWorkOrderCard extends StatelessWidget {
  final WorkOrderModel workOrder;
  final VoidCallback onViewDetails;

  const ActiveWorkOrderCard({
    super.key,
    required this.workOrder,
    required this.onViewDetails,
  });

  IconData _getCategoryIcon(String? category) {
    switch (category?.toUpperCase()) {
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

  Color _getCategoryColor(String? category) {
    switch (category?.toUpperCase()) {
      case 'DRAINAGE':
        return const Color(0xFF0284C7);
      case 'ROAD':
        return const Color(0xFFD97706);
      case 'ELECTRICAL':
        return const Color(0xFFCA8A04);
      case 'WASTE':
        return const Color(0xFF7C3AED);
      case 'ENVIRONMENT':
        return const Color(0xFF059669);
      default:
        return CivicColors.forest;
    }
  }

  Color _getCategoryBg(String? category) {
    switch (category?.toUpperCase()) {
      case 'DRAINAGE':
        return const Color(0xFFE0F2FE);
      case 'ROAD':
        return const Color(0xFFFEF3C7);
      case 'ELECTRICAL':
        return const Color(0xFFFEF9C3);
      case 'WASTE':
        return const Color(0xFFF3E8FF);
      case 'ENVIRONMENT':
        return const Color(0xFFD1FAE5);
      default:
        return CivicColors.mintTint;
    }
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg = CivicColors.badgeHighBg;
    Color text = CivicColors.badgeHighText;
    Color border = CivicColors.badgeHighBorder;

    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        bg = CivicColors.badgeCriticalBg;
        text = CivicColors.badgeCriticalText;
        border = CivicColors.badgeCriticalBorder;
        break;
      case 'MEDIUM':
        bg = CivicColors.badgeMediumBg;
        text = CivicColors.badgeMediumText;
        border = CivicColors.badgeMediumBorder;
        break;
      case 'LOW':
        bg = CivicColors.badgeLowBg;
        text = CivicColors.badgeLowText;
        border = CivicColors.badgeLowBorder;
        break;
      default:
        bg = CivicColors.badgeHighBg;
        text = CivicColors.badgeHighText;
        border = CivicColors.badgeHighBorder;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        '${priority.toUpperCase()} PRIORITY',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _getCategoryColor(workOrder.problemCategory);
    final catBg = _getCategoryBg(workOrder.problemCategory);

    return Container(
      decoration: BoxDecoration(
        color: CivicColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
        boxShadow: const [CivicShadows.card],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent strip (pulsing amber/forest)
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF59E0B),
                  CivicColors.forest,
                  CivicColors.mintPip,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Mission Banner & Priority
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: catBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: catColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _getCategoryIcon(workOrder.problemCategory),
                              size: 16,
                              color: catColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (workOrder.problemCategory != null)
                          Text(
                            workOrder.problemCategory!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: CivicColors.slateGreen,
                              letterSpacing: 0.6,
                            ),
                          ),
                      ],
                    ),
                    _buildPriorityBadge(workOrder.priority),
                  ],
                ),
                const SizedBox(height: 12),

                // Problem Title
                Text(
                  workOrder.problemTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CivicColors.charcoal,
                    letterSpacing: -0.2,
                    height: 1.25,
                  ),
                ),
                if (workOrder.problemAddress != null && workOrder.problemAddress!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: CivicColors.forest,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          workOrder.problemAddress!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: CivicColors.slateGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (workOrder.instructions != null && workOrder.instructions!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAF8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFDCE5DF),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 14,
                              color: CivicColors.forest,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'COORDINATOR DISPATCH INSTRUCTIONS',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: CivicColors.forest,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          workOrder.instructions!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF2C3E37),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Action CTA
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: onViewDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CivicColors.forest,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View Work Order & Site Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
