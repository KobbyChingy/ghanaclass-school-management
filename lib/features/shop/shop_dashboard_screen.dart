import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/core/providers/database_provider.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/features/shop/shop_providers.dart';
import 'package:ghanaclass_school_management/shared/widgets/portal_surface.dart';

class ShopDashboardScreen extends ConsumerWidget {
  const ShopDashboardScreen({super.key});

  Future<_ShopDashboardSnapshot> _loadSnapshot(WidgetRef ref) async {
    final service = ref.read(shopServiceProvider);
    final db = ref.read(databaseProvider);

    final itemsFuture = service.getItems();
    final lowFuture = service.getLowStockItems();
    final salesFuture = service.getRecentSales(limit: 10);
    final movementsFuture = service.getRecentMovements(limit: 10);

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final salesRowFuture = db.customSelect(
      'SELECT COUNT(*) AS cnt, COALESCE(SUM(total_amount), 0) AS total '
      'FROM shop_sales '
      "WHERE sold_at >= ? AND sold_at < ? AND status = 'completed'",
      variables: [Variable<DateTime>(dayStart), Variable<DateTime>(dayEnd)],
      readsFrom: {db.shopSales},
    ).getSingle();

    final values = await Future.wait<dynamic>([
      itemsFuture,
      lowFuture,
      salesFuture,
      movementsFuture,
      salesRowFuture,
    ]);

    final items = values[0] as List<dynamic>;
    final lowStock = values[1] as List<dynamic>;
    final recentSales = values[2] as List<dynamic>;
    final recentMovements = values[3] as List<dynamic>;
    final salesRow = values[4];

    final outOfStockCount = items.where((i) => (i.quantityOnHand as double) <= 0).length;
    final inventoryValue = items.fold<double>(
      0,
      (sum, i) => sum + ((i.quantityOnHand as double) * (i.costPrice as double)),
    );

    final salesCount = (salesRow.data['cnt'] as int?) ?? 0;
    final salesTotal = (salesRow.data['total'] as num?)?.toDouble() ?? 0.0;

    return _ShopDashboardSnapshot(
      itemCount: items.length,
      lowStockCount: lowStock.length,
      outOfStockCount: outOfStockCount,
      todaySalesCount: salesCount,
      todaySalesTotal: salesTotal,
      inventoryValue: inventoryValue,
      lowStockItems: lowStock,
      recentSales: recentSales,
      recentMovements: recentMovements,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academicYear = ref.watch(activeYearProvider);
    final term = ref.watch(activeTermProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            PortalHeroBanner(
              eyebrow: 'Shop portal',
              title: 'Dashboard & Daily Command Center',
              subtitle:
                  'Track stock health, monitor sales momentum, and jump into POS or inventory actions quickly.',
              icon: Icons.storefront_outlined,
              primary: const Color(0xFFD97706),
              accent: const Color(0xFF2563EB),
              metrics: [
                PortalHeroMetric(label: 'Academic year', value: '$academicYear'),
                PortalHeroMetric(label: 'Active term', value: 'Term $term'),
              ],
              trailing: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => context.go('/pos'),
                    icon: const Icon(Icons.point_of_sale_outlined),
                    label: const Text('POS'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.go('/inventory'),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Inventory'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.go('/shop/reports'),
                    icon: const Icon(Icons.bar_chart_outlined),
                    label: const Text('Reports'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<_ShopDashboardSnapshot>(
                future: _loadSnapshot(ref),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(child: Text('Unable to load dashboard: ${snapshot.error}'));
                  }

                  final data = snapshot.data!;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 980;

                      final kpis = [
                        _KpiCard(
                          title: 'Today sales',
                          value: 'GHS ${data.todaySalesTotal.toStringAsFixed(2)}',
                          subtitle: '${data.todaySalesCount} completed receipts',
                          tone: const Color(0xFF0EA5E9),
                        ),
                        _KpiCard(
                          title: 'Items in catalog',
                          value: '${data.itemCount}',
                          subtitle: '${data.outOfStockCount} out of stock',
                          tone: const Color(0xFF8B5CF6),
                        ),
                        _KpiCard(
                          title: 'Low stock alerts',
                          value: '${data.lowStockCount}',
                          subtitle: 'Reorder attention needed',
                          tone: const Color(0xFFF97316),
                        ),
                        _KpiCard(
                          title: 'Inventory value',
                          value: 'GHS ${data.inventoryValue.toStringAsFixed(2)}',
                          subtitle: 'Based on current cost prices',
                          tone: const Color(0xFF16A34A),
                        ),
                      ];

                      final lowStockPanel = PortalSectionPanel(
                        title: 'Low Stock Priority List',
                        subtitle: 'Items at or below reorder threshold.',
                        expandChild: true,
                        child: data.lowStockItems.isEmpty
                            ? const Center(child: Text('No low-stock items right now.'))
                            : ListView.separated(
                                itemCount: data.lowStockItems.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = data.lowStockItems[index];
                                  return ListTile(
                                    title: Text(item.name),
                                    subtitle: Text(
                                      'Stock ${item.quantityOnHand.toStringAsFixed(0)} '
                                      'of reorder ${item.reorderLevel.toStringAsFixed(0)}',
                                    ),
                                    trailing: OutlinedButton(
                                      onPressed: () => context.go('/inventory'),
                                      child: const Text('Restock'),
                                    ),
                                  );
                                },
                              ),
                      );

                      final activityPanel = PortalSectionPanel(
                        title: 'Recent Sales & Movements',
                        subtitle: 'Latest checkout and stock activity.',
                        expandChild: true,
                        child: ListView(
                          children: [
                            ...data.recentSales.take(6).map(
                              (sale) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.receipt_long_outlined, size: 18),
                                title: Text('${sale.receiptNo} • GHS ${sale.totalAmount.toStringAsFixed(2)}'),
                                subtitle: Text('${sale.paymentMethod} • ${sale.customerType}'),
                              ),
                            ),
                            const Divider(height: 20),
                            ...data.recentMovements.take(6).map(
                              (m) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.swap_vert_circle_outlined, size: 18),
                                title: Text('${m.movementType.toUpperCase()} • Qty ${m.quantity.toStringAsFixed(0)}'),
                                subtitle: Text('Item #${m.itemId}'),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (compact) {
                        return ListView(
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final kpi in kpis)
                                  SizedBox(
                                    width: constraints.maxWidth < 640 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2,
                                    child: kpi,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(height: 420, child: lowStockPanel),
                            const SizedBox(height: 12),
                            SizedBox(height: 420, child: activityPanel),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: kpis[0]),
                              const SizedBox(width: 12),
                              Expanded(child: kpis[1]),
                              const SizedBox(width: 12),
                              Expanded(child: kpis[2]),
                              const SizedBox(width: 12),
                              Expanded(child: kpis[3]),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: lowStockPanel),
                                const SizedBox(width: 12),
                                Expanded(child: activityPanel),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color tone;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ShopDashboardSnapshot {
  final int itemCount;
  final int lowStockCount;
  final int outOfStockCount;
  final int todaySalesCount;
  final double todaySalesTotal;
  final double inventoryValue;
  final List<dynamic> lowStockItems;
  final List<dynamic> recentSales;
  final List<dynamic> recentMovements;

  const _ShopDashboardSnapshot({
    required this.itemCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.todaySalesCount,
    required this.todaySalesTotal,
    required this.inventoryValue,
    required this.lowStockItems,
    required this.recentSales,
    required this.recentMovements,
  });
}
