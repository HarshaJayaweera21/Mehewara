import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/report_model.dart';
import '../../../services/reports/report_service.dart';
import '../../../widgets/common/civic_header.dart';
import '../../auth/auth_widgets.dart';
import 'resident_report_detail_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key, this.onCreateReport, this.service});

  final VoidCallback? onCreateReport;
  final ReportService? service;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  late final ReportService _service;
  final _search = TextEditingController();
  late Future<List<ResidentReport>> _reports;
  String _filter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ReportService();
    _reports = _service.getMyReports();
  }

  Future<void> _refresh() async {
    setState(() {
      _reports = _service.getMyReports();
    });
    await _reports;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: CivicHeader(
        title: 'My Reports',
        subtitle: 'Community Issue Tracking',
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            icon: const Icon(Icons.refresh_rounded, color: CivicColors.forest),
            onPressed: () {
              HapticFeedback.selectionClick();
              _refresh();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: widget.onCreateReport != null
          ? FloatingActionButton.extended(
              backgroundColor: CivicColors.forest,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Report issue',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: widget.onCreateReport,
            )
          : null,
      body: CivicAtmosphericBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: FutureBuilder<List<ResidentReport>>(
                    future: _reports,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: CivicColors.forest,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return _ReportsMessage(
                          icon: Icons.cloud_off_outlined,
                          title: 'We could not load your reports',
                          detail: snapshot.error.toString(),
                          onRefresh: _refresh,
                          refreshLabel: 'Try again',
                        );
                      }

                      final reports = snapshot.data ?? const <ResidentReport>[];
                      if (reports.isEmpty) {
                        return _ReportsMessage(
                          icon: Icons.mark_email_unread_outlined,
                          title: 'No reports yet',
                          detail:
                              'When you report a municipal issue, its progress and dispatch status will appear here.',
                          onCreateReport: widget.onCreateReport,
                          onRefresh: _refresh,
                        );
                      }

                      final activeCount = reports
                          .where(
                            (report) => const {
                              'PENDING',
                              'PROCESSING',
                              'ASSIGNED',
                            }.contains(report.status.toUpperCase()),
                          )
                          .length;
                      final resolvedCount = reports
                          .where(
                            (report) => report.status.toUpperCase() == 'RESOLVED',
                          )
                          .length;
                      final query = _search.text.trim().toLowerCase();
                      final visibleReports = reports.where((report) {
                        final matchesStatus = switch (_filter) {
                          'In progress' => const {
                            'PENDING',
                            'PROCESSING',
                            'ASSIGNED',
                          }.contains(report.status.toUpperCase()),
                          'Resolved' => report.status.toUpperCase() == 'RESOLVED',
                          'Closed' => report.status.toUpperCase() == 'CANCELLED',
                          _ => true,
                        };
                        final matchesQuery = query.isEmpty ||
                            (report.title?.toLowerCase().contains(query) ?? false) ||
                            report.description.toLowerCase().contains(query) ||
                            (report.address?.toLowerCase().contains(query) ?? false) ||
                            report.category.toLowerCase().contains(query);
                        return matchesStatus && matchesQuery;
                      }).toList();

                      return RefreshIndicator(
                        color: CivicColors.forest,
                        onRefresh: _refresh,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            wide ? 32 : 16,
                            16,
                            wide ? 32 : 16,
                            80,
                          ),
                          itemCount: visibleReports.isEmpty ? 4 : visibleReports.length + 3,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _ReportsHero(
                                total: reports.length,
                                active: activeCount,
                                resolved: resolvedCount,
                                onCreateReport: widget.onCreateReport,
                              );
                            }
                            if (index == 1) {
                              return _ReportFilters(
                                selected: _filter,
                                onSelected: (value) => setState(() => _filter = value),
                              );
                            }
                            if (index == 2) {
                              return TextField(
                                controller: _search,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Search your reports by title, category, address...',
                                  hintStyle: const TextStyle(
                                    fontSize: 13,
                                    color: CivicColors.subdued,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: CivicColors.slateGreen,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8E4),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8E4),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: CivicColors.forest,
                                      width: 1.5,
                                    ),
                                  ),
                                  suffixIcon: _search.text.isEmpty
                                      ? null
                                      : IconButton(
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: CivicColors.slateGreen,
                                          ),
                                          onPressed: () {
                                            _search.clear();
                                            setState(() {});
                                          },
                                        ),
                                ),
                              );
                            }
                            if (visibleReports.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 36),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: CivicColors.mintTint,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                          Icons.filter_list_off_rounded,
                                          color: CivicColors.forest,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No reports match your search or filter.',
                                        style: TextStyle(
                                          color: CivicColors.charcoal,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Try clearing your search query or selecting "All".',
                                        style: TextStyle(
                                          color: CivicColors.slateGreen,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            final report = visibleReports[index - 3];
                            return _ReportCard(
                              report: report,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ResidentReportDetailScreen(
                                      reportId: report.id,
                                    ),
                                  ),
                                );
                                if (mounted) _refresh();
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReportsHero extends StatelessWidget {
  final int total;
  final int active;
  final int resolved;
  final VoidCallback? onCreateReport;

  const _ReportsHero({
    required this.total,
    required this.active,
    required this.resolved,
    this.onCreateReport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Bar with Action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Reports',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: CivicColors.forest,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Track community issues filed with municipal councils',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: CivicColors.slateGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onCreateReport != null) ...[
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onCreateReport,
                style: FilledButton.styleFrom(
                  backgroundColor: CivicColors.forest,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'New Report',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // 2x2 Metric Grid
        Row(
          children: [
            Expanded(
              child: _buildHeroStatTile(
                title: 'Total Reports',
                value: '$total',
                subtitle: 'Submitted issues',
                icon: Icons.assignment_outlined,
                iconBg: CivicColors.mintTint,
                iconColor: CivicColors.forest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHeroStatTile(
                title: 'Active / Dispatched',
                value: '$active',
                subtitle: 'Crew responding',
                icon: Icons.pending_actions_outlined,
                iconBg: const Color(0xFFFFF7ED),
                iconColor: const Color(0xFFC2410C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildHeroStatTile(
                title: 'Resolved Issues',
                value: '$resolved',
                subtitle: 'Verified complete',
                icon: Icons.check_circle_outline_rounded,
                iconBg: const Color(0xFFF0FDF4),
                iconColor: const Color(0xFF166534),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHeroStatTile(
                title: 'Resolution Rate',
                value: total > 0 ? '${((resolved / total) * 100).round()}%' : '100%',
                subtitle: 'Community impact',
                icon: Icons.auto_graph_rounded,
                iconBg: CivicColors.mintTint,
                iconColor: CivicColors.forest,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroStatTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return CivicSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: CivicColors.charcoal,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: CivicColors.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: CivicColors.slateGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ResidentReport report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = _ReportStatus.from(report.status);
    return CivicSurfaceCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: report.photos.isNotEmpty && report.photos.first.url.isNotEmpty
                ? Image.network(
                    report.photos.first.url,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _ReportThumbnail(
                      category: report.category,
                      status: status,
                    ),
                  )
                : _ReportThumbnail(
                    category: report.category,
                    status: status,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: CivicColors.mintTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _categoryLabel(report.category).toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: CivicColors.forest,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(status: status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  report.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: CivicColors.charcoal,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _Meta(
                      icon: Icons.calendar_today_outlined,
                      text: DateFormat.yMMMd().format(report.createdAt),
                    ),
                    _Meta(
                      icon: Icons.tag_rounded,
                      text: _shortId(report.id),
                    ),
                    if (report.address?.isNotEmpty == true)
                      _Meta(
                        icon: Icons.location_on_outlined,
                        text: report.address!,
                      ),
                    if (report.photos.isNotEmpty)
                      _Meta(
                        icon: Icons.photo_outlined,
                        text: '${report.photos.length} photo${report.photos.length == 1 ? '' : 's'}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            color: CivicColors.subdued,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: CivicColors.slateGreen),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: CivicColors.slateGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _ReportStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: status.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 11, color: status.foreground),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: status.foreground,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportStatus {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;

  const _ReportStatus({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
  });

  factory _ReportStatus.from(String value) {
    switch (value.toUpperCase()) {
      case 'RESOLVED':
        return const _ReportStatus(
          label: 'Resolved',
          icon: Icons.check_circle_rounded,
          background: CivicColors.badgeResolvedBg,
          foreground: CivicColors.badgeResolvedText,
          border: CivicColors.badgeResolvedBorder,
        );
      case 'ASSIGNED':
        return const _ReportStatus(
          label: 'Dispatched',
          icon: Icons.engineering_rounded,
          background: CivicColors.badgeAssignedBg,
          foreground: CivicColors.badgeAssignedText,
          border: CivicColors.badgeAssignedBorder,
        );
      case 'CANCELLED':
        return const _ReportStatus(
          label: 'Closed',
          icon: Icons.cancel_rounded,
          background: CivicColors.badgeCriticalBg,
          foreground: CivicColors.badgeCriticalText,
          border: CivicColors.badgeCriticalBorder,
        );
      case 'PROCESSING':
        return const _ReportStatus(
          label: 'In Review',
          icon: Icons.hourglass_top_rounded,
          background: CivicColors.badgeProcessingBg,
          foreground: CivicColors.badgeProcessingText,
          border: CivicColors.badgeProcessingBorder,
        );
      default:
        return const _ReportStatus(
          label: 'Received',
          icon: Icons.inbox_rounded,
          background: CivicColors.badgeMediumBg,
          foreground: CivicColors.badgeMediumText,
          border: CivicColors.badgeMediumBorder,
        );
    }
  }
}

class _ReportsMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onCreateReport;
  final Future<void> Function() onRefresh;
  final String refreshLabel;

  const _ReportsMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.onCreateReport,
    required this.onRefresh,
    this.refreshLabel = 'Refresh',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CivicSurfaceCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: CivicColors.mintTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 28, color: CivicColors.forest),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: CivicColors.charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: CivicColors.slateGreen,
                  ),
                ),
                const SizedBox(height: 20),
                if (onCreateReport != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: onCreateReport,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Report an Issue',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: CivicColors.forest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: onRefresh,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDDE2DE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      refreshLabel,
                      style: const TextStyle(
                        color: CivicColors.charcoal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportThumbnail extends StatelessWidget {
  final String category;
  final _ReportStatus status;

  const _ReportThumbnail({required this.category, required this.status});

  IconData _iconForCategory(String cat) {
    switch (cat.toUpperCase()) {
      case 'ROAD':
        return Icons.construction_outlined;
      case 'DRAINAGE':
        return Icons.water_drop_outlined;
      case 'WASTE':
        return Icons.delete_sweep_outlined;
      case 'ELECTRICAL':
        return Icons.electric_bolt_outlined;
      case 'ENVIRONMENT':
        return Icons.park_outlined;
      default:
        return Icons.report_problem_outlined;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: CivicColors.mintTint,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(
          _iconForCategory(category),
          color: CivicColors.forest,
          size: 30,
        ),
      );
}

class _ReportFilters extends StatelessWidget {
  const _ReportFilters({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final label in const [
              'All',
              'In progress',
              'Resolved',
              'Closed',
            ]) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: selected == label ? FontWeight.w800 : FontWeight.w600,
                    color: selected == label ? CivicColors.forest : CivicColors.charcoal,
                  ),
                  selected: selected == label,
                  onSelected: (_) => onSelected(label),
                  selectedColor: CivicColors.mintTint,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected == label
                        ? CivicColors.forest
                        : const Color(0xFFE2E8E4),
                    width: selected == label ? 1.4 : 1.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

String _shortId(String id) =>
    id.length >= 8 ? '#${id.substring(0, 4).toUpperCase()}' : '#$id';

String _categoryLabel(String value) => switch (value.toUpperCase()) {
      'ROAD' => 'Road Hazard',
      'DRAINAGE' => 'Drainage Issue',
      'WASTE' => 'Waste Sanitation',
      'ELECTRICAL' => 'Electrical Grid',
      'ENVIRONMENT' => 'Environment',
      _ => value,
    };
