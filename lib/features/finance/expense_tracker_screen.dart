import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/features/finance/finance_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/features/director/director_kpi_providers.dart';
import 'package:drift/drift.dart' as drift;

class ExpenseTrackerScreen extends ConsumerStatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  ConsumerState<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends ConsumerState<ExpenseTrackerScreen> {
  String _selectedCategory = 'All';
  final List<String> _baseCategories = ['All', 'Utility', 'Maintenance', 'Admin', 'Supplies', 'Academics', 'Other', 'Shop Stock'];

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(combinedExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Institutional Expenses'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showAddExpenseDialog(context),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Log Expense'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.actionIndigo,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final expensesList = expensesAsync.when(
            data: (expenses) {
                final filtered = _selectedCategory == 'All'
                  ? expenses
                  : expenses.where((e) => e.category == _selectedCategory).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('No expenses recorded in this category.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final e = filtered[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getCategoryColor(e.category).withValues(alpha: 0.1),
                        child: Icon(_getCategoryIcon(e.category), color: _getCategoryColor(e.category), size: 20),
                      ),
                      title: Text(e.description ?? e.category),
                      subtitle: Text(
                        '${e.isInstitutional ? 'Institutional' : 'Operating'} • ${DateFormat('MMM dd, yyyy').format(e.expenseDate)}',
                      ),
                      trailing: Text(
                        'GH₵ ${e.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );

          final compactHeight = constraints.maxHeight < 760;
          if (compactHeight) {
            return ListView(
              children: [
                _buildSummaryBar(expensesAsync),
                _buildFilterBar(expensesAsync),
                SizedBox(height: 360, child: expensesList),
              ],
            );
          }

          return Column(
            children: [
              _buildSummaryBar(expensesAsync),
              _buildFilterBar(expensesAsync),
              Expanded(child: expensesList),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryBar(AsyncValue<List<FinanceExpenseEntry>> async) {
    return async.when(
      data: (list) {
        final total = list.fold<double>(0, (sum, e) => sum + e.amount);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Wrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              _StatItem(label: 'Total Expenditures', value: 'GH₵ ${total.toStringAsFixed(2)}', icon: LucideIcons.trendingDown, color: AppTheme.error),
              _StatItem(label: 'Last Logged', value: list.isEmpty ? 'N/A' : DateFormat('MMM dd').format(list.first.expenseDate), icon: LucideIcons.calendar, color: AppTheme.textMuted),
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildFilterBar(AsyncValue<List<FinanceExpenseEntry>> async) {
    final categories = async.maybeWhen(
      data: (items) {
        final dynamicCategories = items
            .map((e) => e.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        return <String>{..._baseCategories, ...dynamicCategories}.toList(growable: false);
      },
      orElse: () => _baseCategories,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (v) => setState(() => _selectedCategory = cat),
              selectedColor: AppTheme.actionIndigo.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.actionIndigo,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _AddExpenseDialog(),
    ).then((_) => ref.refresh(combinedExpensesProvider));
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Utility': return Colors.blue;
      case 'Maintenance': return Colors.orange;
      case 'Admin': return Colors.purple;
      case 'Supplies': return Colors.teal;
      default: return AppTheme.textMuted;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Utility': return LucideIcons.zap;
      case 'Maintenance': return Icons.build;
      case 'Admin': return LucideIcons.fileText;
      case 'Supplies': return LucideIcons.package;
      default: return LucideIcons.dollarSign;
    }
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
      ],
    );
  }
}

class _AddExpenseDialog extends ConsumerStatefulWidget {
  const _AddExpenseDialog();

  @override
  ConsumerState<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<_AddExpenseDialog> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'Utility';
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log New Expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: ['Utility', 'Maintenance', 'Admin', 'Supplies', 'Academics', 'Other']
                .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _category = v!),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Amount (GH₵)'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Description / Payee'),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Expense Date'),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(_date)),
            trailing: const Icon(LucideIcons.calendar),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final amount = double.tryParse(_amountController.text) ?? 0.0;
            if (amount <= 0) return;

            final admin = ref.read(currentUserProvider)!;
            await ref.read(financeServiceProvider).addInstitutionalExpense(InstitutionalExpensesCompanion.insert(
              category: _category,
              amount: amount,
              description: drift.Value(_descController.text),
              expenseDate: _date,
              recordedBy: admin.id,
            ));
            final activeYear = ref.read(activeYearProvider);
            ref.invalidate(institutionalExpensesProvider);
            ref.invalidate(combinedExpensesProvider);
            ref.invalidate(monthlyExpensesProvider(_date.year));
            ref.invalidate(totalExpenseProvider(_date.year));
            if (activeYear != _date.year) {
              ref.invalidate(monthlyExpensesProvider(activeYear));
              ref.invalidate(totalExpenseProvider(activeYear));
            }
            ref.invalidate(yearlyExpenseProvider);
            ref.invalidate(directorKpisProvider);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Record Expense'),
        ),
      ],
    );
  }
}
