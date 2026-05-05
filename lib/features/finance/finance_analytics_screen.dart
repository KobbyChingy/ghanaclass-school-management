import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';

import 'staff_payroll_trends_chart.dart';
import 'alerts_thresholds_card.dart';
import 'custom_export_card.dart';
import 'interactive_dashboard_card.dart';
import 'asset_depreciation_maintenance_card.dart';
import 'budget_forecast_variance_card.dart';
import 'finance_analytics_providers.dart';
import 'revenue_and_profit_card.dart';
import 'year_over_year_comparison_chart.dart';
import 'fee_collection_rate_card.dart';
import 'top_debtors_card.dart';
import 'expense_trends_chart.dart';
import 'cash_flow_forecast_card.dart';
import 'payment_method_analysis_chart.dart';

class FinanceAnalyticsScreen extends ConsumerWidget {
  const FinanceAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(activeYearProvider);
    final incomeAsync = ref.watch(monthlyIncomeProvider(year));
    final expenseAsync = ref.watch(monthlyExpensesProvider(year));
    final categoriesAsync = ref.watch(expenseCategoryTotalsProvider(year));

    return Scaffold(
      appBar: AppBar(
        title: Text('Financial Analytics - $year'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RevenueAndProfitCard(year: year),
            const SizedBox(height: 24),
            YearOverYearComparisonChart(),
            const SizedBox(height: 24),
            FeeCollectionRateCard(year: year),
            const SizedBox(height: 24),
            TopDebtorsCard(),
            const SizedBox(height: 24),
            ExpenseTrendsChart(year: year),
            const SizedBox(height: 24),
            CashFlowForecastCard(year: year),
            const SizedBox(height: 24),
            PaymentMethodAnalysisChart(year: year),
            const SizedBox(height: 24),
            StaffPayrollTrendsChart(),
            const SizedBox(height: 24),
            AlertsThresholdsCard(),
            const SizedBox(height: 24),
            CustomExportCard(),
            const SizedBox(height: 24),
            InteractiveDashboardCard(),
            const SizedBox(height: 24),
            const AssetDepreciationMaintenanceCard(),
            const SizedBox(height: 24),
            const BudgetForecastVarianceCard(),
            const SizedBox(height: 24),
            _buildSummaryCards(incomeAsync, expenseAsync),
            const SizedBox(height: 32),
            const Text('Monthly Income vs Expenses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildIncomeExpenseChart(incomeAsync, expenseAsync),
            const SizedBox(height: 48),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;
                final distribution = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Expense Distribution', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildExpenseCategoryChart(categoriesAsync),
                  ],
                );
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildCategoryList(categoriesAsync),
                  ],
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      distribution,
                      const SizedBox(height: 24),
                      details,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: distribution),
                    const SizedBox(width: 32),
                    Expanded(flex: 2, child: details),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(AsyncValue<Map<int, double>> incomeAsync, AsyncValue<Map<int, double>> expenseAsync) {
    final totalIncome = incomeAsync.whenData((m) => m.values.fold(0.0, (a, b) => a + b)).value ?? 0.0;
    final totalExpense = expenseAsync.whenData((m) => m.values.fold(0.0, (a, b) => a + b)).value ?? 0.0;
    final balance = totalIncome - totalExpense;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        final cards = [
          _summaryCard('Total Income', totalIncome, LucideIcons.trendingUp, Colors.green),
          _summaryCard('Total Expenses', totalExpense, LucideIcons.trendingDown, Colors.red),
          _summaryCard('Net Balance', balance, LucideIcons.wallet, AppTheme.actionIndigo),
        ];

        if (stacked) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 16),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 24),
            ],
          ],
        );
      },
    );
  }

  Widget _summaryCard(String title, double amount, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              Text(
                'GH₵ ${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseChart(AsyncValue<Map<int, double>> incomeAsync, AsyncValue<Map<int, double>> expenseAsync) {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: incomeAsync.when(
        data: (income) => expenseAsync.when(
          data: (expense) {
            return LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                        if (val.toInt() >= 1 && val.toInt() <= 12) {
                          return Text(months[val.toInt()], style: const TextStyle(fontSize: 10));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: income.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 4,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.green.withValues(alpha: 0.1)),
                  ),
                  LineChartBarData(
                    spots: expense.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 4,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.red.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildExpenseCategoryChart(AsyncValue<Map<String, double>> categoriesAsync) {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: categoriesAsync.when(
        data: (data) {
          if (data.isEmpty) return const Center(child: Text('No expense data.'));
          final colors = [AppTheme.actionIndigo, Colors.red, Colors.orange, Colors.blue, Colors.green, Colors.purple];
          int i = 0;
          final total = data.values.fold<double>(0.0, (a, b) => a + b);

          return PieChart(
            PieChartData(
              sections: data.entries.map((e) {
                final color = colors[i++ % colors.length];
                return PieChartSectionData(
                  value: e.value,
                  title: total <= 0 ? '0%' : '${((e.value / total) * 100).toStringAsFixed(0)}%',
                  color: color,
                  radius: 100,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildCategoryList(AsyncValue<Map<String, double>> categoriesAsync) {
    return categoriesAsync.when(
      data: (data) => ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        itemBuilder: (context, index) {
          final entry = data.entries.elementAt(index);
          return ListTile(
            leading: const Icon(LucideIcons.tag, size: 16),
            title: Text(entry.key),
            trailing: Text('GH₵ ${entry.value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        },
      ),
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}
