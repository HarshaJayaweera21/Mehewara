import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/problem.dart';
import '../../../models/problem_lifecycle.dart';
import '../../../services/problems/problem_service.dart';
import '../../../widgets/common/civic_header.dart';
import '../../auth/auth_widgets.dart';

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

  IconData _getCategoryIcon() {
    switch (_problem.category) {
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
    switch (_problem.category) {
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
    switch (_problem.category) {
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

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final lifecycle = ProblemLifecycle(_problem);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: CivicHeader(
        title: 'Incident Scope & Details',
        subtitle: 'INCIDENT #${_getShortIncidentId()}',
        actions: [
          IconButton(
            tooltip: 'Refresh details',
            icon: const Icon(Icons.refresh_rounded, size: 20, color: CivicColors.forest),
            onPressed: () {
              HapticFeedback.selectionClick();
              _fetchFullDetails();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoading)
              const LinearProgressIndicator(
                minHeight: 2.5,
                color: CivicColors.forest,
                backgroundColor: Colors.transparent,
              ),

            // Main Scrollable Content wrapped in atmospheric background
            Expanded(
              child: CivicAtmosphericBackground(
                child: RefreshIndicator(
                  color: CivicColors.forest,
                  onRefresh: _fetchFullDetails,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        const SizedBox(height: 28),
                      ],
                    ),
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
  // SECTION 1: HERO INCIDENT SUMMARY CARD
  // ===========================================================================
  Widget _buildHeroCard() {
    final catColor = _getCategoryColor();
    final catBg = _getCategoryBg();

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
          // Top accent gradient strip
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF59E0B), // Amber
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
                // Meta Tags Row: Category squircle + Priority + Status
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
                          _buildPriorityPill(),
                          _buildCategoryTag(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusPill(),
                  ],
                ),
                const SizedBox(height: 12),

                // Incident Title
                Text(
                  _problem.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CivicColors.charcoal,
                    letterSpacing: -0.3,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),

                // Location Subtitle with centroid coordinates
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: CivicColors.forest,
                    ),
                    const SizedBox(width: 5),
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
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: '${_problem.latitude}, ${_problem.longitude}',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Coordinates copied to clipboard'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: CivicColors.forest,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CivicColors.segmentBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDCE5DF)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 11, color: CivicColors.slateGreen),
                            SizedBox(width: 3),
                            Text(
                              'GPS',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: CivicColors.slateGreen,
                              ),
                            ),
                          ],
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
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFDCE5DF),
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

                // AI Triage Callout Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: CivicColors.forest,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mehewara AI Intelligence: Spatial clustering unified ${_problem.reportCount} citizen reports into this municipal work incident.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: CivicColors.forest,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Card Footer Timestamps
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFFE6ECE8),
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
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCategoryTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFDCE5DF), width: 1),
      ),
      child: Text(
        _problem.category,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: CivicColors.slateGreen,
          letterSpacing: 0.5,
        ),
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
        border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
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
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: CivicColors.mintTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: CivicColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Resolution Progress Lifecycle',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CivicColors.charcoal,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
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
          const SizedBox(height: 16),

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
                    margin: const EdgeInsets.symmetric(vertical: 3),
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
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 5),
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
        border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
        boxShadow: const [CivicShadows.card],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: CivicColors.mintTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.groups_rounded,
                    size: 16,
                    color: CivicColors.forest,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFFE6ECE8),
                  width: 1,
                ),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 13,
                  color: CivicColors.slateGreen,
                ),
                SizedBox(width: 5),
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
          color: const Color(0xFFDCE5DF),
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
          color: const Color(0xFFDCE5DF),
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
