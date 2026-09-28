import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/work_order_model.dart';
import '../../../services/crew_service.dart';
import '../widgets/problem_location_map.dart';

class ProblemDetailScreen extends StatefulWidget {
  final WorkOrderModel workOrder;
  final CrewService crewService;
  final VoidCallback onWorkOrderUpdated;
  final bool hasOtherActiveMission;

  const ProblemDetailScreen({
    super.key,
    required this.workOrder,
    required this.crewService,
    required this.onWorkOrderUpdated,
    this.hasOtherActiveMission = false,
  });

  @override
  State<ProblemDetailScreen> createState() => _ProblemDetailScreenState();
}

class _ProblemDetailScreenState extends State<ProblemDetailScreen> {
  late WorkOrderModel _currentOrder;
  Map<String, dynamic>? _problemDetails;
  bool _isLoadingProblem = true;
  bool _isActionLoading = false;
  String? _problemError;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.workOrder;
    _fetchFullProblem();
  }

  Future<void> _fetchFullProblem() async {
    setState(() {
      _isLoadingProblem = true;
      _problemError = null;
    });

    try {
      final details = await widget.crewService.getProblemDetails(_currentOrder.problemId);
      if (mounted) {
        setState(() {
          _problemDetails = details;
          _isLoadingProblem = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _problemError = e.toString();
          _isLoadingProblem = false;
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

  Future<void> _handleStartWork() async {
    if (widget.hasOtherActiveMission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Squad already has an active mission in progress. Complete or report an issue before starting another job.'),
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
              _currentOrder.problemTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will mark the squad as BUSY, set the work order to IN PROGRESS, and record the start timestamp.',
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
      final updated = await widget.crewService.startWorkOrder(_currentOrder.id);
      if (mounted) {
        setState(() {
          _currentOrder = updated;
        });
        widget.onWorkOrderUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work order "${_currentOrder.problemTitle}" is now IN PROGRESS.'),
            backgroundColor: AppColors.primaryForest,
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  Future<void> _handleCompleteWork() async {
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
                _currentOrder.problemTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Remediation Notes (Mandatory):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter field observations, materials used, asphalt compacted, road opened...',
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
      final updated = await widget.crewService.completeWorkOrder(_currentOrder.id, notesController.text.trim());
      if (mounted) {
        setState(() {
          _currentOrder = updated;
        });
        widget.onWorkOrderUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work order "${_currentOrder.problemTitle}" marked COMPLETED!'),
            backgroundColor: AppColors.statusAvailableText,
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  Future<void> _handleReportIssue() async {
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
                    _currentOrder.problemTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const Text('Issue Severity / Action:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                  const Text('Blocker Reason (Mandatory):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Specify impediment (e.g. broken main, excavator breakdown)...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 5) {
                        return 'Please enter at least 5 characters.';
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
      final updated = await widget.crewService.reportWorkOrderIssue(
        _currentOrder.id,
        reasonController.text.trim(),
        action: selectedAction,
      );
      if (mounted) {
        setState(() {
          _currentOrder = updated;
        });
        widget.onWorkOrderUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Issue reported on "${_currentOrder.problemTitle}". Returned to coordinator pool.'),
            backgroundColor: AppColors.priorityCritical,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    final priorityColor = _getPriorityColor(_currentOrder.priority);
    final priorityBg = _getPriorityBg(_currentOrder.priority);

    final description = _problemDetails?['description'] ??
        _currentOrder.problemDescription ??
        'Municipal remediation requested. Full structural triage and site leveling required.';

    final latitude = (_problemDetails?['latitude'] is num)
        ? (_problemDetails!['latitude'] as num).toDouble()
        : _currentOrder.latitude;

    final longitude = (_problemDetails?['longitude'] is num)
        ? (_problemDetails!['longitude'] as num).toDouble()
        : _currentOrder.longitude;

    final address = _problemDetails?['address'] ?? _currentOrder.problemAddress ?? 'Municipal Ward District';

    final relatedReports = (_problemDetails?['relatedReports'] as List<dynamic>?) ?? [];

    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Problem Details & Site Map',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              'Work Order #${_currentOrder.id.length > 8 ? _currentOrder.id.substring(0, 8) : _currentOrder.id}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          if (_isActionLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryForest),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Priority Banner
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _currentOrder.isInProgress ? AppColors.statusBusyBg : AppColors.softSage,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _currentOrder.isInProgress ? AppColors.statusBusyBorder : AppColors.mintAccent,
                        ),
                      ),
                      child: Text(
                        _currentOrder.status == 'IN_PROGRESS'
                            ? '● LIVE ON-SITE'
                            : (_currentOrder.status == 'ASSIGNED' ? 'IN QUEUE' : _currentOrder.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _currentOrder.isInProgress ? AppColors.statusBusyText : AppColors.primaryForest,
                        ),
                      ),
                    ),
                    if (_currentOrder.priorityScore > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.canvasBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Text(
                          'SCORE: ${_currentOrder.priorityScore}/100',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
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
                    'PRIORITY: ${_currentOrder.priority}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Title & Category
            Text(
              _currentOrder.problemTitle,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.softSage,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (_currentOrder.problemCategory ?? 'GENERAL').toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryForest),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Assigned: ${dateFormat.format(_currentOrder.assignedAt ?? _currentOrder.createdAt)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Section 1: Problem Description
            _buildSectionHeader('PROBLEM SPECIFICATION & SCOPE', Icons.description_outlined),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textPrimary),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Section 2: Location Map & Coordinates
            _buildSectionHeader('INCIDENT LOCATION & GEOGRAPHIC MAP', Icons.map_outlined),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: AppColors.priorityCritical, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ProblemLocationMap(
                      latitude: latitude,
                      longitude: longitude,
                      address: address,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Section 3: Coordinator Instructions
            if (_currentOrder.instructions != null && _currentOrder.instructions!.isNotEmpty) ...[
              _buildSectionHeader('COORDINATOR FIELD DIRECTIVES', Icons.campaign_outlined),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.canvasBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  _currentOrder.instructions!,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Section 4: Consolidated Citizen Reports
            _buildSectionHeader(
              'CONSOLIDATED CITIZEN COMPLAINTS (${relatedReports.isNotEmpty ? relatedReports.length : _currentOrder.reportCount})',
              Icons.people_outline,
            ),
            const SizedBox(height: 8),
            if (_isLoadingProblem)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_problemError != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Additional resident complaint data: $_problemError',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (relatedReports.isNotEmpty)
              ...relatedReports.map((report) => _buildReportItem(report, dateFormat))
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_read_outlined, size: 20, color: AppColors.primaryForest),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _currentOrder.reportCount > 0
                              ? '${_currentOrder.reportCount} resident complaint(s) were consolidated by AI agents into this problem.'
                              : 'Dispatched via municipal supervisory triage.',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // Execution Action Footer
            if (_currentOrder.isQueued) ...[
              if (widget.hasOtherActiveMission)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.priorityCriticalBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.priorityCritical.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.lock_outline, size: 18, color: AppColors.priorityCritical),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Another mission is currently active. Finish or report an issue on that job before starting this queued order.',
                          style: TextStyle(fontSize: 11, color: AppColors.priorityCritical, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isActionLoading || widget.hasOtherActiveMission) ? null : _handleStartWork,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    widget.hasOtherActiveMission ? 'Locked (Active Mission In Progress)' : 'Start Work Order Now',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryForest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ] else if (_currentOrder.isInProgress) ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: _isActionLoading ? null : _handleCompleteWork,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Complete Work'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryForest,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _isActionLoading ? null : _handleReportIssue,
                      icon: const Icon(Icons.report_problem_outlined, color: AppColors.priorityCritical),
                      label: const Text('Blocker / Issue', style: TextStyle(color: AppColors.priorityCritical)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.priorityCritical),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primaryForest),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildReportItem(dynamic report, DateFormat dateFormat) {
    final desc = report['description'] ?? 'No text provided';
    final reportAddress = report['address'];
    final createdAt = report['createdAt'] != null ? DateTime.tryParse(report['createdAt']) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.softSage,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (report['status'] ?? 'REPORTED').toString().toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primaryForest),
                  ),
                ),
                if (createdAt != null)
                  Text(
                    dateFormat.format(createdAt),
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.35),
            ),
            if (reportAddress != null && reportAddress.toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reportAddress.toString(),
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
