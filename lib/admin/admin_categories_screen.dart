import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes/app_routes.dart';
import '../controllers/product_controller.dart';
import '../models/category.dart';

class AdminCategoriesScreen extends StatelessWidget {
  const AdminCategoriesScreen({super.key});

  static const route = AppRoutes.adminCategories;

  @override
  Widget build(BuildContext context) {
    final productCtrl = context.watch<ProductController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Manage categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, productCtrl, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: productCtrl.categories
            .map(
              (c) => ListTile(
                title: Text(c.name),
                subtitle: Text(c.id),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _edit(context, productCtrl, c),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () => productCtrl.deleteCategory(c.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    ProductController productCtrl,
    ShopCategory? existing,
  ) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final id = TextEditingController(text: existing?.id ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add category' : 'Edit category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: id,
              enabled: existing == null,
              decoration: const InputDecoration(labelText: 'ID'),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final cat = ShopCategory(
                id: id.text.trim(),
                name: name.text.trim(),
                icon: existing?.icon ?? 'category',
                imageUrl: existing?.imageUrl ?? '',
              );
              if (existing == null) {
                productCtrl.addCategory(cat);
              } else {
                productCtrl.updateCategory(cat);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
