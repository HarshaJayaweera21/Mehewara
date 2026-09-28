import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum CivicNavTab {
  incidents,
  reportIssue,
  myReports,
  profile,
}

/// Reusable civic bottom navigation bar matching Stitch Mehewara specifications.
/// Easily pluggable across resident screens so team members can link their screens.
class CivicBottomNavBar extends StatelessWidget {
  final CivicNavTab currentTab;
  final ValueChanged<CivicNavTab>? onTabSelected;
  final VoidCallback? onReportIssuePressed;

  const CivicBottomNavBar({
    super.key,
    this.currentTab = CivicNavTab.incidents,
    this.onTabSelected,
    this.onReportIssuePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: CivicColors.cardSurface,
        border: Border(
          top: BorderSide(color: CivicColors.navBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Tab 1: Incidents
          _buildNavItem(
            icon: Icons.map_rounded,
            label: 'Incidents',
            isActive: currentTab == CivicNavTab.incidents,
            onTap: () => onTabSelected?.call(CivicNavTab.incidents),
          ),

          // Tab 2: Report Issue (Center Primary Action Icon)
          _buildCenterActionItem(
            label: 'Report Issue',
            onTap: () {
              onReportIssuePressed?.call();
              onTabSelected?.call(CivicNavTab.reportIssue);
            },
          ),

          // Tab 3: My Reports
          _buildNavItem(
            icon: Icons.description_outlined,
            label: 'My Reports',
            isActive: currentTab == CivicNavTab.myReports,
            onTap: () => onTabSelected?.call(CivicNavTab.myReports),
          ),

          // Tab 4: Profile
          _buildNavItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            isActive: currentTab == CivicNavTab.profile,
            onTap: () => onTabSelected?.call(CivicNavTab.profile),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? CivicColors.forest : CivicColors.subdued,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? CivicColors.forest : CivicColors.subdued,
              ),
            ),
            if (isActive)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: CivicColors.forest,
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterActionItem({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: CivicColors.mintTint,
                shape: BoxShape.circle,
                border: Border.all(
                  color: CivicColors.mintPip.withValues(alpha: 0.4),
                  width: 1,
                ),
                boxShadow: const [CivicShadows.subtle],
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 20,
                color: CivicColors.forest,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: CivicColors.forest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
