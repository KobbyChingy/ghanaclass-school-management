import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/features/shop/shop_providers.dart';
import 'package:ghanaclass_school_management/features/students/student_providers.dart';
import 'package:ghanaclass_school_management/shared/widgets/portal_surface.dart';

class ShopWalletScreen extends ConsumerStatefulWidget {
  const ShopWalletScreen({super.key});

  @override
  ConsumerState<ShopWalletScreen> createState() => _ShopWalletScreenState();
}

class _ShopWalletScreenState extends ConsumerState<ShopWalletScreen> {
  Student? _selectedStudent;

  final TextEditingController _topUpAmount = TextEditingController();
  final TextEditingController _reference = TextEditingController();
  bool _saving = false;

  String _studentName(Student student) {
    final parts = <String>[
      student.firstName,
      if (student.otherNames != null && student.otherNames!.trim().isNotEmpty)
        student.otherNames!.trim(),
      student.lastName,
    ];
    return parts.where((part) => part.trim().isNotEmpty).join(' ');
  }

  @override
  void dispose() {
    _topUpAmount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickStudent() async {
    final picked = await showDialog<Student>(
      context: context,
      builder: (context) => const _StudentPickerDialog(),
    );
    if (!mounted || picked == null) return;

    setState(() => _selectedStudent = picked);
    ref.invalidate(studentWalletProvider(picked.id));
    ref.invalidate(walletTransactionsProvider(picked.id));
  }

  Future<void> _topUp() async {
    final currentUser = ref.read(currentUserProvider);
    final student = _selectedStudent;
    if (currentUser == null || student == null) {
      if (student == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a student')),
        );
      }
      return;
    }

    final amount = double.tryParse(_topUpAmount.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final actorRole = UserRole.values.firstWhere(
      (role) => role.name == currentUser.role,
      orElse: () => UserRole.shop,
    );

    setState(() => _saving = true);
    try {
      final service = ref.read(shopServiceProvider);
      await service.topUpWallet(
        studentId: student.id,
        amount: amount,
        reference: _reference.text,
        actorUserId: currentUser.id,
        actorName: currentUser.fullName,
        actorRole: actorRole,
      );

      if (!mounted) return;
      _topUpAmount.clear();
      _reference.clear();
      ref.invalidate(studentWalletProvider(student.id));
      ref.invalidate(walletTransactionsProvider(student.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Top-up successful')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = _selectedStudent;
    final academicYear = ref.watch(activeYearProvider);
    final term = ref.watch(activeTermProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PortalHeroBanner(
              eyebrow: 'Shop wallets',
              title: 'Student Wallet Management',
              subtitle: 'Search students, top up balances, and monitor wallet movements from the shop portal.',
              icon: Icons.account_balance_wallet_outlined,
              primary: const Color(0xFFD97706),
              accent: const Color(0xFF2563EB),
              metrics: [
                PortalHeroMetric(label: 'Academic year', value: '$academicYear'),
                PortalHeroMetric(label: 'Active term', value: 'Term $term'),
                PortalHeroMetric(
                  label: 'Selected student',
                  value: student == null ? 'None' : _studentName(student),
                ),
              ],
              trailing: FilledButton.tonalIcon(
                onPressed: _pickStudent,
                icon: const Icon(Icons.person_search_outlined),
                label: Text(
                  student == null ? 'Select student' : _studentName(student),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (student != null)
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PortalSectionPanel(
                        title: 'Wallet Balance',
                        subtitle: 'Current student wallet position and top-up controls.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Consumer(
                              builder: (context, ref, _) {
                                final walletAsync = ref.watch(
                                  studentWalletProvider(student.id),
                                );
                                return walletAsync.when(
                                  data: (wallet) => Text(
                                    'Balance: GHS ${(wallet?.balance ?? 0).toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  loading: () => const Text('Balance: ...'),
                                  error: (e, _) => Text('Error: $e'),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _topUpAmount,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Top-up amount (GHS)',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _reference,
                              decoration: const InputDecoration(
                                labelText: 'Reference (optional, MoMo/Cash note)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _saving ? null : _topUp,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.add_circle_outline),
                              label: const Text('Top up'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: PortalSectionPanel(
                        title: 'Transactions',
                        subtitle: 'Recent wallet credits, debits, and references for the selected student.',
                        child: Consumer(
                          builder: (context, ref, _) {
                            final txAsync = ref.watch(
                              walletTransactionsProvider(student.id),
                            );
                            return txAsync.when(
                              data: (transactions) {
                                if (transactions.isEmpty) {
                                  return const Center(
                                    child: Text('No transactions yet'),
                                  );
                                }
                                return ListView.separated(
                                  itemCount: transactions.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final transaction = transactions[index];
                                    return ListTile(
                                      title: Text(
                                        '${transaction.type} • GHS ${transaction.amount.toStringAsFixed(2)}',
                                      ),
                                      subtitle: Text(
                                        '${transaction.createdAt}${transaction.reference == null ? '' : ' • ${transaction.reference}'}',
                                      ),
                                    );
                                  },
                                );
                              },
                              loading: () =>
                                  const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Center(child: Text('Error: $e')),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'Select a student to view wallet balance and transactions.',
                  ),
                ),
              ),
          ],
        ),
      ),
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
        StudentFilter(
          searchQuery:
              _controller.text.trim().isEmpty ? null : _controller.text.trim(),
        ),
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
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search students',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: studentsAsync.when(
                data: (students) {
                  if (students.isEmpty) {
                    return const Center(child: Text('No students found'));
                  }
                  return ListView.separated(
                    itemCount: students.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return ListTile(
                        title: Text('${student.firstName} ${student.lastName}'.trim()),
                        subtitle: Text('Student ID: ${student.id}'),
                        onTap: () => Navigator.of(context).pop(student),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
