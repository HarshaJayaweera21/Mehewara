import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/work_order_model.dart';
import '../../../services/crew_service.dart';
import '../../auth/auth_widgets.dart';
import 'problem_detail_screen.dart';

class CrewJobsScreen extends StatefulWidget {
  final CrewService crewService;

  const CrewJobsScreen({
    super.key,
    required this.crewService,
  });

  @override
  State<CrewJobsScreen> createState() => _CrewJobsScreenState();
}

class _CrewJobsScreenState extends State<CrewJobsScreen> {
  List<WorkOrderModel> _workOrders = [];
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWorkOrders();
  }

  void _openProblemDetails(WorkOrderModel order, {WorkOrderModel? currentActive}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProblemDetailScreen(
          workOrder: order,
          crewService: widget.crewService,
          onWorkOrderUpdated: _loadWorkOrders,
          hasOtherActiveMission: currentActive != null && currentActive.id != order.id,
        ),
      ),
    );
  }

  Future<void> _loadWorkOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await widget.crewService.getCrewWorkOrders();
      if (mounted) {
        setState(() {
          _workOrders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return CivicColors.badgeCriticalText;
      case 'HIGH':
        return CivicColors.badgeHighText;
      case 'MEDIUM':
        return CivicColors.badgeMediumText;
      default:
        return CivicColors.badgeLowText;
    }
  }

  Color _getPriorityBg(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return CivicColors.badgeCriticalBg;
      case 'HIGH':
        return CivicColors.badgeHighBg;
      case 'MEDIUM':
        return CivicColors.badgeMediumBg;
      default:
        return CivicColors.badgeLowBg;
    }
  }

  Color _getPriorityBorder(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return CivicColors.badgeCriticalBorder;
      case 'HIGH':
        return CivicColors.badgeHighBorder;
      case 'MEDIUM':
        return CivicColors.badgeMediumBorder;
      default:
        return CivicColors.badgeLowBorder;
    }
  }

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

  Future<void> _handleStartWork(WorkOrderModel order, {WorkOrderModel? currentActive}) async {
    if (currentActive != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Squad already has active mission: "${currentActive.problemTitle}". Complete or report issue before starting a new job.',
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Start Work Order?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.problemTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: CivicColors.charcoal),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will transition the work order to IN PROGRESS and update the squad availability status to BUSY in the central municipal dispatch registry.',
              style: TextStyle(fontSize: 12.5, color: CivicColors.slateGreen, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: CivicColors.slateGreen)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CivicColors.forest,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start Job'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await widget.crewService.startWorkOrder(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work Order "${order.problemTitle}" is now IN PROGRESS.'),
            backgroundColor: CivicColors.forest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        await _loadWorkOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start work order: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _handleCompleteWork(WorkOrderModel order) async {
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: CivicColors.forest),
            SizedBox(width: 8),
            Text('Complete Work Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.problemTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CivicColors.charcoal),
              ),
              const SizedBox(height: 12),
              const Text(
                'Completion Notes (Mandatory):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CivicColors.charcoal),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe remediation actions taken, equipment utilized, materials, and final site conditions...',
                  hintStyle: const TextStyle(fontSize: 12, color: CivicColors.subdued),
                  filled: true,
                  fillColor: const Color(0xFFF9FBF9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDCE5DF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CivicColors.forest, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Please enter at least 5 characters of completion notes.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: CivicColors.slateGreen)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CivicColors.forest,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Confirm Completion'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await widget.crewService.completeWorkOrder(order.id, notesController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work Order "${order.problemTitle}" marked COMPLETED. Squad is now free.'),
            backgroundColor: CivicColors.forest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        await _loadWorkOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete work order: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _handleReportIssue(WorkOrderModel order) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedAction = 'FAIL';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.report_problem_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Report Issue / Blocker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.problemTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CivicColors.charcoal),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select Resolution Action:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CivicColors.charcoal),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => setModalState(() => selectedAction = 'FAIL'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedAction == 'FAIL' ? const Color(0xFFFEF2F2) : const Color(0xFFF9FBF9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedAction == 'FAIL' ? const Color(0xFFDC2626) : const Color(0xFFDCE5DF),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedAction == 'FAIL' ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 16,
                            color: selectedAction == 'FAIL' ? const Color(0xFFDC2626) : CivicColors.subdued,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Return to Coordinator Pool (Need special equipment/crew)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CivicColors.charcoal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => setModalState(() => selectedAction = 'CANCEL'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedAction == 'CANCEL' ? const Color(0xFFFEF2F2) : const Color(0xFFF9FBF9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedAction == 'CANCEL' ? const Color(0xFFDC2626) : const Color(0xFFDCE5DF),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedAction == 'CANCEL' ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 16,
                            color: selectedAction == 'CANCEL' ? const Color(0xFFDC2626) : CivicColors.subdued,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Cancel Work Order (Site inaccessible / false alarm)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CivicColors.charcoal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Explanation / Blocker Reason (Mandatory):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CivicColors.charcoal),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Specify impediment (e.g. missing heavy machinery, flooded access, resident obstruction)...',
                      hintStyle: const TextStyle(fontSize: 12, color: CivicColors.subdued),
                      filled: true,
                      fillColor: const Color(0xFFF9FBF9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDCE5DF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 5) {
                        return 'Please enter at least 5 characters describing the issue.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back', style: TextStyle(color: CivicColors.slateGreen)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await widget.crewService.reportWorkOrderIssue(
        order.id,
        reasonController.text.trim(),
        action: selectedAction,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Issue reported on "${order.problemTitle}". Problem returned to coordinator pool.',
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        await _loadWorkOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to report issue: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: CivicColors.forest),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: CivicColors.subdued),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadWorkOrders,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CivicColors.forest,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Partition work orders
    final inProgressOrder = _workOrders.where((w) => w.isInProgress).firstOrNull;
    final queuedOrders = _workOrders.where((w) => w.isQueued).toList();
    final pastOrders = _workOrders.where((w) => w.isClosed).toList();

    return CivicAtmosphericBackground(
      child: RefreshIndicator(
        onRefresh: _loadWorkOrders,
        color: CivicColors.forest,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Squad Operations & Queue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: CivicColors.charcoal,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Execute active missions and manage municipal priority dispatch queue.',
                          style: TextStyle(
                            fontSize: 12,
                            color: CivicColors.subdued,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isActionLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: CivicColors.forest),
                    ),
                ],
              ),

              const SizedBox(height: 18),

              // SECTION 1: ACTIVE MISSION (HERO)
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: inProgressOrder != null ? const Color(0xFFD97706) : CivicColors.subdued,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'CURRENT ACTIVE MISSION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: CivicColors.slateGreen,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (inProgressOrder != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: const Text(
                        'IN PROGRESS (BUSY)',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD97706),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 10),

              if (inProgressOrder != null)
                _buildInProgressHeroCard(inProgressOrder)
              else
                CivicSurfaceCard(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: CivicColors.mintTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle_outline_rounded, color: CivicColors.forest, size: 24),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No Active Mission in Progress',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: CivicColors.charcoal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          queuedOrders.isNotEmpty
                              ? 'Squad is currently ready. Start Job #1 from the dispatch queue below.'
                              : 'No active or queued work orders. Squad is on standby at depot.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: CivicColors.subdued, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // SECTION 2: PRIORITIZED DISPATCH QUEUE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.format_list_numbered_rounded, size: 16, color: CivicColors.forest),
                      SizedBox(width: 6),
                      Text(
                        'PRIORITY DISPATCH QUEUE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: CivicColors.slateGreen,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: queuedOrders.isNotEmpty ? CivicColors.mintTint : CivicColors.segmentBg,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${queuedOrders.length} In Queue',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: queuedOrders.isNotEmpty ? CivicColors.forest : CivicColors.subdued,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Sorted by municipal urgency & AI score. Feeds to squad as active missions complete.',
                style: TextStyle(fontSize: 11, color: CivicColors.subdued),
              ),

              const SizedBox(height: 12),

              if (queuedOrders.isNotEmpty)
                ...queuedOrders.asMap().entries.map(
                      (entry) => _buildQueuedOrderCard(
                        order: entry.value,
                        queueRank: entry.key + 1,
                        isNextUp: entry.key == 0,
                        currentActive: inProgressOrder,
                      ),
                    )
              else
                CivicSurfaceCard(
                  padding: const EdgeInsets.all(22),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 36, color: CivicColors.slateGreen),
                        SizedBox(height: 8),
                        Text(
                          'Queue is Empty',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: CivicColors.charcoal),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'When coordinators approve recommendations, jobs will stack up here automatically.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: CivicColors.subdued, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // SECTION 3: PAST / COMPLETED JOBS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'COMPLETED & PAST JOBS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: CivicColors.slateGreen,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    '${pastOrders.length} Logged',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CivicColors.subdued,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (pastOrders.isNotEmpty)
                ...pastOrders.map((order) => _buildPastOrderCard(order))
              else
                CivicSurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: const Center(
                    child: Text(
                      'No past completed jobs recorded yet.',
                      style: TextStyle(fontSize: 12, color: CivicColors.subdued),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInProgressHeroCard(WorkOrderModel order) {
    final priorityColor = _getPriorityColor(order.priority);
    final priorityBg = _getPriorityBg(order.priority);
    final priorityBorder = _getPriorityBorder(order.priority);
    final startedTime = order.startedAt != null
        ? DateFormat('hh:mm a').format(order.startedAt!)
        : 'Recently Started';

    return Container(
      decoration: BoxDecoration(
        color: CivicColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
        boxShadow: const [CivicShadows.card],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _openProblemDetails(order, currentActive: order);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt_rounded, size: 13, color: Color(0xFFD97706)),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE ON-SITE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Started $startedTime',
                            style: const TextStyle(fontSize: 11, color: CivicColors.subdued),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: priorityBg,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: priorityBorder),
                        ),
                        child: Text(
                          '${order.priority.toUpperCase()} PRIORITY',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: priorityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    order.problemTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: CivicColors.charcoal,
                      letterSpacing: -0.2,
                      height: 1.25,
                    ),
                  ),
                  if (order.problemCategory != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${order.problemCategory}',
                      style: const TextStyle(fontSize: 12, color: CivicColors.forest, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (order.problemAddress != null && order.problemAddress!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 15, color: CivicColors.forest),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            order.problemAddress!,
                            style: const TextStyle(fontSize: 12, color: CivicColors.slateGreen),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (order.instructions != null && order.instructions!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAF8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDCE5DF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'COORDINATOR DISPATCH INSTRUCTIONS',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: CivicColors.forest,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            order.instructions!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2C3E37),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Tappable Details Callout
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: CivicColors.mintTint,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CivicColors.mintPip.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.map_outlined, size: 14, color: CivicColors.forest),
                            SizedBox(width: 6),
                            Text(
                              'View Problem Scope, Description & Location Map',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CivicColors.forest),
                            ),
                          ],
                        ),
                        Icon(Icons.arrow_forward_ios, size: 11, color: CivicColors.forest),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: _isActionLoading ? null : () => _handleCompleteWork(order),
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: const Text('Complete Work'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CivicColors.forest,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: _isActionLoading ? null : () => _handleReportIssue(order),
                          icon: const Icon(Icons.report_problem_rounded, size: 16, color: Color(0xFFDC2626)),
                          label: const Text('Blocker', style: TextStyle(color: Color(0xFFDC2626))),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueuedOrderCard({
    required WorkOrderModel order,
    required int queueRank,
    required bool isNextUp,
    WorkOrderModel? currentActive,
  }) {
    final priorityColor = _getPriorityColor(order.priority);
    final priorityBg = _getPriorityBg(order.priority);
    final priorityBorder = _getPriorityBorder(order.priority);
    final canStart = currentActive == null;
    final catColor = _getCategoryColor(order.problemCategory);
    final catBg = _getCategoryBg(order.problemCategory);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CivicColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNextUp ? CivicColors.forest : const Color(0xFFDCE5DF),
          width: isNextUp ? 1.5 : 1.2,
        ),
        boxShadow: const [CivicShadows.subtle],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _openProblemDetails(order, currentActive: currentActive);
        },
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isNextUp ? CivicColors.forest : CivicColors.segmentBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isNextUp ? '#$queueRank NEXT UP' : '#$queueRank IN QUEUE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isNextUp ? Colors.white : CivicColors.slateGreen,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      if (order.isQuickWin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: CivicColors.mintTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '⚡ QUICK WIN',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: CivicColors.forest),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: priorityBg,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: priorityBorder),
                    ),
                    child: Text(
                      order.priority.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: priorityColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: catBg,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: catColor.withValues(alpha: 0.25)),
                    ),
                    child: Center(
                      child: Icon(_getCategoryIcon(order.problemCategory), size: 16, color: catColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.problemTitle,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: CivicColors.charcoal,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (order.problemCategory != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            order.problemCategory!.toUpperCase(),
                            style: const TextStyle(fontSize: 10.5, color: CivicColors.slateGreen, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (order.problemAddress != null && order.problemAddress!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: CivicColors.forest),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.problemAddress!,
                        style: const TextStyle(fontSize: 11.5, color: CivicColors.slateGreen),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // Start Job Button
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _isActionLoading
                      ? null
                      : () => _handleStartWork(order, currentActive: currentActive),
                  icon: Icon(
                    canStart ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
                    size: 16,
                  ),
                  label: Text(
                    canStart ? 'Start Work Order' : 'Locked (Active Mission In Progress)',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canStart ? CivicColors.forest : CivicColors.segmentBg,
                    foregroundColor: canStart ? Colors.white : CivicColors.subdued,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPastOrderCard(WorkOrderModel order) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final isCompleted = order.status == 'COMPLETED';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CivicColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
        boxShadow: const [CivicShadows.subtle],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          _openProblemDetails(order);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.problemTitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: CivicColors.charcoal,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isCompleted ? CivicColors.mintTint : CivicColors.segmentBg,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isCompleted ? CivicColors.forest : CivicColors.subdued,
                      ),
                    ),
                  ),
                ],
              ),
              if (order.completionNotes != null && order.completionNotes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Notes: ${order.completionNotes}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: CivicColors.slateGreen),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.problemCategory ?? 'GENERAL',
                    style: const TextStyle(fontSize: 11, color: CivicColors.subdued, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      Text(
                        dateFormat.format(order.completedAt ?? order.createdAt),
                        style: const TextStyle(fontSize: 11, color: CivicColors.subdued),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: CivicColors.slateGreen),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
