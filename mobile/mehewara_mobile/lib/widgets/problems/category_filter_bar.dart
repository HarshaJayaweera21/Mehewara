import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class CategoryFilterBar extends StatelessWidget {
  final String selectedCategory;
  final int totalCount;
  final ValueChanged<String> onSelectCategory;

  const CategoryFilterBar({
    super.key,
    required this.selectedCategory,
    required this.totalCount,
    required this.onSelectCategory,
  });

  static const List<Map<String, dynamic>> categories = [
    {'key': 'ALL', 'label': 'All', 'icon': Icons.apps_rounded},
    {'key': 'DRAINAGE', 'label': 'Drainage', 'icon': Icons.water_drop_rounded},
    {'key': 'ROAD', 'label': 'Road', 'icon': Icons.construction_rounded},
    {'key': 'WASTE', 'label': 'Waste', 'icon': Icons.delete_outline_rounded},
    {'key': 'ELECTRICAL', 'label': 'Electrical', 'icon': Icons.bolt_rounded},
    {'key': 'ENVIRONMENT', 'label': 'Environment', 'icon': Icons.eco_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final key = cat['key'] as String;
          final label = cat['label'] as String;
          final icon = cat['icon'] as IconData;
          final isSelected = key == selectedCategory;
          final isAll = key == 'ALL';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelectCategory(key);
              },
              borderRadius: BorderRadius.circular(100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isAll ? 14 : 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? CivicColors.forest : CivicColors.cardSurface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? CivicColors.forest
                        : const Color(0xFFDCE4DF),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: CivicColors.forest.withValues(alpha: 0.22),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : const [CivicShadows.subtle],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 14.5,
                      color: isSelected ? CivicColors.mintPip : CivicColors.slateGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : CivicColors.charcoal,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (isAll) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CivicColors.mintPip
                              : CivicColors.segmentBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? CivicColors.forest : CivicColors.slateGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
