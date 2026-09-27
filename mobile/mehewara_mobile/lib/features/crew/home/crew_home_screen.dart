import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/crew_model.dart';
import '../../../models/work_order_model.dart';
import '../../../services/crew_service.dart';
import '../widgets/crew_status_badge.dart';
import '../widgets/status_toggle_switch.dart';
import '../widgets/active_work_order_card.dart';
import '../jobs/problem_detail_screen.dart';

class CrewHomeScreen extends StatefulWidget {
  final CrewService crewService;
  final VoidCallback onNavigateToJobs;

  const CrewHomeScreen({
    super.key,
    required this.crewService,
    required this.onNavigateToJobs,
  });

  @override
  State<CrewHomeScreen> createState() => _CrewHomeScreenState();
}

class _CrewHomeScreenState extends State<CrewHomeScreen> {
  CrewModel? _crew;
  WorkOrderModel? _inProgressOrder;
  List<WorkOrderModel> _queuedOrders = [];
  bool _isLoading = true;
  bool _isTogglingStatus = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _openProblemDetails(WorkOrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProblemDetailScreen(
          workOrder: order,
          crewService: widget.crewService,
          onWorkOrderUpdated: _loadData,
          hasOtherActiveMission: _inProgressOrder != null && _inProgressOrder!.id != order.id,
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final crew = await widget.crewService.getCrewProfile();
      WorkOrderModel? inProgress;
      List<WorkOrderModel> queued = [];

      try {
        final orders = await widget.crewService.getCrewWorkOrders();
        inProgress = orders.where((o) => o.isInProgress).firstOrNull;
        queued = orders.where((o) => o.isQueued).toList();
      } catch (_) {
        // Work orders fetch optional
      }

      if (mounted) {
        setState(() {
          _crew = crew;
          _inProgressOrder = inProgress;
          _queuedOrders = queued;
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

  Future<void> _handleStatusToggle(bool makeAvailable) async {
    if (_crew == null || _isTogglingStatus) return;

    final targetStatus = makeAvailable ? 'AVAILABLE' : 'UNAVAILABLE';

    setState(() {
      _isTogglingStatus = true;
    });

    try {
      final updated = await widget.crewService.updateCrewStatus(targetStatus);
      if (mounted) {
        setState(() {
          _crew = updated;
          _isTogglingStatus = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Squad availability updated to $targetStatus'),
            backgroundColor: makeAvailable ? AppColors.primaryForest : AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTogglingStatus = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.priorityCritical,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
                onPressed: _loadData,
                child: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      );
    }

    final crew = _crew!;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryForest,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome & Readiness Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primaryForest,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryForest.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.softSage.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${crew.crewType} SQUADRON',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mintAccent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      CrewStatusBadge(status: crew.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    crew.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Leader: ${crew.crewLeaderName ?? "Municipal Supervisor"}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Availability Status Toggle Switch
            StatusToggleSwitch(
              crew: crew,
              isLoading: _isTogglingStatus,
              onToggle: _handleStatusToggle,
            ),

            const SizedBox(height: 20),

            // Section Header: Active Mission
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CURRENT OPERATIONAL MISSION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onNavigateToJobs,
                  child: Text(
                    _queuedOrders.isNotEmpty
                        ? 'Queue (${_queuedOrders.length} pending) →'
                        : 'View All Jobs →',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryForest,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (_inProgressOrder != null)
              ActiveWorkOrderCard(
                workOrder: _inProgressOrder!,
                onViewDetails: () => _openProblemDetails(_inProgressOrder!),
              )
            else if (_queuedOrders.isNotEmpty)
              Card(
                elevation: 1,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: AppColors.mintAccent.withValues(alpha: 0.5)),
                ),
                child: InkWell(
                  onTap: () => _openProblemDetails(_queuedOrders.first),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.softSage,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '#1 NEXT UP IN QUEUE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryForest,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.canvasBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.borderDefault),
                              ),
                              child: Text(
                                'PRIORITY: ${_queuedOrders.first.priority}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _queuedOrders.first.problemTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_queuedOrders.first.problemAddress != null &&
                            _queuedOrders.first.problemAddress!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _queuedOrders.first.problemAddress!,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.canvasBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Row(
                                children: [
                                  Icon(Icons.map_outlined, size: 13, color: AppColors.primaryForest),
                                  SizedBox(width: 6),
                                  Text(
                                    'Tap to view description, map & reports',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryForest),
                                  ),
                                ],
                              ),
                              Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primaryForest),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '${_queuedOrders.length} task(s) awaiting execution in squad queue',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onNavigateToJobs,
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Open Queue & Start Mission'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryForest,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
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
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.primaryForest,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No Active Remediation Mission',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Squad is on standby at municipal depot. New work orders authorized by coordinator will appear here in real-time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Telemetry & Specs
            const Text(
              'SQUAD TELEMETRY & SPECIFICATIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSpecRow(
                      icon: Icons.business_outlined,
                      label: 'Assigned Depot / Ward',
                      value: 'Central Colombo Depot',
                    ),
                    const Divider(height: 20),
                    _buildSpecRow(
                      icon: Icons.phone_outlined,
                      label: 'Emergency Contact Line',
                      value: crew.contactNumber ?? '+94 11 269 1111',
                    ),
                    const Divider(height: 20),
                    _buildSpecRow(
                      icon: Icons.fingerprint,
                      label: 'Municipal Registry ID',
                      value: crew.id.length > 18 ? '${crew.id.substring(0, 18)}...' : crew.id,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryForest),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
