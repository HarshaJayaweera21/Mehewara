import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/common/civic_bottom_nav_bar.dart';
import 'problems/problem_explorer_screen.dart';
import 'profile/resident_profile_screen.dart';
import 'report_issue/report_issue_screen.dart';
import 'reports/my_reports_screen.dart';

class ResidentShellScreen extends StatefulWidget {
  const ResidentShellScreen({super.key});

  @override
  State<ResidentShellScreen> createState() => _ResidentShellScreenState();
}

class _ResidentShellScreenState extends State<ResidentShellScreen> {
  int _index = 0;

  void _select(CivicNavTab tab) {
    setState(() => _index = CivicNavTab.values.indexOf(tab));
  }

  List<Widget> get _pages => [
        const ProblemExplorerScreen(embedded: true),
        ReportIssueScreen(onReportCreated: () => _select(CivicNavTab.myReports)),
        MyReportsScreen(onCreateReport: () => _select(CivicNavTab.reportIssue)),
        const ResidentProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 760;
        return Scaffold(
          backgroundColor: CivicColors.alabaster,
          body: Row(
            children: [
              if (useRail) _ResidentRail(selectedIndex: _index, onSelected: _select),
              Expanded(child: IndexedStack(index: _index, children: _pages)),
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : CivicBottomNavBar(
                  currentTab: CivicNavTab.values[_index],
                  onTabSelected: _select,
                ),
        );
      },
    );
  }
}

class _ResidentRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<CivicNavTab> onSelected;

  const _ResidentRail({required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const labels = ['Incidents', 'Report issue', 'My reports', 'Profile'];
    const icons = [
      Icons.map_outlined,
      Icons.add_location_alt_outlined,
      Icons.description_outlined,
      Icons.person_outline_rounded,
    ];

    return Container(
      width: 228,
      decoration: const BoxDecoration(
        color: CivicColors.cardSurface,
        border: Border(right: BorderSide(color: CivicColors.borderSubtle)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('මෙහෙවර', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: CivicColors.forest)),
                    SizedBox(height: 2),
                    Text('Community portal', style: TextStyle(fontSize: 12, color: CivicColors.slateGreen)),
                  ],
                ),
              ),
              for (var i = 0; i < labels.length; i++)
                _RailItem(
                  icon: icons[i],
                  label: labels[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(CivicNavTab.values[i]),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: CivicColors.mintTint, borderRadius: BorderRadius.circular(12)),
                child: const Text(
                  'Your reports help keep the community moving.',
                  style: TextStyle(fontSize: 12, height: 1.35, color: CivicColors.forest),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? CivicColors.mintTint : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? CivicColors.forest : CivicColors.slateGreen),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? CivicColors.forest : CivicColors.charcoal)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

