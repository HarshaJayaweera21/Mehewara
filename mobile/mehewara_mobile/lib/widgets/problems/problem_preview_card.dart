import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/problem.dart';

class ProblemPreviewCard extends StatelessWidget {
  final Problem problem;
  final VoidCallback onTrackProgress;

  const ProblemPreviewCard({
    super.key,
    required this.problem,
    required this.onTrackProgress,
  });

  Widget _buildPriorityBadge() {
    Color bg = CivicColors.badgeHighBg;
    Color text = CivicColors.badgeHighText;
    Color border = CivicColors.badgeHighBorder;
    String label = '${problem.priority ?? 'HIGH'} PRIORITY';

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
        label = problem.priority != null ? '${problem.priority} PRIORITY' : 'ACTIVE INCIDENT';
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
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
    return Container(
      decoration: BoxDecoration(
        color: CivicColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CivicColors.borderSubtle, width: 1),
        boxShadow: const [CivicShadows.card],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Meta Row: Priority Badge + Category Tag + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildPriorityBadge(),
                  const SizedBox(width: 8),
                  Text(
                    problem.category,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: CivicColors.slateGreen,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
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
              fontSize: 15.5,
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
                  '${problem.address ?? 'Ward 4'} • Centroid: ${problem.latitude.toStringAsFixed(4)}, ${problem.longitude.toStringAsFixed(4)}',
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
          const SizedBox(height: 12),

          // Community Consolidation Impact Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: CivicColors.mintTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CivicColors.mintPip.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.groups_outlined,
                  size: 18,
                  color: CivicColors.forest,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${problem.reportCount} community reports consolidated into this incident',
                    style: const TextStyle(
                      fontSize: 11,
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
            height: 44,
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
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
