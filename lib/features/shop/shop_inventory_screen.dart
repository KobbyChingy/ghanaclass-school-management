import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/shop/shop_providers.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

enum _InventoryStockFilter { all, low, out }

class ShopInventoryScreen extends ConsumerStatefulWidget {
  const ShopInventoryScreen({super.key});

  @override
  ConsumerState<ShopInventoryScreen> createState() => _ShopInventoryScreenState();
}

class _ShopInventoryScreenState extends ConsumerState<ShopInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  _InventoryStockFilter _stockFilter = _InventoryStockFilter.all;
  bool _bulkBusy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openItemEditor({ShopItem? item}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _ItemEditorDialog(item: item),
    );
    if (ok == true) {
      ref.invalidate(shopItemsProvider);
      ref.invalidate(shopLowStockItemsProvider);
    }
  }

  Future<void> _openStockDialog(ShopItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _StockMovementDialog(item: item),
    );
    if (ok == true) {
      ref.invalidate(shopItemsProvider);
      ref.invalidate(shopRecentMovementsProvider);
      ref.invalidate(shopLowStockItemsProvider);
    }
  }

  Future<void> _bulkRestock(List<ShopItem> targetItems) async {
    if (targetItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items to restock.')));
      return;
    }

    final qtyController = TextEditingController(text: '5');
    final unitCostController = TextEditingController();
    final notesController = TextEditingController(text: 'Bulk restock');

    final payload = await showDialog<({double qty, double? unitCost, String? notes})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bulk restock (${targetItems.length} items)'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Add quantity to each item'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unitCostController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Unit cost (optional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text.trim()) ?? 0;
              if (qty <= 0) return;
              final unitCost = double.tryParse(unitCostController.text.trim());
              final notes = notesController.text.trim();
              Navigator.of(context).pop((qty: qty, unitCost: unitCost, notes: notes.isEmpty ? null : notes));
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    qtyController.dispose();
    unitCostController.dispose();
    notesController.dispose();

    if (payload == null) return;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;
    final actorRole = UserRole.values.firstWhere(
      (r) => r.name == currentUser.role,
      orElse: () => UserRole.shop,
    );

    setState(() => _bulkBusy = true);
    try {
      final service = ref.read(shopServiceProvider);
      final count = await service.bulkRestockItems(
        itemIds: targetItems.map((i) => i.id).toList(growable: false),
        addQuantity: payload.qty,
        unitCost: payload.unitCost,
        notes: payload.notes,
        actorUserId: currentUser.id,
        actorName: currentUser.fullName,
        actorRole: actorRole,
      );

      ref.invalidate(shopItemsProvider);
      ref.invalidate(shopLowStockItemsProvider);
      ref.invalidate(shopRecentMovementsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulk restock completed for $count items.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bulk restock failed: $e')));
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _exportCsv(List<ShopItem> targetItems) async {
    if (targetItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to export.')));
      return;
    }

    try {
      final service = ref.read(shopServiceProvider);
      final csvText = await service.exportInventoryCsv(itemIds: targetItems.map((e) => e.id).toList(growable: false));
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}\\shop_inventory_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvText);
      await OpenFile.open(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Inventory exported to ${file.path}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importCsv() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = pick?.files.single.path;
    if (path == null) return;

    final actorRole = UserRole.values.firstWhere(
      (r) => r.name == currentUser.role,
      orElse: () => UserRole.shop,
    );

    setState(() => _bulkBusy = true);
    try {
      final csvText = await File(path).readAsString();
      final service = ref.read(shopServiceProvider);
      final result = await service.importInventoryCsvText(
        csvText: csvText,
        actorUserId: currentUser.id,
        actorName: currentUser.fullName,
        actorRole: actorRole,
      );

      ref.invalidate(shopItemsProvider);
      ref.invalidate(shopLowStockItemsProvider);
      ref.invalidate(shopRecentMovementsProvider);

      if (!mounted) return;
      final summary =
          'Imported ${result.imported}, updated ${result.updated}, failed ${result.failed}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));

      if (result.errors.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import errors'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Text(result.errors.take(20).join('\n')),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final actorRole = currentUser == null
        ? UserRole.shop
        : UserRole.values.firstWhere(
            (r) => r.name == currentUser.role,
            orElse: () => UserRole.shop,
          );
    final hideCanteenItems = actorRole == UserRole.shop;

    final itemsAsync = ref.watch(shopItemsProvider(_searchController.text));
    final lowAsync = ref.watch(shopLowStockItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory (School Shop)'),
        actions: [
          IconButton(
            tooltip: 'Dashboard',
            onPressed: () => context.go('/shop/dashboard'),
            icon: const Icon(Icons.space_dashboard_outlined),
          ),
          IconButton(
            tooltip: 'POS',
            onPressed: () => context.go('/pos'),
            icon: const Icon(Icons.point_of_sale_outlined),
          ),
          IconButton(
            tooltip: 'Suppliers',
            onPressed: () => context.go('/shop/suppliers'),
            icon: const Icon(Icons.local_shipping_outlined),
          ),
          IconButton(
            tooltip: 'Reports',
            onPressed: () => context.go('/shop/reports'),
            icon: const Icon(Icons.bar_chart_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openItemEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final chips = [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _stockFilter == _InventoryStockFilter.all,
                    onSelected: (_) => setState(() => _stockFilter = _InventoryStockFilter.all),
                  ),
                  ChoiceChip(
                    label: const Text('Low only'),
                    selected: _stockFilter == _InventoryStockFilter.low,
                    onSelected: (_) => setState(() => _stockFilter = _InventoryStockFilter.low),
                  ),
                  ChoiceChip(
                    label: const Text('Out of stock'),
                    selected: _stockFilter == _InventoryStockFilter.out,
                    onSelected: (_) => setState(() => _stockFilter = _InventoryStockFilter.out),
                  ),
                ];

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search items',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      lowAsync.when(
                        data: (low) {
                          final visibleLow = hideCanteenItems ? low.where((i) => !i.isCanteenItem).toList() : low;
                          return Chip(
                            label: Text('Low stock: ${visibleLow.length}'),
                            backgroundColor: visibleLow.isEmpty ? Colors.green.shade50 : Colors.orange.shade50,
                          );
                        },
                        loading: () => const Chip(label: Text('Low stock: ...')),
                        error: (e, st) => const Chip(label: Text('Low stock: ?')),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [...chips]),
                      ),
                    ],
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 420,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search items',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    lowAsync.when(
                      data: (low) {
                        final visibleLow = hideCanteenItems ? low.where((i) => !i.isCanteenItem).toList() : low;
                        return Chip(
                          label: Text('Low stock: ${visibleLow.length}'),
                          backgroundColor: visibleLow.isEmpty ? Colors.green.shade50 : Colors.orange.shade50,
                        );
                      },
                      loading: () => const Chip(label: Text('Low stock: ...')),
                      error: (e, st) => const Chip(label: Text('Low stock: ?')),
                    ),
                    ...chips,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: itemsAsync.when(
                data: (items) {
                  final baseItems = hideCanteenItems ? items.where((i) => !i.isCanteenItem).toList() : items;
                  final filteredItems = baseItems.where((item) {
                    final low = item.reorderLevel > 0 && item.quantityOnHand <= item.reorderLevel;
                    final out = item.quantityOnHand <= 0;
                    switch (_stockFilter) {
                      case _InventoryStockFilter.all:
                        return true;
                      case _InventoryStockFilter.low:
                        return low;
                      case _InventoryStockFilter.out:
                        return out;
                    }
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return const Center(child: Text('No matching inventory items.'));
                  }

                  return Column(
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _bulkBusy ? null : () => _bulkRestock(filteredItems),
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('Bulk restock'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _bulkBusy ? null : () => _exportCsv(filteredItems),
                            icon: const Icon(Icons.file_download_outlined),
                            label: const Text('Export CSV'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _bulkBusy ? null : _importCsv,
                            icon: const Icon(Icons.file_upload_outlined),
                            label: const Text('Import CSV'),
                          ),
                          if (_bulkBusy)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filteredItems.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final low = item.reorderLevel > 0 && item.quantityOnHand <= item.reorderLevel;
                            final out = item.quantityOnHand <= 0;
                            return ListTile(
                              title: Text(item.name),
                              subtitle: Text(
                                'Category: ${item.category} • Stock: ${item.quantityOnHand.toStringAsFixed(0)}'
                                '${item.reorderLevel > 0 ? ' (reorder ${item.reorderLevel.toStringAsFixed(0)})' : ''}',
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  if (out) const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                                  if (!out && low) const Icon(Icons.warning_amber_outlined, color: Colors.orange),
                                  IconButton(
                                    tooltip: 'Stock in/out',
                                    onPressed: () => _openStockDialog(item),
                                    icon: const Icon(Icons.swap_vert_circle_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit item',
                                    onPressed: () => _openItemEditor(item: item),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemEditorDialog extends ConsumerStatefulWidget {
  final ShopItem? item;

  const _ItemEditorDialog({this.item});

  @override
  ConsumerState<_ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends ConsumerState<_ItemEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _reorder;
  late final TextEditingController _size;
  late final TextEditingController _color;
  late final TextEditingController _variant;
  late final TextEditingController _mandatory;

  bool _isActive = true;
  bool _isPerishable = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _category = TextEditingController(text: item?.category ?? 'other');
    _sku = TextEditingController(text: item?.sku ?? '');
    _barcode = TextEditingController(text: item?.barcode ?? '');
    _cost = TextEditingController(text: (item?.costPrice ?? 0).toString());
    _price = TextEditingController(text: (item?.sellingPrice ?? 0).toString());
    _reorder = TextEditingController(text: (item?.reorderLevel ?? 0).toString());
    _size = TextEditingController(text: item?.size ?? '');
    _color = TextEditingController(text: item?.color ?? '');
    _variant = TextEditingController(text: item?.variantGroup ?? '');
    _mandatory = TextEditingController(text: item?.mandatoryForClassCodes ?? '');
    _isActive = item?.isActive ?? true;
    _isPerishable = item?.isPerishable ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _sku.dispose();
    _barcode.dispose();
    _cost.dispose();
    _price.dispose();
    _reorder.dispose();
    _size.dispose();
    _color.dispose();
    _variant.dispose();
    _mandatory.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    final cost = double.tryParse(_cost.text.trim()) ?? 0;
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final reorder = double.tryParse(_reorder.text.trim()) ?? 0;

    final service = ref.read(shopServiceProvider);
    await service.upsertItem(
      id: widget.item?.id,
      name: name,
      category: _category.text.trim().isEmpty ? 'other' : _category.text.trim(),
      sku: _sku.text,
      barcode: _barcode.text,
      costPrice: cost,
      sellingPrice: price,
      reorderLevel: reorder,
      size: _size.text,
      color: _color.text,
      variantGroup: _variant.text,
      mandatoryForClassCodes: _mandatory.text,
      isActive: _isActive,
      isPerishable: _isPerishable,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit item' : 'Add item'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: _category, decoration: const InputDecoration(labelText: 'Category (uniforms, stationery, canteen, textbooks, others)')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU (optional)'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _barcode, decoration: const InputDecoration(labelText: 'Barcode (optional)'))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost price'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling price'))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: _reorder, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reorder level (low stock alert)')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _size, decoration: const InputDecoration(labelText: 'Size (uniform)'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _color, decoration: const InputDecoration(labelText: 'Color (uniform)'))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _variant, decoration: const InputDecoration(labelText: 'Variant group (e.g., JHS Uniform)'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _mandatory, decoration: const InputDecoration(labelText: 'Mandatory for classes (e.g., JHS1,JHS2)'))),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('Active'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPerishable,
                onChanged: (v) => setState(() => _isPerishable = v),
                title: const Text('Perishable (canteen)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _StockMovementDialog extends ConsumerStatefulWidget {
  final ShopItem item;

  const _StockMovementDialog({required this.item});

  @override
  ConsumerState<_StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends ConsumerState<_StockMovementDialog> {
  final TextEditingController _qty = TextEditingController(text: '1');
  final TextEditingController _unitCost = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  String _type = 'purchase';
  int? _supplierId;
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _unitCost.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final actorRole = UserRole.values.firstWhere(
      (r) => r.name == currentUser.role,
      orElse: () => UserRole.shop,
    );

    final qty = double.tryParse(_qty.text.trim()) ?? 0;
    final unitCost = double.tryParse(_unitCost.text.trim());

    setState(() => _saving = true);
    try {
      final service = ref.read(shopServiceProvider);
      await service.recordStockMovement(
        itemId: widget.item.id,
        movementType: _type,
        quantity: qty,
        unitCost: (_type == 'purchase') ? unitCost : null,
        supplierId: _supplierId,
        notes: _notes.text,
        actorUserId: currentUser.id,
        actorName: currentUser.fullName,
        actorRole: actorRole,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(shopSuppliersProvider);

    return AlertDialog(
      title: Text('Stock movement: ${widget.item.name}'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey<String>('type:$_type'),
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'purchase', child: Text('Purchase (Stock In)')),
                DropdownMenuItem(value: 'in', child: Text('Stock In (Other)')),
                DropdownMenuItem(value: 'out', child: Text('Stock Out (Issue/Write-off)')),
                DropdownMenuItem(value: 'return', child: Text('Return (Stock In)')),
                DropdownMenuItem(value: 'adjust', child: Text('Adjust (Stock In)')),
              ],
              onChanged: _saving ? null : (v) => setState(() => _type = v ?? 'purchase'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 8),
            if (_type == 'purchase')
              TextField(
                controller: _unitCost,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Unit cost (optional)'),
              ),
            const SizedBox(height: 8),
            suppliersAsync.when(
              data: (suppliers) {
                return DropdownButtonFormField<int?>(
                  key: ValueKey<String>('sup:${_supplierId ?? 'none'}'),
                  initialValue: _supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier (optional)'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('None')),
                    ...suppliers.map(
                      (s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: _saving ? null : (v) => setState(() => _supplierId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Supplier error: $e'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
