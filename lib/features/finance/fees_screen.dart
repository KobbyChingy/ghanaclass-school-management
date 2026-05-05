import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'finance_providers.dart';
import 'finance_service.dart';
import 'fee_reminders_tracking_card.dart';
import 'fee_payment_screen.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';

enum _FeesQuickAction { addFee, collectFees, analytics }

class FeesScreen extends ConsumerStatefulWidget {
  const FeesScreen({super.key});

  @override
  ConsumerState<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends ConsumerState<FeesScreen> {
  int? _selectedFeeClassId;

  @override
  Widget build(BuildContext context) {
    final feesAsync = ref.watch(feeStructuresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Management'),
        actions: [
          PopupMenuButton<_FeesQuickAction>(
            tooltip: 'Finance actions',
            onSelected: (action) {
              switch (action) {
                case _FeesQuickAction.addFee:
                  _showAddFeeDialog(context, ref);
                case _FeesQuickAction.collectFees:
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FeePaymentScreen()));
                case _FeesQuickAction.analytics:
                  context.push('/finance/analytics');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _FeesQuickAction.addFee,
                child: ListTile(
                  leading: Icon(LucideIcons.plus),
                  title: Text('Set Fee Structure'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _FeesQuickAction.collectFees,
                child: ListTile(
                  leading: Icon(LucideIcons.banknote),
                  title: Text('Collect Fees'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _FeesQuickAction.analytics,
                child: ListTile(
                  leading: Icon(LucideIcons.barChart3),
                  title: Text('View Analytics'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: feesAsync.when(
        data: (fees) => fees.isEmpty 
          ? _buildEmptyState(context, ref)
          : _buildFinanceDashboard(context, ref, fees),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.banknote, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No fee structures defined',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showAddFeeDialog(context, ref),
            child: const Text('Create Fee Structure'),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceDashboard(BuildContext context, WidgetRef ref, List<FeeStructure> fees) {
    final classesAsync = ref.watch(classesProvider);
    final ledgerAsync = ref.watch(feesLedgerProvider);
    final classNames = classesAsync.maybeWhen(
      data: (classes) => {for (final schoolClass in classes) schoolClass.id: schoolClass.className},
      orElse: () => <int, String>{},
    );
    final owingRows = ledgerAsync.maybeWhen(
      data: (rows) => rows,
      orElse: () => const <StudentFeesLedgerRow>[],
    );
    final owingCountByFee = <int, int>{};
    final owingAmountByFee = <int, double>{};
    for (final row in owingRows) {
      owingCountByFee.update(row.feeStructureId, (value) => value + 1, ifAbsent: () => 1);
      owingAmountByFee.update(row.feeStructureId, (value) => value + row.balance, ifAbsent: () => row.balance);
    }
    final filteredFees = _selectedFeeClassId == null
        ? fees
        : fees.where((fee) => fee.classId == _selectedFeeClassId).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const FeeRemindersTrackingCard(),
        const SizedBox(height: 24),
        _buildSummaryCards(context, ref),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final filterField = SizedBox(
              width: compact ? double.infinity : 260,
              child: classesAsync.when(
                data: (classes) => DropdownButtonFormField<int?>(
                  initialValue: _selectedFeeClassId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Filter fee structures'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All classes')),
                    ...classes.map(
                      (schoolClass) => DropdownMenuItem<int?>(
                        value: schoolClass.id,
                        child: Text(
                          schoolClass.className,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedFeeClassId = value),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error loading classes: $e'),
              ),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fee Structure by Class',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  filterField,
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: Text(
                    'Fee Structure by Class',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                filterField,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        for (final fee in filteredFees)
          _buildFeeCard(
            context,
            fee: fee,
            classNames: classNames,
            owingCount: owingCountByFee[fee.id] ?? 0,
            owingAmount: owingAmountByFee[fee.id] ?? 0,
          ),
      ],
    );
  }

  Widget _buildFeeCard(
    BuildContext context, {
    required FeeStructure fee,
    required Map<int, String> classNames,
    required int owingCount,
    required double owingAmount,
  }) {
    final statusChip = owingCount > 0
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$owingCount owing',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                Text(
                  'GHS ${owingAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Fully paid',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            final infoSection = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.creditCard, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fee.feeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Amount: GHS ${fee.amount.toStringAsFixed(2)}'
                        '${fee.classId == null ? ' • All classes' : ' • ${classNames[fee.classId] ?? 'Class #${fee.classId}'}'}',
                      ),
                    ],
                  ),
                ),
              ],
            );

            final actionsSection = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: compact ? WrapAlignment.start : WrapAlignment.end,
              children: [
                statusChip,
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FeePaymentScreen(
                        initialTabIndex: 1,
                        initialLedgerClassId: fee.classId,
                        initialLedgerFeeStructureId: fee.id,
                      ),
                    ),
                  ),
                  icon: const Icon(LucideIcons.listFilter, size: 16),
                  label: const Text('View Owing'),
                ),
                if (!compact) const Icon(LucideIcons.chevronRight, size: 18),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoSection,
                  const SizedBox(height: 12),
                  actionsSection,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: infoSection),
                const SizedBox(width: 16),
                Flexible(child: actionsSection),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsProvider);
    final ledgerAsync = ref.watch(feesLedgerProvider);
    final expensesAsync = ref.watch(institutionalExpensesProvider);

    final totalCollected = paymentsAsync.maybeWhen(
      data: (payments) => payments.fold<double>(0, (sum, payment) => sum + payment.amountPaid),
      orElse: () => 0.0,
    );
    final totalOwing = ledgerAsync.maybeWhen(
      data: (rows) => rows.fold<double>(0, (sum, row) => sum + row.balance),
      orElse: () => 0.0,
    );
    final monthExpenses = expensesAsync.maybeWhen(
      data: (expenses) {
        final now = DateTime.now();
        return expenses
            .where((expense) => expense.expenseDate.year == now.year && expense.expenseDate.month == now.month)
            .fold<double>(0, (sum, expense) => sum + expense.amount);
      },
      orElse: () => 0.0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final cards = [
          _buildMiniStat(context, 'Total Collected', 'GHS ${totalCollected.toStringAsFixed(2)}', Colors.green),
          _buildMiniStat(
            context,
            'Owing',
            'GHS ${totalOwing.toStringAsFixed(2)}',
            Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeePaymentScreen(initialTabIndex: 1)),
            ),
          ),
          _buildMiniStat(context, 'Month Expenses', 'GHS ${monthExpenses.toStringAsFixed(2)}', Colors.red),
        ];

        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                SizedBox(width: double.infinity, child: cards[index]),
                if (index != cards.length - 1) const SizedBox(height: 16),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
            const SizedBox(width: 16),
            Expanded(child: cards[2]),
          ],
        );
      },
    );
  }

  Widget _buildMiniStat(BuildContext context, String title, String value, Color color, {VoidCallback? onTap}) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddFeeDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    int? selectedClassId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Consumer(
          builder: (context, dialogRef, _) {
            final classesAsync = dialogRef.watch(classesProvider);

            return AlertDialog(
              title: const Text('Define Fee'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Fee Name (e.g. JHS 3 School Fees)')),
                  TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount (GHS)'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  classesAsync.when(
                    data: (classes) => DropdownButtonFormField<int?>(
                      initialValue: selectedClassId,
                      decoration: const InputDecoration(labelText: 'Apply fee to class'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All classes')),
                        ...classes.map(
                          (schoolClass) => DropdownMenuItem<int?>(
                            value: schoolClass.id,
                            child: Text(schoolClass.className),
                          ),
                        ),
                      ],
                      onChanged: (value) => setDialogState(() => selectedClassId = value),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => Text('Error loading classes: $e'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty || amountController.text.isEmpty) return;

                    await ref.read(financeServiceProvider).createFeeStructure(
                          FeeStructuresCompanion.insert(
                            feeName: nameController.text.trim(),
                            amount: double.parse(amountController.text),
                            category: 'Tuition',
                            academicYear: DateTime.now().year,
                            classId: drift.Value(selectedClassId),
                          ),
                        );
                    final currentUser = ref.read(currentUserProvider);
                    if (currentUser != null) {
                      await ref.read(activityServiceProvider).logActivity(
                            actorUserId: currentUser.id,
                            actorName: currentUser.fullName,
                            actorRole: UserRole.values
                                .firstWhere(
                                  (r) => r.name == currentUser.role,
                                  orElse: () => UserRole.accountant,
                                ),
                            module: 'finance',
                            actionType: 'fee_structure_created',
                            description:
                                'Accountant created fee structure "${nameController.text.trim()}" for academic year ${DateTime.now().year}',
                            isImportant: true,
                          );
                    }
                    ref.invalidate(feeStructuresProvider);
                    ref.invalidate(feesLedgerProvider);
                    ref.invalidate(feesLedgerFilteredProvider);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
