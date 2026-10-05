import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/report_model.dart';
import '../../../services/reports/report_service.dart';
import '../../../widgets/common/civic_header.dart';
import '../../auth/auth_widgets.dart';

class ResidentReportDetailScreen extends StatefulWidget {
  final String reportId;

  const ResidentReportDetailScreen({super.key, required this.reportId});

  @override
  State<ResidentReportDetailScreen> createState() =>
      _ResidentReportDetailScreenState();
}

class _ResidentReportDetailScreenState extends State<ResidentReportDetailScreen> {
  final _service = ReportService();
  late Future<ResidentReport> _report;

  @override
  void initState() {
    super.initState();
    _report = _service.getReport(widget.reportId);
  }

  Future<void> _refresh() async {
    setState(() {
      _report = _service.getReport(widget.reportId);
    });
    await _report;
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: CivicHeader(
        title: 'Report Progress',
        subtitle: 'INCIDENT TRACKING',
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: CivicColors.forest),
            tooltip: 'Refresh Status',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CivicAtmosphericBackground(
        child: FutureBuilder<ResidentReport>(
          future: _report,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: CivicColors.forest),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CivicSurfaceCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 46,
                          color: CivicColors.slateGreen,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Could not load report details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: CivicColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: CivicColors.slateGreen,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _refresh,
                          style: FilledButton.styleFrom(
                            backgroundColor: CivicColors.forest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final report = snapshot.data!;
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1050),
                    child: RefreshIndicator(
                      color: CivicColors.forest,
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          wide ? 32 : 16,
                          12,
                          wide ? 32 : 16,
                          40,
                        ),
                        children: [
                          // 1. Status Banner Card
                          _StatusBanner(
                            report: report,
                            onCopyId: () => _copyToClipboard(
                              report.id,
                              'Tracking ID',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Main Content Split
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _buildReportInformation(report),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 5,
                                  child: _buildProgress(report),
                                ),
                              ],
                            )
                          else ...[
                            _buildProgress(report),
                            const SizedBox(height: 16),
                            _buildReportInformation(report),
                          ],
                          const SizedBox(height: 16),

                          // 3. Location Map Card
                          _LocationCard(report: report),

                          // 4. Evidence Photos Card
                          if (report.photos.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _PhotosCard(photos: report.photos),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgress(ResidentReport report) {
    return CivicSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.route_rounded, size: 20, color: CivicColors.forest),
              SizedBox(width: 10),
              Text(
                'Lifecycle & Updates',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: CivicColors.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ProgressTimeline(
            status: report.status,
            linkedProblemCount: report.linkedProblemCount,
          ),
          if (report.parsedAiAnalysis != null) ...[
            const Divider(height: 28, color: Color(0xFFEBEFEA)),
            _AiTriageCard(info: report.parsedAiAnalysis!),
          ],
        ],
      ),
    );
  }

  Widget _buildReportInformation(ResidentReport report) {
    return CivicSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                size: 20,
                color: CivicColors.forest,
              ),
              const SizedBox(width: 10),
              const Text(
                'Incident Details',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: CivicColors.charcoal,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: CivicColors.mintTint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: CivicColors.mintPip.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  report.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: CivicColors.forest,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'What you reported',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: CivicColors.charcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            report.description,
            style: const TextStyle(
              height: 1.5,
              fontSize: 13.5,
              color: CivicColors.slateGreen,
            ),
          ),
          const Divider(height: 28, color: Color(0xFFEBEFEA)),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: CivicColors.slateGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Submitted ${DateFormat.yMMMd().add_jm().format(report.createdAt)}',
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
      ),
    );
  }
}

class _AiTriageCard extends StatelessWidget {
  final AiTriageInfo info;

  const _AiTriageCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final isUncertain = info.isUncertain;

    final cardBg = isUncertain ? const Color(0xFFFFFBEB) : CivicColors.mintTint;
    final cardBorder = isUncertain
        ? const Color(0xFFFDE68A)
        : CivicColors.mintPip.withValues(alpha: 0.35);
    final iconColor = isUncertain ? const Color(0xFFB45309) : CivicColors.forest;
    final titleColor = isUncertain ? const Color(0xFF92400E) : CivicColors.forest;
    final textColor = isUncertain ? const Color(0xFF78350F) : CivicColors.forest;
    final chipBg = Colors.white.withValues(alpha: 0.85);

