import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'finance_providers.dart';

class FeeRemindersTrackingCard extends ConsumerWidget {
  const FeeRemindersTrackingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feesAsync = ref.watch(feeStructuresProvider);
    final paymentsAsync = ref.watch(feePaymentsProvider);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Automated Fee Reminders & Payment Tracking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            feesAsync.when(
              data: (fees) => paymentsAsync.when(
                data: (payments) {
                  if (fees.isEmpty) {
                    return const Text('No fee structures defined.');
                  }
                  // Example: Show outstanding and paid per fee
                  return Column(
                    children: fees.map((fee) {
                      final paid = payments.where((p) => p.feeStructureId == fee.id).fold<double>(0, (sum, p) => sum + p.amountPaid);
                      final outstanding = fee.amount - paid;
                      final reminderButton = outstanding > 0
                          ? ElevatedButton(
                              child: const Text('Send Reminder'),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Reminder sent for ${fee.feeName}')),
                                );
                              },
                            )
                          : null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 720;
                            final infoSection = Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  outstanding > 0 ? Icons.warning : Icons.check_circle,
                                  color: outstanding > 0 ? Colors.orange : Colors.green,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fee.feeName,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Paid: GHS ${paid.toStringAsFixed(2)} | Outstanding: GHS ${outstanding.toStringAsFixed(2)}',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );

                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  infoSection,
                                  if (reminderButton != null) ...[
                                    const SizedBox(height: 10),
                                    reminderButton,
                                  ],
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: infoSection),
                                if (reminderButton != null) ...[
                                  const SizedBox(width: 12),
                                  reminderButton,
                                ],
                              ],
                            );
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error: $e'),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
