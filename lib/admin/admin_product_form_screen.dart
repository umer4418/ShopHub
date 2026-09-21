import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes/app_routes.dart';
import '../controllers/product_controller.dart';
import '../core/consants/app_images.dart';
import '../models/product.dart';

class AdminProductFormScreen extends StatefulWidget {
  const AdminProductFormScreen({super.key});

  static const route = AppRoutes.adminProductForm;

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _image;
  late final TextEditingController _price;
  late final TextEditingController _original;
  late final TextEditingController _short;
  late final TextEditingController _desc;
  late final TextEditingController _stock;
  String? _categoryId;
  bool _featured = false;
  bool _popular = false;
  String? _editingId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nameInitialized) return;
    _nameInitialized = true;
    final productCtrl = context.read<ProductController>();
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    Product? existing;
    if (id != null) {
      try {
        existing = productCtrl.products.firstWhere((p) => p.id == id);
      } catch (_) {
        existing = null;
      }
    }
    _editingId = existing?.id;
    _name = TextEditingController(text: existing?.name ?? '');
    _image = TextEditingController(text: existing?.imageUrl ?? '');
    _price = TextEditingController(text: existing?.price.toString() ?? '');
    _original = TextEditingController(text: existing?.originalPrice.toString() ?? '');
    _short = TextEditingController(text: existing?.shortDescription ?? '');
    _desc = TextEditingController(text: existing?.description ?? '');
    _stock = TextEditingController(text: existing?.stock.toString() ?? '10');
    _categoryId = existing?.categoryId ?? productCtrl.categories.first.id;
    _featured = existing?.featured ?? false;
    _popular = existing?.popular ?? false;
  }

  bool _nameInitialized = false;

  @override
  void dispose() {
    _name.dispose();
    _image.dispose();
    _price.dispose();
    _original.dispose();
    _short.dispose();
    _desc.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productCtrl = context.watch<ProductController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId == null ? 'Add product' : 'Edit product'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Product name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              items: productCtrl.categories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _image,
              decoration: const InputDecoration(
                labelText:
                    'Image URL (or drop files in assets/images/products)',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
              validator: (v) =>
                  double.tryParse(v ?? '') == null ? 'Enter a number' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _original,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Original price (for discount)',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _short,
              decoration:
                  const InputDecoration(labelText: 'Short description'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _desc,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _stock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock'),
            ),
            SwitchListTile(
              title: const Text('Featured'),
              value: _featured,
              onChanged: (v) => setState(() => _featured = v),
            ),
            SwitchListTile(
              title: const Text('Popular'),
              value: _popular,
              onChanged: (v) => setState(() => _popular = v),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                final price = double.parse(_price.text);
                final original =
                    double.tryParse(_original.text) ?? price;
                final product = Product(
                  id: _editingId ?? 'p${DateTime.now().millisecondsSinceEpoch}',
                  name: _name.text.trim(),
                  categoryId: _categoryId ?? productCtrl.categories.first.id,
                  imageUrl: _image.text.trim().isEmpty
                      ? AppImages.placeholder
                      : _image.text.trim(),
                  price: price,
                  originalPrice: original,
                  rating: 4.5,
                  reviewCount: 0,
                  shortDescription: _short.text.trim(),
                  description: _desc.text.trim(),
                  stock: int.tryParse(_stock.text) ?? 0,
                  featured: _featured,
                  popular: _popular,
                );
                if (_editingId == null) {
                  productCtrl.addProduct(product);
                } else {
                  productCtrl.updateProduct(product);
                }
                Navigator.pop(context);
              },
              child:
                  Text(_editingId == null ? 'Save product' : 'Update product'),
            ),
          ],
        ),
      ),
    );
  }
}
