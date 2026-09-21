import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../theme/colors.dart';

/// Category Card Widget
class CategoryCard extends StatelessWidget {
  final ShopCategory category;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  static IconData iconForCategory(String name) {
    return switch (name) {
      'devices' => Icons.devices_other,
      'checkroom' => Icons.checkroom,
      'chair' => Icons.chair_outlined,
      'spa' => Icons.spa_outlined,
      'sports_soccer' => Icons.sports_soccer,
      'shopping_basket' => Icons.shopping_basket_outlined,
      'child_care' => Icons.child_care,
      'smartphone' => Icons.smartphone,
      _ => Icons.category_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ShopColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: ShopColors.primarySoft,
              child: Icon(iconForCategory(category.icon), color: ShopColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
