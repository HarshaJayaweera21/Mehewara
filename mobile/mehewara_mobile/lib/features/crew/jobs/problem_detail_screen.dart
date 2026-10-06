import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/work_order_model.dart';
import '../../../services/crew_service.dart';
import '../../../widgets/common/civic_header.dart';
import '../../auth/auth_widgets.dart';
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

  Future<void> _handleStartWork() async {
    if (widget.hasOtherActiveMission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Squad already has an active mission in progress. Complete or report an issue before starting another job.'),
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
              _currentOrder.problemTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: CivicColors.charcoal),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will mark the squad as BUSY, set the work order to IN PROGRESS, and record the start timestamp in the municipal registry.',
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
      final updated = await widget.crewService.startWorkOrder(_currentOrder.id);
      if (mounted) {
        setState(() {
          _currentOrder = updated;
        });
        widget.onWorkOrderUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work order "${_currentOrder.problemTitle}" is now IN PROGRESS.'),
            backgroundColor: CivicColors.forest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
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

  Future<void> _handleCompleteWork() async {
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
                _currentOrder.problemTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CivicColors.charcoal),
              ),
              const SizedBox(height: 12),
              const Text(
                'Remediation Notes (Mandatory):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CivicColors.charcoal),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter field observations, materials used, asphalt compacted, road opened...',
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
      final updated = await widget.crewService.completeWorkOrder(_currentOrder.id, notesController.text.trim());
      if (mounted) {
        setState(() {
          _currentOrder = updated;
        });
        widget.onWorkOrderUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work order "${_currentOrder.problemTitle}" marked COMPLETED.'),
            backgroundColor: CivicColors.forest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
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

  Future<void> _handleReportIssue() async {
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
                    _currentOrder.problemTitle,
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
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
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
    final priorityColor = _getPriorityColor(_currentOrder.priority);
    final priorityBg = _getPriorityBg(_currentOrder.priority);
    final priorityBorder = _getPriorityBorder(_currentOrder.priority);

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
    final catColor = _getCategoryColor(_currentOrder.problemCategory);
    final catBg = _getCategoryBg(_currentOrder.problemCategory);

    final orderIdShort = _currentOrder.id.length > 8 ? _currentOrder.id.substring(0, 8).toUpperCase() : _currentOrder.id.toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: CivicHeader(
        title: 'Mission Scope & Site Details',
        subtitle: 'Work Order #$orderIdShort',
        actions: [
          if (_isActionLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: CivicColors.forest),
              ),
            ),
        ],
      ),
      body: CivicAtmosphericBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Summary Card
              Container(
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
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: catBg,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(color: catColor.withValues(alpha: 0.25)),
                                    ),
                                    child: Center(
                                      child: Icon(_getCategoryIcon(_currentOrder.problemCategory), size: 16, color: catColor),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: _currentOrder.isInProgress ? const Color(0xFFFFFBEB) : CivicColors.mintTint,
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: _currentOrder.isInProgress
                                            ? const Color(0xFFFCD34D)
                                            : CivicColors.mintPip.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      _currentOrder.status == 'IN_PROGRESS'
                                          ? '● LIVE ON-SITE'
                                          : (_currentOrder.status == 'ASSIGNED' ? 'IN QUEUE' : _currentOrder.status),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _currentOrder.isInProgress ? const Color(0xFFD97706) : CivicColors.forest,
                                      ),
                                    ),
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
                                  '${_currentOrder.priority.toUpperCase()} PRIORITY',
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
                            _currentOrder.problemTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: CivicColors.charcoal,
                              letterSpacing: -0.3,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                (_currentOrder.problemCategory ?? 'GENERAL').toUpperCase(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CivicColors.slateGreen),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Assigned: ${dateFormat.format(_currentOrder.assignedAt ?? _currentOrder.createdAt)}',
                                style: const TextStyle(fontSize: 11, color: CivicColors.subdued),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Quick Win & Duration Chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (_currentOrder.isQuickWin)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: CivicColors.mintTint,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: CivicColors.mintPip.withValues(alpha: 0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 13, color: CivicColors.forest),
                                      SizedBox(width: 3),
                                      Text(
                                        'QUICK WIN OPPORTUNITY',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: CivicColors.forest,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: CivicColors.segmentBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFDCE5DF)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 13, color: CivicColors.slateGreen),
                                    const SizedBox(width: 4),
                                    Text(
                                      'EST. FIX TIME: ~${_currentOrder.estimatedDurationMinutes ?? 60} MINS',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: CivicColors.slateGreen,
                                      ),
                                    ),
                                  ],
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

              const SizedBox(height: 18),

              // Section 1: Problem Description
              _buildSectionHeader('PROBLEM SPECIFICATION & SCOPE', Icons.description_outlined),
              const SizedBox(height: 8),
              CivicSurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 13, height: 1.45, color: CivicColors.charcoal),
                ),
              ),

              const SizedBox(height: 18),

              // Section 2: Location Map & Coordinates
              _buildSectionHeader('INCIDENT LOCATION & GEOGRAPHIC MAP', Icons.map_outlined),
              const SizedBox(height: 8),
              CivicSurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, color: CivicColors.forest, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CivicColors.charcoal),
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

              const SizedBox(height: 18),

              // Section 3: Coordinator Instructions
              if (_currentOrder.instructions != null && _currentOrder.instructions!.isNotEmpty) ...[
                _buildSectionHeader('COORDINATOR FIELD DIRECTIVES', Icons.campaign_outlined),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CivicColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
                    boxShadow: const [CivicShadows.subtle],
                  ),
                  child: Text(
                    _currentOrder.instructions!,
                    style: const TextStyle(fontSize: 13, color: CivicColors.charcoal, height: 1.4),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Section 4: Consolidated Citizen Reports
              _buildSectionHeader(
                'CONSOLIDATED CITIZEN COMPLAINTS (${relatedReports.isNotEmpty ? relatedReports.length : _currentOrder.reportCount})',
                Icons.people_outline_rounded,
              ),
              const SizedBox(height: 8),
              if (_isLoadingProblem)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: CivicColors.forest)))
              else if (_problemError != null)
                CivicSurfaceCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: CivicColors.subdued),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Additional resident complaint data: $_problemError',
                          style: const TextStyle(fontSize: 11.5, color: CivicColors.subdued),
                        ),
                      ),
                    ],
                  ),
                )
              else if (relatedReports.isNotEmpty)
                ...relatedReports.map((report) => _buildReportItem(report, dateFormat))
              else
                CivicSurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_read_outlined, size: 20, color: CivicColors.forest),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _currentOrder.reportCount > 0
                              ? '${_currentOrder.reportCount} resident complaint(s) were consolidated by AI agents into this problem.'
                              : 'Dispatched via municipal supervisory triage.',
                          style: const TextStyle(fontSize: 12, color: CivicColors.slateGreen),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 28),

              // Execution Action Footer
              if (_currentOrder.isQueued) ...[
                if (widget.hasOtherActiveMission)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Another mission is currently active. Finish or report an issue on that job before starting this queued order.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: (_isActionLoading || widget.hasOtherActiveMission) ? null : _handleStartWork,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      widget.hasOtherActiveMission ? 'Locked (Active Mission In Progress)' : 'Start Work Order Now',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CivicColors.forest,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ] else if (_currentOrder.isInProgress) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _isActionLoading ? null : _handleCompleteWork,
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('Complete Work', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CivicColors.forest,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _isActionLoading ? null : _handleReportIssue,
                          icon: const Icon(Icons.report_problem_rounded, color: Color(0xFFDC2626)),
                          label: const Text('Blocker', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
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
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: CivicColors.forest),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: CivicColors.slateGreen,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CivicColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
        boxShadow: const [CivicShadows.subtle],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CivicColors.mintTint,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (report['status'] ?? 'REPORTED').toString().toUpperCase(),
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: CivicColors.forest),
                ),
              ),
              if (createdAt != null)
                Text(
                  dateFormat.format(createdAt),
                  style: const TextStyle(fontSize: 10.5, color: CivicColors.subdued),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(fontSize: 12.5, color: CivicColors.charcoal, height: 1.35),
          ),
          if (reportAddress != null && reportAddress.toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 12, color: CivicColors.subdued),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    reportAddress.toString(),
                    style: const TextStyle(fontSize: 10.5, color: CivicColors.subdued),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
