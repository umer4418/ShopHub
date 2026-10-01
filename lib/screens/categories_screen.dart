import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/product_controller.dart';
import '../core/widgets/category_card.dart';
import '../models/category.dart';
import '../theme/colors.dart';
import '../utils/responsive.dart';

/// Available sorting options for categories
enum CategorySortOption {
  defaultOrder('Default'),
  nameAsc('Name (A–Z)'),
  nameDesc('Name (Z–A)'),
  mostItems('Most Items');

  final String label;
  const CategorySortOption(this.label);
}

/// Categories Screen
/// Displays a responsive, searchable, and filterable grid of store categories.
/// The top search bar and filter button are fixed, and category cards maintain
/// fixed, stable icon and text alignment during scrolling.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _searchQuery = '';
  CategorySortOption _sortOption = CategorySortOption.defaultOrder;
  bool _onlyWithItems = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final text = _searchCtrl.text;
      if (text != _searchQuery) {
        setState(() {
          _searchQuery = text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  void _resetAllFilters() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _sortOption = CategorySortOption.defaultOrder;
      _onlyWithItems = false;
    });
  }

  bool get _hasActiveFilters =>
      _sortOption != CategorySortOption.defaultOrder || _onlyWithItems;

  void _openFilterSheet(BuildContext context, ProductController productCtrl) {
    var tempSort = _sortOption;
    var tempOnlyWithItems = _onlyWithItems;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  20 + MediaQuery.paddingOf(ctx).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sheet Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter & Sort Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ShopColors.text,
                          ),
                        ),
                        if (tempSort != CategorySortOption.defaultOrder ||
                            tempOnlyWithItems)
                          TextButton(
                            onPressed: () {
                              setModal(() {
                                tempSort = CategorySortOption.defaultOrder;
                                tempOnlyWithItems = false;
                              });
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(color: ShopColors.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sort By Section
                    const Text(
                      'Sort Order',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ShopColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CategorySortOption.values.map((opt) {
                        final isSelected = tempSort == opt;
                        return ChoiceChip(
                          label: Text(opt.label),
                          selected: isSelected,
                          selectedColor: ShopColors.primarySoft,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? ShopColors.primaryDark
                                : ShopColors.text,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? ShopColors.primary
                                : ShopColors.border,
                          ),
                          onSelected: (_) => setModal(() => tempSort = opt),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Availability Filter Section
                    const Text(
                      'Category Availability',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ShopColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All Categories'),
                          selected: !tempOnlyWithItems,
                          selectedColor: ShopColors.primarySoft,
                          labelStyle: TextStyle(
                            color: !tempOnlyWithItems
                                ? ShopColors.primaryDark
                                : ShopColors.text,
                            fontWeight: !tempOnlyWithItems
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: !tempOnlyWithItems
                                ? ShopColors.primary
                                : ShopColors.border,
                          ),
                          onSelected: (_) =>
                              setModal(() => tempOnlyWithItems = false),
                        ),
                        ChoiceChip(
                          label: const Text('With Products Only'),
                          selected: tempOnlyWithItems,
                          selectedColor: ShopColors.primarySoft,
                          labelStyle: TextStyle(
                            color: tempOnlyWithItems
                                ? ShopColors.primaryDark
                                : ShopColors.text,
                            fontWeight: tempOnlyWithItems
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: tempOnlyWithItems
                                ? ShopColors.primary
                                : ShopColors.border,
                          ),
                          onSelected: (_) =>
                              setModal(() => tempOnlyWithItems = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Apply Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ShopColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _sortOption = tempSort;
                            _onlyWithItems = tempOnlyWithItems;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<ShopCategory> _filterAndSortCategories(
    List<ShopCategory> source,
    ProductController productCtrl,
  ) {
    var result = List<ShopCategory>.from(source);

    // 1. Search Query Filter
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result
          .where((cat) => cat.name.toLowerCase().contains(query))
          .toList();
    }

    // 2. Only Categories with Products Filter
    if (_onlyWithItems) {
      result = result.where((cat) {
        final count =
            productCtrl.products.where((p) => p.categoryId == cat.id).length;
        return count > 0;
      }).toList();
    }

    // 3. Sorting
    switch (_sortOption) {
      case CategorySortOption.nameAsc:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case CategorySortOption.nameDesc:
        result.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case CategorySortOption.mostItems:
        result.sort((a, b) {
          final countA =
              productCtrl.products.where((p) => p.categoryId == a.id).length;
          final countB =
              productCtrl.products.where((p) => p.categoryId == b.id).length;
          return countB.compareTo(countA);
        });
        break;
      case CategorySortOption.defaultOrder:
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final productCtrl = Get.find<ProductController>();
    final isSmall = Responsive.isSmallMobile(context);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: ShopColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ==============================================================
          // FIXED TOP BAR: SEARCH BAR & FILTER BUTTON
          // Stays permanently pinned at the top when scrolling down
          // ==============================================================
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 10 : 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: ShopColors.border.withValues(alpha: 0.8)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: Container(
                        height: isSmall ? 42 : 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _searchFocus.hasFocus
                                ? ShopColors.primary
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: ShopColors.muted,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                focusNode: _searchFocus,
                                textInputAction: TextInputAction.search,
                                style: TextStyle(
                                  fontSize: isSmall ? 13 : 14,
                                  color: ShopColors.text,
                                ),
                                decoration: InputDecoration(
                                  hintText: isSmall
                                      ? 'Search...'
                                      : 'Search categories...',
                                  hintStyle: TextStyle(
                                    fontSize: isSmall ? 12.5 : 13.5,
                                    color: ShopColors.muted,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: _clearSearch,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE5E7EB),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Filter Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openFilterSheet(context, productCtrl),
                        child: Container(
                          height: isSmall ? 42 : 46,
                          width: isSmall ? 42 : 46,
                          decoration: BoxDecoration(
                            color: _hasActiveFilters
                                ? ShopColors.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _hasActiveFilters
                                  ? ShopColors.primary
                                  : ShopColors.border,
                              width: 1.2,
                            ),
                            boxShadow: _hasActiveFilters
                                ? [
                                    BoxShadow(
                                      color: ShopColors.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: isSmall ? 19 : 21,
                                  color: _hasActiveFilters
                                      ? Colors.white
                                      : ShopColors.text,
                                ),
                                if (_hasActiveFilters)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Active Filter / Search Query Summary Row
                Obx(() {
                  final filtered = _filterAndSortCategories(
                    productCtrl.categories,
                    productCtrl,
                  );
                  final isFiltered =
                      _searchQuery.isNotEmpty || _hasActiveFilters;

                  if (!isFiltered) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8, left: 2, right: 2),
                      child: Text(
                        '${productCtrl.categories.length} Categories',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: ShopColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? '${filtered.length} found for "$_searchQuery"'
                                : '${filtered.length} Categories (${_sortOption.label})',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: ShopColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: _resetAllFilters,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              'Reset All',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: ShopColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // ==============================================================
          // SCROLLABLE CATEGORY GRID
          // Cards have fixed internal layout so icons and text never move
          // ==============================================================
          Expanded(
            child: Obx(() {
              final displayedCategories = _filterAndSortCategories(
                productCtrl.categories,
                productCtrl,
              );

              // Empty state if search or filter yielded 0 results
              if (displayedCategories.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: ShopColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search_off_rounded,
                            size: 36,
                            color: ShopColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No categories found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ShopColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No category matches "$_searchQuery".'
                              : 'No categories match the active filter.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ShopColors.muted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ShopColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _resetAllFilters,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text(
                            'Reset Search & Filters',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: Responsive.screenPadding(
                  context,
                  horizontal: isSmall ? 10 : 16,
                  vertical: 14,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: Responsive.gridColumns(
                    context,
                    minItemWidth: isSmall ? 135 : 150,
                  ),
                  mainAxisSpacing: isSmall ? 10 : 12,
                  crossAxisSpacing: isSmall ? 10 : 12,
                  childAspectRatio: Responsive.value<double>(
                    context,
                    smallMobile: 0.98,
                    mobile: isMobile ? 1.05 : 1.1,
                    tablet: 1.15,
                    desktop: 1.2,
                  ),
                ),
                itemCount: displayedCategories.length,
                itemBuilder: (_, i) {
                  final cat = displayedCategories[i];
                  final itemCount = productCtrl.products
                      .where((p) => p.categoryId == cat.id)
                      .length;

                  return CategoryCard(
                    category: cat,
                    itemCount: itemCount,
                    onTap: () {
                      productCtrl.setFilters(categoryId: cat.id);
                      Navigator.pushNamed(context, AppRoutes.products);
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