    final chips = <_TriageBadge>[];
    if (info.affectedAsset != null && info.affectedAsset!.trim().isNotEmpty) {
      chips.add(_TriageBadge(
        icon: Icons.layers_outlined,
        label: 'Asset: ${info.affectedAsset}',
      ));
    }
    if (info.priority != null && info.priority!.trim().isNotEmpty) {
      chips.add(_TriageBadge(
        icon: Icons.flag_rounded,
        label: '${info.priority} Priority',
      ));
    }
    if (info.inferredCategory != null && info.inferredCategory!.trim().isNotEmpty) {
      chips.add(_TriageBadge(
        icon: Icons.category_outlined,
        label: info.inferredCategory!,
      ));
    }
    for (final hazard in info.hazards) {
      chips.add(_TriageBadge(
        icon: Icons.warning_amber_rounded,
        label: hazard,
      ));
    }
    for (final ev in info.evidence) {
      chips.add(_TriageBadge(
        icon: Icons.check_circle_outline_rounded,
        label: ev,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isUncertain
                      ? const Color(0xFFFEF3C7)
                      : CivicColors.mintPip.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUncertain
                      ? Icons.policy_rounded
                      : Icons.auto_awesome_rounded,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            info.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (info.badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isUncertain
                                  ? const Color(0xFFFDE68A)
                                  : CivicColors.mintPip.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              info.badgeText!,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isUncertain
                                    ? const Color(0xFF92400E)
                                    : CivicColors.forest,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      info.summary,
                      style: TextStyle(
                        height: 1.45,
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (info.observedIssue != null &&
              info.observedIssue!.trim().isNotEmpty &&
              info.observedIssue != info.summary) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cardBorder, width: 0.7),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Observed: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      color: titleColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      info.observedIssue!,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chips.map((c) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder, width: 0.7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.icon, size: 12, color: iconColor),
                      const SizedBox(width: 4),
                      Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (isUncertain && info.missingInformation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Awaiting coordinator verification: ${info.missingInformation.join(", ")}',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 11,
                color: Color(0xFF92400E),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TriageBadge {
  final IconData icon;
  final String label;

  const _TriageBadge({required this.icon, required this.label});
}


class _StatusBanner extends StatelessWidget {
  final ResidentReport report;
  final VoidCallback onCopyId;

  const _StatusBanner({required this.report, required this.onCopyId});

  @override
  Widget build(BuildContext context) {
    final status = _mapStatus(report.status);

    return CivicSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: status.border),
                ),
                child: Icon(status.icon, color: status.foreground, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT RESOLUTION STATUS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: CivicColors.slateGreen,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: CivicColors.charcoal,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (report.linkedProblemCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: CivicColors.badgeAssignedBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CivicColors.badgeAssignedBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_tree_outlined,
                        size: 13,
                        color: CivicColors.badgeAssignedText,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Assigned to Crew',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: CivicColors.badgeAssignedText,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFEBEFEA)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.tag_rounded,
                    size: 15,
                    color: CivicColors.slateGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tracking ID: ${report.id.length > 12 ? "${report.id.substring(0, 12)}..." : report.id}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CivicColors.slateGreen,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onCopyId,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 14, color: CivicColors.forest),
                      SizedBox(width: 4),
                      Text(
                        'Copy ID',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CivicColors.forest,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _StatusInfo _mapStatus(String value) {
    switch (value.toUpperCase()) {
      case 'RESOLVED':
        return _StatusInfo(
          label: 'Issue Resolved',
          icon: Icons.check_circle_rounded,
          background: CivicColors.badgeResolvedBg,
          foreground: CivicColors.badgeResolvedText,
          border: CivicColors.badgeResolvedBorder,
        );
      case 'ASSIGNED':
        return _StatusInfo(
          label: 'Dispatched to Field Crew',
          icon: Icons.engineering_rounded,
          background: CivicColors.badgeAssignedBg,
          foreground: CivicColors.badgeAssignedText,
          border: CivicColors.badgeAssignedBorder,
        );
      case 'PROCESSING':
        return _StatusInfo(
          label: 'Under Municipal Review',
          icon: Icons.hourglass_top_rounded,
          background: CivicColors.badgeProcessingBg,
          foreground: CivicColors.badgeProcessingText,
          border: CivicColors.badgeProcessingBorder,
        );
      case 'CANCELLED':
        return _StatusInfo(
          label: 'Closed / Duplicate',
          icon: Icons.cancel_rounded,
          background: CivicColors.badgeCriticalBg,
          foreground: CivicColors.badgeCriticalText,
          border: CivicColors.badgeCriticalBorder,
        );
      default:
        return _StatusInfo(
          label: 'Report Received',
          icon: Icons.inbox_rounded,
          background: CivicColors.mintTint,
          foreground: CivicColors.forest,
          border: CivicColors.mintPip.withValues(alpha: 0.4),
        );
    }
  }
}

class _StatusInfo {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;

  _StatusInfo({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
  });
}

class _ProgressTimeline extends StatelessWidget {
  final String status;
  final int linkedProblemCount;

  const _ProgressTimeline({
    required this.status,
    required this.linkedProblemCount,
  });

  @override
  Widget build(BuildContext context) {
    const stages = <_TimelineStage>[
      _TimelineStage('Received', 'Your report has been recorded in the civic system.', 'PENDING'),
      _TimelineStage('Reviewing', 'Municipal coordinators assess severity & routing.', 'PROCESSING'),
      _TimelineStage('Assigned', 'Dispatched to specialized local field remediation squad.', 'ASSIGNED'),
      _TimelineStage('Resolved', 'Remediation completed and verified with photographic proof.', 'RESOLVED'),
    ];
    final active = stages.indexWhere((stage) => stage.status == status);
    final current = active < 0 ? 0 : active;

    return Column(
      children: List.generate(stages.length, (index) {
        final stage = stages[index];
        final complete = index < current;
        final selected = index == current;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: complete
                        ? CivicColors.forest
                        : (selected ? CivicColors.mintTint : const Color(0xFFF0F4F2)),
                    border: Border.all(
                      color: complete || selected
                          ? CivicColors.forest
                          : const Color(0xFFDDE2DE),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    complete
                        ? Icons.check_rounded
                        : (selected ? Icons.circle : Icons.circle_outlined),
                    color: complete ? Colors.white : CivicColors.forest,
                    size: complete ? 15 : 8,
                  ),
                ),
                if (index < stages.length - 1)
                  Container(
                    width: 2,
                    height: 38,
                    color: complete ? CivicColors.forest : const Color(0xFFDDE2DE),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? CivicColors.forest : CivicColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      index == 1 && linkedProblemCount > 0
                          ? 'Linked to municipal work order dispatch.'
                          : stage.detail,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: CivicColors.slateGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _TimelineStage {
  final String label;
  final String detail;
  final String status;

  const _TimelineStage(this.label, this.detail, this.status);
}

class _LocationCard extends StatelessWidget {
  final ResidentReport report;

  const _LocationCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return CivicSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: CivicColors.forest,
              ),
              const SizedBox(width: 10),
              const Text(
                'Reported Location',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: CivicColors.charcoal,
                ),
              ),
              const Spacer(),
              Text(
                '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: CivicColors.slateGreen,
                ),
              ),
            ],
          ),
          if (report.address?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              report.address!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CivicColors.slateGreen,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(report.latitude, report.longitude),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.mehewara.mobile',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(report.latitude, report.longitude),
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_pin,
                          size: 46,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotosCard extends StatelessWidget {
  final List<ReportPhoto> photos;

  const _PhotosCard({required this.photos});

  @override
  Widget build(BuildContext context) {
    return CivicSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 20,
                color: CivicColors.forest,
              ),
              const SizedBox(width: 10),
              const Text(
                'Photographic Evidence',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: CivicColors.charcoal,
                ),
              ),
              const Spacer(),
              Text(
                '${photos.length} photo${photos.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: CivicColors.slateGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, index) => ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  photos[index].url,
                  width: 150,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 150,
                    decoration: BoxDecoration(
                      color: CivicColors.mintTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: CivicColors.slateGreen,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
