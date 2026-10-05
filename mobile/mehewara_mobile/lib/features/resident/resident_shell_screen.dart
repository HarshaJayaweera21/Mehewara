import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/common/civic_bottom_nav_bar.dart';
import '../auth/auth_widgets.dart';
import 'problems/problem_explorer_screen.dart';
import 'profile/resident_profile_screen.dart';
import 'report_issue/report_issue_screen.dart';
import 'reports/my_reports_screen.dart';

class ResidentShellScreen extends StatefulWidget {
  final CivicNavTab initialTab;

  const ResidentShellScreen({
    super.key,
    this.initialTab = CivicNavTab.myReports,
  });

  @override
  State<ResidentShellScreen> createState() => _ResidentShellScreenState();
}

class _ResidentShellScreenState extends State<ResidentShellScreen> {
  late int _index;

  @override
  void initState() {
    super.initState();
    final tabIndex = CivicNavTab.values.indexOf(widget.initialTab);
    _index = tabIndex >= 0 ? tabIndex : CivicNavTab.values.indexOf(CivicNavTab.myReports);
  }

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
          backgroundColor: const Color(0xFFF4F7F4),
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
      Icons.assignment_outlined,
      Icons.person_outline_rounded,
    ];
    const activeIcons = [
      Icons.map_rounded,
      Icons.add_location_alt_rounded,
      Icons.assignment_rounded,
      Icons.person_rounded,
    ];

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8E4), width: 1.1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 12, 4, 24),
                child: AuthBrand(),
              ),
              for (var i = 0; i < labels.length; i++)
                _RailItem(
                  icon: icons[i],
                  activeIcon: activeIcons[i],
                  label: labels[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(CivicNavTab.values[i]),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEBF6F0), Color(0xFFF3FAF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: CivicColors.mintPip.withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: CivicColors.forest,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your reports keep the city safe and well-maintained.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: CivicColors.forest,
                        ),
                      ),
                    ),
                  ],
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
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? CivicColors.mintTint : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 20,
                  color: selected ? CivicColors.forest : CivicColors.slateGreen,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? CivicColors.forest : CivicColors.charcoal,
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
