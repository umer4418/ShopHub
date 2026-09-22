import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/product_controller.dart';
import '../core/widgets/category_card.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final productCtrl = Get.find<ProductController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: Obx(
        () => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: productCtrl.categories.length,
          itemBuilder: (_, i) {
            final c = productCtrl.categories[i];
            return CategoryCard(
              category: c,
              onTap: () {
                productCtrl.setFilters(categoryId: c.id);
                Navigator.pushNamed(context, AppRoutes.products);
              },
            );
          },
        ),
      ),
    );
  }
}
