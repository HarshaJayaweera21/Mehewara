import 'package:intl/intl.dart';
import 'problem.dart';

enum LifecycleNodeState { completed, active, pending }

class LifecycleStageInfo {
  final int stageNumber;
  final String title;
  final String subtitle;
  final String? timeLabel;
  final LifecycleNodeState state;
  final String? leadInspector;
  final String? transitStatus;

  LifecycleStageInfo({
    required this.stageNumber,
    required this.title,
    required this.subtitle,
    this.timeLabel,
    required this.state,
    this.leadInspector,
    this.transitStatus,
  });

  bool get isCompleted => state == LifecycleNodeState.completed;
  bool get isActive => state == LifecycleNodeState.active;
  bool get isPending => state == LifecycleNodeState.pending;
}

class ProblemLifecycle {
  final Problem problem;

  ProblemLifecycle(this.problem);

  int get currentStageNumber {
    final status = problem.status.toUpperCase();
    switch (status) {
      case 'RESOLVED':
      case 'CLOSED':
        return 5;
      case 'IN_PROGRESS':
        return 4;
      case 'ASSIGNED':
        return 3;
      case 'IDENTIFIED':
      case 'PROCESSING':
      case 'AWAITING_ASSIGNMENT':
        return 2;
      case 'PENDING':
      default:
        return 1;
    }
  }

  String get stageBadgeText {
    final stage = currentStageNumber;
    if (stage == 5) return 'Stage 5 of 5 (Resolved)';
    return 'Stage $stage of 5';
  }

  List<LifecycleStageInfo> get stages {
    final activeStage = currentStageNumber;
    final timeFormat = DateFormat('hh:mm a');
    final dateFormat = DateFormat('MMM dd');

    final incidentRef = problem.id.length > 5
        ? '#P-${problem.id.substring(0, 3).toUpperCase()}'
        : '#P-023';

    final categoryName = problem.category.isNotEmpty
        ? '${problem.category[0].toUpperCase()}${problem.category.substring(1).toLowerCase()}'
        : 'Public Works';

    final count = problem.reportCount > 0 ? problem.reportCount : 1;

    // Stage 1: Submitted
    final stage1State = activeStage > 1
        ? LifecycleNodeState.completed
        : (activeStage == 1 ? LifecycleNodeState.active : LifecycleNodeState.pending);

    // Stage 2: Consolidated
    final stage2State = activeStage > 2
        ? LifecycleNodeState.completed
        : (activeStage == 2 ? LifecycleNodeState.active : LifecycleNodeState.pending);

    // Stage 3: Dispatched & Assigned
    final stage3State = activeStage > 3
        ? LifecycleNodeState.completed
        : (activeStage == 3 ? LifecycleNodeState.active : LifecycleNodeState.pending);

    // Stage 4: On-Site & In Progress
    final stage4State = activeStage > 4
        ? LifecycleNodeState.completed
        : (activeStage == 4 ? LifecycleNodeState.active : LifecycleNodeState.pending);

    // Stage 5: Resolved
    final stage5State = activeStage >= 5
        ? LifecycleNodeState.completed
        : LifecycleNodeState.pending;

    return [
      LifecycleStageInfo(
        stageNumber: 1,
        title: 'Report Submitted by Citizen',
        subtitle: 'Verified by municipal triage system • ${dateFormat.format(problem.createdAt)}',
        timeLabel: timeFormat.format(problem.createdAt),
        state: stage1State,
      ),
      LifecycleStageInfo(
        stageNumber: 2,
        title: 'Consolidated into Municipal Problem',
        subtitle: 'AI Agent grouped $count community ${count == 1 ? 'report' : 'reports'} into incident $incidentRef',
        timeLabel: timeFormat.format(problem.createdAt.add(const Duration(minutes: 45))),
        state: stage2State,
      ),
      LifecycleStageInfo(
        stageNumber: 3,
        title: 'Work Crew Dispatched & Work Order Issued',
        subtitle: 'Assigned to Ward Central $categoryName Crew',
        leadInspector: 'M. Perera',
        transitStatus: 'In Transit',
        state: stage3State,
      ),
      LifecycleStageInfo(
        stageNumber: 4,
        title: 'Crew On-Site & Repair In Progress',
        subtitle: 'Expected arrival window: Active municipal response',
        state: stage4State,
      ),
      LifecycleStageInfo(
        stageNumber: 5,
        title: 'Issue Resolved & Public Works Verified',
        subtitle: 'Final photographic verification by area municipal inspector',
        state: stage5State,
      ),
    ];
  }
}
