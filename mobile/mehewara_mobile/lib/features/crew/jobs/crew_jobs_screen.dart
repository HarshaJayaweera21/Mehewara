import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/work_order_model.dart';
import '../../../services/crew_service.dart';

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

  Future<void> _handleStartWork(WorkOrderModel order, {WorkOrderModel? currentActive}) async {
    if (currentActive != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Squad already has active mission: "${currentActive.problemTitle}". Complete or report issue before starting a new job.',
          ),
          backgroundColor: AppColors.priorityCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Work Order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.problemTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will transition the work order to IN PROGRESS and update the squad availability status to BUSY in the central municipal dispatch registry.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryForest,
              foregroundColor: Colors.white,
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
            backgroundColor: AppColors.primaryForest,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadWorkOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start work order: $e'),
            backgroundColor: AppColors.priorityCritical,
            behavior: SnackBarBehavior.floating,
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
        title: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: AppColors.statusAvailableText),
            SizedBox(width: 8),
            Text('Complete Work Order'),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Completion Notes (Mandatory):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe remediation actions taken, equipment utilized, materials, and final site conditions...',
                  hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryForest,
              foregroundColor: Colors.white,
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
            content: Text('Work Order "${order.problemTitle}" marked COMPLETED. Squad is now free for next queued job.'),
            backgroundColor: AppColors.statusAvailableText,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadWorkOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete work order: $e'),
            backgroundColor: AppColors.priorityCritical,
            behavior: SnackBarBehavior.floating,
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
          title: Row(
            children: const [
              Icon(Icons.report_problem_outlined, color: AppColors.priorityCritical),
              SizedBox(width: 8),
              Text('Report Issue / Blocker'),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Issue Severity / Action:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => setModalState(() => selectedAction = 'FAIL'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: selectedAction == 'FAIL' ? AppColors.priorityCriticalBg : AppColors.canvasBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selectedAction == 'FAIL' ? AppColors.priorityCritical : AppColors.borderDefault,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedAction == 'FAIL' ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 16,
                            color: selectedAction == 'FAIL' ? AppColors.priorityCritical : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Field Blocker / Failure (Job will be rescheduled)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setModalState(() => selectedAction = 'CANCEL'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedAction == 'CANCEL' ? AppColors.priorityCriticalBg : AppColors.canvasBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selectedAction == 'CANCEL' ? AppColors.priorityCritical : AppColors.borderDefault,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedAction == 'CANCEL' ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 16,
                            color: selectedAction == 'CANCEL' ? AppColors.priorityCritical : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Cancel Work Order (Site inaccessible / false alarm)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Explanation / Blocker Reason (Mandatory):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Specify impediment (e.g. missing heavy machinery, flooded access, resident obstruction)...',
                      hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
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
              child: const Text('Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.priorityCritical,
                foregroundColor: Colors.white,
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
              'Issue reported on "${order.problemTitle}". Problem returned to coordinator pool. Squad is now free for next queued job.',
            ),
            backgroundColor: AppColors.priorityCritical,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadWorkOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to report issue: $e'),
            backgroundColor: AppColors.priorityCritical,
            behavior: SnackBarBehavior.floating,
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
        child: CircularProgressIndicator(color: AppColors.primaryForest),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.priorityCritical),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadWorkOrders,
                child: const Text('Retry'),
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

    return RefreshIndicator(
      onRefresh: _loadWorkOrders,
      color: AppColors.primaryForest,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                          color: AppColors.primaryForest,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Execute active missions and manage municipal priority dispatch queue.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryForest),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // SECTION 1: ACTIVE MISSION (HERO)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: inProgressOrder != null ? AppColors.statusBusyText : AppColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'CURRENT ACTIVE MISSION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
                if (inProgressOrder != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.statusBusyBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.statusBusyBorder),
                    ),
                    child: const Text(
                      'IN PROGRESS (BUSY)',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.statusBusyText,
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.softSage,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle_outline, color: AppColors.primaryForest, size: 24),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No Active Mission in Progress',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          queuedOrders.isNotEmpty
                              ? 'Squad is currently ready. Start Job #1 from the dispatch queue below.'
                              : 'No active or queued work orders. Squad is on standby at depot.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // SECTION 2: PRIORITIZED DISPATCH QUEUE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_list_numbered, size: 16, color: AppColors.primaryForest),
                    const SizedBox(width: 6),
                    const Text(
                      'PRIORITY DISPATCH QUEUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: queuedOrders.isNotEmpty ? AppColors.softSage : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${queuedOrders.length} In Queue',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: queuedOrders.isNotEmpty ? AppColors.primaryForest : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Sorted by municipal urgency & AI score. Automatically feeds to squad as active jobs finish.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),

            const SizedBox(height: 10),

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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: const [
                        Icon(Icons.inbox_outlined, size: 36, color: AppColors.textMuted),
                        SizedBox(height: 8),
                        Text(
                          'Queue is Empty',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'When coordinators approve recommendations, jobs will stack up here automatically.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
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
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '${pastOrders.length} Logged',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (pastOrders.isNotEmpty)
              ...pastOrders.map((order) => _buildPastOrderCard(order))
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No past completed jobs recorded yet.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInProgressHeroCard(WorkOrderModel order) {
    final priorityColor = _getPriorityColor(order.priority);
    final priorityBg = _getPriorityBg(order.priority);
    final startedTime = order.startedAt != null
        ? DateFormat('hh:mm a').format(order.startedAt!)
        : 'Recently Started';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.mintAccent, width: 1.5),
      ),
      child: Padding(
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.statusBusyBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.bolt, size: 14, color: AppColors.statusBusyText),
                          SizedBox(width: 4),
                          Text(
                            'LIVE ON-SITE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.statusBusyText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Started $startedTime',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: priorityColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'PRIORITY: ${order.priority}',
                    style: TextStyle(
                      fontSize: 10,
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
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
            if (order.problemCategory != null) ...[
              const SizedBox(height: 4),
              Text(
                'Category: ${order.problemCategory}',
                style: const TextStyle(fontSize: 12, color: AppColors.primaryForest, fontWeight: FontWeight.w600),
              ),
            ],
            if (order.problemAddress != null && order.problemAddress!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.problemAddress!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                  color: AppColors.canvasBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COORDINATOR DISPATCH INSTRUCTIONS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      order.instructions!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading ? null : () => _handleCompleteWork(order),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Complete Work'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryForest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _isActionLoading ? null : () => _handleReportIssue(order),
                    icon: const Icon(Icons.report_problem_outlined, size: 16, color: AppColors.priorityCritical),
                    label: const Text('Blocker / Issue', style: TextStyle(color: AppColors.priorityCritical)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.priorityCritical),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
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
    final canStart = currentActive == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isNextUp
            ? BorderSide(color: AppColors.mintAccent.withValues(alpha: 0.6), width: 1.2)
            : const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isNextUp ? AppColors.softSage : AppColors.canvasBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isNextUp ? AppColors.mintAccent : AppColors.borderDefault,
                        ),
                      ),
                      child: Text(
                        isNextUp ? '#$queueRank NEXT UP' : '#$queueRank IN QUEUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isNextUp ? AppColors.primaryForest : AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    if (order.priorityScore > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.canvasBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SCORE ${order.priorityScore}',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: priorityColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    order.priority,
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
              order.problemTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (order.problemCategory != null) ...[
              const SizedBox(height: 3),
              Text(
                'Category: ${order.problemCategory}',
                style: const TextStyle(fontSize: 11, color: AppColors.primaryForest, fontWeight: FontWeight.w600),
              ),
            ],
            if (order.problemAddress != null && order.problemAddress!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.problemAddress!,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
            if (order.instructions != null && order.instructions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.canvasBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Instructions: ${order.instructions}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Start Job Button (Enforces Single Active Invariant)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isActionLoading
                    ? null
                    : () => _handleStartWork(order, currentActive: currentActive),
                icon: Icon(
                  canStart ? Icons.play_arrow_rounded : Icons.lock_outline,
                  size: 16,
                ),
                label: Text(
                  canStart
                      ? 'Start Work Order'
                      : 'Locked (Active Mission In Progress)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canStart ? AppColors.primaryForest : AppColors.surfaceSubtle,
                  foregroundColor: canStart ? Colors.white : AppColors.textMuted,
                  elevation: canStart ? 1 : 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastOrderCard(WorkOrderModel order) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final isCompleted = order.status == 'COMPLETED';
    final statusColor = isCompleted
        ? AppColors.statusAvailableText
        : (order.status == 'CANCELLED' ? AppColors.textSecondary : AppColors.priorityCritical);
    final statusBg = isCompleted
        ? AppColors.statusAvailableBg
        : (order.status == 'CANCELLED' ? AppColors.canvasBg : AppColors.priorityCriticalBg);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (order.completionNotes != null && order.completionNotes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Notes: ${order.completionNotes}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.problemCategory ?? 'GENERAL',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
                Text(
                  dateFormat.format(order.completedAt ?? order.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

