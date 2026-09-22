import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shop/constants.dart';
import 'package:shop/models/coupon_model.dart';
import 'package:shop/models/home_section_model.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/providers/admin_provider.dart';
import 'package:shop/providers/product_provider.dart';

class AdminHomeSectionsScreen extends StatelessWidget {
  const AdminHomeSectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final sections = adminProvider.homeSections;

    return Scaffold(
      appBar: AppBar(title: const Text('Home sections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.view_stream_outlined),
        label: const Text('Add section'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          if (sections.isEmpty)
            const _SectionEmptyState()
          else
            ...sections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: defaultPadding),
                child: _HomeSectionCard(
                  section: section,
                  onEdit: () => _openEditor(context, section: section),
                  onDelete: () => _deleteSection(context, section),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    HomeSectionModel? section,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HomeSectionEditorSheet(initialSection: section),
    );
  }

  Future<void> _deleteSection(
    BuildContext context,
    HomeSectionModel section,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete section?'),
        content: Text('Remove "${section.title}" from the home page?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final adminProvider = context.read<AdminProvider>();
    final success = await adminProvider.deleteHomeSection(section.id);
    if (!context.mounted) return;
    if (success) {
      await context.read<ProductProvider>().loadInitialData();
    }
  }
}

class _HomeSectionCard extends StatelessWidget {
  const _HomeSectionCard({
    required this.section,
    required this.onEdit,
    required this.onDelete,
  });

  final HomeSectionModel section;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${section.productIds.length} curated products • Order ${section.sortOrder}',
          ),
          const SizedBox(height: 6),
          Text(
            section.isWithinDisplayRange ? 'Visible now' : 'Currently hidden',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (section.hasSectionDiscount) ...[
            const SizedBox(height: 6),
            Text(
              section.sectionDiscountType == CouponDiscountType.flatAmount
                  ? 'Section offer: Rs ${section.sectionDiscountValue?.toStringAsFixed(0) ?? '0'} off'
                  : 'Section offer: ${section.sectionDiscountValue?.toStringAsFixed(0) ?? '0'}% off',
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onDelete,
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

class _HomeSectionEditorSheet extends StatefulWidget {
  const _HomeSectionEditorSheet({this.initialSection});

  final HomeSectionModel? initialSection;

  @override
  State<_HomeSectionEditorSheet> createState() =>
      _HomeSectionEditorSheetState();
}

class _HomeSectionEditorSheetState extends State<_HomeSectionEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _sortOrderController;
  late final TextEditingController _discountValueController;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedProductIds = <String>{};
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _isActive = true;
  bool _hasDiscount = false;
  CouponDiscountType _discountType = CouponDiscountType.percentage;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final section = widget.initialSection;
    _titleController = TextEditingController(text: section?.title ?? '');
    _sortOrderController = TextEditingController(
      text: (section?.sortOrder ?? 0).toString(),
    );
    _discountValueController = TextEditingController(
      text: section?.sectionDiscountValue?.toStringAsFixed(0) ?? '',
    );
    _selectedProductIds.addAll(section?.productIds ?? const []);
    _isActive = section?.isActive ?? true;
    _hasDiscount = section?.hasSectionDiscount ?? false;
    _discountType =
        section?.sectionDiscountType ?? CouponDiscountType.percentage;
    _startDate = section?.startDate;
    _endDate = section?.endDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sortOrderController.dispose();
    _discountValueController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final products = adminProvider.products;

    // Collect and sort unique categories
    final categoryCounts = <String, int>{};
    for (final p in products) {
      final cat = p.categoryName.trim().isEmpty ? 'Uncategorized' : p.categoryName.trim();
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }
    final sortedCategories = categoryCounts.keys.toList()..sort();

    // Filter products by category and search query
    final filteredProducts = products.where((product) {
      // 1. Category filter
      if (_selectedCategory == 'selected') {
        if (!_selectedProductIds.contains(product.id)) return false;
      } else if (_selectedCategory != 'all') {
        final cat = product.categoryName.trim().isEmpty ? 'Uncategorized' : product.categoryName.trim();
        if (cat.toLowerCase() != _selectedCategory.toLowerCase()) {
          return false;
        }
      }

      // 2. Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = product.title.toLowerCase().contains(q);
        final matchesCat = product.categoryName.toLowerCase().contains(q);
        final matchesBrand = product.brandName.toLowerCase().contains(q);
        if (!matchesName && !matchesCat && !matchesBrand) {
          return false;
        }
      }

      return true;
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header with Drag Handle & Close Button ─────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.initialSection == null
                              ? 'Create home section'
                              : 'Edit home section',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Scrollable Form Body ──────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Title is required'
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Section title',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _sortOrderController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Display order',
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show this section'),
                          value: _isActive,
                          onChanged: (value) => setState(() => _isActive = value),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _startDate == null
                                ? 'Start date (optional)'
                                : 'Starts ${_formatDate(_startDate!)}',
                          ),
                          trailing: TextButton(
                            onPressed: () => _pickDate(isStart: true),
                            child: const Text('Select'),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _endDate == null
                                ? 'End date (optional)'
                                : 'Ends ${_formatDate(_endDate!)}',
                          ),
                          trailing: TextButton(
                            onPressed: () => _pickDate(isStart: false),
                            child: const Text('Select'),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Apply a section discount'),
                          value: _hasDiscount,
                          onChanged: (value) => setState(() => _hasDiscount = value),
                        ),
                        if (_hasDiscount) ...[
                          DropdownButtonFormField<CouponDiscountType>(
                            initialValue: _discountType,
                            decoration: const InputDecoration(
                              labelText: 'Section discount type',
                            ),
                            items: CouponDiscountType.values
                                .map(
                                  (item) => DropdownMenuItem<CouponDiscountType>(
                                    value: item,
                                    child: Text(
                                      item == CouponDiscountType.flatAmount
                                          ? 'Flat amount off'
                                          : 'Percentage off',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _discountType = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _discountValueController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Section discount value',
                            ),
                          ),
                        ],
                        const Divider(height: 32),

                        // ── Curated Products Header & Actions ─────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Curated products (${_selectedProductIds.length} selected)',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_selectedProductIds.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setState(() => _selectedProductIds.clear());
                                },
                                child: const Text('Clear all'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // ── Search Bar ──────────────────────────────
                        TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search by name, brand, or category...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ── Category Filter Chips ─────────────────────
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: Text('All (${products.length})'),
                                selected: _selectedCategory == 'all',
                                onSelected: (_) =>
                                    setState(() => _selectedCategory = 'all'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                avatar: const Icon(Icons.check_circle_outline, size: 16),
                                label: Text('Selected (${_selectedProductIds.length})'),
                                selected: _selectedCategory == 'selected',
                                onSelected: (_) =>
                                    setState(() => _selectedCategory = 'selected'),
                              ),
                              for (final cat in sortedCategories) ...[
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: Text('$cat (${categoryCounts[cat]})'),
                                  selected: _selectedCategory == cat,
                                  onSelected: (_) =>
                                      setState(() => _selectedCategory = cat),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Filtered Products List ───────────────────
                        if (filteredProducts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 40,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedCategory == 'selected'
                                        ? 'No products selected yet.'
                                        : 'No products match your search or filter.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...filteredProducts.map(
                            (product) {
                              final isSelected = _selectedProductIds.contains(product.id);
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: isSelected,
                                secondary: product.imageUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          product.imageUrl,
                                          width: 42,
                                          height: 42,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 42,
                                            height: 42,
                                            color: Colors.grey.withValues(alpha: 0.1),
                                            child: const Icon(
                                              Icons.inventory_2_outlined,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      )
                                    : null,
                                onChanged: (_) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedProductIds.remove(product.id);
                                    } else {
                                      _selectedProductIds.add(product.id);
                                    }
                                  });
                                },
                                title: Text(
                                  product.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${product.categoryName}${product.brandName.isNotEmpty ? " · ${product.brandName}" : ""} · Rs ${product.price.toStringAsFixed(0)}',
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Sticky Save Button at Bottom ───────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: adminProvider.isSaving ? null : _save,
                    icon: adminProvider.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(
                      adminProvider.isSaving
                          ? 'Saving...'
                          : 'Save section (${_selectedProductIds.length} selected)',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await context.read<AdminProvider>().saveHomeSection(
      HomeSectionModel(
        id: widget.initialSection?.id ?? '',
        title: _titleController.text.trim(),
        productIds: _selectedProductIds.toList(),
        sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
        startDate: _startDate,
        endDate: _endDate,
        isActive: _isActive,
        sectionDiscountType: _hasDiscount ? _discountType : null,
        sectionDiscountValue: _hasDiscount
            ? double.tryParse(_discountValueController.text.trim()) ?? 0
            : null,
        createdAt: widget.initialSection?.createdAt,
        updatedAt: DateTime.now(),
      ),
    );

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<AdminProvider>().errorMessage ??
                'Could not save home section.',
          ),
        ),
      );
      return;
    }
    await context.read<ProductProvider>().loadInitialData();
    if (!mounted) return;
    Navigator.pop(context);
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.view_stream_outlined, size: 52),
          SizedBox(height: 12),
          Text('No home sections yet'),
          SizedBox(height: 8),
          Text(
            'Create seasonal or promotional sections like Diwali Special and pin selected products there.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
