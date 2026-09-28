import 'package:flutter/material.dart';
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

  static const List<Map<String, String>> categories = [
    {'key': 'ALL', 'label': 'All', 'icon': ''},
    {'key': 'DRAINAGE', 'label': 'Drainage', 'icon': '💧'},
    {'key': 'ROAD', 'label': 'Road', 'icon': '🚧'},
    {'key': 'WASTE', 'label': 'Waste', 'icon': '🗑️'},
    {'key': 'ELECTRICAL', 'label': 'Electrical', 'icon': '⚡'},
    {'key': 'ENVIRONMENT', 'label': 'Environment', 'icon': '🌿'},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat['key'] == selectedCategory;
          final isAll = cat['key'] == 'ALL';

          return GestureDetector(
            onTap: () => onSelectCategory(cat['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(
                horizontal: isAll ? 14 : 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected ? CivicColors.forest : CivicColors.cardSurface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isSelected ? CivicColors.forest : CivicColors.borderSubtle,
                  width: 1,
                ),
                boxShadow: const [CivicShadows.subtle],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cat['icon']!.isNotEmpty) ...[
                    Text(
                      cat['icon']!,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    cat['label']!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : CivicColors.charcoal,
                    ),
                  ),
                  if (isAll) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.22)
                            : CivicColors.segmentBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : CivicColors.slateGreen,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
