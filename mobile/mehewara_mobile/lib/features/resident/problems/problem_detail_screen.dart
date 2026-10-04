import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/problem.dart';
import '../../../models/problem_lifecycle.dart';
import '../../../services/problems/problem_service.dart';

class ProblemDetailScreen extends StatefulWidget {
  final Problem problem;

  const ProblemDetailScreen({
    super.key,
    required this.problem,
  });

  @override
  State<ProblemDetailScreen> createState() => _ProblemDetailScreenState();
}

class _ProblemDetailScreenState extends State<ProblemDetailScreen> {
  final ProblemService _service = ProblemService();
  late Problem _problem;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _problem = widget.problem;
    _fetchFullDetails();
  }

  Future<void> _fetchFullDetails() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _service.getProblemById(_problem.id);
      if (mounted) {
        setState(() {
          _problem = updated;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }

  String _getShortIncidentId() {
    if (_problem.id.length > 5) {
      return _problem.id.substring(0, 5).toUpperCase();
    }
    return _problem.id.isNotEmpty ? _problem.id.toUpperCase() : 'P-023';
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final lifecycle = ProblemLifecycle(_problem);

    return Scaffold(
      backgroundColor: CivicColors.alabaster,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Sticky Navigation Header
            _buildStickyHeader(),
            if (_isLoading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: CivicColors.forest,
                backgroundColor: Colors.transparent,
              ),

            // 2. Main Scrollable Content
            Expanded(
              child: RefreshIndicator(
                color: CivicColors.forest,
                onRefresh: _fetchFullDetails,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SECTION 1: HERO INCIDENT SUMMARY CARD
                      _buildHeroCard(),
                      const SizedBox(height: 14),

                      // SECTION 2: RESOLUTION PROGRESS LIFECYCLE (STEPPER)
                      _buildLifecycleCard(lifecycle),
                      const SizedBox(height: 14),

                      // SECTION 3: COMMUNITY IMPACT & GROUPED REPORTS CARD
                      _buildCommunityImpactCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. STICKY TOP APP BAR
  // ===========================================================================
  Widget _buildStickyHeader() {
    return Container(
      decoration: BoxDecoration(
        color: CivicColors.alabaster.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: Color(0x99DDE2DE), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: CivicColors.cardSurface,
                shape: BoxShape.circle,
                border: Border.all(color: CivicColors.borderSubtle, width: 1),
                boxShadow: const [CivicShadows.subtle],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: CivicColors.charcoal,
                ),
              ),
            ),
          ),

          // Incident Center Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: CivicColors.mintTint,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: CivicColors.mintPip.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: CivicColors.mintPip,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'INCIDENT #${_getShortIncidentId()}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CivicColors.forest,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),

          // Right Spacer to balance the layout
          const SizedBox(width: 38),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: HERO INCIDENT SUMMARY CARD
  // ===========================================================================
  Widget _buildHeroCard() {
    return Container(
      decoration: BoxDecoration(
        color: CivicColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CivicColors.borderSubtle, width: 1),
        boxShadow: const [CivicShadows.card],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent gradient strip
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFBBF24), // Amber
                  CivicColors.forest, // Forest Green
                  CivicColors.mintPip, // Mint Accent
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meta Tags Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildPriorityPill(),
                        const SizedBox(width: 6),
                        _buildCategoryTag(),
                      ],
                    ),
                    _buildStatusPill(),
                  ],
                ),
                const SizedBox(height: 12),

                // Incident Title
                Text(
                  _problem.title,
                  style: const TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    color: CivicColors.charcoal,
                    letterSpacing: -0.3,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),

                // Location Subtitle
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: CivicColors.forest,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _problem.address ??
                            'Centroid: ${_problem.latitude.toStringAsFixed(4)}, ${_problem.longitude.toStringAsFixed(4)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: CivicColors.slateGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Narrative Description Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFBF9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CivicColors.borderSubtle.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _problem.description ??
                        'Heavy accumulation and civic obstruction reported. Automated municipal triage assigned to local work crew.',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF2C3E37),
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Card Footer Timestamps
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: CivicColors.borderSubtle.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: CivicColors.subdued.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reported ${_formatRelativeTime(_problem.createdAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: CivicColors.subdued,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: CivicColors.mintTint.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Updated ${_formatRelativeTime(_problem.updatedAt ?? _problem.createdAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CivicColors.forest,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityPill() {
    Color bg = CivicColors.badgeHighBg;
    Color text = CivicColors.badgeHighText;
    Color border = CivicColors.badgeHighBorder;
    String label = '${_problem.priority ?? 'HIGH'} PRIORITY';

    switch (_problem.priority) {
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
        bg = const Color(0xFFFFFBEB);
        text = const Color(0xFFD97706);
        border = const Color(0xFFFCD34D);
        label = _problem.priority != null ? '${_problem.priority} PRIORITY' : 'HIGH PRIORITY';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
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
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildCategoryTag() {
    IconData icon = Icons.water_drop_rounded;
    switch (_problem.category) {
      case 'ROAD':
        icon = Icons.construction_rounded;
        break;
      case 'ELECTRICAL':
        icon = Icons.bolt_rounded;
        break;
      case 'WASTE':
        icon = Icons.delete_outline_rounded;
        break;
      case 'ENVIRONMENT':
        icon = Icons.eco_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: CivicColors.borderSubtle.withValues(alpha: 0.7), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF0284C7)),
          const SizedBox(width: 3.5),
          Text(
            _problem.category,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: CivicColors.slateGreen,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    Color bg = const Color(0xFFCCFBF1);
    Color text = const Color(0xFF0D9488);
    Color border = const Color(0xFF99F6E4);
    String label = _problem.status;

    if (_problem.status == 'RESOLVED' || _problem.status == 'CLOSED') {
      bg = CivicColors.badgeResolvedBg;
      text = CivicColors.badgeResolvedText;
      border = CivicColors.badgeResolvedBorder;
    } else if (_problem.status == 'ASSIGNED') {
      bg = CivicColors.badgeAssignedBg;
      text = CivicColors.badgeAssignedText;
      border = CivicColors.badgeAssignedBorder;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
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
          const SizedBox(width: 4.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: text,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 2: RESOLUTION PROGRESS LIFECYCLE (VERTICAL STEPPER)
  // ===========================================================================
  Widget _buildLifecycleCard(ProblemLifecycle lifecycle) {
    final stages = lifecycle.stages;

    return Container(
      decoration: BoxDecoration(
        color: CivicColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CivicColors.borderSubtle, width: 1),
        boxShadow: const [CivicShadows.card],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: CivicColors.mintTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.shield_outlined,
                        size: 15,
                        color: CivicColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Resolution Progress Lifecycle',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: CivicColors.charcoal,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CivicColors.mintTint,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  lifecycle.stageBadgeText,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: CivicColors.forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stepper List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stages.length,
            itemBuilder: (context, index) {
              final stage = stages[index];
              final isLast = index == stages.length - 1;
              return _buildStepperItem(stage, isLast: isLast);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepperItem(LifecycleStageInfo stage, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Node + Connecting Line
          Column(
            children: [
              _buildNodeIcon(stage),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: stage.isCompleted ? CivicColors.forest : const Color(0xFFE2E8F0),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Right: Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: stage.isActive
                  ? _buildActiveStageCard(stage)
                  : _buildStandardStageContent(stage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeIcon(LifecycleStageInfo stage) {
    if (stage.isCompleted) {
      return Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          color: CivicColors.forest,
          shape: BoxShape.circle,
          boxShadow: [CivicShadows.subtle],
        ),
        child: const Center(
          child: Icon(
            Icons.check_rounded,
            size: 15,
            color: Colors.white,
          ),
        ),
      );
    } else if (stage.isActive) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: CivicColors.forest,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: CivicColors.mintPip.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: CivicColors.mintPip,
            ),
          ),
        ),
      );
    } else {
      // Pending
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
        ),
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildActiveStageCard(LifecycleStageInfo stage) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: CivicColors.mintTint.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CivicColors.mintPip.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: const [CivicShadows.subtle],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  stage.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CivicColors.forest,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CivicColors.forest,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            stage.subtitle,
            style: const TextStyle(
              fontSize: 11.5,
              color: CivicColors.charcoal,
              height: 1.25,
            ),
          ),
          if (stage.leadInspector != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: CivicColors.forest.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: CivicColors.mintPip,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Lead Inspector: ${stage.leadInspector}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CivicColors.slateGreen,
                        ),
                      ),
                    ],
                  ),
                  if (stage.transitStatus != null)
                    Text(
                      stage.transitStatus!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: CivicColors.forest,
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

  Widget _buildStandardStageContent(LifecycleStageInfo stage) {
    final isCompleted = stage.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  stage.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isCompleted ? FontWeight.w700 : FontWeight.w500,
                    color: isCompleted ? CivicColors.charcoal : const Color(0xFF64748B),
                  ),
                ),
              ),
              if (stage.timeLabel != null)
                Text(
                  stage.timeLabel!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: CivicColors.subdued,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            stage.subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: isCompleted ? CivicColors.slateGreen : const Color(0xFF94A3B8),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 3: COMMUNITY IMPACT & GROUPED REPORTS CARD
  // ===========================================================================
  Widget _buildCommunityImpactCard() {
    final reports = _problem.relatedReports;
    final totalMerged = _problem.reportCount > 0 ? _problem.reportCount : 1;

    return Container(
      decoration: BoxDecoration(
        color: CivicColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CivicColors.borderSubtle, width: 1),
        boxShadow: const [CivicShadows.card],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const Text(
                'Community Impact',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CivicColors.charcoal,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: CivicColors.mintTint,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$totalMerged Merged',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CivicColors.forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Civic Informational Banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CivicColors.mintTint.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CivicColors.mintPip.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: CivicColors.forest,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$totalMerged ${totalMerged == 1 ? 'resident reported' : 'residents reported'} this same issue.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: CivicColors.forest,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Anonymized Citizen Reports List
          if (reports.isNotEmpty) ...[
            ...reports.map((r) => _buildReportItem(r)),
          ] else ...[
            // Fallback preview matching Stitch if related reports are not individually seeded
            _buildReportPlaceholder(
              '#R-1047',
              '18h ago • Ward 4',
              'Heavy water accumulation on street',
            ),
            _buildReportPlaceholder(
              '#R-1039',
              '20h ago • Ward 4',
              'Drain overflowing near college gate',
            ),
            _buildReportPlaceholder(
              '#R-1021',
              '1d ago • Ward 4',
              'Water blocking pedestrian sidewalk',
            ),
          ],

          const SizedBox(height: 10),

          // Privacy Footnote
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: CivicColors.borderSubtle.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.security_outlined,
                  size: 13,
                  color: CivicColors.slateGreen,
                ),
                SizedBox(width: 4),
                Text(
                  'Resident identities anonymized for civic privacy',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: CivicColors.subdued,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(RelatedReportSummary r) {
    final ref = r.reportId.length > 5
        ? '#R-${r.reportId.substring(0, 4).toUpperCase()}'
        : '#R-1047';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CivicColors.borderSubtle.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ref,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: CivicColors.forest,
                ),
              ),
              Text(
                '${_formatRelativeTime(r.createdAt)} • ${r.address?.split(',').first ?? 'Ward 4'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: CivicColors.subdued,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '"${r.description}"',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CivicColors.charcoal,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportPlaceholder(String id, String meta, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CivicColors.borderSubtle.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                id,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: CivicColors.forest,
                ),
              ),
              Text(
                meta,
                style: const TextStyle(
                  fontSize: 11,
                  color: CivicColors.subdued,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '"$text"',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CivicColors.charcoal,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
