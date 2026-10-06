import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

enum CivicNavTab {
  myReports,
  reportIssue,
  incidents,
  profile,
}

/// Data model for a single tab in a [CivicBottomNavBar.custom] bar.
class CivicNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const CivicNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Modern civic bottom navigation bar matching Mehewara municipal aesthetic.
class CivicBottomNavBar extends StatelessWidget {
  final CivicNavTab currentTab;
  final ValueChanged<CivicNavTab>? onTabSelected;
  final VoidCallback? onReportIssuePressed;

  final List<CivicNavItem>? _items;
  final int? _currentIndex;
  final ValueChanged<int>? _onSelected;

  const CivicBottomNavBar({
    super.key,
    this.currentTab = CivicNavTab.myReports,
    this.onTabSelected,
    this.onReportIssuePressed,
  })  : _items = null,
        _currentIndex = null,
        _onSelected = null;

  const CivicBottomNavBar.custom({
    super.key,
    required int currentIndex,
    required ValueChanged<int> onSelected,
    required List<CivicNavItem> items,
  })  : _items = items, // ignore: prefer_initializing_formals
        _currentIndex = currentIndex, // ignore: prefer_initializing_formals
        _onSelected = onSelected, // ignore: prefer_initializing_formals
        currentTab = CivicNavTab.myReports,
        onTabSelected = null,
        onReportIssuePressed = null;

  factory CivicBottomNavBar.crew({
    Key? key,
    required int currentIndex,
    required ValueChanged<int> onTabSelected,
  }) {
    return CivicBottomNavBar.custom(
      key: key,
      currentIndex: currentIndex,
      onSelected: onTabSelected,
      items: const [
        CivicNavItem(
          icon: Icons.radar_outlined,
          activeIcon: Icons.radar_rounded,
          label: 'Status & Depot',
        ),
        CivicNavItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          label: 'Mission Queue',
        ),
        CivicNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Squad Profile',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items ?? _defaultItems;

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
              for (var i = 0; i < items.length; i++)
                _buildNavItem(
                  icon: items[i].icon,
                  activeIcon: items[i].activeIcon,
                  label: items[i].label,
                  isActive: _isItemActive(i),
                  onTap: () => _handleTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<CivicNavItem> get _defaultItems => const [
        CivicNavItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          label: 'My Reports',
        ),
        CivicNavItem(
          icon: Icons.add_circle_outline_rounded,
          activeIcon: Icons.add_circle_rounded,
          label: 'Report Issue',
        ),
        CivicNavItem(
          icon: Icons.map_outlined,
          activeIcon: Icons.map_rounded,
          label: 'Incidents',
        ),
        CivicNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
        ),
      ];

  bool _isItemActive(int index) {
    if (_items != null) {
      return _currentIndex == index;
    }
    return currentTab.index == index;
  }

  void _handleTap(int index) {
    HapticFeedback.selectionClick();

    if (_items != null) {
      _onSelected?.call(index);
      return;
    }

    final tab = CivicNavTab.values[index];
    if (tab == CivicNavTab.reportIssue) {
      onReportIssuePressed?.call();
    }
    onTabSelected?.call(tab);
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
