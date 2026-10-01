import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../theme/colors.dart';

/// Category Card Widget
class CategoryCard extends StatelessWidget {
  final ShopCategory category;
  final VoidCallback onTap;
  final int? itemCount;

  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
    this.itemCount,
  });

  static IconData iconForCategory(String name) {
    return switch (name.toLowerCase()) {
      'devices' || 'electronics' => Icons.devices_other,
      'checkroom' || 'fashion' || 'clothing' => Icons.checkroom,
      'chair' || 'furniture' || 'home' => Icons.chair_outlined,
      'spa' || 'beauty' => Icons.spa_outlined,
      'sports_soccer' || 'sports' => Icons.sports_soccer,
      'shopping_basket' || 'groceries' || 'grocery' => Icons.shopping_basket_outlined,
      'child_care' || 'toys' || 'kids' => Icons.child_care,
      'smartphone' || 'mobile' || 'phones' => Icons.smartphone,
      'watch' || 'watches' => Icons.watch_outlined,
      'shoe' || 'shoes' || 'footwear' => Icons.skateboarding,
      'book' || 'books' => Icons.menu_book_outlined,
      _ => Icons.category_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ShopColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Fixed-dimension Icon Box (never moves or shifts)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ShopColors.primarySoft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ShopColors.primary.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      iconForCategory(category.icon),
                      color: ShopColors.primary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Fixed-position Category Name
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: ShopColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
                if (itemCount != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    itemCount == 1 ? '1 item' : '$itemCount items',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: ShopColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
