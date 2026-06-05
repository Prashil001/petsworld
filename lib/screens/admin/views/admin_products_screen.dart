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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Effective stock for a product — uses total pack stock if the product
  /// has pack options, otherwise the simple stockQuantity field.
  int _effectiveStock(ProductModel p) =>
      p.packOptions.isEmpty ? p.stockQuantity : p.totalPackStock;

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
    final hasActiveFilter = _searchQuery.trim().isNotEmpty || _stockFilterEnabled;

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

          // ── Active filter chip + result count ──────────────────────────
          if (hasActiveFilter)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                defaultPadding,
                0,
                defaultPadding,
                defaultPadding / 2,
              ),
              child: Row(
                children: [
                  if (_stockFilterEnabled)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
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
                      ),
                    ),
                  Expanded(
                    child: Text(
                      '${filtered.length} of ${allProducts.length} products',
                      style: Theme.of(context).textTheme.bodySmall,
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
                                  });
                                },
                                child: const Text('Clear filters'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        defaultPadding,
                        0,
                        defaultPadding,
                        defaultPadding,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: defaultPadding),
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        return _ProductCard(
                          product: product,
                          effectiveStock: _effectiveStock(product),
                          adminProvider: adminProvider,
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
