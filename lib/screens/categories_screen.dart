import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/product_controller.dart';
import '../core/widgets/category_card.dart';
import '../utils/responsive.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final productCtrl = Get.find<ProductController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: Obx(
        () => GridView.builder(
          padding: Responsive.screenPadding(context, horizontal: 16, vertical: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Responsive.gridColumns(context, minItemWidth: 150),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: Responsive.value<double>(
              context,
              smallMobile: 1.25,
              mobile: 1.35,
              tablet: 1.45,
              desktop: 1.5,
            ),
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
