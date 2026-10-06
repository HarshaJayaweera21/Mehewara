import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/problem.dart';

class ProblemPreviewCard extends StatelessWidget {
  final Problem problem;
  final VoidCallback onTrackProgress;
  final VoidCallback? onClose;

  const ProblemPreviewCard({
    super.key,
    required this.problem,
    required this.onTrackProgress,
    this.onClose,
  });

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

  Color _getCategoryColor() {
    switch (problem.category) {
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

  Color _getCategoryBg() {
    switch (problem.category) {
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

  Widget _buildPriorityBadge() {
    Color bg = CivicColors.badgeHighBg;
    Color text = CivicColors.badgeHighText;
    Color border = CivicColors.badgeHighBorder;
    String label = problem.priority ?? 'HIGH';

    switch (problem.priority) {
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
        bg = CivicColors.mintTint;
        text = CivicColors.forest;
        border = CivicColors.mintPip.withValues(alpha: 0.4);
        label = problem.priority ?? 'HIGH';
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
        '$label PRIORITY',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bg = CivicColors.badgeProcessingBg;
    Color text = CivicColors.badgeProcessingText;
    Color border = CivicColors.badgeProcessingBorder;
    String label = problem.status;

    if (problem.status == 'RESOLVED') {
      bg = CivicColors.badgeResolvedBg;
      text = CivicColors.badgeResolvedText;
      border = CivicColors.badgeResolvedBorder;
    } else if (problem.status == 'ASSIGNED') {
      bg = CivicColors.badgeAssignedBg;
      text = CivicColors.badgeAssignedText;
      border = CivicColors.badgeAssignedBorder;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: text,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: text,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _getCategoryColor();
    final catBg = _getCategoryBg();

    return Container(
      decoration: BoxDecoration(
        color: CivicColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
        boxShadow: const [CivicShadows.card],
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle bar with optional close button
          Row(
            children: [
              const SizedBox(width: 24),
              Expanded(
                child: Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5CE),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              if (onClose != null)
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: CivicColors.mintTint,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CivicColors.mintPip.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: CivicColors.forest,
                    ),
                  ),
                )
              else
                const SizedBox(width: 24),
            ],
          ),
          const SizedBox(height: 12),

          // Meta Row: Category Squircle + Category & Priority + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                    _getCategoryIcon(),
                    size: 16,
                    color: catColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildPriorityBadge(),
                    Text(
                      problem.category,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: CivicColors.slateGreen,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            problem.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CivicColors.charcoal,
              letterSpacing: -0.2,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),

          // Location Row with pin icon
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: CivicColors.forest,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${problem.address ?? 'Ward 4'} • ${problem.latitude.toStringAsFixed(4)}, ${problem.longitude.toStringAsFixed(4)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: CivicColors.slateGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Community Consolidation Impact Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: CivicColors.mintTint,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: CivicColors.mintPip.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.groups_rounded,
                  size: 16,
                  color: CivicColors.forest,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${problem.reportCount} community ${problem.reportCount == 1 ? 'report' : 'reports'} consolidated into this incident',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: CivicColors.forest,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Primary CTA Button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: onTrackProgress,
              style: ElevatedButton.styleFrom(
                backgroundColor: CivicColors.forest,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Track Incident & Progress',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
