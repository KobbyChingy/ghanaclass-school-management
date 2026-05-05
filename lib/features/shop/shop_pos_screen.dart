import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/features/chef/canteen_providers.dart';
import 'package:ghanaclass_school_management/features/shop/shop_providers.dart';
import 'package:ghanaclass_school_management/features/shop/shop_receipt_pdf_service.dart';
import 'package:ghanaclass_school_management/features/shop/shop_service.dart';
import 'package:ghanaclass_school_management/features/students/student_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/shared/widgets/portal_surface.dart';
import 'package:ghanaclass_school_management/shared/printing/pdf_preview_screen.dart';

class ShopPosScreen extends ConsumerStatefulWidget {
  const ShopPosScreen({super.key});

  @override
  ConsumerState<ShopPosScreen> createState() => _ShopPosScreenState();
}

class _ShopPosScreenState extends ConsumerState<ShopPosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _historySearchController = TextEditingController();
  final TextEditingController _amountReceivedController = TextEditingController(text: '0');
  final TextEditingController _momoRefController = TextEditingController();

  String _paymentMethod = 'cash';
  String _customerType = 'walkin';
  Student? _selectedStudent;

  final Map<int, _CartLine> _cart = {};
  bool _submitting = false;
  bool _canteenMenuOnly = false;

  String _studentName(Student s) {
    final parts = <String>[s.firstName, if (s.otherNames != null && s.otherNames!.trim().isNotEmpty) s.otherNames!.trim(), s.lastName];
    return parts.where((p) => p.trim().isNotEmpty).join(' ');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _historySearchController.dispose();
    _amountReceivedController.dispose();
    _momoRefController.dispose();
    super.dispose();
  }

  Future<void> _previewReceiptBySaleId(int saleId) async {
    final service = ref.read(shopServiceProvider);
    final detail = await service.getSaleDetail(saleId);
    if (!mounted || detail == null) return;

    final schoolInfo = await ref.read(institutionalIdentityProvider.future);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: 'Receipt ${detail.sale.receiptNo}',
          pdfFileName: 'receipt-${detail.sale.receiptNo}.pdf',
          canChangeOrientation: false,
          buildPdf: (format) => ShopReceiptPdfService().buildSaleReceiptPdf(
            detail: detail,
            schoolInfo: schoolInfo,
            pageFormat: format,
          ),
        ),
      ),
    );
  }

  Future<void> _openSaleDrilldown(ShopSale sale) async {
    final service = ref.read(shopServiceProvider);
    final detail = await service.getSaleDetail(sale.id);
    if (!mounted || detail == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Receipt ${detail.sale.receiptNo}'),
        content: SizedBox(
          width: 720,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat('dd MMM yyyy, HH:mm').format(detail.sale.soldAt)}  |  '
                '${detail.sale.paymentMethod.toUpperCase()}  |  '
                '${detail.sale.customerName ?? detail.sale.customerType}',
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('Units: ${detail.totalUnits.toStringAsFixed(0)}')),
                    Expanded(
                      child: Text(
                        'Total: GHS ${detail.sale.totalAmount.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: detail.lines.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = detail.lines[index];
                    return ListTile(
                      title: Text(line.item?.name ?? 'Item #${line.line.itemId}'),
                      subtitle: Text(
                        '${line.line.quantity.toStringAsFixed(0)} x GHS ${line.line.unitPrice.toStringAsFixed(2)}',
                      ),
                      trailing: Text('GHS ${line.line.lineTotal.toStringAsFixed(2)}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _previewReceiptBySaleId(sale.id);
            },
            icon: const Icon(Icons.print_outlined),
            label: const Text('Reprint receipt'),
          ),
        ],
      ),
    );
  }

  double get _cartTotal {
    double total = 0;
    for (final line in _cart.values) {
      total += line.unitPrice * line.quantity;
    }
    return total;
  }

  double get _cartUnits {
    double units = 0;
    for (final line in _cart.values) {
      units += line.quantity;
    }
    return units;
  }

  void _addToCart(ShopItem item) {
    _addToCartWithPrice(item, item.sellingPrice);
  }

  void _addToCartWithPrice(ShopItem item, double unitPrice) {
    setState(() {
      final existing = _cart[item.id];
      final nextQty = (existing?.quantity ?? 0) + 1;
      _cart[item.id] = _CartLine(
        itemId: item.id,
        name: item.name,
        unitPrice: unitPrice,
        quantity: nextQty,
        available: item.quantityOnHand,
      );
    });
  }

  void _updateQty(int itemId, double nextQty) {
    setState(() {
      if (nextQty <= 0) {
        _cart.remove(itemId);
        return;
      }
      final current = _cart[itemId];
      if (current == null) return;
      _cart[itemId] = current.copyWith(quantity: nextQty);
    });
  }

  Future<void> _pickStudentForWallet() async {
    final picked = await showDialog<Student>(
      context: context,
      builder: (context) => const _StudentPickerDialog(),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _selectedStudent = picked);
    }
  }

  Future<void> _completeSale() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }

    if (_paymentMethod == 'wallet' && _selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a student for wallet payment')));
      return;
    }

    final actorRole = UserRole.values.firstWhere(
      (r) => r.name == currentUser.role,
      orElse: () => UserRole.shop,
    );

    final amountReceived = double.tryParse(_amountReceivedController.text.trim()) ?? 0;

    setState(() => _submitting = true);
    try {
      final service = ref.read(shopServiceProvider);
      final result = await service.createSale(
        lines: _cart.values
            .map(
              (l) => SaleLineInput(itemId: l.itemId, quantity: l.quantity, unitPrice: l.unitPrice),
            )
            .toList(growable: false),
        paymentMethod: _paymentMethod,
        actorUserId: currentUser.id,
        actorName: currentUser.fullName,
        actorRole: actorRole,
        customerType: _customerType,
        studentId: _selectedStudent?.id,
        customerName: _selectedStudent == null ? null : _studentName(_selectedStudent!),
        amountReceived: amountReceived,
        momoReference: _paymentMethod == 'momo' ? _momoRefController.text.trim() : null,
      );

      if (!mounted) return;
      setState(() {
        _cart.clear();
        _amountReceivedController.text = '0';
        _momoRefController.clear();
      });

      ref.invalidate(shopItemsProvider);
      ref.invalidate(shopRecentSalesProvider);
      ref.invalidate(shopRecentMovementsProvider);
      if (_selectedStudent != null) {
        ref.invalidate(studentWalletProvider(_selectedStudent!.id));
        ref.invalidate(walletTransactionsProvider(_selectedStudent!.id));
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sale completed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Receipt: ${result.receiptNo}'),
              Text('Total: GHS ${result.totalAmount.toStringAsFixed(2)}'),
              if (_paymentMethod == 'cash') Text('Change: GHS ${result.changeGiven.toStringAsFixed(2)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final academicYear = ref.watch(activeYearProvider);
    final term = ref.watch(activeTermProvider);
    final itemsAsync = _canteenMenuOnly
      ? null
      : ref.watch(shopItemsProvider(_searchController.text));
    final canteenAsync = _canteenMenuOnly
      ? ref.watch(canteenTodayPosItemsProvider(_searchController.text))
      : null;
    final salesHistoryAsync = ref.watch(
      shopSalesHistoryProvider(
        _historySearchController.text.trim().isEmpty ? null : _historySearchController.text.trim(),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS (School Shop)'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Dashboard',
            onPressed: () => context.go('/shop/dashboard'),
            icon: const Icon(Icons.space_dashboard_outlined),
          ),
          IconButton(
            tooltip: 'Wallets',
            onPressed: () => context.go('/shop/wallet'),
            icon: const Icon(Icons.account_balance_wallet_outlined),
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 1100;
            final inventoryPanel = PortalSectionPanel(
                        title: 'Items & Checkout Feed',
                        subtitle: 'Search stock, switch to the canteen menu, and add items to the live basket.',
                        expandChild: true,
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                labelText: 'Search items (name / SKU / barcode)',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              value: _canteenMenuOnly,
                              onChanged: (v) => setState(() => _canteenMenuOnly = v),
                              title: const Text('Canteen menu only (today)'),
                              subtitle: const Text('Uses chef-defined daily menu and override prices.'),
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _canteenMenuOnly
                                  ? canteenAsync!.when(
                                      data: (items) {
                                        if (items.isEmpty) {
                                          return const Center(child: Text('No canteen menu items for today.'));
                                        }
                                        return ListView.separated(
                                          itemCount: items.length,
                                          separatorBuilder: (context, index) => const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final posItem = items[index];
                                            final item = posItem.item;
                                            return ListTile(
                                              title: Text(item.name),
                                              subtitle: Text(
                                                'GHS ${posItem.effectivePrice.toStringAsFixed(2)} • Stock ${item.quantityOnHand.toStringAsFixed(0)}',
                                              ),
                                              trailing: FilledButton(
                                                onPressed: item.quantityOnHand <= 0
                                                    ? null
                                                    : () => _addToCartWithPrice(item, posItem.effectivePrice),
                                                child: const Text('Add'),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      loading: () => const Center(child: CircularProgressIndicator()),
                                      error: (e, _) => Center(child: Text('Error: $e')),
                                    )
                                  : itemsAsync!.when(
                                      data: (items) {
                                        if (items.isEmpty) {
                                          return const Center(child: Text('No items found'));
                                        }
                                        return ListView.separated(
                                          itemCount: items.length,
                                          separatorBuilder: (context, index) => const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final item = items[index];
                                            final low = item.reorderLevel > 0 && item.quantityOnHand <= item.reorderLevel;
                                            return ListTile(
                                              title: Text(item.name),
                                              subtitle: Text(
                                                'GHS ${item.sellingPrice.toStringAsFixed(2)} • Stock ${item.quantityOnHand.toStringAsFixed(0)}'
                                                '${low ? ' • LOW' : ''}',
                                              ),
                                              trailing: FilledButton(
                                                onPressed: item.quantityOnHand <= 0 ? null : () => _addToCart(item),
                                                child: const Text('Add'),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      loading: () => const Center(child: CircularProgressIndicator()),
                                      error: (e, _) => Center(child: Text('Error: $e')),
                                    ),
                            ),
                          ],
                        ),
                      );
            final cartPanel = PortalSectionPanel(
                        title: 'Cart & Payment',
                        subtitle: 'Review the current basket, choose payment method, and complete the sale.',
                        expandChild: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _cart.isEmpty
                                  ? const Center(child: Text('No items yet'))
                                  : ListView.separated(
                                      itemCount: _cart.length,
                                      separatorBuilder: (context, index) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final line = _cart.values.elementAt(index);
                                        final over = line.quantity > line.available;
                                        return ListTile(
                                          title: Text(line.name),
                                          subtitle: Text(
                                            'Qty ${line.quantity.toStringAsFixed(0)} • Unit GHS ${line.unitPrice.toStringAsFixed(2)}'
                                            '${over ? ' • OVER STOCK' : ''}',
                                          ),
                                          trailing: Wrap(
                                            spacing: 8,
                                            children: [
                                              IconButton(
                                                onPressed: () => _updateQty(line.itemId, line.quantity - 1),
                                                icon: const Icon(Icons.remove_circle_outline),
                                              ),
                                              IconButton(
                                                onPressed: () => _updateQty(line.itemId, line.quantity + 1),
                                                icon: const Icon(Icons.add_circle_outline),
                                              ),
                                              IconButton(
                                                onPressed: () => _updateQty(line.itemId, 0),
                                                icon: const Icon(Icons.delete_outline),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceSoft,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total'),
                                      Text(
                                        'GHS ${_cartTotal.toStringAsFixed(2)}',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey<String>('pay:$_paymentMethod'),
                                    initialValue: _paymentMethod,
                                    items: const [
                                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                                      DropdownMenuItem(value: 'momo', child: Text('Mobile Money (MoMo)')),
                                      DropdownMenuItem(value: 'card', child: Text('Card')),
                                      DropdownMenuItem(value: 'wallet', child: Text('Student Wallet')),
                                    ],
                                    onChanged: _submitting
                                        ? null
                                        : (v) {
                                            if (v == null) return;
                                            setState(() => _paymentMethod = v);
                                          },
                                    decoration: const InputDecoration(labelText: 'Payment method'),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey<String>('cust:$_customerType'),
                                    initialValue: _customerType,
                                    items: const [
                                      DropdownMenuItem(value: 'walkin', child: Text('Walk-in')),
                                      DropdownMenuItem(value: 'student', child: Text('Student')),
                                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                                      DropdownMenuItem(value: 'parent', child: Text('Parent')),
                                    ],
                                    onChanged: _submitting
                                        ? null
                                        : (v) {
                                            if (v == null) return;
                                            setState(() => _customerType = v);
                                          },
                                    decoration: const InputDecoration(labelText: 'Customer type'),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_paymentMethod == 'cash')
                                    TextField(
                                      controller: _amountReceivedController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Amount received (cash)'),
                                    ),
                                  if (_paymentMethod == 'momo')
                                    TextField(
                                      controller: _momoRefController,
                                      decoration: const InputDecoration(labelText: 'MoMo reference (optional)'),
                                    ),
                                  if (_paymentMethod == 'wallet')
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          onPressed: _submitting ? null : _pickStudentForWallet,
                                          icon: const Icon(Icons.person_search_outlined),
                                          label: Text(
                                            _selectedStudent == null ? 'Select student' : _studentName(_selectedStudent!),
                                          ),
                                        ),
                                        if (_selectedStudent != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Consumer(
                                              builder: (context, ref, _) {
                                                final walletAsync = ref.watch(studentWalletProvider(_selectedStudent!.id));
                                                return walletAsync.when(
                                                  data: (w) => Text(
                                                    'Wallet balance: GHS ${(w?.balance ?? 0).toStringAsFixed(2)}',
                                                  ),
                                                  loading: () => const Text('Wallet balance: ...'),
                                                  error: (e, _) => Text('Wallet error: $e'),
                                                );
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: (_submitting || _cart.isEmpty)
                                              ? null
                                              : () => setState(() {
                                                    _cart.clear();
                                                    _amountReceivedController.text = '0';
                                                    _momoRefController.clear();
                                                  }),
                                          icon: const Icon(Icons.delete_sweep_outlined),
                                          label: const Text('Clear cart'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: _submitting ? null : _completeSale,
                                          icon: _submitting
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Icon(Icons.check_circle_outline),
                                          label: const Text('Complete sale'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );

            final historyPanel = PortalSectionPanel(
                        title: 'Transaction History',
                        subtitle: 'Search receipts, inspect line items, and reprint instantly.',
                        expandChild: true,
                        child: Column(
                          children: [
                            TextField(
                              controller: _historySearchController,
                              decoration: const InputDecoration(
                                labelText: 'Search by receipt, customer, payment...',
                                prefixIcon: Icon(Icons.receipt_long_outlined),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: salesHistoryAsync.when(
                                data: (sales) {
                                  if (sales.isEmpty) {
                                    return const Center(child: Text('No matching transactions.'));
                                  }
                                  return ListView.separated(
                                    itemCount: sales.length,
                                    separatorBuilder: (context, index) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final sale = sales[index];
                                      return ListTile(
                                        title: Text(sale.receiptNo),
                                        subtitle: Text(
                                          '${DateFormat('dd MMM, HH:mm').format(sale.soldAt)} • '
                                          '${sale.paymentMethod.toUpperCase()} • '
                                          '${sale.customerName ?? sale.customerType}',
                                        ),
                                        trailing: Wrap(
                                          spacing: 4,
                                          children: [
                                            IconButton(
                                              tooltip: 'Line-item drilldown',
                                              onPressed: () => _openSaleDrilldown(sale),
                                              icon: const Icon(Icons.visibility_outlined),
                                            ),
                                            IconButton(
                                              tooltip: 'Reprint receipt',
                                              onPressed: () => _previewReceiptBySaleId(sale.id),
                                              icon: const Icon(Icons.print_outlined),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (e, _) => Center(child: Text('History error: $e')),
                              ),
                            ),
                          ],
                        ),
                      );

            return Column(
              children: [
                PortalHeroBanner(
                  eyebrow: 'Shop portal',
                  title: 'Point of Sale Operations',
                  subtitle: '${currentUser?.fullName ?? 'Shop operator'} is handling checkout, stock movements, wallets, and reporting for the current school cycle.',
                  icon: Icons.storefront_outlined,
                  primary: const Color(0xFFD97706),
                  accent: const Color(0xFF2563EB),
                  metrics: [
                    PortalHeroMetric(label: 'Academic year', value: '$academicYear'),
                    PortalHeroMetric(label: 'Active term', value: 'Term $term'),
                    PortalHeroMetric(label: 'Cart lines', value: '${_cart.length}'),
                    PortalHeroMetric(label: 'Units', value: _cartUnits.toStringAsFixed(0)),
                    PortalHeroMetric(label: 'Cart total', value: 'GHS ${_cartTotal.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: stacked
                      ? ListView(
                          children: [
                            SizedBox(height: 560, child: inventoryPanel),
                            const SizedBox(height: 16),
                            SizedBox(height: 620, child: cartPanel),
                            const SizedBox(height: 16),
                            SizedBox(height: 520, child: historyPanel),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: inventoryPanel,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: cartPanel,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: historyPanel,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CartLine {
  final int itemId;
  final String name;
  final double unitPrice;
  final double quantity;
  final double available;

  const _CartLine({
    required this.itemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.available,
  });

  _CartLine copyWith({double? quantity}) {
    return _CartLine(
      itemId: itemId,
      name: name,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
      available: available,
    );
  }
}

class _StudentPickerDialog extends ConsumerStatefulWidget {
  const _StudentPickerDialog();

  @override
  ConsumerState<_StudentPickerDialog> createState() => _StudentPickerDialogState();
}

class _StudentPickerDialogState extends ConsumerState<_StudentPickerDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(
      studentsListProvider(
        StudentFilter(searchQuery: _controller.text.trim().isEmpty ? null : _controller.text.trim()),
      ),
    );

    return AlertDialog(
      title: const Text('Select student'),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search students'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: studentsAsync.when(
                data: (students) {
                  if (students.isEmpty) return const Center(child: Text('No students found'));
                  return ListView.separated(
                    itemCount: students.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = students[index];
                      return ListTile(
                        title: Text('${s.firstName} ${s.lastName}'.trim()),
                        subtitle: Text('Student ID: ${s.id}'),
                        onTap: () => Navigator.of(context).pop(s),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      ],
    );
  }
}
