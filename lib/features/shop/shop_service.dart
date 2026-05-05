import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/services/activity_service.dart';

class ShopService {
  final AppDatabase _db;
  final ActivityService _activity;

  ShopService(this._db, {required ActivityService activityService})
      : _activity = activityService;

  // -------- Categories --------

  Future<List<ShopCategory>> getCategories() {
    return (_db.select(_db.shopCategories)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  Future<int> upsertCategory({
    int? id,
    required String name,
    String? description,
    int sortOrder = 0,
  }) {
    final companion = ShopCategoriesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      name: Value(name.trim()),
      description: Value(description?.trim()),
      sortOrder: Value(sortOrder),
      isDirty: const Value(true),
    );
    return _db.into(_db.shopCategories).insertOnConflictUpdate(companion);
  }

  // -------- Suppliers --------

  Future<List<ShopSupplier>> getSuppliers() {
    return (_db.select(_db.shopSuppliers)
          ..orderBy([
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  Future<int> upsertSupplier({
    int? id,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) {
    final companion = ShopSuppliersCompanion(
      id: id == null ? const Value.absent() : Value(id),
      name: Value(name.trim()),
      phone: Value(phone?.trim()),
      email: Value(email?.trim()),
      address: Value(address?.trim()),
      notes: Value(notes?.trim()),
      isDirty: const Value(true),
    );
    return _db.into(_db.shopSuppliers).insertOnConflictUpdate(companion);
  }

  // -------- Items / Inventory --------

  Future<List<ShopItem>> getItems({
    String? query,
    bool activeOnly = true,
    bool? canteenOnly,
  }) {
    final q = _db.select(_db.shopItems);

    if (activeOnly) {
      q.where((t) => t.isActive.equals(true));
    }

    if (canteenOnly != null) {
      q.where((t) => t.isCanteenItem.equals(canteenOnly));
    }

    final trimmed = query?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      q.where(
        (t) =>
            t.name.like('%$trimmed%') |
            t.sku.like('%$trimmed%') |
            t.barcode.like('%$trimmed%'),
      );
    }

    q.orderBy([
      (t) => OrderingTerm.asc(t.name),
    ]);

    return q.get();
  }

  Future<int> upsertItem({
    int? id,
    required String name,
    String category = 'other',
    int? categoryId,
    String? sku,
    String? barcode,
    String? description,
    String? size,
    String? color,
    String? variantGroup,
    String? mandatoryForClassCodes,
    double costPrice = 0,
    double sellingPrice = 0,
    double reorderLevel = 0,
    bool isActive = true,
    bool isPerishable = false,
    bool isCanteenItem = false,
  }) {
    final companion = ShopItemsCompanion(
      id: id == null ? const Value.absent() : Value(id),
      name: Value(name.trim()),
      category: Value(category.trim().isEmpty ? 'other' : category.trim()),
      categoryId: Value(categoryId),
      sku: Value(_nullIfBlank(sku)),
      barcode: Value(_nullIfBlank(barcode)),
      description: Value(_nullIfBlank(description)),
      size: Value(_nullIfBlank(size)),
      color: Value(_nullIfBlank(color)),
      variantGroup: Value(_nullIfBlank(variantGroup)),
      mandatoryForClassCodes: Value(_nullIfBlank(mandatoryForClassCodes)),
      costPrice: Value(costPrice),
      sellingPrice: Value(sellingPrice),
      reorderLevel: Value(reorderLevel),
      isActive: Value(isActive),
      isPerishable: Value(isPerishable),
      isCanteenItem: Value(isCanteenItem),
      isDirty: const Value(true),
    );

    return _db.into(_db.shopItems).insertOnConflictUpdate(companion);
  }

  Future<void> recordStockMovement({
    required int itemId,
    required String movementType,
    required double quantity,
    double? unitCost,
    int? supplierId,
    String? reference,
    String? notes,
    required int actorUserId,
    required String actorName,
    required UserRole actorRole,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be > 0');
    }

    await _db.transaction(() async {
      await _db.into(_db.shopStockMovements).insert(
            ShopStockMovementsCompanion.insert(
              itemId: itemId,
              movementType: Value(movementType.trim().isEmpty ? 'adjust' : movementType.trim()),
              quantity: quantity,
              unitCost: Value(unitCost),
              supplierId: Value(supplierId),
              reference: Value(_nullIfBlank(reference)),
              notes: Value(_nullIfBlank(notes)),
              createdBy: actorUserId,
              isDirty: const Value(true),
            ),
          );

      final delta = _movementDelta(movementType, quantity);
      await _db.customStatement(
        'UPDATE shop_items '
        'SET quantity_on_hand = quantity_on_hand + ?, is_dirty = 1 '
        'WHERE id = ?',
        [delta, itemId],
      );

      // Optional: auto-post purchases to school Expenses for accountant visibility.
      if (movementType.toLowerCase().trim() == 'purchase' && unitCost != null) {
        final item = await (_db.select(_db.shopItems)..where((t) => t.id.equals(itemId))).getSingle();
        final amount = unitCost * quantity;
        await _db.into(_db.expenses).insert(
              ExpensesCompanion.insert(
                description: 'Shop stock purchase: ${item.name} x$quantity',
                amount: amount,
                category: 'Shop Stock',
                recordedBy: actorUserId,
              ),
            );
      }

      await _activity.logActivity(
        actorUserId: actorUserId,
        actorName: actorName,
        actorRole: actorRole,
        module: 'shop',
        actionType: 'stock_$movementType',
        description: 'Stock $movementType for item#$itemId qty=$quantity',
      );
    });
  }

  Future<List<ShopStockMovement>> getRecentMovements({int limit = 50}) {
    return (_db.select(_db.shopStockMovements)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<List<ShopItem>> getLowStockItems() {
    final q = _db.select(_db.shopItems)
      ..where((t) => t.isActive.equals(true) & t.reorderLevel.isBiggerThanValue(0));

    // quantityOnHand <= reorderLevel
    q.where((t) => t.quantityOnHand.isSmallerOrEqual(t.reorderLevel));

    q.orderBy([(t) => OrderingTerm.asc(t.quantityOnHand)]);
    return q.get();
  }

  // -------- POS / Sales --------

  Future<SaleResult> createSale({
    required List<SaleLineInput> lines,
    required String paymentMethod,
    required int actorUserId,
    required String actorName,
    required UserRole actorRole,
    String customerType = 'walkin',
    int? studentId,
    String? customerName,
    double amountReceived = 0,
    String? momoReference,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('Cart is empty');
    }

    final normalizedPayment = paymentMethod.trim().isEmpty ? 'cash' : paymentMethod.trim().toLowerCase();
    final receiptNo = _generateReceiptNo();

    return await _db.transaction(() async {
      final itemsById = await _loadItemsById(lines.map((l) => l.itemId).toSet());

      double total = 0;
      for (final line in lines) {
        final item = itemsById[line.itemId];
        if (item == null) throw StateError('Item not found: ${line.itemId}');
        if (!item.isActive) throw StateError('Item is inactive: ${item.name}');
        if (line.quantity <= 0) throw ArgumentError('Invalid quantity for ${item.name}');
        if (item.quantityOnHand < line.quantity) {
          throw StateError('Insufficient stock for ${item.name} (available ${item.quantityOnHand})');
        }
        final unitPrice = line.unitPrice ?? item.sellingPrice;
        total += unitPrice * line.quantity;
      }

      if (normalizedPayment == 'wallet') {
        if (studentId == null) throw ArgumentError('Student is required for wallet payment');
        final wallet = await _getOrCreateWallet(studentId);
        if (wallet.balance < total) {
          throw StateError('Insufficient wallet balance (GHS ${wallet.balance.toStringAsFixed(2)})');
        }
      }

        final changeGiven = (normalizedPayment == 'cash')
          ? (amountReceived - total).clamp(0, double.infinity).toDouble()
          : 0.0;

      final saleId = await _db.into(_db.shopSales).insert(
            ShopSalesCompanion.insert(
              receiptNo: receiptNo,
              paymentMethod: Value(normalizedPayment),
              customerType: Value(customerType.trim().isEmpty ? 'walkin' : customerType.trim()),
              studentId: Value(studentId),
              customerName: Value(_nullIfBlank(customerName)),
              totalAmount: total,
              amountReceived: Value(amountReceived),
              changeGiven: Value(changeGiven),
              momoReference: Value(_nullIfBlank(momoReference)),
              soldBy: actorUserId,
              isDirty: const Value(true),
            ),
          );

      for (final line in lines) {
        final item = itemsById[line.itemId]!;
        final unitPrice = line.unitPrice ?? item.sellingPrice;
        final lineTotal = unitPrice * line.quantity;

        await _db.into(_db.shopSaleItems).insert(
              ShopSaleItemsCompanion.insert(
                saleId: saleId,
                itemId: item.id,
                quantity: line.quantity,
                unitPrice: unitPrice,
                lineTotal: lineTotal,
                isDirty: const Value(true),
              ),
            );

        await _db.into(_db.shopStockMovements).insert(
              ShopStockMovementsCompanion.insert(
                itemId: item.id,
                movementType: const Value('sale'),
                quantity: line.quantity,
                createdBy: actorUserId,
                reference: Value(receiptNo),
                isDirty: const Value(true),
              ),
            );

        await (_db.update(_db.shopItems)..where((t) => t.id.equals(item.id))).write(
          ShopItemsCompanion(
            quantityOnHand: Value(item.quantityOnHand - line.quantity),
            isDirty: const Value(true),
          ),
        );
      }

      if (normalizedPayment == 'wallet') {
        final wallet = await _getOrCreateWallet(studentId!);
        await (_db.update(_db.studentWallets)..where((t) => t.studentId.equals(studentId))).write(
          StudentWalletsCompanion(
            balance: Value(wallet.balance - total),
            updatedAt: Value(DateTime.now()),
            isDirty: const Value(true),
          ),
        );

        await _db.into(_db.walletTransactions).insert(
              WalletTransactionsCompanion.insert(
                studentId: studentId,
                type: 'purchase',
                amount: -total,
                saleId: Value(saleId),
                reference: Value(receiptNo),
                createdBy: actorUserId,
                isDirty: const Value(true),
              ),
            );
      }

      await _activity.logActivity(
        actorUserId: actorUserId,
        actorName: actorName,
        actorRole: actorRole,
        module: 'shop',
        actionType: 'sale',
        description: 'Sale $receiptNo total=GHS ${total.toStringAsFixed(2)} method=$normalizedPayment',
        isImportant: total >= 500,
      );

      return SaleResult(
        saleId: saleId,
        receiptNo: receiptNo,
        totalAmount: total,
        changeGiven: changeGiven,
      );
    });
  }

  Future<List<ShopSale>> getRecentSales({int limit = 30, String? query}) {
    final q = _db.select(_db.shopSales)
      ..orderBy([(t) => OrderingTerm.desc(t.soldAt)])
      ..limit(limit);

    final trimmed = query?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      q.where(
        (t) =>
            t.receiptNo.like('%$trimmed%') |
            t.customerName.like('%$trimmed%') |
            t.paymentMethod.like('%$trimmed%') |
            t.customerType.like('%$trimmed%'),
      );
    }

    return q.get();
  }

  Future<List<ShopSaleItem>> getSaleItems(int saleId) {
    return (_db.select(_db.shopSaleItems)..where((t) => t.saleId.equals(saleId))).get();
  }

  Future<ShopSaleDetail?> getSaleDetail(int saleId) async {
    final sale = await (_db.select(_db.shopSales)..where((t) => t.id.equals(saleId))).getSingleOrNull();
    if (sale == null) return null;

    final lines = await (_db.select(_db.shopSaleItems)..where((t) => t.saleId.equals(sale.id))).get();
    final itemIds = lines.map((l) => l.itemId).toSet();
    final itemsById = await _loadItemsById(itemIds);

    final detailLines = lines
        .map((line) => ShopSaleLineDetail(line: line, item: itemsById[line.itemId]))
        .toList(growable: false);

    return ShopSaleDetail(sale: sale, lines: detailLines);
  }

  Future<int> bulkRestockItems({
    required List<int> itemIds,
    required double addQuantity,
    double? unitCost,
    String? notes,
    required int actorUserId,
    required String actorName,
    required UserRole actorRole,
  }) async {
    if (itemIds.isEmpty) return 0;
    if (addQuantity <= 0) throw ArgumentError('Restock quantity must be > 0');

    final uniqueItemIds = itemIds.toSet().toList(growable: false);
    final items = await (_db.select(_db.shopItems)..where((t) => t.id.isIn(uniqueItemIds))).get();
    if (items.isEmpty) return 0;

    await _db.transaction(() async {
      for (final item in items) {
        await _db.into(_db.shopStockMovements).insert(
              ShopStockMovementsCompanion.insert(
                itemId: item.id,
                movementType: const Value('purchase'),
                quantity: addQuantity,
                unitCost: Value(unitCost),
                notes: Value(_nullIfBlank(notes)),
                createdBy: actorUserId,
                isDirty: const Value(true),
              ),
            );

        await (_db.update(_db.shopItems)..where((t) => t.id.equals(item.id))).write(
          ShopItemsCompanion(
            quantityOnHand: Value(item.quantityOnHand + addQuantity),
            isDirty: const Value(true),
          ),
        );

        if (unitCost != null && unitCost > 0) {
          await _db.into(_db.expenses).insert(
                ExpensesCompanion.insert(
                  description: 'Bulk restock: ${item.name} x$addQuantity',
                  amount: unitCost * addQuantity,
                  category: 'Shop Stock',
                  recordedBy: actorUserId,
                ),
              );
        }
      }

      await _activity.logActivity(
        actorUserId: actorUserId,
        actorName: actorName,
        actorRole: actorRole,
        module: 'shop',
        actionType: 'bulk_restock',
        description: 'Bulk restock ${items.length} items by $addQuantity units',
        isImportant: items.length >= 10,
      );
    });

    return items.length;
  }

  Future<String> exportInventoryCsv({List<int>? itemIds}) async {
    final items = itemIds == null || itemIds.isEmpty
        ? await getItems(activeOnly: false)
        : await (_db.select(_db.shopItems)..where((t) => t.id.isIn(itemIds))).get();

    final rows = <List<dynamic>>[
      [
        'id',
        'name',
        'category',
        'sku',
        'barcode',
        'cost_price',
        'selling_price',
        'quantity_on_hand',
        'reorder_level',
        'is_active',
        'is_canteen_item',
      ],
      ...items.map(
        (i) => [
          i.id,
          i.name,
          i.category,
          i.sku ?? '',
          i.barcode ?? '',
          i.costPrice,
          i.sellingPrice,
          i.quantityOnHand,
          i.reorderLevel,
          i.isActive ? 1 : 0,
          i.isCanteenItem ? 1 : 0,
        ],
      ),
    ];

    return const ListToCsvConverter().convert(rows);
  }

  Future<InventoryCsvImportResult> importInventoryCsvText({
    required String csvText,
    required int actorUserId,
    required String actorName,
    required UserRole actorRole,
  }) async {
    final trimmed = csvText.trim();
    if (trimmed.isEmpty) {
      return const InventoryCsvImportResult(imported: 0, updated: 0, failed: 0, errors: ['CSV is empty']);
    }

    final rawRows = const CsvToListConverter(shouldParseNumbers: false).convert(trimmed, eol: '\n');
    if (rawRows.isEmpty) {
      return const InventoryCsvImportResult(imported: 0, updated: 0, failed: 0, errors: ['CSV has no rows']);
    }

    final headers = rawRows.first.map((c) => c.toString().trim().toLowerCase()).toList(growable: false);
    final dataRows = rawRows.skip(1).toList(growable: false);

    int idx(String name) => headers.indexOf(name);
    final idxName = idx('name');
    if (idxName < 0) {
      return const InventoryCsvImportResult(
        imported: 0,
        updated: 0,
        failed: 0,
        errors: ['Missing required column: name'],
      );
    }

    int imported = 0;
    int updated = 0;
    int failed = 0;
    final errors = <String>[];

    final idxId = idx('id');
    final idxCategory = idx('category');
    final idxSku = idx('sku');
    final idxBarcode = idx('barcode');
    final idxCost = idx('cost_price');
    final idxSelling = idx('selling_price');
    final idxQty = idx('quantity_on_hand');
    final idxReorder = idx('reorder_level');
    final idxActive = idx('is_active');
    final idxCanteen = idx('is_canteen_item');

    await _db.transaction(() async {
      for (var i = 0; i < dataRows.length; i++) {
        final rowNo = i + 2;
        final row = dataRows[i];

        String? readStr(int index) {
          if (index < 0 || index >= row.length) return null;
          final v = row[index].toString().trim();
          return v.isEmpty ? null : v;
        }

        double readDouble(int index, {double fallback = 0}) {
          final s = readStr(index);
          if (s == null) return fallback;
          return double.tryParse(s) ?? fallback;
        }

        bool readBool(int index, {bool fallback = true}) {
          final s = readStr(index);
          if (s == null) return fallback;
          final n = s.toLowerCase();
          return n == '1' || n == 'true' || n == 'yes' || n == 'y';
        }

        final name = readStr(idxName);
        if (name == null) {
          failed++;
          errors.add('Row $rowNo: name is required');
          continue;
        }

        final id = int.tryParse(readStr(idxId) ?? '');
        final sku = readStr(idxSku);
        final barcode = readStr(idxBarcode);

        ShopItem? existing;
        if (id != null) {
          existing = await (_db.select(_db.shopItems)..where((t) => t.id.equals(id))).getSingleOrNull();
        }
        if (existing == null && sku != null) {
          existing = await (_db.select(_db.shopItems)..where((t) => t.sku.equals(sku))).getSingleOrNull();
        }
        if (existing == null && barcode != null) {
          existing = await (_db.select(_db.shopItems)..where((t) => t.barcode.equals(barcode))).getSingleOrNull();
        }

        try {
          final persistedId = await upsertItem(
            id: existing?.id,
            name: name,
            category: readStr(idxCategory) ?? existing?.category ?? 'other',
            sku: sku ?? existing?.sku,
            barcode: barcode ?? existing?.barcode,
            costPrice: readDouble(idxCost, fallback: existing?.costPrice ?? 0),
            sellingPrice: readDouble(idxSelling, fallback: existing?.sellingPrice ?? 0),
            reorderLevel: readDouble(idxReorder, fallback: existing?.reorderLevel ?? 0),
            isActive: readBool(idxActive, fallback: existing?.isActive ?? true),
            isCanteenItem: readBool(idxCanteen, fallback: existing?.isCanteenItem ?? false),
          );

          final savedItemId = existing?.id ?? persistedId;
          final savedItem = await (_db.select(_db.shopItems)..where((t) => t.id.equals(savedItemId))).getSingleOrNull();
          if (savedItem == null) {
            throw StateError('Imported item could not be reloaded after save');
          }

          final targetQty = readDouble(idxQty, fallback: savedItem.quantityOnHand);
          final delta = targetQty - savedItem.quantityOnHand;
          if (delta > 0) {
            final unitCost = readDouble(idxCost, fallback: savedItem.costPrice);
            await _db.into(_db.shopStockMovements).insert(
                  ShopStockMovementsCompanion.insert(
                    itemId: savedItem.id,
                    movementType: const Value('purchase'),
                    quantity: delta,
                    unitCost: unitCost > 0 ? Value(unitCost) : const Value.absent(),
                    notes: const Value('CSV inventory import'),
                    createdBy: actorUserId,
                    isDirty: const Value(true),
                  ),
                );

            await (_db.update(_db.shopItems)..where((t) => t.id.equals(savedItem.id))).write(
              ShopItemsCompanion(
                quantityOnHand: Value(targetQty),
                isDirty: const Value(true),
              ),
            );

            if (unitCost > 0) {
              await _db.into(_db.expenses).insert(
                    ExpensesCompanion.insert(
                      description: 'CSV import stock purchase: ${savedItem.name} x$delta',
                      amount: unitCost * delta,
                      category: 'Shop Stock',
                      recordedBy: actorUserId,
                    ),
                  );
            }
          } else if (delta < 0) {
            await _db.into(_db.shopStockMovements).insert(
                  ShopStockMovementsCompanion.insert(
                    itemId: savedItem.id,
                    movementType: const Value('out'),
                    quantity: delta.abs(),
                    notes: const Value('CSV inventory import adjustment'),
                    createdBy: actorUserId,
                    isDirty: const Value(true),
                  ),
                );

            await (_db.update(_db.shopItems)..where((t) => t.id.equals(savedItem.id))).write(
              ShopItemsCompanion(
                quantityOnHand: Value(targetQty),
                isDirty: const Value(true),
              ),
            );
          }

          if (existing == null) {
            imported++;
          } else {
            updated++;
          }
        } catch (e) {
          failed++;
          errors.add('Row $rowNo: $e');
        }
      }

      await _activity.logActivity(
        actorUserId: actorUserId,
        actorName: actorName,
        actorRole: actorRole,
        module: 'shop',
        actionType: 'inventory_csv_import',
        description: 'Inventory CSV import: imported=$imported updated=$updated failed=$failed',
        isImportant: failed > 0,
      );
    });

    return InventoryCsvImportResult(imported: imported, updated: updated, failed: failed, errors: errors);
  }

  // -------- Wallet --------

  Future<StudentWallet> _getOrCreateWallet(int studentId) async {
    final existing = await (_db.select(_db.studentWallets)..where((t) => t.studentId.equals(studentId))).getSingleOrNull();
    if (existing != null) return existing;

    final id = await _db.into(_db.studentWallets).insert(
          StudentWalletsCompanion.insert(
            studentId: studentId,
            balance: const Value(0.0),
            isDirty: const Value(true),
          ),
        );
    return (await (_db.select(_db.studentWallets)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<StudentWallet?> getWallet(int studentId) {
    return (_db.select(_db.studentWallets)..where((t) => t.studentId.equals(studentId))).getSingleOrNull();
  }

  Future<void> topUpWallet({
    required int studentId,
    required double amount,
    required int actorUserId,
    required String actorName,
    required UserRole actorRole,
    String? reference,
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be > 0');

    await _db.transaction(() async {
      final wallet = await _getOrCreateWallet(studentId);
      await (_db.update(_db.studentWallets)..where((t) => t.studentId.equals(studentId))).write(
        StudentWalletsCompanion(
          balance: Value(wallet.balance + amount),
          updatedAt: Value(DateTime.now()),
          isDirty: const Value(true),
        ),
      );

      await _db.into(_db.walletTransactions).insert(
            WalletTransactionsCompanion.insert(
              studentId: studentId,
              type: 'topup',
              amount: amount,
              reference: Value(_nullIfBlank(reference)),
              createdBy: actorUserId,
              isDirty: const Value(true),
            ),
          );

      await _activity.logActivity(
        actorUserId: actorUserId,
        actorName: actorName,
        actorRole: actorRole,
        module: 'shop',
        actionType: 'wallet_topup',
        description: 'Wallet top-up student#$studentId amount=GHS ${amount.toStringAsFixed(2)}',
      );
    });
  }

  Future<List<WalletTransaction>> getWalletTransactions(int studentId, {int limit = 50}) {
    return (_db.select(_db.walletTransactions)
          ..where((t) => t.studentId.equals(studentId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  // -------- Helpers --------

  Future<Map<int, ShopItem>> _loadItemsById(Set<int> ids) async {
    if (ids.isEmpty) return <int, ShopItem>{};
    final rows = await (_db.select(_db.shopItems)..where((t) => t.id.isIn(ids))).get();
    return {for (final r in rows) r.id: r};
  }

  static String _generateReceiptNo() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return 'SHOP-$y$m$d-$hh$mm$ss$ms';
  }

  static double _movementDelta(String movementType, double qty) {
    final t = movementType.toLowerCase().trim();
    switch (t) {
      case 'purchase':
      case 'in':
      case 'return':
        return qty;
      case 'sale':
      case 'issue':
      case 'out':
        return -qty;
      case 'adjust':
      default:
        // Treat adjust as positive by default (UI can use out/in for direction)
        return qty;
    }
  }

  static String? _nullIfBlank(String? v) {
    final t = v?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }
}

class SaleLineInput {
  final int itemId;
  final double quantity;
  final double? unitPrice;

  const SaleLineInput({
    required this.itemId,
    required this.quantity,
    this.unitPrice,
  });
}

class SaleResult {
  final int saleId;
  final String receiptNo;
  final double totalAmount;
  final double changeGiven;

  const SaleResult({
    required this.saleId,
    required this.receiptNo,
    required this.totalAmount,
    required this.changeGiven,
  });
}

class ShopSaleLineDetail {
  final ShopSaleItem line;
  final ShopItem? item;

  const ShopSaleLineDetail({required this.line, required this.item});
}

class ShopSaleDetail {
  final ShopSale sale;
  final List<ShopSaleLineDetail> lines;

  const ShopSaleDetail({required this.sale, required this.lines});

  double get totalUnits => lines.fold(0, (sum, l) => sum + l.line.quantity);
}

class InventoryCsvImportResult {
  final int imported;
  final int updated;
  final int failed;
  final List<String> errors;

  const InventoryCsvImportResult({
    required this.imported,
    required this.updated,
    required this.failed,
    required this.errors,
  });
}
