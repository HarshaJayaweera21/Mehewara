import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/report_model.dart';
import '../../../services/reports/report_service.dart';
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
    setState(() => _reports = _service.getMyReports());
    await _reports;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CivicColors.alabaster,
      body: SafeArea(
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
                        detail: 'When you report an issue, its progress will appear here.',
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
                      final matchesQuery =
                          query.isEmpty ||
                          (report.title?.toLowerCase().contains(query) ?? false) ||
                          report.description.toLowerCase().contains(query) ||
                          (report.address?.toLowerCase().contains(query) ??
                              false) ||
                          report.category.toLowerCase().contains(query);
                      return matchesStatus && matchesQuery;
                    }).toList();
                    return RefreshIndicator(
                      color: CivicColors.forest,
                      onRefresh: _refresh,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 32 : 16,
                          20,
                          wide ? 32 : 16,
                          32,
                        ),
                        itemCount: visibleReports.isEmpty
                            ? 4
                            : visibleReports.length + 3,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _ReportsHero(
                              total: reports.length,
                              active: activeCount,
                              resolved: resolvedCount,
                            );
                          }
                          if (index == 1) {
                            return _ReportFilters(
                              selected: _filter,
                              onSelected: (value) =>
                                  setState(() => _filter = value),
                            );
                          }
                          if (index == 2) {
                            return TextField(
                              controller: _search,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search your reports',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () {
                                          _search.clear();
                                          setState(() {});
                                        },
                                      ),
                              ),
                            );
                          }
                          if (visibleReports.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 28),
                              child: Center(
                                child: Text(
                                  'No reports match these filters.',
                                  style: TextStyle(
                                    color: CivicColors.slateGreen,
                                  ),
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
    );
  }
}

class _ReportsHero extends StatelessWidget {
  final int total;
  final int active;
  final int resolved;

  const _ReportsHero({
    required this.total,
    required this.active,
    required this.resolved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CivicColors.forest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [CivicShadows.card],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My reports',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Count(label: 'Active', value: active),
                    const SizedBox(width: 18),
                    _Count(label: 'Resolved', value: resolved),
                    const SizedBox(width: 18),
                    _Count(label: 'Total', value: total),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.folder_shared_outlined,
            size: 34,
            color: CivicColors.mintPip,
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    report.photos.isNotEmpty &&
                        report.photos.first.url.isNotEmpty
                    ? Image.network(
                        report.photos.first.url,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _ReportThumbnail(status: status),
                      )
                    : _ReportThumbnail(status: status),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _categoryLabel(report.category),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .5,
                              color: CivicColors.slateGreen,
                            ),
                          ),
                        ),
                        _StatusChip(status: status),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      report.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: CivicColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _Meta(
                          icon: Icons.calendar_today_outlined,
                          text: DateFormat.yMMMd().format(report.createdAt),
                        ),
                        _Meta(
                          icon: Icons.confirmation_number_outlined,
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
                            text:
                                '${report.photos.length} photo${report.photos.length == 1 ? '' : 's'}',
                          ),
                        if (report.linkedProblemCount > 0)
                          _Meta(
                            icon: Icons.account_tree_outlined,
                            text: 'Linked to a problem',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: CivicColors.subdued),
            ],
          ),
        ),
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
        Icon(icon, size: 14, color: CivicColors.slateGreen),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: CivicColors.slateGreen),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.border),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: status.foreground,
        ),
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
    switch (value) {
      case 'RESOLVED':
        return const _ReportStatus(
          label: 'Resolved',
          icon: Icons.check_circle_outline,
          background: CivicColors.badgeResolvedBg,
          foreground: CivicColors.badgeResolvedText,
          border: CivicColors.badgeResolvedBorder,
        );
      case 'ASSIGNED':
        return const _ReportStatus(
          label: 'Assigned',
          icon: Icons.engineering_outlined,
          background: CivicColors.badgeAssignedBg,
          foreground: CivicColors.badgeAssignedText,
          border: CivicColors.badgeAssignedBorder,
        );
      case 'CANCELLED':
        return const _ReportStatus(
          label: 'Cancelled',
          icon: Icons.cancel_outlined,
          background: CivicColors.badgeCriticalBg,
          foreground: CivicColors.badgeCriticalText,
          border: CivicColors.badgeCriticalBorder,
        );
      case 'PROCESSING':
        return const _ReportStatus(
          label: 'Reviewing',
          icon: Icons.hourglass_top_rounded,
          background: CivicColors.badgeProcessingBg,
          foreground: CivicColors.badgeProcessingText,
          border: CivicColors.badgeProcessingBorder,
        );
      default:
        return const _ReportStatus(
          label: 'Received',
          icon: Icons.mark_email_unread_outlined,
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
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: CivicColors.forest),
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
                  height: 1.4,
                  color: CivicColors.slateGreen,
                ),
              ),
              const SizedBox(height: 18),
              if (onCreateReport != null) ...[
                FilledButton.icon(
                  onPressed: onCreateReport,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Report an issue'),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton(
                onPressed: onRefresh,
                child: Text(refreshLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportThumbnail extends StatelessWidget {
  const _ReportThumbnail({required this.status});
  final _ReportStatus status;

  @override
  Widget build(BuildContext context) => Container(
    width: 68,
    height: 68,
    color: status.background,
    alignment: Alignment.center,
    child: Icon(status.icon, color: status.foreground, size: 28),
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
              selected: selected == label,
              onSelected: (_) => onSelected(label),
              selectedColor: CivicColors.mintTint,
            ),
          ),
        ],
      ],
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(
        label,
        style: const TextStyle(color: Color(0xFFD9EEE5), fontSize: 11),
      ),
    ],
  );
}

String _shortId(String id) =>
    id.length >= 8 ? '#${id.substring(0, 4).toUpperCase()}' : '#$id';

String _categoryLabel(String value) => switch (value.toUpperCase()) {
  'ROAD' => 'Road',
  'DRAINAGE' => 'Drainage',
  'WASTE' => 'Waste',
  'ELECTRICAL' => 'Electrical',
  'ENVIRONMENT' => 'Environment',
  _ => value,
};
