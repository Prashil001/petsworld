import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shop/components/network_image_with_loader.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/providers/admin_provider.dart';
import 'package:shop/providers/auth_provider.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/route/route_constants.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _stockFilterEnabled = false;
  int _maxStockValue = 0;
  String _selectedMajorCategory = 'all';
  String? _selectedSubCategory;
  final Set<String> _collapsedCategories = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Effective stock for a product — uses total pack stock if the product
  /// has pack options, otherwise the simple stockQuantity field.
  int _effectiveStock(ProductModel p) =>
      p.packOptions.isEmpty ? p.stockQuantity : p.totalPackStock;

  String _getMajorCategory(ProductModel p) {
    final cat =
        p.categoryName.trim().isEmpty ? 'Uncategorized' : p.categoryName.trim();
    if (cat.contains('>')) {
      return cat.split('>').first.trim();
    }
    return cat;
  }

  String _getSubCategory(ProductModel p) {
    final cat =
        p.categoryName.trim().isEmpty ? 'Uncategorized' : p.categoryName.trim();
    if (cat.contains('>')) {
      final parts = cat.split('>');
      if (parts.length > 1) {
        return parts.sublist(1).join('>').trim();
      }
    }
    return '';
  }

  String _getFullCategory(ProductModel p) {
    return p.categoryName.trim().isEmpty
        ? 'Uncategorized'
        : p.categoryName.trim();
  }

  List<ProductModel> _applyFilters(List<ProductModel> source) {
    var list = source;

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) {
        return p.title.toLowerCase().contains(q) ||
            p.brandName.toLowerCase().contains(q) ||
            p.categoryName.toLowerCase().contains(q);
      }).toList();
    }

    if (_stockFilterEnabled) {
      list = list.where((p) => _effectiveStock(p) <= _maxStockValue).toList();
    }

    if (_selectedMajorCategory != 'all') {
      list = list.where((p) {
        return _getMajorCategory(p).toLowerCase() ==
            _selectedMajorCategory.toLowerCase();
      }).toList();
    }

    if (_selectedSubCategory != null && _selectedSubCategory!.isNotEmpty) {
      list = list.where((p) {
        return _getSubCategory(p).toLowerCase() ==
            _selectedSubCategory!.toLowerCase();
      }).toList();
    }

    return list;
  }

  void _openFilterSheet() {
    bool tempEnabled = _stockFilterEnabled;
    final controller = TextEditingController(text: _maxStockValue.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: defaultPadding,
                right: defaultPadding,
                top: defaultPadding,
                bottom:
                    MediaQuery.of(sheetContext).viewInsets.bottom +
                    defaultPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  Text(
                    'Filter products',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: defaultPadding / 2),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Filter by low stock'),
                    subtitle: const Text(
                      'Show only products at or below the stock you set',
                    ),
                    value: tempEnabled,
                    activeThumbColor: primaryColor,
                    onChanged: (v) => setSheetState(() => tempEnabled = v),
                  ),
                  const SizedBox(height: defaultPadding / 2),
                  TextField(
                    controller: controller,
                    enabled: tempEnabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Max stock',
                      helperText: '0 = only out-of-stock products',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _stockFilterEnabled = false;
                              _maxStockValue = 0;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: defaultPadding),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final parsed =
                                int.tryParse(controller.text.trim()) ?? 0;
                            setState(() {
                              _stockFilterEnabled = tempEnabled;
                              _maxStockValue = parsed < 0 ? 0 : parsed;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final adminProvider = context.watch<AdminProvider>();

    if (authProvider.isAdmin &&
        adminProvider.products.isEmpty &&
        !adminProvider.isLoading) {
      Future.microtask(adminProvider.loadAdminData);
    }

    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage products')),
        body: const Center(
          child: Text('Admin access is required to manage products.'),
        ),
      );
    }

    final allProducts = adminProvider.products;
    final filtered = _applyFilters(allProducts);

    // Compute major category counts across allProducts
    final majorCategoryCounts = <String, int>{};
    for (final p in allProducts) {
      final major = _getMajorCategory(p);
      majorCategoryCounts[major] = (majorCategoryCounts[major] ?? 0) + 1;
    }
    final sortedMajorCategories = majorCategoryCounts.keys.toList()
      ..sort((a, b) {
        if (a == 'Uncategorized') return 1;
        if (b == 'Uncategorized') return -1;
        return a.compareTo(b);
      });

    // Compute subcategories if a major category is selected
    final subCategoryCounts = <String, int>{};
    if (_selectedMajorCategory != 'all') {
      for (final p in allProducts) {
        if (_getMajorCategory(p).toLowerCase() ==
            _selectedMajorCategory.toLowerCase()) {
          final sub = _getSubCategory(p);
          if (sub.isNotEmpty) {
            subCategoryCounts[sub] = (subCategoryCounts[sub] ?? 0) + 1;
          }
        }
      }
    }
    final sortedSubCategories = subCategoryCounts.keys.toList()..sort();

    // Group filtered products by their full category (e.g. Dogs > Toys)
    final categoryGroups = <String, List<ProductModel>>{};
    for (final p in filtered) {
      final cat = _getFullCategory(p);
      categoryGroups.putIfAbsent(cat, () => []).add(p);
    }
    final sortedGroupKeys = categoryGroups.keys.toList()
      ..sort((a, b) {
        if (a == 'Uncategorized') return 1;
        if (b == 'Uncategorized') return -1;
        return a.compareTo(b);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Manage products')),
      body: Column(
        children: [
          // ── Search + filter row ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              defaultPadding,
              defaultPadding,
              defaultPadding,
              defaultPadding / 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search by name, brand, or category',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterButton(
                  active: _stockFilterEnabled,
                  onTap: _openFilterSheet,
                ),
              ],
            ),
          ),

          // ── Major Category horizontal chips ────────────────────────────
          if (sortedMajorCategories.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: defaultPadding),
                children: [
                  _CategoryChip(
                    label: 'All',
                    count: allProducts.length,
                    selected: _selectedMajorCategory == 'all',
                    onTap: () {
                      setState(() {
                        _selectedMajorCategory = 'all';
                        _selectedSubCategory = null;
                      });
                    },
                  ),
                  for (final major in sortedMajorCategories)
                    _CategoryChip(
                      label: major,
                      count: majorCategoryCounts[major] ?? 0,
                      selected: _selectedMajorCategory.toLowerCase() ==
                          major.toLowerCase(),
                      onTap: () {
                        setState(() {
                          if (_selectedMajorCategory.toLowerCase() ==
                              major.toLowerCase()) {
                            _selectedMajorCategory = 'all';
                            _selectedSubCategory = null;
                          } else {
                            _selectedMajorCategory = major;
                            _selectedSubCategory = null;
                          }
                        });
                      },
                    ),
                ],
              ),
            ),

          // ── Subcategory chips (when a major category is selected) ────────
          if (sortedSubCategories.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: defaultPadding),
                children: [
                  _SubCategoryChip(
                    label: 'All $_selectedMajorCategory',
                    selected: _selectedSubCategory == null,
                    onTap: () {
                      setState(() {
                        _selectedSubCategory = null;
                      });
                    },
                  ),
                  for (final sub in sortedSubCategories)
                    _SubCategoryChip(
                      label: sub,
                      count: subCategoryCounts[sub],
                      selected: _selectedSubCategory?.toLowerCase() ==
                          sub.toLowerCase(),
                      onTap: () {
                        setState(() {
                          if (_selectedSubCategory?.toLowerCase() ==
                              sub.toLowerCase()) {
                            _selectedSubCategory = null;
                          } else {
                            _selectedSubCategory = sub;
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ],

          // ── Active filter chips + Result count + Expand/Collapse all ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              defaultPadding,
              6,
              defaultPadding,
              6,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${filtered.length} of ${allProducts.length} products',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (_stockFilterEnabled)
                        InputChip(
                          label: Text(
                            _maxStockValue == 0
                                ? 'Out of stock'
                                : 'Stock ≤ $_maxStockValue',
                            style: const TextStyle(fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              _stockFilterEnabled = false;
                              _maxStockValue = 0;
                            });
                          },
                          backgroundColor: primaryColor.withValues(alpha: 0.12),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ),
                      if (_selectedMajorCategory != 'all')
                        InputChip(
                          label: Text(
                            _selectedSubCategory == null
                                ? _selectedMajorCategory
                                : '$_selectedMajorCategory > $_selectedSubCategory',
                            style: const TextStyle(fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              _selectedMajorCategory = 'all';
                              _selectedSubCategory = null;
                            });
                          },
                          backgroundColor: primaryColor.withValues(alpha: 0.12),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
                if (sortedGroupKeys.length > 1)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_collapsedCategories.length ==
                            sortedGroupKeys.length) {
                          _collapsedCategories.clear();
                        } else {
                          _collapsedCategories.addAll(sortedGroupKeys);
                        }
                      });
                    },
                    icon: Icon(
                      _collapsedCategories.length == sortedGroupKeys.length
                          ? Icons.unfold_more
                          : Icons.unfold_less,
                      size: 16,
                    ),
                    label: Text(
                      _collapsedCategories.length == sortedGroupKeys.length
                          ? 'Expand all'
                          : 'Collapse all',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // ── List ───────────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<AdminProvider>().loadAdminData(),
              child: allProducts.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(defaultPadding),
                      children: const [
                        SizedBox(height: defaultPadding * 3),
                        Center(
                          child: Text(
                            'No products found yet. Add your first pet product to Firestore from this screen.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : filtered.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(defaultPadding),
                      children: [
                        const SizedBox(height: defaultPadding * 3),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: Theme.of(context).disabledColor,
                              ),
                              const SizedBox(height: defaultPadding / 2),
                              const Text(
                                'No products match your search or filter.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: defaultPadding),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _stockFilterEnabled = false;
                                    _maxStockValue = 0;
                                    _selectedMajorCategory = 'all';
                                    _selectedSubCategory = null;
                                  });
                                },
                                child: const Text('Clear filters'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        defaultPadding,
                        0,
                        defaultPadding,
                        defaultPadding * 2,
                      ),
                      itemCount: sortedGroupKeys.length,
                      itemBuilder: (context, groupIndex) {
                        final categoryTitle = sortedGroupKeys[groupIndex];
                        final categoryProducts =
                            categoryGroups[categoryTitle] ?? [];
                        final isCollapsed =
                            _collapsedCategories.contains(categoryTitle);

                        return _CategorySection(
                          categoryTitle: categoryTitle,
                          products: categoryProducts,
                          isCollapsed: isCollapsed,
                          onToggleCollapse: () {
                            setState(() {
                              if (isCollapsed) {
                                _collapsedCategories.remove(categoryTitle);
                              } else {
                                _collapsedCategories.add(categoryTitle);
                              }
                            });
                          },
                          adminProvider: adminProvider,
                          effectiveStock: _effectiveStock,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, adminProductFormScreenRoute);
        },
        label: const Text('Add product'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

/// Category chip for major category selection.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        onSelected: (_) => onTap(),
        label: Text('$label ($count)'),
        selectedColor: primaryColor,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : null,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? primaryColor : Theme.of(context).dividerColor,
          ),
        ),
        backgroundColor: Theme.of(context).cardColor,
        showCheckmark: false,
      ),
    );
  }
}

