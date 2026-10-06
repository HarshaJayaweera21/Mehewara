import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/crew_model.dart';
import '../../../models/work_order_model.dart';
import '../../../services/crew_service.dart';
import '../../../services/location_service.dart';
import '../../auth/auth_widgets.dart';
import '../jobs/problem_detail_screen.dart';
import '../widgets/active_work_order_card.dart';
import '../widgets/crew_status_badge.dart';
import '../widgets/crew_work_map.dart';
import '../widgets/status_toggle_switch.dart';

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
  List<WorkOrderModel> _completedOrders = [];
  bool _isLoading = true;
  bool _isTogglingStatus = false;
  String? _errorMessage;
  CrewLocation _crewLocation = CrewLocation.defaultDepot;
  bool _isRefreshingLocation = false;

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() => _isRefreshingLocation = true);
    try {
      final loc = await LocationService().getCurrentLocation();
      if (mounted) {
        setState(() {
          _crewLocation = loc;
          _isRefreshingLocation = false;
        });
      }
      widget.crewService.sendHeartbeat(loc.latitude, loc.longitude);
    } catch (_) {
      if (mounted) {
        setState(() => _isRefreshingLocation = false);
      }
    }
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

      final orders = await widget.crewService.getCrewWorkOrders();
      inProgress = orders.where((o) => o.isInProgress).firstOrNull;
      queued = orders.where((o) => o.isQueued).toList();
      final completed = orders.where((o) => o.isCompleted).toList()
        ..sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));
      final recentCompleted = completed.take(3).toList();

      if (mounted) {
        setState(() {
          _crew = crew;
          _inProgressOrder = inProgress;
          _queuedOrders = queued;
          _completedOrders = recentCompleted;
          _isLoading = false;
        });
        _fetchLocation();
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
            content: Text(
              makeAvailable
                  ? (updated.isBusy ? 'Squad resumed active duty on current mission' : 'Squad marked AVAILABLE on standby')
                  : 'Squad marked UNAVAILABLE (On break / off-duty)',
            ),
            backgroundColor: makeAvailable ? CivicColors.forest : CivicColors.charcoal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
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
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry Connection'),
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

    final crew = _crew!;

    return CivicAtmosphericBackground(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: CivicColors.forest,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Welcome & Readiness Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: CivicColors.forest,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [CivicShadows.card],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${crew.crewType.toUpperCase()} SQUADRON',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: CivicColors.mintPip,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        CrewStatusBadge(status: crew.status),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      crew.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 14,
                          color: CivicColors.mintPip,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Leader: ${crew.crewLeaderName ?? "Municipal Supervisor"}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Availability Status Toggle Switch
              StatusToggleSwitch(
                crew: crew,
                isLoading: _isTogglingStatus,
                onToggle: _handleStatusToggle,
              ),

              const SizedBox(height: 18),

              // Section Header: Active Mission
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CURRENT OPERATIONAL MISSION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: CivicColors.slateGreen,
                      letterSpacing: 0.6,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onNavigateToJobs();
                    },
                    child: Text(
                      _queuedOrders.isNotEmpty
                          ? 'Queue (${_queuedOrders.length} pending) →'
                          : 'View All Jobs →',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CivicColors.forest,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (_inProgressOrder != null)
                ActiveWorkOrderCard(
                  workOrder: _inProgressOrder!,
                  onViewDetails: () {
                    HapticFeedback.selectionClick();
                    widget.onNavigateToJobs();
                  },
                )
              else if (_queuedOrders.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: CivicColors.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: CivicColors.mintPip.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: const [CivicShadows.subtle],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onNavigateToJobs();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: CivicColors.mintTint,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '#1 NEXT UP IN QUEUE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: CivicColors.forest,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: CivicColors.segmentBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFDCE5DF)),
                                ),
                                child: Text(
                                  'PRIORITY: ${_queuedOrders.first.priority}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: CivicColors.charcoal,
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
                              color: CivicColors.charcoal,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (_queuedOrders.first.problemAddress != null &&
                              _queuedOrders.first.problemAddress!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: CivicColors.forest),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _queuedOrders.first.problemAddress!,
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                '${_queuedOrders.length} task(s) awaiting execution in squad queue',
                                style: const TextStyle(fontSize: 11.5, color: CivicColors.subdued),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                widget.onNavigateToJobs();
                              },
                              icon: const Icon(Icons.play_arrow_rounded, size: 18),
                              label: const Text('Open Queue & Start Mission'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CivicColors.forest,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                CivicSurfaceCard(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: CivicColors.mintTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: CivicColors.forest,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No Active Remediation Mission',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: CivicColors.charcoal,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Squad is on standby at municipal depot. New work orders authorized by coordinator will appear here in real-time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: CivicColors.subdued,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Operational Field Work Map
              CrewWorkMap(
                crewLocation: _crewLocation,
                inProgressOrder: _inProgressOrder,
                queuedOrders: _queuedOrders,
                onSelectOrder: _openProblemDetails,
                onRefreshGps: _fetchLocation,
                isRefreshingGps: _isRefreshingLocation,
              ),

              if (_completedOrders.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'RECENT SQUAD COMPLETIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: CivicColors.slateGreen,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                ..._completedOrders.map((order) => Container(
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: CivicColors.mintTint,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: CivicColors.forest,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.problemTitle.isNotEmpty ? order.problemTitle : order.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: CivicColors.charcoal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      order.completedAt != null
                                          ? 'Completed ${_formatRelativeTime(order.completedAt!)}'
                                          : 'Completed recently',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: CivicColors.subdued,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: CivicColors.slateGreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
