import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/report_model.dart';
import '../../../services/reports/report_service.dart';

class ResidentReportDetailScreen extends StatefulWidget {
  final String reportId;

  const ResidentReportDetailScreen({super.key, required this.reportId});

  @override
  State<ResidentReportDetailScreen> createState() => _ResidentReportDetailScreenState();
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
    setState(() => _report = _service.getReport(widget.reportId));
    await _report;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CivicColors.alabaster,
      appBar: AppBar(title: const Text('Report progress')),
      body: FutureBuilder<ResidentReport>(
        future: _report,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: CivicColors.forest));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 46, color: CivicColors.slateGreen),
                    const SizedBox(height: 12),
                    Text(snapshot.error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
                  ],
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
                      padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 16, wide ? 32 : 16, 32),
                      children: [
                        _StatusBanner(report: report),
                        const SizedBox(height: 16),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: _buildReportInformation(report)),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: _buildProgress(report)),
                            ],
                          )
                        else ...[
                          _buildProgress(report),
                          const SizedBox(height: 16),
                          _buildReportInformation(report),
                        ],
                        const SizedBox(height: 16),
                        _LocationCard(report: report),
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
    );
  }

  Widget _buildProgress(ResidentReport report) {
    return _DetailCard(
      title: 'Progress updates',
      icon: Icons.route_outlined,
      child: Column(
        children: [
          _ProgressTimeline(status: report.status, linkedProblemCount: report.linkedProblemCount),
          if (report.aiAnalysis?.isNotEmpty == true) ...[
            const Divider(height: 28),
            const Align(alignment: Alignment.centerLeft, child: Text('Initial assessment', style: TextStyle(fontWeight: FontWeight.w800, color: CivicColors.charcoal))),
            const SizedBox(height: 7),
            Text(_assessmentSummary(report.aiAnalysis!), style: const TextStyle(height: 1.45, color: CivicColors.slateGreen)),
          ],
        ],
      ),
    );
  }

  Widget _buildReportInformation(ResidentReport report) {
    return _DetailCard(
      title: 'Your submission',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelValue(label: 'Category', value: report.category),
          const SizedBox(height: 14),
          const Text('What you reported', style: TextStyle(fontWeight: FontWeight.w800, color: CivicColors.charcoal)),
          const SizedBox(height: 6),
          Text(report.description, style: const TextStyle(height: 1.45, color: CivicColors.slateGreen)),
          const Divider(height: 30),
          Row(
            children: [
              const Icon(Icons.schedule_outlined, size: 17, color: CivicColors.slateGreen),
              const SizedBox(width: 8),
              Expanded(child: Text('Submitted ${DateFormat.yMMMd().add_jm().format(report.createdAt)}', style: const TextStyle(fontSize: 12, color: CivicColors.slateGreen))),
            ],
          ),
        ],
      ),
    );
  }

  String _assessmentSummary(String input) {
    try {
      final decoded = jsonDecode(input);
      if (decoded is Map<String, dynamic>) {
        return (decoded['observedIssue'] ?? decoded['summary'] ?? input).toString();
      }
    } catch (_) {
      // The backend can return an opaque analysis value while processing.
    }
    return input;
  }
}

class _StatusBanner extends StatelessWidget {
  final ResidentReport report;

  const _StatusBanner({required this.report});

  @override
  Widget build(BuildContext context) {
    final status = report.status.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: CivicColors.forest, borderRadius: BorderRadius.circular(18), boxShadow: const [CivicShadows.card]),
      child: Row(
        children: [
          const CircleAvatar(radius: 26, backgroundColor: CivicColors.mintPip, child: Icon(Icons.track_changes_rounded, color: CivicColors.forest)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current status', style: TextStyle(fontSize: 12, color: Color(0xFFD9EEE5))),
                const SizedBox(height: 3),
                Text(status, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
          if (report.linkedProblemCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
              child: const Text('Linked', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
        ],
      ),
    );
  }
}

class _ProgressTimeline extends StatelessWidget {
  final String status;
  final int linkedProblemCount;

  const _ProgressTimeline({required this.status, required this.linkedProblemCount});

  @override
  Widget build(BuildContext context) {
    const stages = <_TimelineStage>[
      _TimelineStage('Received', 'Your report has been recorded.', 'PENDING'),
      _TimelineStage('Reviewing', 'The municipal team is assessing the details.', 'PROCESSING'),
      _TimelineStage('Assigned', 'A work order has been assigned.', 'ASSIGNED'),
      _TimelineStage('Resolved', 'The issue has been completed.', 'RESOLVED'),
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
                Icon(complete ? Icons.check_circle : selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: complete || selected ? CivicColors.forest : CivicColors.subdued, size: 22),
                if (index < stages.length - 1) Container(width: 2, height: 36, color: complete ? CivicColors.mintPip : CivicColors.borderSubtle),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stage.label, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? CivicColors.forest : CivicColors.charcoal)),
                    const SizedBox(height: 2),
                    Text(index == 1 && linkedProblemCount > 0 ? 'Linked to a municipal problem for follow-up.' : stage.detail, style: const TextStyle(fontSize: 12, height: 1.3, color: CivicColors.slateGreen)),
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
    return _DetailCard(
      title: 'Reported location',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.address?.isNotEmpty == true) ...[
            Text(report.address!, style: const TextStyle(color: CivicColors.slateGreen)),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 210,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(report.latitude, report.longitude),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.mehewara.mobile'),
                  MarkerLayer(markers: [Marker(point: LatLng(report.latitude, report.longitude), width: 46, height: 46, child: const Icon(Icons.location_pin, size: 44, color: Colors.red))]),
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
    return _DetailCard(
      title: 'Evidence photos',
      icon: Icons.photo_library_outlined,
      child: SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, index) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              photos[index].url,
              width: 150,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(width: 150, color: CivicColors.surfaceSubtle, child: const Icon(Icons.broken_image_outlined, color: CivicColors.slateGreen)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 21, color: CivicColors.forest),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: CivicColors.charcoal)),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;

  const _LabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: CivicColors.mintTint, borderRadius: BorderRadius.circular(8)),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CivicColors.forest)),
    );
  }
}