/// Subcategory chip.
class _SubCategoryChip extends StatelessWidget {
  const _SubCategoryChip({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = count != null ? '$label ($count)' : label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        label: Text(text),
        selectedColor: primaryColor.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: selected ? primaryColor : null,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? primaryColor : Theme.of(context).dividerColor,
          ),
        ),
        backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
        visualDensity: VisualDensity.compact,
        showCheckmark: false,
      ),
    );
  }
}

/// A collapsible section for a category with its products.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categoryTitle,
    required this.products,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.adminProvider,
    required this.effectiveStock,
  });

  final String categoryTitle;
  final List<ProductModel> products;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final AdminProvider adminProvider;
  final int Function(ProductModel) effectiveStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category Header Card ─────────────────────────────
          Material(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onToggleCollapse,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        size: 18,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        categoryTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${products.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: theme.iconTheme.color?.withValues(alpha: 0.7),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Products under this category ─────────────────────
          if (!isCollapsed) ...[
            const SizedBox(height: defaultPadding / 2),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: defaultPadding / 2),
              itemBuilder: (context, index) {
                final product = products[index];
                return _ProductCard(
                  product: product,
                  effectiveStock: effectiveStock(product),
                  adminProvider: adminProvider,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Filter icon button with a dot indicator when active.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? primaryColor.withValues(alpha: 0.15)
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? primaryColor : Theme.of(context).dividerColor,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: active
                    ? primaryColor
                    : Theme.of(context).iconTheme.color,
              ),
              if (active)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Product card extracted to keep the build method readable.
/// Logic (Edit / Delete) preserved identically from the original screen.
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.effectiveStock,
    required this.adminProvider,
  });

  final ProductModel product;
  final int effectiveStock;
  final AdminProvider adminProvider;

  @override
  Widget build(BuildContext context) {
    final lowStock = effectiveStock == 0;

    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: const BorderRadius.all(
          Radius.circular(defaultBorderRadious),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(defaultBorderRadious),
                  ),
                  child: NetworkImageWithLoader(product.imageUrl),
                ),
              ),
              const SizedBox(width: defaultPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: defaultPadding / 4),
                    Text(
                      product.brandName.isEmpty
                          ? product.categoryName
                          : product.brandName,
                    ),
                    const SizedBox(height: defaultPadding / 4),
                    Text(
                      'Rs ${product.price.toStringAsFixed(0)}'
                      '${product.salePrice != null ? '  Sale Rs ${product.salePrice!.toStringAsFixed(0)}' : ''}',
                    ),
                    const SizedBox(height: defaultPadding / 4),
                    Row(
                      children: [
                        Text(
                          'Stock: $effectiveStock | ${product.isActive ? 'Active' : 'Hidden'}',
                          style: TextStyle(
                            color: lowStock ? errorColor : null,
                            fontWeight: lowStock ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
                    ),
                    if (product.packOptions.isNotEmpty) ...[
                      const SizedBox(height: defaultPadding / 4),
                      Text(
                        'Packs: ${product.packOptions.map((option) => '${option.label} (${option.stockQuantity})').join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: defaultPadding / 4),
                    Text(
                      'Featured: ${product.isFeatured ? 'Yes' : 'No'} | Best Seller: ${product.isPopular ? 'Yes' : 'No'} | New Arrival: ${product.isNewArrival ? 'Yes' : 'No'}',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: defaultPadding),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      adminProductFormScreenRoute,
                      arguments: product,
                    );
                  },
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: defaultPadding),
              Expanded(
                child: ElevatedButton(
                  onPressed: adminProvider.isSaving
                      ? null
                      : () async {
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                title: const Text('Delete product?'),
                                content: Text(
                                  'Remove ${product.title} from the catalog?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext, false);
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext, true);
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (shouldDelete == true && context.mounted) {
                            final admin = context.read<AdminProvider>();
                            final products = context.read<ProductProvider>();
                            await admin.deleteProduct(product.id);
                            if (context.mounted) {
                              await products.loadInitialData();
                            }
                          }
                        },
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
