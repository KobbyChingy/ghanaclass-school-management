import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:drift/drift.dart' as drift;
import 'package:url_launcher/url_launcher.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/features/finance/finance_providers.dart';
import 'package:ghanaclass_school_management/features/finance/finance_service.dart';
import 'package:ghanaclass_school_management/features/finance/finance_pdf_service.dart';
import 'package:ghanaclass_school_management/features/students/student_providers.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ghanaclass_school_management/shared/printing/pdf_preview_screen.dart';

class FeePaymentScreen extends ConsumerStatefulWidget {
  const FeePaymentScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialLedgerClassId,
    this.initialLedgerFeeStructureId,
  });

  final int initialTabIndex;
  final int? initialLedgerClassId;
  final int? initialLedgerFeeStructureId;

  @override
  ConsumerState<FeePaymentScreen> createState() => _FeePaymentScreenState();
}

class _FeePaymentScreenState extends ConsumerState<FeePaymentScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late final TabController _tabController;
  
  // Selection
  Student? _selectedStudent;
  FeeStructure? _selectedFee;
  String _paymentMethod = 'cash';

  String _ledgerSearch = '';
  int? _ledgerClassId;
  int? _ledgerFeeStructureId;
  
  // Inputs
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isProcessing = false;

  Future<void> _exportOwingCsv(List<StudentFeesLedgerRow> rows) async {
    final buffer = StringBuffer();
    buffer.writeln('Student ID,Student Name,Class,Fee Structure,Total Fees,Total Paid,Balance,Guardian Name,Guardian Phone,Guardian Email');
    for (final row in rows) {
      String csvCell(String value) => '"${value.replaceAll('"', '""')}"';

      buffer.writeln([
        csvCell(row.studentCode),
        csvCell('${row.firstName} ${row.lastName}'),
        csvCell(row.className ?? '-'),
        csvCell(row.feeName),
        row.totalFees.toStringAsFixed(2),
        row.totalPaid.toStringAsFixed(2),
        row.balance.toStringAsFixed(2),
        csvCell(row.guardianName),
        csvCell(row.guardianPhone),
        csvCell(row.guardianEmail ?? ''),
      ].join(','));
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'owing_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${directory.path}\\$fileName');
    await file.writeAsString(buffer.toString());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Owing list exported to ${file.path}')),
    );
  }

  Future<void> _previewOwingReport({
    required List<StudentFeesLedgerRow> rows,
    required String classFilterLabel,
    required String feeFilterLabel,
  }) async {
    final schoolInfo = await ref.read(institutionalIdentityProvider.future);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: 'Owing Report',
          subtitle: '${rows.length} owing entries',
          pdfFileName: 'owing-report-${DateTime.now().millisecondsSinceEpoch}.pdf',
          buildPdf: (format) => FinancePdfService().buildOwingLedgerPdf(
            rows: rows,
            schoolInfo: schoolInfo,
            classFilterLabel: classFilterLabel,
            feeFilterLabel: feeFilterLabel,
            searchQuery: _ledgerSearch.isEmpty ? null : _ledgerSearch,
            pageFormat: format,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _ledgerClassId = widget.initialLedgerClassId;
    _ledgerFeeStructureId = widget.initialLedgerFeeStructureId;
  }

  List<FeeStructure> _applicableFees(List<FeeStructure> allFees) {
    final studentClassId = _selectedStudent?.classId;
    if (_selectedStudent == null) {
      return allFees;
    }

    return allFees
        .where((fee) => fee.classId == null || fee.classId == studentClassId)
        .toList(growable: false);
  }

  String _normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    // Keep leading + and digits, strip common separators.
    final cleaned = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    return cleaned;
  }

  Future<void> _launchOrCopy(Uri uri, {required String fallbackCopyText}) async {
    try {
      final can = await canLaunchUrl(uri);
      if (can) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    } catch (_) {
      // Fall through to clipboard.
    }

    await Clipboard.setData(ClipboardData(text: fallbackCopyText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open an app. Copied details to clipboard.')),
    );
  }

  Future<void> _contactGuardianSms(StudentFeesLedgerRow row) async {
    final phone = _normalizePhone(row.guardianPhone);
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardian phone number is missing.')),
      );
      return;
    }

    final message =
        'Hello ${row.guardianName},\n\n${row.firstName} ${row.lastName} (ID: ${row.studentCode}) is owing school fees. '
        'Outstanding balance: GHS ${row.balance.toStringAsFixed(2)}.\n\nPlease make payment. Thank you.';

    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );

    await _launchOrCopy(uri, fallbackCopyText: 'SMS to $phone\n\n$message');
  }

  Future<void> _contactGuardianEmail(StudentFeesLedgerRow row) async {
    final email = (row.guardianEmail ?? '').trim();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardian email address is missing.')),
      );
      return;
    }

    final subject = 'Outstanding Fees: ${row.firstName} ${row.lastName} (${row.studentCode})';
    final body =
        'Hello ${row.guardianName},\n\n'
        'This is a reminder that ${row.firstName} ${row.lastName} (ID: ${row.studentCode}) has an outstanding school fees balance.\n\n'
        'Outstanding balance: GHS ${row.balance.toStringAsFixed(2)}\n\n'
        'Please make payment at your earliest convenience.\n\nThank you.';

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    await _launchOrCopy(uri, fallbackCopyText: 'Email to $email\nSubject: $subject\n\n$body');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student')));
      return;
    }
    if (_selectedFee == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a fee type')));
      return;
    }

    // Guard against stale/deleted fee structures.
    final allFees = await ref.read(feeStructuresProvider.future);
    FeeStructure? currentFee;
    for (final f in allFees) {
      if (f.id == _selectedFee!.id) {
        currentFee = f;
        break;
      }
    }
    if (currentFee == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected fee type no longer exists. Please re-select.')),
        );
      }
      return;
    }
    _selectedFee = currentFee;

    setState(() => _isProcessing = true);

    try {
      final amount = double.parse(_amountController.text);
      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }

      final outstanding = await ref
          .read(financeServiceProvider)
          .getOutstandingForStudentFeeStructure(_selectedStudent!.id, _selectedFee!.id);
      if (outstanding > 0.0001 && amount - outstanding > 0.0001) {
        throw Exception('Amount cannot exceed outstanding balance (GHS ${outstanding.toStringAsFixed(2)})');
      }

      final receiptNo = 'RCPT-${DateTime.now().millisecondsSinceEpoch}';

      final payment = PaymentsCompanion(
        studentId: drift.Value(_selectedStudent!.id),
        feeStructureId: drift.Value(_selectedFee!.id),
        amountPaid: drift.Value(amount),
        paymentMethod: drift.Value(_paymentMethod),
        receiptNumber: drift.Value(receiptNo),
        notes: drift.Value(_notesController.text.isNotEmpty ? _notesController.text : null),
        paymentDate: drift.Value(DateTime.now()),
      );

      final paymentId = await ref.read(financeServiceProvider).recordPayment(payment);
      
      // Log Activity
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        await ref.read(activityServiceProvider).logActivity(
          actorUserId: currentUser.id,
          actorName: currentUser.fullName,
          actorRole: UserRole.values.firstWhere((r) => r.name == currentUser.role, orElse: () => UserRole.accountant),
          module: 'finance',
          actionType: 'payment_collected',
          description: 'Collected GHS $amount from ${_selectedStudent!.firstName} ${_selectedStudent!.lastName} for ${_selectedFee!.feeName}',
          isImportant: true,
        );
      }

      // Refresh Providers
      ref.invalidate(paymentsProvider);
      ref.invalidate(feesLedgerProvider);
      ref.invalidate(feesLedgerFilteredProvider);

      if (!mounted) return;
      {
        final screenNavigator = Navigator.of(context);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Row(children: [Icon(LucideIcons.checkCircle, color: Colors.green), SizedBox(width: 8), Text('Payment Recorded')]),
            content: Text('Transaction successful.\nReceipt #: $receiptNo\n\nDo you want to print the receipt?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close dialog
                  if (screenNavigator.canPop()) {
                    screenNavigator.pop(); // Close screen
                  }
                },
                child: const Text('No, Close'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(dialogContext).pop(); // Close dialog
                  // Fetch full payment object
                  final fullPayment = await ref.read(financeServiceProvider).getPaymentById(paymentId);
                  final schoolInfo = await ref.read(institutionalIdentityProvider.future);

                  final feeTotal = _selectedFee!.amount;
                  final paidToDate = await ref
                      .read(financeServiceProvider)
                      .getTotalPaidForStudentFeeStructure(_selectedStudent!.id, _selectedFee!.id);
                  final balanceRemaining = (feeTotal - paidToDate).clamp(0.0, double.infinity);

                  final cashierName = ref.read(currentUserProvider)?.fullName;

                  final receiptStudent = _selectedStudent!;
                  final receiptFee = _selectedFee!;

                  if (!mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PdfPreviewScreen(
                        title: 'Fee Receipt',
                        subtitle: 'Receipt #${fullPayment.receiptNumber}',
                        pdfFileName: 'receipt-${fullPayment.receiptNumber}.pdf',
                        buildPdf: (format) {
                          return FinancePdfService().buildReceiptPdf(
                            payment: fullPayment,
                            student: receiptStudent,
                            feeStructure: receiptFee,
                            schoolInfo: schoolInfo,
                            feeTotal: feeTotal,
                            paidToDate: paidToDate,
                            balanceRemaining: balanceRemaining,
                            receivedByName: cashierName,
                            pageFormat: format,
                          );
                        },
                      ),
                    ),
                  );

                  if (!mounted) return;
                  if (screenNavigator.canPop()) screenNavigator.pop();
                },
                icon: const Icon(LucideIcons.printer),
                label: const Text('Preview & Print'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect Fees'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Collect'),
            Tab(text: 'Owing'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCollectTab(),
          _buildLedgerTab(),
        ],
      ),
    );
  }

  Widget _buildCollectTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStudentSelector(),
                const SizedBox(height: 24),
                _buildFeeSelector(),
                const SizedBox(height: 24),
                _buildPaymentDetails(),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _submitPayment,
                  icon: _isProcessing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.checkCircle),
                  label: Text(_isProcessing ? 'Processing...' : 'Record Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLedgerTab() {
    final classesAsync = ref.watch(classesProvider);
    final feeStructuresAsync = ref.watch(feeStructuresProvider);
    final ledgerAsync = ref.watch(
      feesLedgerFilteredProvider(
        FeesLedgerFilter(
          classId: _ledgerClassId,
          feeStructureId: _ledgerFeeStructureId,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: classesAsync.when(
                  data: (classes) => DropdownButtonFormField<int?>(
                    initialValue: _ledgerClassId,
                    decoration: const InputDecoration(labelText: 'Filter by class'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All classes')),
                      ...classes.map(
                        (schoolClass) => DropdownMenuItem<int?>(
                          value: schoolClass.id,
                          child: Text(schoolClass.className),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _ledgerClassId = value),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => Text('Error loading classes: $e'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: feeStructuresAsync.when(
                  data: (fees) => DropdownButtonFormField<int?>(
                    initialValue: _ledgerFeeStructureId,
                    decoration: const InputDecoration(labelText: 'Filter by fee structure'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All fee structures')),
                      ...fees.map(
                        (fee) => DropdownMenuItem<int?>(
                          value: fee.id,
                          child: Text(fee.feeName),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _ledgerFeeStructureId = value),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => Text('Error loading fee structures: $e'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(LucideIcons.search),
              labelText: 'Search owing student (name or ID)',
            ),
            onChanged: (v) => setState(() => _ledgerSearch = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ledgerAsync.when(
              data: (rows) {
                final classes = classesAsync.maybeWhen(
                  data: (value) => value,
                  orElse: () => const <SchoolClassesData>[],
                );
                final fees = feeStructuresAsync.maybeWhen(
                  data: (value) => value,
                  orElse: () => const <FeeStructure>[],
                );
                final classFilterLabel = _ledgerClassId == null
                    ? 'All classes'
                    : (() {
                        for (final schoolClass in classes) {
                          if (schoolClass.id == _ledgerClassId) {
                            return schoolClass.className;
                          }
                        }
                        return 'Class #$_ledgerClassId';
                      })();
                final feeFilterLabel = _ledgerFeeStructureId == null
                    ? 'All fee structures'
                    : (() {
                        for (final fee in fees) {
                          if (fee.id == _ledgerFeeStructureId) {
                            return fee.feeName;
                          }
                        }
                        return 'Fee #$_ledgerFeeStructureId';
                      })();
                final filtered = rows.where((r) {
                  if (_ledgerSearch.isEmpty) return true;
                  final haystack = '${r.firstName} ${r.lastName} ${r.studentCode}'.toLowerCase();
                  return haystack.contains(_ledgerSearch);
                }).toList();

                final totalOwing = filtered.fold<double>(0, (sum, row) => sum + row.balance);
                final uniqueStudents = filtered.map((row) => row.studentId).toSet().length;

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Filtered owing entries: ${filtered.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(
                                  'Students: $uniqueStudents • Total Owing: GHS ${totalOwing.toStringAsFixed(2)}',
                                  style: const TextStyle(color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: filtered.isEmpty ? null : () => _exportOwingCsv(filtered),
                            icon: const Icon(LucideIcons.fileSpreadsheet, size: 16),
                            label: const Text('Export CSV'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: filtered.isEmpty
                                ? null
                                : () => _previewOwingReport(
                                      rows: filtered,
                                      classFilterLabel: classFilterLabel,
                                      feeFilterLabel: feeFilterLabel,
                                    ),
                            icon: const Icon(LucideIcons.printer, size: 16),
                            label: const Text('Print / Preview'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No owing students found.'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final r = filtered[index];
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(child: Text(r.firstName.isNotEmpty ? r.firstName[0] : 'S')),
                                    title: Text('${r.firstName} ${r.lastName}'),
                                    subtitle: Text(
                                      'ID: ${r.studentCode}${r.className == null ? '' : ' • ${r.className}'}\n'
                                      '${r.feeName}: GHS ${r.totalFees.toStringAsFixed(2)}  Paid: GHS ${r.totalPaid.toStringAsFixed(2)}  Balance: GHS ${r.balance.toStringAsFixed(2)}',
                                    ),
                                    isThreeLine: true,
                                    trailing: Wrap(
                                      spacing: 8,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        IconButton(
                                          tooltip: 'Send SMS to guardian',
                                          onPressed: () => _contactGuardianSms(r),
                                          icon: const Icon(LucideIcons.messageCircle, size: 18),
                                        ),
                                        IconButton(
                                          tooltip: 'Send email to guardian',
                                          onPressed: () => _contactGuardianEmail(r),
                                          icon: const Icon(LucideIcons.mail, size: 18),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            final messenger = ScaffoldMessenger.of(context);

                                            final student = await ref.read(studentServiceProvider).getStudentById(r.studentId);
                                            if (!mounted) return;
                                            if (student == null) {
                                              messenger.showSnackBar(
                                                const SnackBar(content: Text('Student not found.'), backgroundColor: Colors.red),
                                              );
                                              return;
                                            }

                                            setState(() {
                                              _selectedStudent = student;
                                              _selectedFee = null;
                                              _amountController.text = r.balance.toStringAsFixed(2);
                                            });

                                            final fees = await ref.read(feeStructuresProvider.future);
                                            if (!mounted) return;
                                            if (fees.isNotEmpty) {
                                              final applicableFees = _applicableFees(fees);
                                              final preferred = applicableFees.cast<FeeStructure?>().firstWhere(
                                                    (fee) => fee?.id == r.feeStructureId,
                                                    orElse: () => applicableFees.isNotEmpty ? applicableFees.first : null,
                                                  );
                                              if (preferred != null) {
                                                setState(() {
                                                  _selectedFee = preferred;
                                                  _amountController.text = r.balance.toStringAsFixed(2);
                                                });
                                              }
                                            }

                                            _tabController.animateTo(0);
                                          },
                                          icon: const Icon(LucideIcons.banknote, size: 16),
                                          label: const Text('Collect'),
                                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Student Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_selectedStudent != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(_selectedStudent!.firstName[0])),
                title: Text('${_selectedStudent!.firstName} ${_selectedStudent!.lastName}'),
                subtitle: Text('ID: ${_selectedStudent!.studentId}'),
                trailing: IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => setState(() => _selectedStudent = null),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () => _showStudentSearchDialog(),
                icon: const Icon(LucideIcons.search),
                label: const Text('Select Student'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeSelector() {
    final feesAsync = ref.watch(feeStructuresProvider);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Purpose', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            feesAsync.when(
              data: (fees) {
                final applicableFees = _applicableFees(fees);

                if (applicableFees.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedStudent == null
                            ? 'No fee types found. Please set a fee structure first.'
                            : 'No fee structure applies to the selected student class yet.',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(LucideIcons.arrowLeft, size: 18),
                        label: const Text('Go back to Fee Structures'),
                      ),
                    ],
                  );
                }

                FeeStructure? selected;
                if (_selectedFee != null) {
                  for (final f in applicableFees) {
                    if (f.id == _selectedFee!.id) {
                      selected = f;
                      break;
                    }
                  }
                }

                return DropdownButtonFormField<FeeStructure>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Select Fee Type *'),
                  items: applicableFees
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(
                            f.classId == null
                                ? '${f.feeName} (GHS ${f.amount})'
                                : '${f.feeName} (GHS ${f.amount})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedFee = v;
                    if (v != null) _amountController.text = v.amount.toString();
                  }),
                  validator: (v) => v == null ? 'Required' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => Text('Error loading fees: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transaction Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount Received (GHS) *', prefixText: 'GH₵ '),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
              ],
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (Optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _StudentSearchDialog(
        onSelect: (s) => setState(() {
          _selectedStudent = s;
          if (_selectedFee != null && _selectedFee!.classId != null && _selectedFee!.classId != s.classId) {
            _selectedFee = null;
          }
        }),
      ),
    );
  }
}

class _StudentSearchDialog extends ConsumerStatefulWidget {
  final Function(Student) onSelect;
  const _StudentSearchDialog({required this.onSelect});

  @override
  ConsumerState<_StudentSearchDialog> createState() => _StudentSearchDialogState();
}

class _StudentSearchDialogState extends ConsumerState<_StudentSearchDialog> {
  final _searchController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsListProvider(
      StudentFilter(searchQuery: _searchController.text),
    ));

    return Dialog(
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by Name or ID',
                prefixIcon: Icon(LucideIcons.search),
              ),
              onChanged: (v) => setState(() {}), // Trigger rebuild for filter
            ),
            const SizedBox(height: 16),
            Expanded(
              child: studentsAsync.when(
                data: (students) => ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (_, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final s = students[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(s.firstName[0])),
                      title: Text('${s.firstName} ${s.lastName}'),
                      subtitle: Text(s.studentId),
                      onTap: () {
                        widget.onSelect(s);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
