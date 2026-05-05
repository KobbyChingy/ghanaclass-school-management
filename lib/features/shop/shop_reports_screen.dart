import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/core/providers/database_provider.dart';
import 'package:ghanaclass_school_management/features/shop/shop_providers.dart';
import 'package:ghanaclass_school_management/shared/widgets/portal_surface.dart';

class ShopReportsScreen extends ConsumerWidget {
  const ShopReportsScreen({super.key});

  Future<_SalesSummary> _loadTodaySummary(WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final rows = await db.customSelect(
      'SELECT COUNT(*) AS cnt, COALESCE(SUM(total_amount), 0) AS total '
      'FROM shop_sales '
      "WHERE sold_at >= ? AND sold_at < ? AND status = 'completed'",
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
      readsFrom: {db.shopSales},
    ).getSingle();

    final cnt = (rows.data['cnt'] as int?) ?? 0;
    final total = (rows.data['total'] as num?)?.toDouble() ?? 0.0;
    return _SalesSummary(count: cnt, total: total);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academicYear = ref.watch(activeYearProvider);
    final term = ref.watch(activeTermProvider);
    final lowAsync = ref.watch(shopLowStockItemsProvider);
    final salesAsync = ref.watch(shopRecentSalesProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            PortalHeroBanner(
              eyebrow: 'Shop reports',
              title: 'Sales & Stock Reporting',
              subtitle: 'Monitor daily sales velocity, low-stock exposure, and recent receipts for the active term.',
              icon: Icons.bar_chart_outlined,
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
                    label: const Text('Back to POS'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.go('/inventory'),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Inventory'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<_SalesSummary>(
              future: _loadTodaySummary(ref),
              builder: (context, snapshot) {
                final data = snapshot.data;
                return Row(
                  children: [
                    Expanded(
                      child: PortalSectionPanel(
                        title: 'Today',
                        subtitle: 'Completed shop sales processed today.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sales: ${data?.count ?? 0}'),
                            Text('Total: GHS ${(data?.total ?? 0).toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PortalSectionPanel(
                        title: 'Low Stock',
                        subtitle: 'Items approaching reorder thresholds.',
                        child: lowAsync.when(
                          data: (low) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Items: ${low.length}'),
                              if (low.isNotEmpty) Text('Next: ${low.first.name}'),
                            ],
                          ),
                          loading: () => const Text('Low Stock: ...'),
                          error: (e, _) => Text('Low stock error: $e'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PortalSectionPanel(
                title: 'Recent Sales',
                subtitle: 'Most recent completed receipts and payment traces.',
                child: salesAsync.when(
                  data: (sales) {
                    if (sales.isEmpty) return const Center(child: Text('No sales yet'));
                    return ListView.separated(
                      itemCount: sales.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final s = sales[index];
                        return ListTile(
                          title: Text('${s.receiptNo} • GHS ${s.totalAmount.toStringAsFixed(2)}'),
                          subtitle: Text('${s.soldAt} • ${s.paymentMethod} • ${s.customerType}'),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesSummary {
  final int count;
  final double total;

  const _SalesSummary({required this.count, required this.total});
}
