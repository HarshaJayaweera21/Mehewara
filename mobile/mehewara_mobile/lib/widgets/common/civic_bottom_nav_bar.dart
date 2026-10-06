import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

enum CivicNavTab {
  myReports,
  reportIssue,
  incidents,
  profile,
}

/// Modern civic bottom navigation bar matching Mehewara municipal aesthetic.
class CivicBottomNavBar extends StatelessWidget {
  final CivicNavTab currentTab;
  final ValueChanged<CivicNavTab>? onTabSelected;
  final VoidCallback? onReportIssuePressed;

  const CivicBottomNavBar({
    super.key,
    this.currentTab = CivicNavTab.myReports,
    this.onTabSelected,
    this.onReportIssuePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8E4), width: 1.1),
        ),
        boxShadow: [
          BoxShadow(
            color: CivicColors.forest.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Tab 1: My Reports
              _buildNavItem(
                icon: Icons.assignment_outlined,
                activeIcon: Icons.assignment_rounded,
                label: 'My Reports',
                isActive: currentTab == CivicNavTab.myReports,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTabSelected?.call(CivicNavTab.myReports);
                },
              ),

              // Tab 2: Report Issue (Standard uniform nav item)
              _buildNavItem(
                icon: Icons.add_circle_outline_rounded,
                activeIcon: Icons.add_circle_rounded,
                label: 'Report Issue',
                isActive: currentTab == CivicNavTab.reportIssue,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onReportIssuePressed?.call();
                  onTabSelected?.call(CivicNavTab.reportIssue);
                },
              ),

              // Tab 3: Incidents Map & Feed
              _buildNavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Incidents',
                isActive: currentTab == CivicNavTab.incidents,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTabSelected?.call(CivicNavTab.incidents);
                },
              ),

              // Tab 4: Profile
              _buildNavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isActive: currentTab == CivicNavTab.profile,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTabSelected?.call(CivicNavTab.profile);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isActive ? 16 : 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isActive ? CivicColors.mintTint : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                size: 22,
                color: isActive ? CivicColors.forest : CivicColors.subdued,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? CivicColors.forest : CivicColors.slateGreen,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
